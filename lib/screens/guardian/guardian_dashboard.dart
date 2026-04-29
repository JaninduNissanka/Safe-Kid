import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';

class GuardianDashboard extends StatefulWidget {
  const GuardianDashboard({super.key});

  @override
  State<GuardianDashboard> createState() => _GuardianDashboardState();
}

class _GuardianDashboardState extends State<GuardianDashboard> {
  final Completer<GoogleMapController> _mapController = Completer();

  String _pairingCode = "Loading...";
  String _childName = "Child";
  int _battery = 0;
  bool _isOnline = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isOutside = false;
  bool _isAlertOpen = false;
  LatLng? _childPos;

  StreamSubscription? _locSub;
  StreamSubscription? _childSub;
  StreamSubscription? _zoneSub;
  StreamSubscription? _alertSub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _childSub?.cancel();
    _zoneSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _pairingCode = "No Code");
      return;
    }
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final code = doc.data()?['pairingCode'] ?? "No Code";
        setState(() => _pairingCode = code);
        if (code != "No Code") {
          _startListeners(code);
        }
      } else {
        if (mounted) setState(() => _pairingCode = "No Code");
      }
    } catch (e) {
      if (mounted) setState(() => _pairingCode = "No Code");
    }
  }

  void _startListeners(String code) {
    _locSub = AuthService().locationStream(code).listen((snap) {
      if (snap.exists && (snap.data()?['isSosActive'] ?? false) && !_isAlertOpen) _showSosAlert();
    });

    _zoneSub = FirebaseFirestore.instance.collection('zones').doc(code).collection('items')
        .where('isActive', isEqualTo: true).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _circles = snap.docs.map((doc) {
          final data = doc.data();
          return Circle(
            circleId: CircleId(doc.id),
            center: LatLng((data['centerLat'] as num).toDouble(), (data['centerLng'] as num).toDouble()),
            radius: (data['radiusMeters'] as num).toDouble(),
            fillColor: Colors.blue.withOpacity(0.08),
            strokeColor: Colors.blue.withOpacity(0.4),
            strokeWidth: 2,
          );
        }).toSet();
      });
      _checkGeofenceStatus();
    });

    _alertSub = FirebaseFirestore.instance.collection('alerts').doc(code).collection('items')
        .where('status', isEqualTo: 'active').where('type', isEqualTo: 'GEOFENCE_EXIT').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => _isOutside = snap.docs.isNotEmpty);
      _checkGeofenceStatus();
    });

    _childSub = FirebaseFirestore.instance.collection('locations').doc(code).snapshots().listen((snap) async {
      if (snap.exists && mounted) {
        final data = snap.data()!;
        final lat = (data['latitude'] as num).toDouble();
        final lng = (data['longitude'] as num).toDouble();
        _childPos = LatLng(lat, lng);
        _childName = data['name'] ?? 'Child';
        _battery = data['battery'] ?? 0;
        _isOnline = data['isOnline'] ?? false;
        
        final icon = await _createPremiumMarker(_childName, _isOutside ? Colors.red : Colors.blue);
        
        setState(() {
          _markers = {
            Marker(
              markerId: const MarkerId('child'),
              position: _childPos!,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
            )
          };
        });
        _checkGeofenceStatus();
      }
    });
  }

  Future<BitmapDescriptor> _createPremiumMarker(String name, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 180.0;
    
    // Draw Shadow
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2), 45, shadowPaint);

    // Outer Circle
    final Paint paint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 40, paint);
    
    // Inner Glow
    final Paint innerPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), 34, innerPaint);

    // Icon (Child Face Placeholder)
    final TextPainter iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = const TextSpan(text: '👦', style: TextStyle(fontSize: 45));
    iconPainter.layout();
    iconPainter.paint(canvas, Offset(size / 2 - 25, size / 2 - 32));

    // Name Label Background
    final RRect labelRect = RRect.fromRectAndRadius(Rect.fromLTWH(size / 2 - 50, size / 2 + 35, 100, 30), const Radius.circular(15));
    canvas.drawRRect(labelRect, Paint()..color = color);

    // Name Text
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: name, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold));
    textPainter.layout();
    textPainter.paint(canvas, Offset(size / 2 - textPainter.width / 2, size / 2 + 41));

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _checkGeofenceStatus() {
    if (_childPos == null || _circles.isEmpty) return;
    final circle = _circles.first;
    final distance = _calculateDistance(_childPos!, circle.center);
    if (distance <= circle.radius && _isOutside) {
      setState(() => _isOutside = false);
    } else if (distance > circle.radius) {
      setState(() => _isOutside = true);
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var a = 0.5 - math.cos((p2.latitude - p1.latitude) * p) / 2 + math.cos(p1.latitude * p) * math.cos(p2.latitude * p) * (1 - math.cos((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  Future<void> _centerOnChild() async {
    if (_childPos == null || !_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_childPos!, 16));
  }

  Future<void> _zoom(bool zoomIn) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    if (zoomIn) controller.animateCamera(CameraUpdate.zoomIn());
    else controller.animateCamera(CameraUpdate.zoomOut());
  }

  void _showSosAlert() {
    _isAlertOpen = true;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("🚨 SOS ALERT!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text("Your child needs immediate assistance!"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () async { Navigator.pop(c); _isAlertOpen = false; await AuthService().setSos(pairingCode: _pairingCode, isActive: false); }, child: const Text("RESOLVE", style: TextStyle(color: Colors.white)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0, 
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text("SafeKid Guardian", style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor, fontWeight: FontWeight.w900, fontSize: 22)),
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.blueGrey), onPressed: () async { await AuthService().signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen())); })],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 14),
            markers: _markers,
            circles: _circles,
            onMapCreated: (c) => _mapController.complete(c),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          Positioned(
            top: 16, left: 0, right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildCompactPairingPill(context),
            ),
          ),

          Positioned(
            top: 100, right: 15,
            child: Column(
              children: [
                _buildMapBtn(Icons.add, () => _zoom(true)),
                const SizedBox(height: 10),
                _buildMapBtn(Icons.remove, () => _zoom(false)),
                const SizedBox(height: 10),
                _buildMapBtn(Icons.my_location, _centerOnChild, color: Colors.indigo),
              ],
            ),
          ),

          Positioned(
            bottom: 30, left: 20, right: 20,
            child: _buildPremiumStatusCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPairingPill(BuildContext context) {
    if (_pairingCode == "Loading...") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_pairingCode == "No Code") {
       return const SizedBox(); 
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vpn_key_rounded, size: 18, color: Theme.of(context).brightness == Brightness.light ? Colors.blue.shade700 : Colors.blue.shade300),
          const SizedBox(width: 12),
          Text(
            _pairingCode,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 3.0,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _pairingCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("📋 Code $_pairingCode copied!\nEnter this code on your child's device to link their location."),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: Colors.indigo,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.copy_rounded, size: 16, color: Theme.of(context).brightness == Brightness.light ? Colors.blue.shade700 : Colors.blue.shade300),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black54}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))]),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildPremiumStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: _isOutside ? Colors.red.withOpacity(0.3) : Theme.of(context).dividerColor),
        boxShadow: [BoxShadow(color: (_isOutside ? Colors.red : Colors.black).withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: _isOutside ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Icon(_isOutside ? Icons.warning_rounded : Icons.child_care, color: _isOutside ? Colors.red : Colors.blue, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_childName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 4),
                    Text(_isOutside ? "OUTSIDE SAFE ZONE" : "Perfectly Safe", style: TextStyle(color: _isOutside ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$_battery%", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const Text("BATTERY", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusChip(Icons.wifi, _isOnline ? "ONLINE" : "OFFLINE", _isOnline ? Colors.green : Colors.grey),
              _statusChip(Icons.location_on, _isOutside ? "BREACH" : "INSIDE", _isOutside ? Colors.red : Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10))]),
    );
  }
}
