import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../auth/role_selection_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  final String childName;
  final String pairingCode; // ✅ REQUIRED for SOS -> locations/{pairingCode}

  const ChildHomeScreen({
    super.key,
    required this.childName,
    required this.pairingCode,
  });

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  bool _isSosActive = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _locationService.startTracking(user.uid);
    }
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    setState(() => _isSosActive = !_isSosActive);

    try {
      // ✅ Write SOS to locations/{pairingCode}
      await _authService.setSos(
        pairingCode: widget.pairingCode,
        isActive: _isSosActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSosActive ? "SOS SENT! Parent alerted!" : "SOS cancelled",
          ),
          backgroundColor: _isSosActive ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send SOS: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    _locationService.stopTracking();
    await _authService.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Child Mode (Tracking On)"),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.my_location, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.childName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "• Location Sharing Active",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Code: ${widget.pairingCode}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const Spacer(),

            // SOS BUTTON
            GestureDetector(
              onTap: _triggerSOS,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: _isSosActive ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isSosActive ? Colors.red : Colors.orange)
                          .withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 60, color: Colors.white),
                    Text(
                      "SOS",
                      style: TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              "Tap in case of emergency",
              style: TextStyle(color: Colors.grey),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
