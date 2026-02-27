import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<LocationData>? _locationSubscription;

  // Cached zone + state
  String? _pairingCode;
  double? _zoneLat;
  double? _zoneLng;
  double? _zoneRadiusMeters;

  bool _isOutside = false;
  String? _activeExitAlertId;

  // Start tracking the child and uploading to Firebase
  Future<void> startTracking(String childId) async {
    // 0) Load pairingCode + last zone once
    await _loadChildPairingCode(childId);
    if (_pairingCode != null) {
      await _loadLatestActiveZone(_pairingCode!);
    }

    // 1) Check Service Status (Is GPS on?)
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    // 2) Check Permissions
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    // 3) Configure Settings (Update every 5 seconds or 10 meters)
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000,
      distanceFilter: 10,
    );

    // 4) Listen to stream and upload
    _locationSubscription = _location.onLocationChanged.listen(
      (LocationData currentLocation) async {
        if (currentLocation.latitude == null ||
            currentLocation.longitude == null) {
          return;
        }

        final lat = currentLocation.latitude!;
        final lng = currentLocation.longitude!;

        print("📍 Moving: $lat, $lng");

        // Upload to Firestore 'users' collection
        await _db.collection('users').doc(childId).update({
          'currentLocation': GeoPoint(lat, lng),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isOnline': true,
        });

        // ✅ Geofence check
        await _checkGeofenceAndAlert(childId, lat, lng);
      },
    );
  }

  Future<void> _loadChildPairingCode(String childId) async {
    try {
      final doc = await _db.collection('users').doc(childId).get();
      final data = doc.data();
      final code = data?['pairingCode'];
      if (code is String && code.length == 6) {
        _pairingCode = code;
      }
    } catch (e) {
      print("❌ Failed to load pairingCode: $e");
    }
  }

  Future<void> _loadLatestActiveZone(String pairingCode) async {
    try {
      // Get latest active zone (you can later support multiple zones)
      final query = await _db
          .collection('zones')
          .doc(pairingCode)
          .collection('items')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _zoneLat = null;
        _zoneLng = null;
        _zoneRadiusMeters = null;
        return;
      }

      final z = query.docs.first.data();
      _zoneLat = (z['centerLat'] as num).toDouble();
      _zoneLng = (z['centerLng'] as num).toDouble();
      _zoneRadiusMeters = (z['radiusMeters'] as num).toDouble();

      print("✅ Loaded Zone: ($_zoneLat,$_zoneLng) r=$_zoneRadiusMeters");
    } catch (e) {
      // If Firestore asks for index, you can remove orderBy and just take first.
      print("❌ Failed to load zone: $e");
    }
  }

  Future<void> _checkGeofenceAndAlert(
      String childId, double lat, double lng) async {
    // Need pairingCode + zone details
    if (_pairingCode == null ||
        _zoneLat == null ||
        _zoneLng == null ||
        _zoneRadiusMeters == null) {
      return;
    }

    final distance = _distanceMeters(lat, lng, _zoneLat!, _zoneLng!);

    final bool outsideNow = distance > _zoneRadiusMeters!;

    // OUTSIDE (first time) => create EXIT alert (active)
    if (outsideNow && !_isOutside) {
      _isOutside = true;

      final alertRef =
          _db.collection('alerts').doc(_pairingCode!).collection('items').doc();

      _activeExitAlertId = alertRef.id;

      await alertRef.set({
        'type': 'GEOFENCE_EXIT',
        'title': 'Child left Safe Zone',
        'message':
            'Child moved outside the safe zone (${_zoneRadiusMeters!.round()}m).',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'childId': childId,
        'distanceMeters': distance.round(),
      });

      print("🚨 GEOFENCE EXIT alert created");
      return;
    }

    // BACK INSIDE => create ENTER alert + resolve EXIT
    if (!outsideNow && _isOutside) {
      _isOutside = false;

      // 1) Create ENTER alert (resolved by default)
      final enterRef =
          _db.collection('alerts').doc(_pairingCode!).collection('items').doc();

      // 2) Resolve old EXIT alert
      WriteBatch batch = _db.batch();

      batch.set(enterRef, {
        'type': 'GEOFENCE_ENTER',
        'title': 'Child returned to Safe Zone',
        'message': 'Child is back inside the safe zone.',
        'status': 'resolved',
        'createdAt': FieldValue.serverTimestamp(),
        'childId': childId,
        'distanceMeters': distance.round(),
      });

      if (_activeExitAlertId != null) {
        final exitRef = _db
            .collection('alerts')
            .doc(_pairingCode!)
            .collection('items')
            .doc(_activeExitAlertId);

        batch.set(
            exitRef,
            {
              'status': 'resolved',
              'resolvedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }

      await batch.commit();
      _activeExitAlertId = null;

      print("✅ GEOFENCE ENTER alert + resolved EXIT");
    }
  }

  // Haversine distance in meters
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);

  // Stop tracking
  void stopTracking() {
    _locationSubscription?.cancel();
  }
}
