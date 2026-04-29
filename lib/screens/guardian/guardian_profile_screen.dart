import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../auth/guardian_login_screen.dart';

class GuardianProfileScreen extends StatefulWidget {
  const GuardianProfileScreen({super.key});

  @override
  State<GuardianProfileScreen> createState() => _GuardianProfileScreenState();
}

class _GuardianProfileScreenState extends State<GuardianProfileScreen> {
  bool _twoFactorEnabled = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        toolbarHeight: 80,
        title: Text(
          "My Profile",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        actions: [
          // Theme Toggle
          CustomAnimatedToggle(
            value: settings.isDarkMode,
            onChanged: (val) => settings.toggleTheme(val),
            leftIcon: Icons.wb_sunny,
            rightIcon: Icons.nightlight_round,
          ),
          const SizedBox(width: 8),
          // Language Toggle
          CustomAnimatedToggle(
            value: settings.isSinhala,
            onChanged: (val) => settings.toggleLanguage(val),
            leftText: "EN",
            rightText: "SI",
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Header
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).cardColor,
                          child: const Icon(Icons.person_outline, size: 50, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0096C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Guardian User",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const Text(
                    "guardian@safekid.com",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Section 1: Account Security
            _buildSectionHeader("Account Security"),
            _buildSettingsGroup([
              _buildSettingTile(
                icon: Icons.lock_outline,
                title: "Change Password",
                onTap: () {},
              ),
              _buildSettingTile(
                icon: Icons.security,
                title: "Two-Factor Authentication",
                trailing: Switch(
                  value: _twoFactorEnabled,
                  activeColor: Colors.indigo,
                  onChanged: (val) => setState(() => _twoFactorEnabled = val),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Section 2: Preferences
            _buildSectionHeader("Preferences"),
            _buildSettingsGroup([
              _buildSettingTile(
                icon: Icons.notifications_none,
                title: "Notification Settings",
                onTap: () {},
              ),
              // Dark Mode removed from here as it's now in the header
            ]),

            const SizedBox(height: 24),

            // Section 3: Danger Zone
            _buildSectionHeader("Danger Zone", isDanger: true),
            _buildSettingsGroup([
              _buildSettingTile(
                icon: Icons.logout,
                title: "Sign Out",
                isDanger: true,
                onTap: () async {
                  await AuthService().signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const GuardianLoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              _buildSettingTile(
                icon: Icons.delete_forever,
                title: "Delete Account",
                isDanger: true,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool isDanger = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: isDanger ? Colors.red : Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDanger ? Colors.red.withOpacity(0.1) : Colors.indigo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDanger ? Colors.red : Colors.indigo,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDanger ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class CustomAnimatedToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final String? leftText;
  final String? rightText;

  const CustomAnimatedToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.leftIcon,
    this.rightIcon,
    this.leftText,
    this.rightText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 70,
          height: 35,
          decoration: BoxDecoration(
            color: value ? Colors.blue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Left Content
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: leftIcon != null
                      ? Icon(leftIcon, size: 16, color: Colors.white)
                      : leftText != null
                          ? Text(leftText!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                          : const SizedBox.shrink(),
                ),
              ),
              // Right Content
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: rightIcon != null
                      ? Icon(rightIcon, size: 16, color: Colors.white)
                      : rightText != null
                          ? Text(rightText!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                          : const SizedBox.shrink(),
                ),
              ),
              // The Sliding Thumb
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
