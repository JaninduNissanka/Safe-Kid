import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../guardian/guardian_shell.dart';
import '../child/child_home_screen.dart';
import 'role_selection_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget _home = const RoleSelectionScreen();

  @override
  void initState() {
    super.initState();
    _checkSignInState();
  }

  Future<void> _checkSignInState() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final role = data['role'];
          
          if (role == 'guardian') {
            _home = const GuardianShell();
          } else if (role == 'child') {
            // Reconstruct pairing code from the auth email (child_123456@safekid.com)
            String email = data['email'] ?? '';
            String code = '';
            if (email.contains('_') && email.contains('@')) {
              code = email.split('_')[1].split('@')[0];
            }
            
            _home = ChildHomeScreen(
              childName: data['name'] ?? "Child",
              pairingCode: code,
            );
          }
        }
      } catch (e) {
        print("Auth Wrapper Error: $e");
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 60, color: Colors.blue),
              SizedBox(height: 20),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    return _home;
  }
}
