import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'screens/auth/auth_wrapper.dart'; // <--- NEW FRONT DOOR

// REQUIREMENT: Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🌙 FCM Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Initialize FCM (Guardian side)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FcmService().init();

  // 3. Request Permissions
  await _requestPermissions();

  // 3. Start the App
  runApp(const SafeKidApp());
}

Future<void> _requestPermissions() async {
  await Permission.locationAlways.request();
  await Permission.notification.request();
  if (await Permission.activityRecognition.isDenied) {
    await Permission.activityRecognition.request();
  }
}

class SafeKidApp extends StatelessWidget {
  const SafeKidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeKid Pro',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // USE THE AUTH WRAPPER TO REMEMBER LOGIN
      home: const AuthWrapper(),
    );
  }
}
