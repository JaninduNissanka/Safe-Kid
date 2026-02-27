import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianZonesScreen extends StatefulWidget {
  const GuardianZonesScreen({super.key});

  @override
  State<GuardianZonesScreen> createState() => _GuardianZonesScreenState();
}

class _GuardianZonesScreenState extends State<GuardianZonesScreen> {
  String _pairingCode = "Loading...";
  double _radiusMeters = 200;
  GeoPoint? _childLocation;
  String _childName = "Child";
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPairingCodeAndChildLocation();
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

    FirebaseFirestore.instance
        .collection('users')
        .where('guardianIds', arrayContains: user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) return;

      final data = snap.docs.first.data();
      final GeoPoint? loc = data['currentLocation'];
      final String name = data['name'] ?? "Child";

      setState(() {
        _childLocation = loc;
        _childName = name;
      });
    });
  }

  Future<void> _saveSafeZone() async {
    if (_pairingCode == "Loading..." || _pairingCode == "No Code") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pairing code not loaded.")),
      );
      return;
    }

    if (_childLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Child location not available yet.")),
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
        'centerLat': _childLocation!.latitude,
        'centerLng': _childLocation!.longitude,
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

  @override
  Widget build(BuildContext context) {
    final hasLocation = _childLocation != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Zones")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      hasLocation
                          ? "Using $_childName current location"
                          : "Waiting for child location...",
                      style: TextStyle(
                          color: hasLocation ? Colors.green : Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (hasLocation)
                      Text(
                        "Lat: ${_childLocation!.latitude.toStringAsFixed(5)}\nLng: ${_childLocation!.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
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

            // ✅ SHOW SAVED ZONES LIST
            Expanded(
              child: _pairingCode == "Loading..." || _pairingCode == "No Code"
                  ? const Center(child: Text("No pairing code loaded."))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('zones')
                          .doc(_pairingCode)
                          .collection('items')
                          .orderBy('createdAt', descending: true)
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
                                trailing: Container(
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
