import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AnomalyPoint {
  final LatLng position;
  final DateTime timestamp;
  final String type; // 'SPEED' | 'ROUTE_DEVIATION' | 'UNUSUAL_TIME'
  final String title;
  final String message;
  final double value; // Speed in km/h or deviation in meters

  AnomalyPoint({
    required this.position,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.message,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'title': title,
      'message': message,
      'value': value,
    };
  }
}

class RouteAnomalyDetector {
  /// Scans a route (points and timestamps) and compares it to a baseline history of past coordinates.
  /// Returns a list of detected anomaly points.
  static List<AnomalyPoint> detectAnomalies({
    required List<LatLng> points,
    required List<DateTime> timestamps,
    required List<LatLng> baselinePoints,
    required double speedLimitKmh,
    List<Map<String, dynamic>> activeZones = const [],
  }) {
    final List<AnomalyPoint> anomalies = [];
    if (points.isEmpty || points.length != timestamps.length) return anomalies;

    // 1. Time anomaly and Route Deviation detection
    for (int i = 0; i < points.length; i++) {
      final currentPoint = points[i];
      final currentTimestamp = timestamps[i];

      // A. Late-Night Time Anomaly
      // If movement is detected between 10 PM and 5 AM and is NOT inside any active geofence/safe-zone
      final hour = currentTimestamp.hour;
      if (hour >= 22 || hour < 5) {
        bool isInsideSafeZone = false;
        for (var zone in activeZones) {
          final double zLat = (zone['centerLat'] as num).toDouble();
          final double zLng = (zone['centerLng'] as num).toDouble();
          final double zRad = (zone['radiusMeters'] as num).toDouble();
          final dist = distanceMeters(currentPoint, LatLng(zLat, zLng));
          if (dist <= zRad) {
            isInsideSafeZone = true;
            break;
          }
        }

        // If outside safe zones late at night, trigger anomaly
        if (!isInsideSafeZone) {
          anomalies.add(
            AnomalyPoint(
              position: currentPoint,
              timestamp: currentTimestamp,
              type: 'UNUSUAL_TIME',
              title: "Late-Night Activity Alert",
              message: "Child was detected outside safe zones at ${currentTimestamp.hour.toString().padLeft(2, '0')}:${currentTimestamp.minute.toString().padLeft(2, '0')}.",
              value: hour.toDouble(),
            ),
          );
        }
      }

      // B. Route Deviation Outlier Detection (Spatial Outliers)
      // Check distance from current point to any historical point from previous days.
      if (baselinePoints.isNotEmpty) {
        double minDistance = double.infinity;
        for (var basePoint in baselinePoints) {
          final dist = distanceMeters(currentPoint, basePoint);
          if (dist < minDistance) {
            minDistance = dist;
          }
        }

        // If the child is more than 300 meters away from ANY point they previously visited,
        // it means they are off-trail/deviating into unfamiliar territory.
        if (minDistance > 300.0) {
          // Prevent spamming if already flagged late night
          final alreadyFlagged = anomalies.any((a) => a.position == currentPoint && a.type == 'UNUSUAL_TIME');
          if (!alreadyFlagged) {
            anomalies.add(
              AnomalyPoint(
                position: currentPoint,
                timestamp: currentTimestamp,
                type: 'ROUTE_DEVIATION',
                title: "Route Deviation Detected",
                message: "Child is ${minDistance.round()}m away from their typical historical paths.",
                value: minDistance,
              ),
            );
          }
        }
      }
    }

    // 2. Velocity-based speed spikes (Speed Anomaly)
    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final t1 = timestamps[i - 1];
      final t2 = timestamps[i];

      final double distance = distanceMeters(p1, p2);
      final double durationSeconds = t2.difference(t1).inSeconds.toDouble();

      if (durationSeconds > 0) {
        final double velocityMps = distance / durationSeconds;
        final double velocityKmh = velocityMps * 3.6;

        // If child's velocity exceeds the parent rule speed limit
        if (velocityKmh > speedLimitKmh) {
          anomalies.add(
            AnomalyPoint(
              position: p2,
              timestamp: t2,
              type: 'SPEED',
              title: "Speed Anomaly Detected",
              message: "Child traveled at ${velocityKmh.toStringAsFixed(1)} km/h, which is above the limit of $speedLimitKmh km/h (indicates vehicular motion).",
              value: velocityKmh,
            ),
          );
        }
      }
    }

    // 3. AI Predictive Geofence Departure
    // If we have at least 3 historical points, we can compute the child's current direction vector
    if (baselinePoints.length >= 3 && activeZones.isNotEmpty) {
      final p0 = baselinePoints[0]; // Newest historical point
      final p1 = baselinePoints[1];
      final p2 = baselinePoints[2];

      // Direction vector 1: from p2 to p1
      final double latVec1 = p1.latitude - p2.latitude;
      final double lngVec1 = p1.longitude - p2.longitude;

      // Direction vector 2: from p1 to p0
      final double latVec2 = p0.latitude - p1.latitude;
      final double lngVec2 = p0.longitude - p1.longitude;

      // Average direction vector (representing velocity and heading)
      final double avgLatVec = (latVec1 + latVec2) / 2.0;
      final double avgLngVec = (lngVec1 + lngVec2) / 2.0;

      // Only project if there is actual movement (to avoid drift/jitter when stationary)
      final double movement = sqrt(avgLatVec * avgLatVec + avgLngVec * avgLngVec);
      if (movement > 0.00005) { // Roughly 5-10 meters displacement
        // Project forward by 3 steps (e.g. 30 seconds of movement)
        final double predLat = p0.latitude + 3.0 * avgLatVec;
        final double predLng = p0.longitude + 3.0 * avgLngVec;
        final LatLng predictedPoint = LatLng(predLat, predLng);

        // Check if the current position is INSIDE any active safe zone,
        // but the PREDICTED position is OUTSIDE that same safe zone!
        for (var zone in activeZones) {
          final double zLat = (zone['centerLat'] as num).toDouble();
          final double zLng = (zone['centerLng'] as num).toDouble();
          final double zRad = (zone['radiusMeters'] as num).toDouble();
          final LatLng zoneCenter = LatLng(zLat, zLng);

          final double currentDist = distanceMeters(p0, zoneCenter);
          final double predictedDist = distanceMeters(predictedPoint, zoneCenter);

          // Trigger predictive alert if child is currently inside but heading outside
          if (currentDist <= zRad && predictedDist > zRad) {
            anomalies.add(
              AnomalyPoint(
                position: p0,
                timestamp: DateTime.now(),
                type: 'PREDICTIVE_BREACH',
                title: "AI Geofence Exit Prediction",
                message: "Predictive analysis indicates the child is heading outside the active safe zone boundary.",
                value: predictedDist,
              ),
            );
            break; // Avoid duplicate alerts
          }
        }
      }
    }

    return anomalies;
  }

  /// Helper to calculate distance between two coordinates in meters
  static double distanceMeters(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) * cos(p2.latitude * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
