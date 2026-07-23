import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
      // 1. Verify parent exists with this pairing code
      QuerySnapshot query = await _db
          .collection('users')
          .where('pairingCode', isEqualTo: code)
          .where('role', isEqualTo: 'guardian')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      DocumentSnapshot parentDoc = query.docs.first;
      String parentId = parentDoc.id;

      // 2. Check if this child is already approved (exists in users collection)
      QuerySnapshot existingChildrenWithName = await _db
          .collection('users')
          .where('guardianIds', arrayContains: parentId)
          .where('role', isEqualTo: 'child')
          .get();

      DocumentSnapshot? alreadyApprovedDoc;
      for (var doc in existingChildrenWithName.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        if (name.toLowerCase() == childName.toLowerCase()) {
          alreadyApprovedDoc = doc;
          break;
        }
      }

      // Anonymous sign in
      UserCredential result = await _auth.signInAnonymously();
      String childUid = result.user!.uid;

      if (alreadyApprovedDoc != null) {
        // Child is already approved! Reuse the child.
        String oldUid = alreadyApprovedDoc.id;
        if (oldUid != childUid) {
          // Delete old user document
          await _db.collection('users').doc(oldUid).delete();
          // Remove oldUid from parent's linkedChildren array
          await _db.collection('users').doc(parentId).update({
            'linkedChildren': FieldValue.arrayRemove([oldUid]),
          });
        }
        // Always ensure childUid is in parent's linkedChildren array
        await _db.collection('users').doc(parentId).update({
          'linkedChildren': FieldValue.arrayUnion([childUid]),
        });

        // Clean up duplicate devices in locations subcollection
        QuerySnapshot existingDevices = await _db
            .collection('locations')
            .doc(code)
            .collection('devices')
            .get();

        final duplicateDevices = existingDevices.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? data['childName'] ?? '';
          return name.toString().toLowerCase() == childName.toLowerCase();
        }).toList();

        for (var doc in duplicateDevices) {
          await doc.reference.delete();
        }

        AppUser approvedChild = AppUser(
          uid: childUid,
          email: "child_${code}_${childName.replaceAll(' ', '_')}@safekid.com",
          name: childName,
          role: 'child',
          guardianIds: [parentId],
        );

        await _db.collection('users').doc(childUid).set(approvedChild.toMap());
        return approvedChild;
      } else {
        // Child is NOT approved. Initiate or reuse a pairing request.
        final requestId = "${code}_${childName.toLowerCase()}";
        
        await _db
            .collection('pairings')
            .doc('requests')
            .collection('items')
            .doc(requestId)
            .set({
          'childName': childName,
          'childUid': childUid,
          'parentId': parentId,
          'pairingCode': code,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        AppUser pendingChild = AppUser(
          uid: childUid,
          email: "child_${code}_${childName.replaceAll(' ', '_')}@safekid.com",
          name: childName,
          role: 'child_pending',
          guardianIds: [parentId],
        );

        return pendingChild;
      }
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // --- 3.5. DOUBLE-HANDSHAKE PAIRING METHODS ---

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingPairingRequestsStream(String parentUid) {
    return _db
        .collection('pairings')
        .doc('requests')
        .collection('items')
        .where('parentId', isEqualTo: parentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> pairingRequestStatusStream(String requestId) {
    return _db
        .collection('pairings')
        .doc('requests')
        .collection('items')
        .doc(requestId)
        .snapshots();
  }

  Future<void> approvePairingRequest(String requestId) async {
    final reqDoc = await _db
        .collection('pairings')
        .doc('requests')
        .collection('items')
        .doc(requestId)
        .get();
    
    if (!reqDoc.exists) return;
    
    final data = reqDoc.data()!;
    final String childUid = data['childUid'];
    final String parentId = data['parentId'];
    final String childName = data['childName'];
    final String pairingCode = data['pairingCode'];
    
    final batch = _db.batch();
    
    // 1. Update request status to accepted
    batch.update(reqDoc.reference, {
      'status': 'accepted',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Create child user document
    final childUserRef = _db.collection('users').doc(childUid);
    AppUser newChild = AppUser(
      uid: childUid,
      email: "child_${pairingCode}_${childName.replaceAll(' ', '_')}@safekid.com",
      name: childName,
      role: 'child',
      guardianIds: [parentId],
    );
    batch.set(childUserRef, newChild.toMap());
    
    // 3. Add childUid to parent's linkedChildren array
    final parentUserRef = _db.collection('users').doc(parentId);
    batch.update(parentUserRef, {
      'linkedChildren': FieldValue.arrayUnion([childUid]),
    });
    
    await batch.commit();
  }

  Future<void> rejectPairingRequest(String requestId) async {
    await _db
        .collection('pairings')
        .doc('requests')
        .collection('items')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeChild({
    required String parentId,
    required String childUid,
    required String childName,
    required String pairingCode,
  }) async {
    final batch = _db.batch();

    // 1. Delete child user document
    final childUserRef = _db.collection('users').doc(childUid);
    batch.delete(childUserRef);

    // 2. Remove childUid from parent's linkedChildren array
    final parentUserRef = _db.collection('users').doc(parentId);
    batch.update(parentUserRef, {
      'linkedChildren': FieldValue.arrayRemove([childUid]),
    });

    // 3. Delete device document from locations/{pairingCode}/devices/{childName.toLowerCase()}
    final deviceRef = _db
        .collection('locations')
        .doc(pairingCode)
        .collection('devices')
        .doc(childName.toLowerCase());
    batch.delete(deviceRef);

    // 4. Delete pairing request document if it exists
    final requestId = "${pairingCode}_${childName.toLowerCase()}";
    final requestRef = _db
        .collection('pairings')
        .doc('requests')
        .collection('items')
        .doc(requestId);
    batch.delete(requestRef);

    await batch.commit();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getRouteHistory({
    required String pairingCode,
    required String childId,
    required DateTime date,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    
    return _db
        .collection('locations')
        .doc(pairingCode)
        .collection('devices')
        .doc(childId.toLowerCase())
        .collection('history')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: false)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getBaselineHistory({
    required String pairingCode,
    required String childId,
    required DateTime beforeDate,
  }) {
    final startOfBeforeDate = DateTime(beforeDate.year, beforeDate.month, beforeDate.day);
    final sevenDaysAgo = startOfBeforeDate.subtract(const Duration(days: 7));
    
    return _db
        .collection('locations')
        .doc(pairingCode)
        .collection('devices')
        .doc(childId.toLowerCase())
        .collection('history')
        .where('timestamp', isLessThan: Timestamp.fromDate(startOfBeforeDate))
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp', descending: false)
        .get();
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

  Stream<QuerySnapshot<Map<String, dynamic>>> devicesLocationStream(String pairingCode) {
    return _db.collection('locations').doc(pairingCode).collection('devices').snapshots();
  }

  Future<void> setSos({
    required String pairingCode,
    required bool isActive,
    required String childId,
    required String childName,
  }) async {
    final locRef = _db.collection('locations').doc(pairingCode);
    final deviceRef = locRef.collection('devices').doc(childId);
    if (isActive) {
      final alertRef = _db.collection('alerts').doc(pairingCode).collection('items').doc();
      final alertId = alertRef.id;
      final batch = _db.batch();
      batch.set(alertRef, {
        'type': 'SOS',
        'title': 'SOS Triggered',
        'message': '$childName pressed SOS',
        'childId': childId,
        'childName': childName,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Update subcollection device doc
      batch.set(deviceRef, {
        'isSosActive': true,
        'sosTriggeredAt': FieldValue.serverTimestamp(),
        'sosStatus': 'active',
        'activeSosAlertId': alertId,
        'childId': childId,
        'name': childName,
      }, SetOptions(merge: true));

      // For backwards compatibility: update root document
      batch.set(locRef, {
        'isSosActive': true,
        'sosTriggeredAt': FieldValue.serverTimestamp(),
        'sosStatus': 'active',
        'activeSosAlertId': alertId,
        'name': childName,
      }, SetOptions(merge: true));

      await batch.commit();

      await _addTimelineEvent(
        pairingCode: pairingCode,
        childId: childId,
        type: 'alert_sos',
        title: '🚨 SOS Alarm Triggered',
        message: '$childName triggered an emergency SOS alert!',
      );
    } else {
      final deviceSnap = await deviceRef.get();
      final data = deviceSnap.data();
      final String? activeAlertId = data?['activeSosAlertId'];
      final batch = _db.batch();
      
      batch.set(deviceRef, {
        'isSosActive': false,
        'sosStatus': 'resolved',
        'activeSosAlertId': FieldValue.delete(),
        'sosResolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(locRef, {
        'isSosActive': false,
        'sosStatus': 'resolved',
        'activeSosAlertId': FieldValue.delete(),
        'sosResolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (activeAlertId != null && activeAlertId.isNotEmpty) {
        final alertRef = _db.collection('alerts').doc(pairingCode).collection('items').doc(activeAlertId);
        batch.set(alertRef, {
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      await _addTimelineEvent(
        pairingCode: pairingCode,
        childId: childId,
        type: 'sos_resolved',
        title: '✅ SOS Resolved',
        message: '$childName\'s SOS status has been resolved.',
      );
    }
  }

  Future<void> _addTimelineEvent({
    required String pairingCode,
    required String childId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      
      // Try to read device's last location coordinates from parent devices doc
      double? lat;
      double? lng;
      try {
        final deviceDoc = await _db
            .collection('locations')
            .doc(pairingCode)
            .collection('devices')
            .doc(childId)
            .get();
        if (deviceDoc.exists) {
          lat = (deviceDoc.data()?['latitude'] as num?)?.toDouble();
          lng = (deviceDoc.data()?['longitude'] as num?)?.toDouble();
        }
      } catch (e) {
        // Fallback
      }

      await _db
          .collection('locations')
          .doc(pairingCode)
          .collection('devices')
          .doc(childId)
          .collection('timeline')
          .add({
        'type': type,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'dateStr': dateStr,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
    } catch (e) {
      print("❌ [TIMELINE SOS ERROR] Failed to write: $e");
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
