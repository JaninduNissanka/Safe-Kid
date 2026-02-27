import 'package:flutter/material.dart';
import 'guardian_login_screen.dart'; // Import Parent Screen
import 'child_login_screen.dart'; // Import Child Screen (New!)

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "SafeKid Pro",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text("Choose your role to continue"),
            const SizedBox(height: 50),

            // Guardian Button
            _buildRoleButton(
              context,
              title: "I am a PARENT",
              subtitle: "Monitor my child's location",
              icon: Icons.family_restroom,
              color: Colors.blue,
              onTap: () {
                // Navigate to Parent Login
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuardianLoginScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Child Button
            _buildRoleButton(
              context,
              title: "I am a CHILD",
              subtitle: "Connect to my parents",
              icon: Icons.child_care,
              color: Colors.orange,
              onTap: () {
                // Navigate to Child Login (UPDATED)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChildLoginScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
