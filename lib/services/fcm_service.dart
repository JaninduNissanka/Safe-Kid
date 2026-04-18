import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Request Permission (iOS/Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    }

    // 2. Setup Foreground Listening (When app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 FCM Message received in foreground: ${message.notification?.title}');
      
      // Manually show a local notification so it pops up while app is open
      if (message.notification != null) {
        NotificationService().showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? "Alert",
          body: message.notification!.body ?? "",
        );
      }
    });

    // 3. Handle Token Generation/Refresh
    _saveTokenToFirestore();
    _fcm.onTokenRefresh.listen((token) => _updateToken(token));
  }

  Future<void> _saveTokenToFirestore() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      _updateToken(token);
    }
  }

  Future<void> _updateToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Save token to parent user doc so child knows where to send pushes
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      print("🔑 FCM Token updated: $token");
    }
  }
}
