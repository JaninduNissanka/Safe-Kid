import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';
import '../../services/route_anomaly_detector.dart';
import '../../widgets/convex_curve_clipper.dart';

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
  String _batteryStatus = "unknown";
  String _connectionType = "unknown";
  bool _isOnline = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isOutside = false;
  bool _isAlertOpen = false;
  LatLng? _childPos;
  String _activity = "stationary";

  List<Map<String, dynamic>> _devices = [];
  String? _selectedChildId;

  StreamSubscription? _locSub;
  StreamSubscription? _childSub;
  StreamSubscription? _zoneSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _pairingRequestsSub;
  bool _isPairingRequestOpen = false;

  // Route Playback & History variables
  bool _isHistoryMode = false;
  bool _showTimelineLog = false;
  DateTime _selectedHistoryDate = DateTime.now();
  List<LatLng> _historyPoints = [];
  List<DateTime> _historyTimestamps = [];
  int _currentHistoryIndex = 0;
  bool _isHistoryPlaying = false;
  Timer? _historyPlayTimer;
  int _playbackSpeedMultiplier = 1;
  Set<Polyline> _polylines = {};
  List<AnomalyPoint> _historyAnomalies = [];
  AnomalyPoint? _selectedAnomaly;
  bool _isMapLoading = true;

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
    _pairingRequestsSub?.cancel();
    _historyPlayTimer?.cancel();
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
    _locSub = AuthService().devicesLocationStream(code).listen((snap) {
      if (!mounted) return;
      for (var doc in snap.docs) {
        final data = doc.data();
        if ((data['isSosActive'] ?? false) && !_isAlertOpen) {
          _showSosAlert(doc.id, data['name'] ?? 'Child');
          break;
        }
      }
    });

    _zoneSub = FirebaseFirestore.instance.collection('zones').doc(code).collection('items')
        .where('isActive', isEqualTo: true).snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _circles = snap.docs.where((doc) {
          final data = doc.data();
          return _isZoneScheduleActiveNow(data);
        }).map((doc) {
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

    final parentUid = FirebaseAuth.instance.currentUser?.uid;
    if (parentUid != null) {
      _pairingRequestsSub?.cancel();
      _pairingRequestsSub = AuthService().pendingPairingRequestsStream(parentUid).listen((snap) {
        if (!mounted) return;
        for (var doc in snap.docs) {
          final data = doc.data();
          final String requestId = doc.id;
          final String childName = data['childName'] ?? 'Child';
          _showPairingRequestDialog(requestId, childName);
          break; // Show one request dialog at a time
        }
      });
    }

    _childSub = AuthService().devicesLocationStream(code).listen((snap) async {
      if (!mounted) return;
      
      final List<Map<String, dynamic>> updatedDevices = [];
      final Set<Marker> newMarkers = {};
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final childId = doc.id;
        final name = data['name'] ?? 'Child';
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final battery = (data['battery'] as num?)?.toInt() ?? 0;
        final batteryStatus = data['batteryStatus'] as String? ?? 'unknown';
        final connectionType = data['connectionType'] as String? ?? 'unknown';
        final isOnline = data['isOnline'] as bool? ?? false;
        final isSosActive = data['isSosActive'] as bool? ?? false;

        if (lat != null && lng != null) {
          final pos = LatLng(lat, lng);
          final bool childOutside = _isChildOutsideGeofence(pos);
          
          final color = isSosActive ? Colors.red : (childOutside ? Colors.orange : Colors.blue);
          final icon = await _createPremiumMarker(name, color);
          
          newMarkers.add(
            Marker(
              markerId: MarkerId(childId),
              position: pos,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: name, snippet: "Battery: $battery%"),
            )
          );

          updatedDevices.add({
            'id': childId,
            'name': name,
            'position': pos,
            'battery': battery,
            'batteryStatus': batteryStatus,
            'connectionType': connectionType,
            'isOnline': isOnline,
            'isOutside': childOutside,
            'isSosActive': isSosActive,
            'activity': data['activity'] as String? ?? 'stationary',
          });
        }
      }

      setState(() {
        _devices = updatedDevices;
        _markers = newMarkers;
        
        if (_selectedChildId == null && _devices.isNotEmpty) {
          _selectedChildId = _devices.first['id'];
        }
        
        if (_selectedChildId != null) {
          final selected = _devices.firstWhere(
            (d) => d['id'] == _selectedChildId,
            orElse: () => _devices.first,
          );
          _selectedChildId = selected['id'];
          _childPos = selected['position'];
          _childName = selected['name'];
          _battery = selected['battery'];
          _batteryStatus = selected['batteryStatus'] ?? 'unknown';
          _connectionType = selected['connectionType'] ?? 'unknown';
          _isOnline = selected['isOnline'];
          _isOutside = selected['isOutside'];
          _activity = selected['activity'] ?? 'stationary';
        }
      });
      _checkGeofenceStatus();
    });
  }

  void _showPairingRequestDialog(String requestId, String childName) {
    if (_isPairingRequestOpen) return;
    _isPairingRequestOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text("Pairing Request", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("Child '$childName' wants to link to your dashboard. Do you approve?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              _isPairingRequestOpen = false;
              await AuthService().rejectPairingRequest(requestId);
            },
            child: const Text("Deny", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              _isPairingRequestOpen = false;
              await AuthService().approvePairingRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final TextPainter iconPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    iconPainter.text = const TextSpan(text: '👦', style: TextStyle(fontSize: 45));
    iconPainter.layout();
    iconPainter.paint(canvas, const Offset(size / 2 - 25, size / 2 - 32));

    // Name Label Background
    final RRect labelRect = RRect.fromRectAndRadius(const Rect.fromLTWH(size / 2 - 50, size / 2 + 35, 100, 30), const Radius.circular(15));
    canvas.drawRRect(labelRect, Paint()..color = color);

    // Name Text
    final TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(text: name, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold));
    textPainter.layout();
    textPainter.paint(canvas, Offset(size / 2 - textPainter.width / 2, size / 2 + 41));

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  bool _isZoneScheduleActiveNow(Map<String, dynamic> data) {
    final bool hasSchedule = data['hasSchedule'] ?? false;
    if (!hasSchedule) return true;

    final now = DateTime.now();

    // 1. Date Range Check
    final bool hasDateRange = data['hasDateRange'] ?? false;
    if (hasDateRange) {
      final String? startDateStr = data['startDate'];
      final String? endDateStr = data['endDate'];
      if (startDateStr != null && endDateStr != null) {
        try {
          final startDt = DateTime.parse(startDateStr);
          final endDt = DateTime.parse(endDateStr).add(const Duration(days: 1));
          if (now.isBefore(startDt) || now.isAfter(endDt)) return false;
        } catch (_) {}
      }
    }

    // 2. Days of Week Check
    final List<dynamic>? selectedDays = data['selectedDays'];
    if (selectedDays != null && selectedDays.isNotEmpty) {
      if (!selectedDays.contains(now.weekday)) return false;
    }

    // 3. Time Window Check
    final String? startTimeStr = data['startTime'];
    final String? endTimeStr = data['endTime'];
    if (startTimeStr != null && endTimeStr != null) {
      try {
        final currentMinutes = now.hour * 60 + now.minute;
        final startParts = startTimeStr.split(':');
        final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endParts = endTimeStr.split(':');
        final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        if (startMinutes <= endMinutes) {
          return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
        } else {
          return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
        }
      } catch (_) {}
    }

    return true;
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
    if (zoomIn) {
      controller.animateCamera(CameraUpdate.zoomIn());
    } else {
      controller.animateCamera(CameraUpdate.zoomOut());
    }
  }

  void _showSosAlert(String childId, String childName) {
    _isAlertOpen = true;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text("dashboard.sos_title".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text("$childName has triggered an SOS! Please assist immediately."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
            ),
            onPressed: () async {
              Navigator.pop(c);
              _isAlertOpen = false;
              await AuthService().setSos(
                pairingCode: _pairingCode,
                isActive: false,
                childId: childId,
                childName: childName,
              );
            },
            child: Text("dashboard.resolve".tr(), style: const TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1D4ED8),
        toolbarHeight: 75,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GuardianLogo(
              size: 38,
              parentColor: Colors.white,
              childColor: Color(0xFF93C5FD),
            ),
            const SizedBox(width: 12),
            Text(
              "dashboard.title".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // Blue header background band (only covers the top clipped curve region to blend with AppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: Container(
                color: const Color(0xFF1D4ED8),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: ConvexCurveClipper(),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(target: LatLng(6.9271, 79.8612), zoom: 14),
                  markers: getMapMarkers(),
                  polylines: _polylines,
                  circles: _circles,
                  onMapCreated: (c) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(c);
                    }
                    setState(() {
                      _isMapLoading = false;
                    });
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
            if (_isMapLoading)
              Positioned.fill(
                child: ClipPath(
                  clipper: ConvexCurveClipper(),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Theme.of(context).brightness == Brightness.light
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF60A5FA),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Loading Map...",
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            Positioned(
              top: 24, left: 0, right: 0,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isHistoryMode) _buildChildSelector(),
                  if (!_isHistoryMode) const SizedBox(height: 12),
                  if (_isHistoryMode && _selectedAnomaly != null) ...[
                    _buildAnomalyDetailCard(),
                    const SizedBox(height: 12),
                  ],
                  _isHistoryMode ? _buildHistoryControlPanel() : _buildPremiumStatusCard(),
                ],
              ),
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left side: Clickable QR Icon and Code
          GestureDetector(
            onTap: _showPairingQrModal,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.blue.shade700
                        : Colors.blue.shade300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _pairingCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical divider to separate visually
          Container(
            height: 20,
            width: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.2),
          ),
          // Right side: Clickable Copy Button
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _pairingCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("dashboard.copied".tr(namedArgs: {'code': _pairingCode})),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  backgroundColor: Colors.indigo,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.blue.shade700
                      : Colors.blue.shade300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPairingQrModal() {
    debugPrint("DEBUG: Opening pairing QR code modal for code: $_pairingCode");
    try {
      showDialog(
        context: context,
        builder: (c) {
          return AlertDialog(
            title: const Center(
              child: Text(
                "Pairing QR Code",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Scan this QR code or use the code below to connect the child's app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: _pairingCode,
                        size: 200.0,
                        errorStateBuilder: (cxt, err) {
                          return Center(
                            child: Text(
                              "QR Error: $err",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _pairingCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.indigo),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _pairingCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("dashboard.copied".tr(namedArgs: {'code': _pairingCode})),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              backgroundColor: Colors.indigo,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text(
                    "Close",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("DEBUG ERROR: Failed to showDialog: $e");
    }
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
                    Text(_isOutside ? "dashboard.outside_safe_zone".tr() : "dashboard.perfectly_safe".tr(), style: TextStyle(color: _isOutside ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getBatteryIcon(),
                    color: _getBatteryColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "$_battery%", 
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 18,
                          color: _getBatteryColor(),
                        ),
                      ),
                      Text(
                        _batteryStatus == 'charging' ? "Charging" : "dashboard.battery".tr(), 
                        style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityRecognitionBadge(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusChip(
                _getConnectionIcon(), 
                _getConnectionText(), 
                _getConnectionColor(),
              ),
              _statusChip(Icons.location_on, _isOutside ? "dashboard.breach".tr() : "dashboard.inside".tr(), _isOutside ? Colors.red : Colors.blue),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHistoryMode = true;
                  });
                  _loadHistoryData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 14, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        "History",
                        style: TextStyle(
                          color: Colors.indigo.shade600,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistoryData() async {
    if (_selectedChildId == null) return;
    
    final selectedDevice = _devices.firstWhere(
      (d) => d['id'] == _selectedChildId,
      orElse: () => {},
    );
    
    final childName = selectedDevice['name'];
    if (childName == null) return;

    try {
      // 1. Fetch Today's Route History
      final snap = await AuthService().getRouteHistory(
        pairingCode: _pairingCode,
        childId: childName,
        date: _selectedHistoryDate,
      );

      final List<LatLng> points = [];
      final List<DateTime> timestamps = [];
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final timestamp = data['timestamp'] as Timestamp?;
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
          timestamps.add(timestamp?.toDate() ?? DateTime.now());
        }
      }

      // 2. Fetch Parental Speed Limit Rule
      final rulesDoc = await FirebaseFirestore.instance.collection('rules').doc(_pairingCode).get();
      final double speedLimitKmh = (rulesDoc.data()?['speedLimitKmh'] ?? 40.0).toDouble();

      // 3. Fetch Baseline History Points for past 7 days
      final baselineSnap = await AuthService().getBaselineHistory(
        pairingCode: _pairingCode,
        childId: childName,
        beforeDate: _selectedHistoryDate,
      );
      final List<LatLng> baselinePoints = [];
      for (var doc in baselineSnap.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        if (lat != null && lng != null) {
          baselinePoints.add(LatLng(lat, lng));
        }
      }

      // 4. Fetch Active Zones for Late Night Out-of-Zone evaluation
      final zonesSnap = await FirebaseFirestore.instance.collection('zones').doc(_pairingCode).collection('items').where('isActive', isEqualTo: true).get();
      final List<Map<String, dynamic>> activeZones = zonesSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // 5. Run AI Route Anomaly Detector
      final anomalies = RouteAnomalyDetector.detectAnomalies(
        points: points,
        timestamps: timestamps,
        baselinePoints: baselinePoints,
        speedLimitKmh: speedLimitKmh,
        activeZones: activeZones,
      );

      setState(() {
        _historyPoints = points;
        _historyTimestamps = timestamps;
        _historyAnomalies = anomalies;
        _selectedAnomaly = null;
        _currentHistoryIndex = 0;
        _isHistoryPlaying = false;
        _historyPlayTimer?.cancel();
        
        // Split polyline into normal (indigo) and anomalous (red) segments
        final Set<Polyline> segments = {};
        for (int i = 1; i < _historyPoints.length; i++) {
          final p1 = _historyPoints[i - 1];
          final p2 = _historyPoints[i];

          // Check if this segment contains an anomaly
          final bool isSegAnomalous = _historyAnomalies.any((a) => a.position == p2 || a.position == p1);

          segments.add(
            Polyline(
              polylineId: PolylineId('history_segment_$i'),
              points: [p1, p2],
              color: isSegAnomalous ? Colors.red.shade600 : Colors.indigo,
              width: 5,
            ),
          );
        }

        // Fallback to simple polyline if no points to construct segments
        if (segments.isEmpty && _historyPoints.isNotEmpty) {
          segments.add(
            Polyline(
              polylineId: const PolylineId('history_route'),
              points: _historyPoints,
              color: Colors.indigo,
              width: 5,
            ),
          );
        }

        _polylines = segments;
      });

      _updateHistoryMarkerAndCamera();
    } catch (e) {
      print("Error loading history: $e");
    }
  }

  Future<void> _updateHistoryMarkerAndCamera() async {
    if (_historyPoints.isEmpty || !_mapController.isCompleted) return;
    
    final controller = await _mapController.future;
    
    if (_currentHistoryIndex == 0) {
      double minLat = _historyPoints.first.latitude;
      double maxLat = _historyPoints.first.latitude;
      double minLng = _historyPoints.first.longitude;
      double maxLng = _historyPoints.first.longitude;
      
      for (var p in _historyPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else {
      final currentPoint = _historyPoints[_currentHistoryIndex];
      controller.animateCamera(CameraUpdate.newLatLng(currentPoint));
    }
  }

  void _toggleHistoryPlayback() {
    if (_isHistoryPlaying) {
      _pauseHistoryPlayback();
    } else {
      _startHistoryPlayback();
    }
  }

  void _startHistoryPlayback() {
    if (_historyPoints.isEmpty) return;
    
    setState(() => _isHistoryPlaying = true);
    
    if (_currentHistoryIndex >= _historyPoints.length - 1) {
      setState(() => _currentHistoryIndex = 0);
    }

    _historyPlayTimer?.cancel();
    final intervalMs = (1000 / _playbackSpeedMultiplier).round();
    _historyPlayTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_currentHistoryIndex < _historyPoints.length - 1) {
        setState(() {
          _currentHistoryIndex++;
        });
        _updateHistoryMarkerAndCamera();
      } else {
        _pauseHistoryPlayback();
      }
    });
  }

  void _pauseHistoryPlayback() {
    _historyPlayTimer?.cancel();
    setState(() => _isHistoryPlaying = false);
  }

  void _changePlaybackSpeed() {
    setState(() {
      if (_playbackSpeedMultiplier == 1) {
        _playbackSpeedMultiplier = 2;
      } else if (_playbackSpeedMultiplier == 2) {
        _playbackSpeedMultiplier = 4;
      } else {
        _playbackSpeedMultiplier = 1;
      }
    });
    
    if (_isHistoryPlaying) {
      _startHistoryPlayback();
    }
  }

  Future<void> _selectHistoryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedHistoryDate) {
      setState(() {
        _selectedHistoryDate = picked;
      });
      _loadHistoryData();
    }
  }

  Set<Marker> getMapMarkers() {
    if (!_isHistoryMode) return _markers;
    
    final Set<Marker> histMarkers = {};
    
    if (_historyPoints.isNotEmpty) {
      histMarkers.add(
        Marker(
          markerId: const MarkerId('history_start'),
          position: _historyPoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start Location'),
        )
      );
      
      histMarkers.add(
        Marker(
          markerId: const MarkerId('history_end'),
          position: _historyPoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End Location'),
        )
      );
      
      if (_currentHistoryIndex < _historyPoints.length) {
        histMarkers.add(
          Marker(
            markerId: const MarkerId('history_current'),
            position: _historyPoints[_currentHistoryIndex],
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: 'Current Position',
              snippet: DateFormat('HH:mm:ss').format(_historyTimestamps[_currentHistoryIndex]),
            ),
          )
        );
      }

      // Add Anomaly Hazard Markers
      for (int i = 0; i < _historyAnomalies.length; i++) {
        final anomaly = _historyAnomalies[i];
        histMarkers.add(
          Marker(
            markerId: MarkerId('anomaly_$i'),
            position: anomaly.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: anomaly.title,
              snippet: "${DateFormat('hh:mm a').format(anomaly.timestamp)}: Tap for AI details",
            ),
            onTap: () {
              setState(() {
                _selectedAnomaly = anomaly;
              });
            },
          )
        );
      }
    }
    return histMarkers;
  }

  Widget _buildHistoryControlPanel() {
    final hasHistory = _historyPoints.isNotEmpty;
    final currentDateStr = DateFormat('yyyy-MM-dd').format(_selectedHistoryDate);
    final timestampStr = hasHistory && _currentHistoryIndex < _historyTimestamps.length
        ? DateFormat('hh:mm:ss a').format(_historyTimestamps[_currentHistoryIndex])
        : '--:--:--';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Route History: $_childName",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Date: $currentDateStr",
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded, color: Colors.blue),
                onPressed: _selectHistoryDate,
              ),
              IconButton(
                icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _isHistoryMode = false;
                    _polylines = {};
                    _isHistoryPlaying = false;
                    _historyPlayTimer?.cancel();
                  });
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showTimelineLog = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_showTimelineLog ? Colors.indigo.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: !_showTimelineLog ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Route Playback",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_showTimelineLog ? Colors.indigo.shade800 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showTimelineLog = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _showTimelineLog ? Colors.indigo.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _showTimelineLog ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Day Timeline",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _showTimelineLog ? Colors.indigo.shade800 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          
          if (_showTimelineLog) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('locations')
                    .doc(_pairingCode)
                    .collection('devices')
                    .doc(_selectedChildId)
                    .collection('timeline')
                    .where('dateStr', isEqualTo: currentDateStr)
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: Colors.indigo),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_view_day_rounded, size: 36, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              "No timeline events logged for this day.",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final events = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final doc = events[index];
                      final data = doc.data();
                      final type = data['type'] as String? ?? 'activity';
                      final title = data['title'] as String? ?? 'Event';
                      final message = data['message'] as String? ?? '';
                      final timestamp = data['timestamp'] as Timestamp?;
                      final lat = data['latitude'] as double?;
                      final lng = data['longitude'] as double?;
                      final value = data['value'];
                      final activityVal = type == 'activity' ? value as String? : null;

                      final timeStr = timestamp != null
                          ? DateFormat('hh:mm a').format(timestamp.toDate())
                          : '--:--';

                      final icon = _getTimelineIcon(type, activityVal);
                      final color = _getTimelineColor(type);

                      return InkWell(
                        onTap: (lat != null && lng != null)
                            ? () async {
                                if (_mapController.isCompleted) {
                                  final controller = await _mapController.future;
                                  controller.animateCamera(
                                    CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
                                  );
                                }
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: color, width: 2),
                                    ),
                                    child: Icon(icon, size: 12, color: color),
                                  ),
                                  if (index < events.length - 1)
                                    Container(
                                      width: 2,
                                      height: 35,
                                      color: Theme.of(context).dividerColor.withOpacity(0.4),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: Theme.of(context).textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).brightness == Brightness.light
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (lat != null && lng != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 10, color: Colors.blue.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Tap to show on map",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ] else ...[
            if (!hasHistory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    const Icon(Icons.route_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      "No location logs found for this day.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Time: $timestampStr",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    "Point: ${_currentHistoryIndex + 1} of ${_historyPoints.length}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _currentHistoryIndex.toDouble(),
                min: 0,
                max: (_historyPoints.length - 1).toDouble(),
                activeColor: Colors.indigo,
                inactiveColor: Colors.indigo.withOpacity(0.1),
                onChanged: (val) {
                  setState(() {
                    _currentHistoryIndex = val.toInt();
                  });
                  _updateHistoryMarkerAndCamera();
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, color: Colors.indigo),
                    onPressed: () {
                      setState(() {
                        _currentHistoryIndex = 0;
                      });
                      _updateHistoryMarkerAndCamera();
                    },
                  ),
                  GestureDetector(
                    onTap: _toggleHistoryPlayback,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.indigo,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isHistoryPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _changePlaybackSpeed,
                    child: Text(
                      "${_playbackSpeedMultiplier}x",
                      style: const TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ],
        ],
      ),
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryStatus == 'charging') return Icons.battery_charging_full;
    if (_battery >= 90) return Icons.battery_full;
    if (_battery >= 75) return Icons.battery_6_bar;
    if (_battery >= 50) return Icons.battery_4_bar;
    if (_battery >= 25) return Icons.battery_2_bar;
    if (_battery >= 10) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor() {
    if (_batteryStatus == 'charging') return Colors.green.shade600;
    if (_battery <= 20) return Colors.red.shade600;
    if (_battery <= 50) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  IconData _getConnectionIcon() {
    if (!_isOnline) return Icons.cloud_off;
    switch (_connectionType) {
      case 'wifi':
        return Icons.wifi;
      case 'cellular':
        return Icons.signal_cellular_alt;
      case 'offline':
        return Icons.cloud_off;
      default:
        return Icons.wifi;
    }
  }

  String _getConnectionText() {
    if (!_isOnline) return "dashboard.offline".tr();
    switch (_connectionType) {
      case 'wifi':
        return "WiFi";
      case 'cellular':
        return "Cellular";
      case 'offline':
        return "dashboard.offline".tr();
      default:
        return "dashboard.online".tr();
    }
  }

  Color _getConnectionColor() {
    return _isOnline && _connectionType != 'offline' ? Colors.green : Colors.grey;
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10))]),
    );
  }

  bool _isChildOutsideGeofence(LatLng childPos) {
    if (_circles.isEmpty) return false;
    final circle = _circles.first;
    final distance = _calculateDistance(childPos, circle.center);
    return distance > circle.radius;
  }

  Widget _buildChildSelector() {
    if (_devices.isEmpty) return const SizedBox();
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final child = _devices[index];
          final isSelected = child['id'] == _selectedChildId;
          final isSosActive = child['isSosActive'] ?? false;
          final isOutside = child['isOutside'] ?? false;
          
          Color borderColor = isSelected
              ? (isSosActive ? Colors.red : (isOutside ? Colors.orange : Colors.blue))
              : Colors.grey.withOpacity(0.3);
          
          Color bgColor = isSelected
              ? borderColor.withOpacity(0.15)
              : Theme.of(context).cardColor.withOpacity(0.9);
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedChildId = child['id'];
                  _childPos = child['position'];
                  _childName = child['name'];
                  _battery = child['battery'];
                  _batteryStatus = child['batteryStatus'] ?? 'unknown';
                  _connectionType = child['connectionType'] ?? 'unknown';
                  _isOnline = child['isOnline'];
                  _isOutside = child['isOutside'];
                  _activity = child['activity'] ?? 'stationary';
                });
                _centerOnChild();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSosActive
                          ? Icons.warning_amber_rounded
                          : (isOutside ? Icons.error_outline : Icons.face),
                      size: 16,
                      color: isSosActive
                          ? Colors.red
                          : (isOutside ? Colors.orange : (isSelected ? Colors.blue : Colors.grey)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      child['name'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey,
                      ),
                    ),
                    if (isSosActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text("SOS", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnomalyDetailCard() {
    if (_selectedAnomaly == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.95),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedAnomaly!.type == 'SPEED'
                      ? Icons.speed_rounded
                      : _selectedAnomaly!.type == 'UNUSUAL_TIME'
                          ? Icons.nights_stay_rounded
                          : Icons.alt_route_rounded,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAnomaly!.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('hh:mm a').format(_selectedAnomaly!.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red.shade700),
                onPressed: () {
                  setState(() {
                    _selectedAnomaly = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedAnomaly!.message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade900,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRecognitionBadge() {
    IconData iconData;
    String label;
    Color color;

    switch (_activity.toLowerCase()) {
      case 'walking':
        iconData = Icons.directions_walk_rounded;
        label = "Walking";
        color = Colors.green.shade700;
        break;
      case 'running':
        iconData = Icons.directions_run_rounded;
        label = "Running";
        color = Colors.deepOrange.shade600;
        break;
      case 'in_vehicle':
        iconData = Icons.directions_car_rounded;
        label = "In a Vehicle";
        color = Colors.blue.shade700;
        break;
      case 'stationary':
      default:
        iconData = Icons.accessibility_new_rounded;
        label = "Stationary";
        color = Colors.blueGrey;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            "Live Activity: ",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white60,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTimelineIcon(String type, String? activityVal) {
    switch (type) {
      case 'alert_sos':
        return Icons.warning_amber_rounded;
      case 'sos_resolved':
        return Icons.check_circle_rounded;
      case 'alert_geofence':
        return Icons.error_outline_rounded;
      case 'geofence_return':
        return Icons.home_rounded;
      case 'alert_speed':
        return Icons.speed_rounded;
      case 'alert_anomaly':
        return Icons.alt_route_rounded;
      case 'activity':
        switch (activityVal?.toLowerCase()) {
          case 'walking':
            return Icons.directions_walk_rounded;
          case 'running':
            return Icons.directions_run_rounded;
          case 'in_vehicle':
            return Icons.directions_car_rounded;
          case 'stationary':
          default:
            return Icons.accessibility_new_rounded;
        }
      default:
        return Icons.circle;
    }
  }

  Color _getTimelineColor(String type) {
    switch (type) {
      case 'alert_sos':
        return Colors.red;
      case 'sos_resolved':
        return Colors.green;
      case 'alert_geofence':
        return Colors.orange.shade700;
      case 'geofence_return':
        return Colors.blue;
      case 'alert_speed':
        return Colors.deepOrange;
      case 'alert_anomaly':
        return Colors.purple;
      case 'activity':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}

class GuardianLogo extends StatelessWidget {
  final double size;
  final Color? parentColor;
  final Color? childColor;

  const GuardianLogo({
    super.key, 
    this.size = 38.0,
    this.parentColor,
    this.childColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Premium Blue Theme colors for adaptive light/dark mode contrast
    final defaultParentColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8); // Vibrant Blue / Royal Blue
    final defaultChildColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6);  // Light Sky Blue / Accent Blue

    return CustomPaint(
      size: Size(size, size),
      painter: GuardianLogoPainter(
        parentColor: parentColor ?? defaultParentColor,
        childColor: childColor ?? defaultChildColor,
      ),
    );
  }
}

class GuardianLogoPainter extends CustomPainter {
  final Color parentColor;
  final Color childColor;

  GuardianLogoPainter({
    required this.parentColor,
    required this.childColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final parentPaint = Paint()
      ..color = parentColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final childPaint = Paint()
      ..color = childColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Draw Parent Head (tilted oval)
    final parentHeadCenter = Offset(w * 0.36, h * 0.15);
    final parentHeadRadiusX = w * 0.08;
    final parentHeadRadiusY = h * 0.10;
    canvas.save();
    canvas.translate(parentHeadCenter.dx, parentHeadCenter.dy);
    canvas.rotate(-0.08);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: parentHeadRadiusX * 2, height: parentHeadRadiusY * 2),
      parentPaint,
    );
    canvas.restore();

    // 2. Draw Parent Body
    final parentPath = Path();
    parentPath.moveTo(w * 0.36, h * 0.23); // Neck base
    // Left shoulder and arm
    parentPath.quadraticBezierTo(w * 0.24, h * 0.25, w * 0.21, h * 0.40);
    parentPath.quadraticBezierTo(w * 0.20, h * 0.48, w * 0.23, h * 0.50);
    parentPath.quadraticBezierTo(w * 0.25, h * 0.42, w * 0.29, h * 0.32);
    // Left side of dress
    parentPath.quadraticBezierTo(w * 0.28, h * 0.52, w * 0.24, h * 0.62);
    // Left leg
    parentPath.quadraticBezierTo(w * 0.28, h * 0.75, w * 0.19, h * 0.83);
    parentPath.quadraticBezierTo(w * 0.28, h * 0.72, w * 0.33, h * 0.63);
    // Right leg
    parentPath.quadraticBezierTo(w * 0.40, h * 0.78, w * 0.43, h * 0.85);
    parentPath.quadraticBezierTo(w * 0.45, h * 0.75, w * 0.47, h * 0.63);
    // Right side of dress
    parentPath.lineTo(w * 0.48, h * 0.61);
    // Right arm extending to hand
    parentPath.quadraticBezierTo(w * 0.44, h * 0.45, w * 0.54, h * 0.50);
    parentPath.quadraticBezierTo(w * 0.45, h * 0.35, w * 0.42, h * 0.25);
    parentPath.close();
    canvas.drawPath(parentPath, parentPaint);

    // 3. Draw Child Head
    final childHeadCenter = Offset(w * 0.66, h * 0.50);
    final childHeadRadiusX = w * 0.07;
    final childHeadRadiusY = h * 0.09;
    canvas.save();
    canvas.translate(childHeadCenter.dx, childHeadCenter.dy);
    canvas.rotate(0.05);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: childHeadRadiusX * 2, height: childHeadRadiusY * 2),
      childPaint,
    );
    canvas.restore();

    // 4. Draw Child Body
    final childPath = Path();
    childPath.moveTo(w * 0.66, h * 0.56); // Neck base
    // Left arm extending up-left to hand
    childPath.quadraticBezierTo(w * 0.60, h * 0.56, w * 0.54, h * 0.50);
    childPath.quadraticBezierTo(w * 0.61, h * 0.62, w * 0.63, h * 0.65);
    // Left side torso and left leg
    childPath.quadraticBezierTo(w * 0.61, h * 0.76, w * 0.60, h * 0.84);
    childPath.quadraticBezierTo(w * 0.65, h * 0.76, w * 0.68, h * 0.68);
    // Right leg
    childPath.quadraticBezierTo(w * 0.72, h * 0.76, w * 0.77, h * 0.84);
    childPath.quadraticBezierTo(w * 0.73, h * 0.72, w * 0.71, h * 0.65);
    // Right arm extending up-right
    childPath.quadraticBezierTo(w * 0.78, h * 0.60, w * 0.82, h * 0.48);
    childPath.quadraticBezierTo(w * 0.74, h * 0.54, w * 0.69, h * 0.56);
    childPath.close();
    canvas.drawPath(childPath, childPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
