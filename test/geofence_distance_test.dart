import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

// -----------------------------------------------------------------------------
// MOCK LOGIC: Extracting the Haversine distance formula from LocationService 
// to unit test the pure mathematical evaluation without Firebase dependencies.
// -----------------------------------------------------------------------------
double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = (lat2 - lat1) * (pi / 180.0);
  final dLon = (lon2 - lon1) * (pi / 180.0);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
      sin(dLon / 2) * sin(dLon / 2);
  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String evaluateGeofence(double distanceMeters, double radiusMeters) {
  if (distanceMeters <= radiusMeters) {
    return "Inside Safe Zone";
  } else {
    return "Geofence Breach";
  }
}

void main() {
  group('Geofence Distance & Haversine Logic Tests (SafeKid Telemetry)', () {
    
    // Base Safe Zone Center Coordinate
    const double zoneLat = 6.9271;
    const double zoneLng = 79.8612;
    const double zoneRadius = 100.0; // 100 meters

    test('Test A: Coordinates 5 meters apart evaluate to "Inside Safe Zone"', () {
      // Coordinate approximately ~5 meters away
      const double childLat = 6.927145; 
      const double childLng = 79.861200;

      final distance = calculateDistanceMeters(zoneLat, zoneLng, childLat, childLng);
      final status = evaluateGeofence(distance, zoneRadius);

      // Assertions
      expect(distance, lessThan(zoneRadius));
      expect(status, equals("Inside Safe Zone"));
    });

    test('Test B: Coordinates 500 meters apart evaluate to "Geofence Breach"', () {
      // Coordinate approximately ~500 meters away
      const double childLat = 6.9316; 
      const double childLng = 79.8612;

      final distance = calculateDistanceMeters(zoneLat, zoneLng, childLat, childLng);
      final status = evaluateGeofence(distance, zoneRadius);

      // Assertions
      expect(distance, greaterThan(zoneRadius));
      expect(status, equals("Geofence Breach"));
    });
    
  });
}
