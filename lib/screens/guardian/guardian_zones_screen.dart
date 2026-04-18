import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GuardianZonesScreen extends StatefulWidget {
  const GuardianZonesScreen({super.key});

  @override
  State<GuardianZonesScreen> createState() => _GuardianZonesScreenState();
}

class _GuardianZonesScreenState extends State<GuardianZonesScreen> {
  String _pairingCode = "Loading...";
  double _radiusMeters = 200;
  GeoPoint? _childLocation;
  GeoPoint _zoneCenter = const GeoPoint(6.9271, 79.8612); // Default to Colombo
  bool _hasCustomCenter = false;
  String _childName = "Child";
  bool _saving = false;
  final Completer<GoogleMapController> _mapController = Completer();

  StreamSubscription? _childSub;
  StreamSubscription? _alertSub;

  bool _isOutside = false;

  @override
  void initState() {
    super.initState();
    _loadPairingCodeAndChildLocation();
  }

  @override
  void dispose() {
    _childSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPairingCodeAndChildLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final guardianDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final code = guardianDoc.data()?['pairingCode'] ?? "No Code";

    if (!mounted) return;
    setState(() => _pairingCode = code);

    _listenForAlerts(code);

    _childSub = FirebaseFirestore.instance
        .collection('users')
        .where('guardianIds', arrayContains: user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) return;

      final data = snap.docs.first.data();
      final GeoPoint? loc = data['currentLocation'];
      final String name = data['name'] ?? "Child";

      if (mounted) {
        setState(() {
          _childLocation = loc;
          _childName = name;
          
          if (loc != null && !_hasCustomCenter) {
            _zoneCenter = loc;
            _centerMap(loc.latitude, loc.longitude);
          }
        });
      }
    });
  }

  void _listenForAlerts(String pairingCode) {
    _alertSub?.cancel();
    _alertSub = FirebaseFirestore.instance
        .collection('alerts')
        .doc(pairingCode)
        .collection('items')
        .where('status', isEqualTo: 'active')
        .where('type', isEqualTo: 'GEOFENCE_EXIT')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() => _isOutside = snap.docs.isNotEmpty);
    });
  }

  Future<void> _centerMap(double lat, double lng) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  Future<void> _saveSafeZone() async {
    if (_pairingCode == "Loading..." || _pairingCode == "No Code") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pairing code not loaded.")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final zonesRef = FirebaseFirestore.instance
          .collection('zones')
          .doc(_pairingCode)
          .collection('items');

      await zonesRef.add({
        'name': 'Home Zone',
        'centerLat': _zoneCenter.latitude,
        'centerLng': _zoneCenter.longitude,
        'radiusMeters': _radiusMeters.round(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Safe Zone saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save zone: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildOutsideAlert() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "⚠️ $_childName is outside of safe area!",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isUsingChild = _childLocation != null && !_hasCustomCenter;

    return Scaffold(
      appBar: AppBar(title: const Text("Zones")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isOutside) _buildOutsideAlert(),

            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Safe Zone Center",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      isUsingChild
                          ? "Auto-centered on $_childName"
                          : "Custom Location (Tap map to change)",
                      style: const TextStyle(color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Lat: ${_zoneCenter.latitude.toStringAsFixed(5)} | Lng: ${_zoneCenter.longitude.toStringAsFixed(5)}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              height: 180,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                  zoom: 15,
                ),
                onTap: (LatLng pos) {
                  setState(() {
                    _zoneCenter = GeoPoint(pos.latitude, pos.longitude);
                    _hasCustomCenter = true;
                  });
                },
                circles: {
                  Circle(
                    circleId: const CircleId('preview_zone'),
                    center: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                    radius: _radiusMeters,
                    fillColor: Colors.blue.withOpacity(0.15),
                    strokeColor: Colors.blue,
                    strokeWidth: 2,
                  )
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('zone_center'),
                    position: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                    infoWindow: const InfoWindow(title: "Safe Zone Center"),
                  )
                },
                onMapCreated: (controller) {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                },
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),

            const SizedBox(height: 16),

            const Text("Radius (meters)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text("${_radiusMeters.round()} m",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Slider(
              value: _radiusMeters,
              min: 50,
              max: 1000,
              divisions: 19,
              label: "${_radiusMeters.round()} m",
              onChanged: (v) => setState(() => _radiusMeters = v),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveSafeZone,
                icon: const Icon(Icons.save),
                label: Text(_saving ? "Saving..." : "Save Safe Zone"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            const Text(
              "Saved Zones",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _pairingCode == "Loading..." || _pairingCode == "No Code"
                  ? const Center(child: Text("No pairing code loaded."))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('zones')
                          .doc(_pairingCode)
                          .collection('items')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text("Error: ${snapshot.error}"));
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                              child: Text("No zones saved yet."));
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final z = docs[i].data();
                            final name = z['name'] ?? 'Zone';
                            final radius = z['radiusMeters'] ?? 0;
                            final active = z['isActive'] == true;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.my_location,
                                  color: active ? Colors.green : Colors.grey,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text("Radius: ${radius}m"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.grey.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        active ? "ACTIVE" : "OFF",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              active ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        FirebaseFirestore.instance
                                            .collection('zones')
                                            .doc(_pairingCode)
                                            .collection('items')
                                            .doc(docs[i].id)
                                            .delete();
                                      },
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
          ],
        ),
      ),
    );
  }
}
