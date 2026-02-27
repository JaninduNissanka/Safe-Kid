import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'screens/auth/role_selection_screen.dart'; // <--- IMPORTANT LINK

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Request Permissions
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
      // CHANGE THE FRONT DOOR HERE:
      home: const RoleSelectionScreen(),
    );
  }
}
