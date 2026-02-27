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
  String _childStatus = "Waiting for child to connect...";

  // SOS popup protection
  bool _isAlertOpen = false;
  int? _lastSosTsMs;

  // Subscriptions
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _locSub; // SOS doc
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _childSub; // user child stream

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
      if (snapshot.docs.isEmpty) return;

      final childDoc = snapshot.docs.first;
      final data = childDoc.data();

      final GeoPoint? location = data['currentLocation'];
      final String name = data['name'] ?? "Child";

      if (location != null) {
        _updateMap(location.latitude, location.longitude, name);
        setState(() => _childStatus = "Tracking $name");
      } else {
        setState(() => _childStatus = "Waiting for child location...");
      }
    });
  }

  Future<void> _updateMap(double lat, double lng, String name) async {
    if (!_mapController.isCompleted) return;
    final GoogleMapController controller = await _mapController.future;

    if (!mounted) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('child'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: name, snippet: "Active now"),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      };
    });

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

  Widget _buildMap() {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: _initialPosition,
      markers: _markers,
      zoomControlsEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
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
          const Icon(Icons.gps_fixed, size: 28, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _childStatus,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
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
            child: const Text("Center"),
          ),
        ],
      ),
    );
  }
}
