import 'dart:math';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- 1. EMAIL/PASSWORD AUTHENTICATION ---

  Future<String?> registerWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String pairingCode = (100000 + Random().nextInt(900000)).toString();

      AppUser newUser = AppUser(
        uid: result.user!.uid,
        email: email,
        name: email.split('@')[0], // Default name
        role: 'guardian',
        pairingCode: pairingCode,
      );

      // Create user document and initialize linkedChildren array
      Map<String, dynamic> userData = newUser.toMap();
      userData['linkedChildren'] = [];

      await _db.collection('users').doc(newUser.uid).set(userData);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Unknown error: $e";
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Unknown error: $e";
    }
  }

  // --- 2. GOOGLE SIGN-IN ---

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "User cancelled the sign-in process.";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // CRITICAL DB STEP: Check if user exists, if not initialize with linkedChildren
      final docRef = _db.collection('users').doc(userCredential.user!.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        String pairingCode = (100000 + Random().nextInt(900000)).toString();
        AppUser newUser = AppUser(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? "",
          name: userCredential.user!.displayName ?? "User",
          role: 'guardian',
          pairingCode: pairingCode,
        );
        
        Map<String, dynamic> userData = newUser.toMap();
        userData['linkedChildren'] = [];
        
        await docRef.set(userData);
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("🔥 FirebaseAuthException in signInWithGoogle: code=${e.code}, message=${e.message}");
      return e.message ?? "Firebase Authentication Failed";
    } on PlatformException catch (e) {
      print("📱 PlatformException in signInWithGoogle: code=${e.code}, message=${e.message}");
      return e.message ?? "Google Sign-In Platform Error";
    } catch (e) {
      print("❌ General Exception in signInWithGoogle: $e");
      return "Unknown error: $e";
    }
  }

  // --- 3. CHILD LOGIN ---

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

      QuerySnapshot existingChildren = await _db
          .collection('users')
          .where('guardianIds', arrayContains: parentId)
          .where('role', isEqualTo: 'child')
          .get();

      if (existingChildren.docs.isNotEmpty) {
        final existingChild = existingChildren.docs.first.data() as Map<String, dynamic>;
        final existingName = existingChild['name'] ?? "";

        if (existingName.toLowerCase() != childName.toLowerCase()) {
          throw Exception("Access Denied: Already in use by $existingName.");
        }

        for (var doc in existingChildren.docs) {
          await doc.reference.delete();
        }
      }

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
      print("Login Error: $e");
      return null;
    }
  }

  // --- 4. SIGN OUT ---

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Sign Out Error: $e");
      await _auth.signOut();
    }
  }

  // --- STREAMS & UTILS ---

  Stream<DocumentSnapshot<Map<String, dynamic>>> locationStream(String pairingCode) {
    return _db.collection('locations').doc(pairingCode).snapshots();
  }

  Future<void> setSos({required String pairingCode, required bool isActive}) async {
    final locRef = _db.collection('locations').doc(pairingCode);
    if (isActive) {
      final alertRef = _db.collection('alerts').doc(pairingCode).collection('items').doc();
      final alertId = alertRef.id;
      final batch = _db.batch();
      batch.set(alertRef, {
        'type': 'SOS', 'title': 'SOS Triggered', 'message': 'Child pressed SOS',
        'status': 'active', 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(locRef, {
        'isSosActive': true, 'sosTriggeredAt': FieldValue.serverTimestamp(),
        'sosStatus': 'active', 'activeSosAlertId': alertId,
      }, SetOptions(merge: true));
      await batch.commit();
    } else {
      final locSnap = await locRef.get();
      final data = locSnap.data();
      final String? activeAlertId = data?['activeSosAlertId'];
      final batch = _db.batch();
      batch.set(locRef, {
        'isSosActive': false, 'sosStatus': 'resolved',
        'activeSosAlertId': FieldValue.delete(), 'sosResolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (activeAlertId != null && activeAlertId.isNotEmpty) {
        final alertRef = _db.collection('alerts').doc(pairingCode).collection('items').doc(activeAlertId);
        batch.set(alertRef, {
          'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> rulesStream(String pairingCode) {
    return _db.collection('rules').doc(pairingCode).snapshots();
  }

  Future<void> setSpeedLimit({required String pairingCode, required int speedKmh}) async {
    await _db.collection('rules').doc(pairingCode).set({
      'speedLimitKmh': speedKmh, 'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
