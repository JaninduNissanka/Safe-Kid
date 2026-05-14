import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class GuardianZonesScreen extends StatefulWidget {
  const GuardianZonesScreen({super.key});

  @override
  State<GuardianZonesScreen> createState() => _GuardianZonesScreenState();
}

class _GuardianZonesScreenState extends State<GuardianZonesScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _pairingCode = "Loading...";
  double _radiusMeters = 1000;
  GeoPoint _zoneCenter = const GeoPoint(6.9271, 79.8612);
  bool _hasCustomCenter = false;
  bool _saving = false;

  StreamSubscription? _childLocSub;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _childLocSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final code = doc.data()?['pairingCode'] ?? "No Code";
      setState(() => _pairingCode = code);
      if (code != "No Code") _startChildLocationListener(code);
    }
  }

  void _startChildLocationListener(String code) {
    _childLocSub = _db.collection('locations').doc(code).snapshots().listen((snap) {
      if (snap.exists && mounted && !_hasCustomCenter) {
        final data = snap.data()!;
        final lat = (data['latitude'] as num).toDouble();
        final lng = (data['longitude'] as num).toDouble();
        setState(() {
          _zoneCenter = GeoPoint(lat, lng);
        });
        _centerMap(lat, lng);
      }
    });
  }

  Future<void> _centerMap(double lat, double lng) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  Future<void> _saveSafeZone() async {
    if (_pairingCode == "Loading..." || _pairingCode == "No Code") return;
    setState(() => _saving = true);

    try {
      final zonesRef = _db.collection('zones').doc(_pairingCode).collection('items');
      final oldZones = await zonesRef.where('isActive', isEqualTo: true).get();
      final batch = _db.batch();
      for (var doc in oldZones.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      final newZoneRef = zonesRef.doc();
      batch.set(newZoneRef, {
        'name': 'Active Safe Zone',
        'centerLat': _zoneCenter.latitude,
        'centerLng': _zoneCenter.longitude,
        'radiusMeters': _radiusMeters.round(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("zones.synced".tr())));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteZone(String docId) async {
    await _db.collection('zones').doc(_pairingCode).collection('items').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("zones.title".tr())),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("zones.step_1".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.withOpacity(0.5))),
                    clipBehavior: Clip.antiAlias,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: LatLng(_zoneCenter.latitude, _zoneCenter.longitude), zoom: 14),
                      onMapCreated: (c) => _mapController.complete(c),
                      onTap: (pos) => setState(() {
                        _zoneCenter = GeoPoint(pos.latitude, pos.longitude);
                        _hasCustomCenter = true;
                      }),
                      circles: {
                        Circle(
                          circleId: const CircleId('preview'),
                          center: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                          radius: _radiusMeters,
                          fillColor: Colors.blue.withOpacity(0.1),
                          strokeColor: Colors.blue,
                          strokeWidth: 2,
                        )
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("zones.radius".tr(args: [_radiusMeters.round().toString()]), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                      ElevatedButton(
                        onPressed: _saving ? null : _saveSafeZone,
                        child: Text(_saving ? "zones.saving".tr() : "zones.apply_zone".tr()),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusMeters,
                    min: 100, max: 2000,
                    onChanged: (v) => setState(() => _radiusMeters = v),
                  ),
                  const Divider(height: 40),
                  Text("zones.step_2".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildZonesList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesList() {
    if (_pairingCode == "Loading...") return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('zones').doc(_pairingCode).collection('items').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Text("zones.no_zones".tr(), style: const TextStyle(color: Colors.grey));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final z = docs[i].data() as Map<String, dynamic>;
            final isActive = z['isActive'] ?? false;
            return Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: isActive ? Colors.green : Colors.grey),
                title: Text("zones.perimeter".tr(args: [z['radiusMeters'].toString()])),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteZone(docs[i].id)),
              ),
            );
          },
        );
      },
    );
  }
}
