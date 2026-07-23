import 'package:flutter/material.dart';
import 'guardian_login_screen.dart';
import 'child_login_screen.dart';
import '../../widgets/safekid_logo.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFF0F6FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Premium Custom SafeKidLogo Silhouette
                const Center(
                  child: SafeKidCartoonLogo(size: 190),
                ),
                const SizedBox(height: 36),

                // Title and taglines
                Text(
                  "SafeKid",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose your role to continue",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.blueGrey.shade300 : const Color(0xFF64748B),
                  ),
                ),

                const Spacer(flex: 2),

                // Interactive Modern Role Panels
                _buildRoleCard(
                  context: context,
                  title: "I am a PARENT",
                  subtitle: "Monitor location, rules, alerts & limits",
                  icon: Icons.family_restroom_rounded,
                  accentColor: const Color(0xFF1D4ED8), // Royal Blue
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GuardianLoginScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                _buildRoleCard(
                  context: context,
                  title: "I am a CHILD",
                  subtitle: "Pair phone, send SOS alerts & sync location",
                  icon: Icons.child_care_rounded,
                  accentColor: const Color(0xFFEA580C), // Playful Orange
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChildLoginScreen(),
                      ),
                    );
                  },
                ),

                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
            child: Row(
              children: [
                // Circular icon frame
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 32, color: accentColor),
                ),
                const SizedBox(width: 18),
                
                // Card details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.blueGrey.shade200 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Chevron end indicator
                Icon(
                  Icons.chevron_right_rounded,
                  color: accentColor.withValues(alpha: 0.6),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
