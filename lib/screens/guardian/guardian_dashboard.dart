import 'dart:async';
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

  // Variables
  String _pairingCode = "Loading...";
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  String _childStatus = "Waiting for child to connect...";

  // Multi-child support
  List<DocumentSnapshot> _allChildren = [];
  String? _selectedChildId;

  // SOS popup protection
  bool _isAlertOpen = false;
  int? _lastSosTsMs;

  // Subscriptions
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _locSub; // SOS doc
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _childSub; // user child stream
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _zoneSub; // zones stream
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _geofenceSub; // EXIT alerts stream

  bool _isOutside = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.9271, 79.8612),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchParentData();
    _startListeningToChildLocationFromUsers(); // map tracking (existing)
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _childSub?.cancel();
    _zoneSub?.cancel();
    _geofenceSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchParentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final code = doc.data()?['pairingCode'] ?? "No Code";

    // ✅ FIX: prevent setState after dispose
    if (!mounted) return;

    setState(() {
      _pairingCode = code;
    });

    // ✅ Start SOS listener once pairing code is ready
    _startListeningToSosFromLocationsDoc(code);
    _startListeningToActiveZones(code);
    _startListeningToGeofenceAlerts(code);
  }

  void _startListeningToGeofenceAlerts(String pairingCode) {
    _geofenceSub?.cancel();
    _geofenceSub = FirebaseFirestore.instance
        .collection('alerts')
        .doc(pairingCode)
        .collection('items')
        .where('status', isEqualTo: 'active')
        .where('type', isEqualTo: 'GEOFENCE_EXIT')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _isOutside = snap.docs.isNotEmpty;
      });
      _updateMarkersAndStatus();
    });
  }

  // =========================
  // SOS: listen to locations/{pairingCode}
  // =========================
  void _startListeningToSosFromLocationsDoc(String pairingCode) {
    _locSub?.cancel();

    _locSub = AuthService().locationStream(pairingCode).listen((snap) {
      final data = snap.data();
      if (data == null) return;

      final bool isSos = (data['isSosActive'] ?? false) as bool;

      // timestamp to avoid repeated dialogs
      final ts = data['sosTriggeredAt'];
      final int tsMs = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;

      if (isSos && !_isAlertOpen && _lastSosTsMs != tsMs) {
        _lastSosTsMs = tsMs;
        _showSosAlert();
      }
    });
  }

  // =========================
  // ZONES: listen to zones/{pairingCode}/items where isActive=true
  // =========================
  void _startListeningToActiveZones(String pairingCode) {
    _zoneSub?.cancel();
    _zoneSub = FirebaseFirestore.instance
        .collection('zones')
        .doc(pairingCode)
        .collection('items')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final circles = snapshot.docs.map((doc) {
        final data = doc.data();
        final lat = (data['centerLat'] as num).toDouble();
        final lng = (data['centerLng'] as num).toDouble();
        final radius = (data['radiusMeters'] as num).toDouble();

        return Circle(
          circleId: CircleId(doc.id),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: Colors.blue.withOpacity(0.15),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        );
      }).toSet();

      setState(() {
        _circles = circles;
      });
    });
  }

  // --- SOS ALERT DIALOG ---
  void _showSosAlert() {
    if (_isAlertOpen) return;
    if (!mounted) return;

    setState(() => _isAlertOpen = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 40),
            SizedBox(width: 10),
            Text(
              "SOS ALERT!",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Child has pressed the SOS button!\n\nCheck their location on the map immediately.",
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // ✅ FIX: check mounted before setState
              if (!mounted) return;
              setState(() => _isAlertOpen = false);

              // ✅ Pro: resolve SOS (turn off)
              if (_pairingCode != "Loading..." && _pairingCode != "No Code") {
                await AuthService().setSos(
                  pairingCode: _pairingCode,
                  isActive: false,
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("RESOLVE"),
          ),
        ],
      ),
    );
  }

  // ======================================
  // Existing location stream (kept for now)
  // This listens to child in users collection.
  // Later we can move child location into locations/{pairingCode}.
  // ======================================
  void _startListeningToChildLocationFromUsers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _childSub?.cancel();

    _childSub = FirebaseFirestore.instance
        .collection('users')
        .where('guardianIds', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _allChildren = snapshot.docs;

        if (_selectedChildId == null && _allChildren.isNotEmpty) {
          _selectedChildId = _allChildren.first.id;
        }
      });

      _updateMarkersAndStatus();
    });
  }

  void _updateMarkersAndStatus() {
    final Set<Marker> newMarkers = {};
    String selectedStatus = "No child selected";

    for (var doc in _allChildren) {
      final data = doc.data() as Map<String, dynamic>;
      final GeoPoint? loc = data['currentLocation'];
      final String name = data['name'] ?? "Child";
      final bool isSelected = doc.id == _selectedChildId;
      final bool isOnline = data['isOnline'] ?? false;

      if (loc != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(loc.latitude, loc.longitude),
            infoWindow: InfoWindow(
                title: name, snippet: isOnline ? "Online" : "Offline"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _isOutside && isSelected 
                ? BitmapDescriptor.hueRed 
                : (isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure)
            ),
          ),
        );

        if (isSelected) {
          if (_isOutside) {
            selectedStatus = "⚠️ $name IS OUTSIDE ZONE!";
          } else {
            selectedStatus = isOnline ? "Tracking $name" : "$name is Offline";
          }

          // Auto-center on selected child if moving
          _centerOnSelectedChild(loc.latitude, loc.longitude);
        }
      }
    }

    setState(() {
      _markers = newMarkers;
      _childStatus = selectedStatus;
    });
  }

  Future<void> _centerOnSelectedChild(double lat, double lng) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _pairingCode));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Code Copied!")));
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guardian Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPairingCard(),
          if (_allChildren.length > 1) _buildChildSelector(),
          Expanded(child: _buildMap()),
          _buildBottomInfoBar(),
        ],
      ),
    );
  }

  Widget _buildPairingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _copyCode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Pairing Code",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pairingCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Tap to copy",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copyCode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _allChildren.length,
        itemBuilder: (context, index) {
          final doc = _allChildren[index];
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? "Child";
          final isSelected = doc.id == _selectedChildId;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(name),
              onSelected: (selected) {
                setState(() {
                  _selectedChildId = doc.id;
                });
                _updateMarkersAndStatus();
              },
              selectedColor: Colors.orange.shade100,
              checkmarkColor: Colors.orange,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _initialPosition,
          markers: _markers,
          circles: _circles,
          zoomControlsEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
        ),
        if (_isOutside) _buildEmergencyBanner(),
      ],
    );
  }

  Widget _buildEmergencyBanner() {
    return Positioned(
      top: 10,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "GEOFENCE ALERT: Child is outside!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_markers.isEmpty || !_mapController.isCompleted) return;
                final controller = await _mapController.future;
                controller.animateCamera(CameraUpdate.newLatLngZoom(_markers.first.position, 16));
              },
              child: const Text("LOCATE", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.08),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            _isOutside ? Icons.warning_rounded : Icons.gps_fixed, 
            size: 28, 
            color: _isOutside ? Colors.red : Colors.orange
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _childStatus,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: _isOutside ? Colors.red.shade700 : Colors.black
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Updates every 5 seconds",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_markers.isEmpty || !_mapController.isCompleted) return;
              final m = _markers.first;
              final controller = await _mapController.future;
              controller.animateCamera(CameraUpdate.newLatLng(m.position));
            },
            child: Text("Center", style: TextStyle(color: _isOutside ? Colors.red : Colors.blue)),
          ),
        ],
      ),
    );
  }
}
