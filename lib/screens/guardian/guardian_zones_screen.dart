import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import '../../widgets/convex_curve_clipper.dart';

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
  LatLng? _childLocation;

  List<dynamic> _searchResults = [];
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _childLocSub?.cancel();
    _searchController.dispose();
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
    _childLocSub = _db.collection('locations').doc(code).collection('devices').snapshots().listen((snap) {
      if (snap.docs.isNotEmpty && mounted) {
        final data = snap.docs.first.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _childLocation = LatLng(lat, lng);
            if (!_hasCustomCenter) {
              _zoneCenter = GeoPoint(lat, lng);
              _centerMap(lat, lng);
            }
          });
        }
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

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });

    try {
      final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5");
      final response = await http.get(url, headers: {
        'User-Agent': 'SafeKidApp/1.0',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Error searching location: $e");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "Just now";
    final dt = ts.toDate();
    final day = dt.day.toString().padLeft(2, '0');
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final month = months[dt.month - 1];
    final year = dt.year;
    
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$day $month $year, $hour:$minute $ampm";
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
            const ZoneLogo(size: 44),
            const SizedBox(width: 12),
            Text(
              "zones.title".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF1D4ED8),
        child: ClipPath(
          clipper: ConvexCurveClipper(),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Set Perimeter Boundary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Search for a location or tap on the map to place the Safe Zone center.",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Address Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.light 
                                  ? Colors.grey.shade300 
                                  : Colors.white10
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              hintText: "Search city, school, or address...",
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: const Icon(Icons.search, color: Colors.blue),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchResults = []);
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (val) {
                              setState(() {});
                            },
                            onSubmitted: _searchLocation,
                          ),
                        ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.light 
                                    ? Colors.grey.shade300 
                                    : Colors.white10
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, idx) {
                                final item = _searchResults[idx];
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: Colors.blue),
                                  title: Text(
                                    item['display_name'] ?? 'Unknown location', 
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                                  ),
                                  onTap: () {
                                    final double lat = double.parse(item['lat']);
                                    final double lon = double.parse(item['lon']);
                                    setState(() {
                                      _zoneCenter = GeoPoint(lat, lon);
                                      _hasCustomCenter = true;
                                      _searchResults = [];
                                    });
                                    _centerMap(lat, lon);
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Interactive Map Container
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_zoneCenter.latitude, _zoneCenter.longitude), 
                              zoom: 14
                            ),
                            onMapCreated: (c) {
                              if (!_mapController.isCompleted) {
                                _mapController.complete(c);
                              }
                            },
                            onTap: (pos) {
                              setState(() {
                                _zoneCenter = GeoPoint(pos.latitude, pos.longitude);
                                _hasCustomCenter = true;
                              });
                              _centerMap(pos.latitude, pos.longitude);
                            },
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                            markers: {
                              Marker(
                                markerId: const MarkerId('center_marker'),
                                position: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                                draggable: true,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                                onDragEnd: (pos) {
                                  setState(() {
                                    _zoneCenter = GeoPoint(pos.latitude, pos.longitude);
                                    _hasCustomCenter = true;
                                  });
                                  _centerMap(pos.latitude, pos.longitude);
                                },
                              ),
                              if (_childLocation != null)
                                Marker(
                                  markerId: const MarkerId('child_marker'),
                                  position: _childLocation!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                  infoWindow: const InfoWindow(title: "Child's Current Location"),
                                ),
                            },
                            circles: {
                              Circle(
                                circleId: const CircleId('preview'),
                                center: LatLng(_zoneCenter.latitude, _zoneCenter.longitude),
                                radius: _radiusMeters,
                                fillColor: Colors.blue.withOpacity(0.12),
                                strokeColor: Colors.blue,
                                strokeWidth: 2,
                              )
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Radius Slider Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.white10,
                            ),
                          ),
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Safe Zone Radius",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Adjust the circular boundary size",
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "${_radiusMeters.round()} m",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blue,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.blue,
                                    inactiveTrackColor: Colors.blue.withOpacity(0.1),
                                    thumbColor: Colors.blue,
                                    overlayColor: Colors.blue.withOpacity(0.12),
                                    valueIndicatorColor: Colors.blue,
                                    trackHeight: 4.0,
                                  ),
                                  child: Slider(
                                    value: _radiusMeters,
                                    min: 100,
                                    max: 2000,
                                    onChanged: (v) => setState(() => _radiusMeters = v),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("100m", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text("2.0km", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveSafeZone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "Save & Sync Safe Zone",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                  ),
                          ),
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
          ),
        ),
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
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final z = docs[i].data() as Map<String, dynamic>;
            final isActive = z['isActive'] ?? false;
            final dynamic rawTime = z['createdAt'];
            final Timestamp? ts = rawTime is Timestamp ? rawTime : null;
            final int radius = (z['radiusMeters'] ?? 1000) as int;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isActive ? Colors.green.withOpacity(0.25) : Colors.grey.withOpacity(0.1),
                ),
              ),
              color: Theme.of(context).cardColor,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  final double zoneLat = (z['centerLat'] as num).toDouble();
                  final double zoneLng = (z['centerLng'] as num).toDouble();
                  setState(() {
                    _zoneCenter = GeoPoint(zoneLat, zoneLng);
                    _radiusMeters = (z['radiusMeters'] as num).toDouble();
                    _hasCustomCenter = true;
                  });
                  _centerMap(zoneLat, zoneLng);
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on_rounded, 
                      color: isActive ? Colors.green : Colors.grey, 
                      size: 24
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        "zones.perimeter".tr(args: [radius.toString()]),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "ACTIVE",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTimestamp(ts),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: () => _deleteZone(docs[i].id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ZoneLogo extends StatelessWidget {
  final double size;

  const ZoneLogo({super.key, this.size = 44.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ZoneLogoPainter(),
    );
  }
}

class ZoneLogoPainter extends CustomPainter {
  Path getShieldPath(Size size, double scale) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    final topCenter = Offset(cx, cy - h * 0.38 * scale);
    final topRight = Offset(cx + w * 0.35 * scale, cy - h * 0.25 * scale);
    final midRight = Offset(cx + w * 0.35 * scale, cy + h * 0.05 * scale);
    final bottom = Offset(cx, cy + h * 0.40 * scale);
    final midLeft = Offset(cx - w * 0.35 * scale, cy + h * 0.05 * scale);
    final topLeft = Offset(cx - w * 0.35 * scale, cy - h * 0.25 * scale);

    path.moveTo(topCenter.dx, topCenter.dy);
    path.quadraticBezierTo(cx + w * 0.18 * scale, cy - h * 0.33 * scale, topRight.dx, topRight.dy);
    path.quadraticBezierTo(cx + w * 0.38 * scale, cy - h * 0.10 * scale, midRight.dx, midRight.dy);
    path.quadraticBezierTo(cx + w * 0.30 * scale, cy + h * 0.28 * scale, bottom.dx, bottom.dy);
    path.quadraticBezierTo(cx - w * 0.30 * scale, cy + h * 0.28 * scale, midLeft.dx, midLeft.dy);
    path.quadraticBezierTo(cx - w * 0.38 * scale, cy - h * 0.10 * scale, topLeft.dx, topLeft.dy);
    path.quadraticBezierTo(cx - w * 0.18 * scale, cy - h * 0.33 * scale, topCenter.dx, topCenter.dy);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    // 1. Draw a soft outer shadow for shield shape
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..isAntiAlias = true;
    final shadowPath = getShieldPath(size, 0.96);
    canvas.save();
    canvas.translate(0, h * 0.03);
    canvas.drawPath(shadowPath, shadowPaint);
    canvas.restore();

    // 2. Draw white outer shield
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final outerPath = getShieldPath(size, 0.96);
    canvas.drawPath(outerPath, whitePaint);

    // 3. Draw inner blue gradient shield (cyan/light blue to royal blue)
    final innerPath = getShieldPath(size, 0.84);
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.40);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF38BDF8), // Cyan / Sky blue at top
        const Color(0xFF1D4ED8), // Royal blue at bottom
      ],
    );
    final Paint gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(innerPath, gradientPaint);

    // 4. Draw white shield inner outline
    final strokePath = getShieldPath(size, 0.70);
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(strokePath, strokePaint);

    // 5. Draw white checkmark in the center
    final checkPath = Path();
    checkPath.moveTo(cx - w * 0.13, cy + h * 0.02);
    checkPath.lineTo(cx - w * 0.02, cy + h * 0.13);
    checkPath.lineTo(cx + w * 0.14, cy - h * 0.11);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
