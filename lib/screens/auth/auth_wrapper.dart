import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../guardian/guardian_shell.dart';
import '../child/child_home_screen.dart';
import 'role_selection_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Unauthenticated State
        if (!snapshot.hasData || snapshot.data == null) {
          return const RoleSelectionScreen();
        }

        // 3. Authenticated State - Need to check Role for routing
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnap.hasData && roleSnap.data!.exists) {
              final data = roleSnap.data!.data() as Map<String, dynamic>;
              final role = data['role'];

              if (role == 'guardian') {
                return const GuardianShell();
              } else if (role == 'child') {
                // Recover pairing code from email for Child routing
                String email = data['email'] ?? '';
                String code = '';
                if (email.contains('_') && email.contains('@')) {
                  code = email.split('_')[1].split('@')[0];
                }
                return ChildHomeScreen(
                  childName: data['name'] ?? "Child",
                  pairingCode: code,
                );
              }
            }

            // Fallback for missing user doc or unknown role
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}
