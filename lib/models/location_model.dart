import 'package:cloud_firestore/cloud_firestore.dart';

class LocationUpdate {
  final String childId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final int batteryLevel;
  final DateTime timestamp;

  LocationUpdate({
    required this.childId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.batteryLevel,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'geoPoint': GeoPoint(latitude, longitude),
      'speed': speed,
      'heading': heading,
      'batteryLevel': batteryLevel,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
