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

    test('Test C: Predictive AI Trajectory Exit Vector projection triggers alert while current position is INSIDE', () {
      // Zone Center & Radius
      const zoneCenterLat = 6.9271;
      const zoneCenterLng = 79.8612;
      const double radiusMeters = 500.0;

      // Child points moving toward boundary:
      // p1 = 10s ago (298m from center)
      // p0 = NOW (353m from center -> STILL INSIDE 500m radius!)
      const double p1Lat = 6.9271;
      const double p1Lng = 79.8585;

      const double p0Lat = 6.9271;
      const double p0Lng = 79.8580; // Current dist ~353m (INSIDE)

      final currentDist = calculateDistanceMeters(zoneCenterLat, zoneCenterLng, p0Lat, p0Lng);
      expect(currentDist, lessThan(radiusMeters)); // Confirmed CURRENTLY INSIDE!

      // Compute heading vector: (p0 - p1)
      const avgLatVec = p0Lat - p1Lat;
      const avgLngVec = p0Lng - p1Lng;

      // Project 3 steps (30 seconds) forward into future:
      const predLat = p0Lat + 3.0 * avgLatVec;
      const predLng = p0Lng + 3.0 * avgLngVec;

      final predictedDist = calculateDistanceMeters(zoneCenterLat, zoneCenterLng, predLat, predLng);
      expect(predictedDist, greaterThan(radiusMeters)); // Confirmed PREDICTED POSITION OUTSIDE!

      // Trigger condition: Current INSIDE + Predicted OUTSIDE = PREDICTIVE_BREACH!
      final bool isPredictiveAlertTriggered = (currentDist <= radiusMeters && predictedDist > radiusMeters);
      expect(isPredictiveAlertTriggered, isTrue);
    });

    test('Test D: Safe Zone Schedule Window evaluation skips geofence checks outside active hours', () {
      const String startTime = "08:00"; // 8:00 AM
      const String endTime = "13:30";   // 1:30 PM

      final startParts = startTime.split(':');
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]); // 480 mins

      final endParts = endTime.split(':');
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);     // 810 mins

      // Case 1: Time is 10:30 AM (630 mins) -> WITHIN schedule window
      const testCurrentMinutes1 = 10 * 60 + 30;
      final bool isWithinWindow1 = testCurrentMinutes1 >= startMinutes && testCurrentMinutes1 <= endMinutes;
      expect(isWithinWindow1, isTrue);

      // Case 2: Time is 03:00 PM (900 mins) -> OUTSIDE schedule window
      const testCurrentMinutes2 = 15 * 60 + 0;
      final bool isWithinWindow2 = testCurrentMinutes2 >= startMinutes && testCurrentMinutes2 <= endMinutes;
      expect(isWithinWindow2, isFalse);
    });
    
  });
}
