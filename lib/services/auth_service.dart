import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. GUARDIAN FEATURES ---

  Future<String?> registerGuardian(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String pairingCode = (100000 + Random().nextInt(900000)).toString();

      AppUser newUser = AppUser(
        uid: result.user!.uid,
        email: email,
        name: name,
        role: 'guardian',
        pairingCode: pairingCode,
      );

      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Unknown error: $e";
    }
  }

  Future<String?> loginGuardian(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // --- 2. CHILD FEATURES ---

  Future<AppUser?> loginChild(String code, String childName) async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      String childUid = result.user!.uid;

      QuerySnapshot query = await _db
          .collection('users')
          .where('pairingCode', isEqualTo: code)
          .where('role', isEqualTo: 'guardian')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        await result.user?.delete();
        return null;
      }

      DocumentSnapshot parentDoc = query.docs.first;
      String parentId = parentDoc.id;

      AppUser newChild = AppUser(
        uid: childUid,
        email: "child_$code@safekid.com",
        name: childName,
        role: 'child',
        guardianIds: [parentId],
      );

      await _db.collection('users').doc(childUid).set(newChild.toMap());
      return newChild;
    } catch (e) {
      return null;
    }
  }

  // ===============================
  // 3) SOS + ALERT LOGGING (Option A)
  // locations/{pairingCode}
  // alerts/{pairingCode}/items/{alertId}
  // ===============================

  Stream<DocumentSnapshot<Map<String, dynamic>>> locationStream(
      String pairingCode) {
    return _db.collection('locations').doc(pairingCode).snapshots();
  }

  /// If isActive == true:
  /// - Set locations/{code}.isSosActive=true
  /// - Create alerts/{code}/items/{alertId} status=active
  /// - Save locations/{code}.activeSosAlertId=alertId
  ///
  /// If isActive == false:
  /// - Set locations/{code}.isSosActive=false
  /// - If activeSosAlertId exists => mark that alert resolved
  /// - Clear activeSosAlertId
  Future<void> setSos({
    required String pairingCode,
    required bool isActive,
  }) async {
    final locRef = _db.collection('locations').doc(pairingCode);

    if (isActive) {
      // Create a new alert item
      final alertRef =
          _db.collection('alerts').doc(pairingCode).collection('items').doc();
      final alertId = alertRef.id;

      final batch = _db.batch();

      batch.set(
        alertRef,
        {
          'type': 'SOS',
          'title': 'SOS Triggered',
          'message': 'Child pressed SOS',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        locRef,
        {
          'isSosActive': true,
          'sosTriggeredAt': FieldValue.serverTimestamp(),
          'sosStatus': 'active',
          'activeSosAlertId': alertId,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } else {
      // Resolve: need to know which alert is active
      final locSnap = await locRef.get();
      final data = locSnap.data();
      final String? activeAlertId = data?['activeSosAlertId'];

      final batch = _db.batch();

      // Turn off SOS in location doc
      batch.set(
        locRef,
        {
          'isSosActive': false,
          'sosStatus': 'resolved',
          'activeSosAlertId': FieldValue.delete(),
          'sosResolvedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Mark alert resolved (if exists)
      if (activeAlertId != null && activeAlertId.isNotEmpty) {
        final alertRef = _db
            .collection('alerts')
            .doc(pairingCode)
            .collection('items')
            .doc(activeAlertId);

        batch.set(
          alertRef,
          {
            'status': 'resolved',
            'resolvedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
