import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'guardian' or 'child'
  final String? pairingCode;
  final List<String> guardianIds;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.pairingCode,
    this.guardianIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'pairingCode': pairingCode,
      'guardianIds': guardianIds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? 'User',
      role: map['role'] ?? 'guardian',
      pairingCode: map['pairingCode'],
      guardianIds: List<String>.from(map['guardianIds'] ?? []),
    );
  }
}
