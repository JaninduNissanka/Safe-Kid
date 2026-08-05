import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../auth/guardian_login_screen.dart';
import '../../widgets/convex_curve_clipper.dart';

class GuardianProfileScreen extends StatefulWidget {
  const GuardianProfileScreen({super.key});

  @override
  State<GuardianProfileScreen> createState() => _GuardianProfileScreenState();
}

class _GuardianProfileScreenState extends State<GuardianProfileScreen> {
  String? _parentUid;
  String? _pairingCode;

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _parentUid = user.uid;
          _pairingCode = doc.data()?['pairingCode'];
        });
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "?";
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final part = parts[0];
      return part.length >= 2
          ? part.substring(0, 2).toUpperCase()
          : part.toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  void _showEditProfileDialog(String currentName, String? currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone ?? "");
    final formKey = GlobalKey<FormState>();
    bool updating = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile Info",
              style: TextStyle(fontWeight: FontWeight.bold)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? "Name cannot be empty"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    prefixIcon: Icon(Icons.phone),
                    hintText: "+1234567890",
                  ),
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      final phoneRegex = RegExp(r'^\+?[0-9\s\-]{7,15}$');
                      if (!phoneRegex.hasMatch(val)) {
                        return "Invalid phone number format";
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: updating ? null : () => Navigator.pop(c),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: updating
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => updating = true);
                        try {
                          final newName = nameController.text.trim();
                          final newPhone = phoneController.text.trim();

                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                              'name': newName,
                              'phoneNumber': newPhone.isEmpty ? null : newPhone,
                            });
                            await user.updateDisplayName(newName);
                          }

                          if (context.mounted) {
                            Navigator.pop(c);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Profile updated successfully"),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => updating = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Save",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool updating = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change Password",
              style: TextStyle(fontWeight: FontWeight.bold)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      prefixIcon: const Icon(Icons.lock_open),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: "New Password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Required";
                      if (val.length < 6) {
                        return "Password must be at least 6 characters";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: "Confirm New Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Required";
                      if (val != newPasswordController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: updating ? null : () => Navigator.pop(c),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: updating
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => updating = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && user.email != null) {
                            final cred = EmailAuthProvider.credential(
                              email: user.email!,
                              password: currentPasswordController.text,
                            );
                            await user.reauthenticateWithCredential(cred);
                            await user
                                .updatePassword(newPasswordController.text);

                            if (context.mounted) {
                              Navigator.pop(c);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Password updated successfully"),
                                    backgroundColor: Colors.green),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => updating = false);
                          String errMsg = e.message ?? "An error occurred";
                          if (e.code == 'wrong-password') {
                            errMsg = "Incorrect current password";
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(errMsg),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => updating = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Change",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog(Map<String, dynamic>? currentPrefs) {
    bool sos = currentPrefs?['sosAlerts'] ?? true;
    bool geofence = currentPrefs?['geofenceBreaches'] ?? true;
    bool speed = currentPrefs?['speedAlerts'] ?? true;
    bool updating = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Notification Settings",
              style: TextStyle(fontWeight: FontWeight.bold)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("SOS Alerts",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text(
                    "Instant push notifications when child triggers SOS",
                    style: TextStyle(fontSize: 12)),
                value: sos,
                activeThumbColor: Colors.indigo,
                onChanged:
                    updating ? null : (val) => setDialogState(() => sos = val),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("Safe Zone Breaches",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text(
                    "Alert when child leaves or enters a safe zone",
                    style: TextStyle(fontSize: 12)),
                value: geofence,
                activeThumbColor: Colors.indigo,
                onChanged: updating
                    ? null
                    : (val) => setDialogState(() => geofence = val),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("Speed Limit Violations",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text(
                    "Alert when child exceeds rule speed threshold",
                    style: TextStyle(fontSize: 12)),
                value: speed,
                activeThumbColor: Colors.indigo,
                onChanged: updating
                    ? null
                    : (val) => setDialogState(() => speed = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: updating ? null : () => Navigator.pop(c),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: updating
                  ? null
                  : () async {
                      setDialogState(() => updating = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'notifications': {
                              'sosAlerts': sos,
                              'geofenceBreaches': geofence,
                              'speedAlerts': speed,
                            }
                          });
                        }
                        if (context.mounted) {
                          Navigator.pop(c);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Notification settings saved"),
                                backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => updating = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: updating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Save",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Terms of Service",
            style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const SingleChildScrollView(
          child: Text(
            "Welcome to SafeKid.\n\n"
            "1. Acceptance of Terms\n"
            "By creating an account, you agree to these Terms of Service. If you do not agree, do not use the service.\n\n"
            "2. Description of Service\n"
            "SafeKid provides real-time child location tracking, telemetry analysis, and zone breach notifications. It requires parent permission and child app installation.\n\n"
            "3. Parental Responsibility\n"
            "The parent/guardian is solely responsible for pairing child devices and monitoring notifications. SafeKid is an aid and not a replacement for parental supervision.\n\n"
            "4. Data Privacy\n"
            "We process children's location data solely to provide tracking alerts to authorized guardians. We do not sell or share location history with third parties.\n\n"
            "5. Limitation of Liability\n"
            "SafeKid relies on GPS, cellular networks, and internet access. We are not liable for gaps in tracking caused by device power loss, poor network connection, or hardware failures.",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Close",
                style: TextStyle(
                    color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Privacy Policy",
            style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const SingleChildScrollView(
          child: Text(
            "Last Updated: June 2026\n\n"
            "1. Information We Collect\n"
            "- Guardian account details: Name, Email, Phone Number.\n"
            "- Child account details: Display Name.\n"
            "- Child Location Data: Periodic coordinates (latitude, longitude, speed) required for geofencing and real-time mapping.\n\n"
            "2. How We Use Information\n"
            "Location data is shared strictly with the paired parent/guardian account. Speed limits are monitored to trigger alerts on the guardian's dashboard.\n\n"
            "3. Data Storage & Retention\n"
            "Location history is stored in our database for up to 7 days, after which it is automatically cleaned up. Guardian profiles are stored until account deletion.\n\n"
            "4. Your Rights & Control\n"
            "You can change profile info, remove paired child devices, or delete your account at any time, which purges all linked data permanently from our servers.",
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Close",
                style: TextStyle(
                    color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Help & Support",
            style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Frequently Asked Questions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Text(
                "Q: How do I pair a child?\n"
                "A: Copy the pairing code shown in the Dashboard tab, open SafeKid on your child's phone, enter the code and submit. Approve the request from your alerts list.\n\n"
                "Q: Why isn't child location updating?\n"
                "A: Ensure child device has location permissions set to 'Always' and internet connectivity is active.\n\n"
                "Q: How are speed limits triggered?\n"
                "A: Rules tab lets you set limits. An alert is sent if the child exceeds that speed for 3 consecutive GPS readings.",
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              Divider(height: 24),
              Text("Contact Us",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              Text(
                "Support Email: support@safekid.com\n"
                "Phone: +1 (800) 555-KIDS\n"
                "Hours: 24/7 Availability",
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Close",
                style: TextStyle(
                    color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool deleting = false;

    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("⚠️ Delete Account?",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This action is permanent and cannot be undone. Deleting your account will purge all children pairings, safe zones, speed rules, location histories, and alerts.",
                  style: TextStyle(
                      fontSize: 14, color: Colors.redAccent, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (!isGoogleUser) ...[
                  const Text(
                      "Please enter your current password to confirm deletion:"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Required" : null,
                  ),
                ] else ...[
                  const Text("Confirm permanent account deletion:"),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(c),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: deleting
                  ? null
                  : () async {
                      if (isGoogleUser || formKey.currentState!.validate()) {
                        setDialogState(() => deleting = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final uid = user.uid;

                            if (!isGoogleUser) {
                              final cred = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: passwordController.text);
                              await user.reauthenticateWithCredential(cred);
                            }

                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get();
                            final pairingCode = userDoc.data()?['pairingCode'];

                            final batch = FirebaseFirestore.instance.batch();

                            final childrenQuery = await FirebaseFirestore
                                .instance
                                .collection('users')
                                .where('guardianIds', arrayContains: uid)
                                .get();

                            for (var childDoc in childrenQuery.docs) {
                              batch.delete(childDoc.reference);
                            }

                            if (pairingCode != null &&
                                pairingCode != "No Code") {
                              batch.delete(FirebaseFirestore.instance
                                  .collection('rules')
                                  .doc(pairingCode));

                              final pairingsQuery = await FirebaseFirestore
                                  .instance
                                  .collection('pairings')
                                  .doc('requests')
                                  .collection('items')
                                  .where('parentId', isEqualTo: uid)
                                  .get();
                              for (var doc in pairingsQuery.docs) {
                                batch.delete(doc.reference);
                              }

                              final zonesQuery = await FirebaseFirestore
                                  .instance
                                  .collection('zones')
                                  .doc(pairingCode)
                                  .collection('items')
                                  .get();
                              for (var doc in zonesQuery.docs) {
                                batch.delete(doc.reference);
                              }
                              batch.delete(FirebaseFirestore.instance
                                  .collection('zones')
                                  .doc(pairingCode));

                              final devicesQuery = await FirebaseFirestore
                                  .instance
                                  .collection('locations')
                                  .doc(pairingCode)
                                  .collection('devices')
                                  .get();
                              for (var deviceDoc in devicesQuery.docs) {
                                final historyQuery = await deviceDoc.reference
                                    .collection('history')
                                    .get();
                                for (var hDoc in historyQuery.docs) {
                                  batch.delete(hDoc.reference);
                                }
                                batch.delete(deviceDoc.reference);
                              }
                              batch.delete(FirebaseFirestore.instance
                                  .collection('locations')
                                  .doc(pairingCode));

                              final alertsQuery = await FirebaseFirestore
                                  .instance
                                  .collection('alerts')
                                  .doc(pairingCode)
                                  .collection('items')
                                  .get();
                              for (var doc in alertsQuery.docs) {
                                batch.delete(doc.reference);
                              }
                              batch.delete(FirebaseFirestore.instance
                                  .collection('alerts')
                                  .doc(pairingCode));
                            }

                            batch.delete(FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid));
                            await batch.commit();
                            await user.delete();

                            if (context.mounted) {
                              Navigator.pop(c);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const GuardianLoginScreen()),
                                (route) => false,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Account successfully deleted"),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => deleting = false);
                          String errMsg = e.message ?? "An error occurred";
                          if (e.code == 'wrong-password') {
                            errMsg = "Incorrect password";
                          } else if (e.code == 'requires-recent-login') {
                            errMsg =
                                "Please sign out and sign back in before deleting account.";
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(errMsg),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => deleting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Delete Account",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveChild(String childUid, String childName) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Child",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            "Are you sure you want to remove '$childName'? This will stop tracking their location and disconnect them from your dashboard."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              if (_parentUid != null && _pairingCode != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Removing $childName...")),
                );

                await AuthService().removeChild(
                  parentId: _parentUid!,
                  childUid: childUid,
                  childName: childName,
                  pairingCode: _pairingCode!,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("$childName removed successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Remove",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String? phone) {
    final initials = _getInitials(name);
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).cardColor,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.blue,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _showEditProfileDialog(name, phone),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF0096C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(String parentUid) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'child')
                .where('guardianIds', arrayContains: parentUid)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _buildStatItem(
                count.toString(),
                "Children",
                Icons.child_care,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('zones')
                .doc(_pairingCode)
                .collection('items')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;
              return _buildStatItem(
                count.toString(),
                "Active Zones",
                Icons.gpp_good_outlined,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rules')
                .doc(_pairingCode)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.hasData
                  ? snap.data!.data() as Map<String, dynamic>?
                  : null;
              final speed = data?['speedLimitKmh'];
              final text = speed != null ? "$speed km/h" : "Not Set";
              return _buildStatItem(
                text,
                "Speed Limit",
                Icons.speed_outlined,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1D4ED8),
        toolbarHeight: 75,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProfileLogo(size: 44),
            const SizedBox(width: 12),
            Text(
              "profile.title".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          CustomAnimatedToggle(
            value: settings.isDarkMode,
            onChanged: (val) => settings.toggleTheme(val),
            leftIcon: Icons.wb_sunny,
            rightIcon: Icons.nightlight_round,
          ),
          const SizedBox(width: 8),
          CustomAnimatedToggle(
            value: context.locale.languageCode == 'si',
            onChanged: (val) {
              if (val) {
                context.setLocale(const Locale('si'));
              } else {
                context.setLocale(const Locale('en'));
              }
            },
            leftText: "🇬🇧",
            rightText: "🇱🇰",
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error loading profile details"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final name = userData?['name'] ?? user.displayName ?? "Guardian User";
          final email =
              userData?['email'] ?? user.email ?? "guardian@safekid.com";
          final phone = userData?['phoneNumber'] as String?;
          final pairingCode = userData?['pairingCode'] ?? "No Code";
          final twoFactorEnabled = userData?['twoFactorEnabled'] ?? false;
          final notificationPrefs =
              userData?['notifications'] as Map<String, dynamic>?;

          if (_parentUid != user.uid || _pairingCode != pairingCode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _parentUid = user.uid;
                  _pairingCode = pairingCode;
                });
              }
            });
          }

          return Container(
            color: const Color(0xFF1D4ED8),
            child: ClipPath(
              clipper: ConvexCurveClipper(),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.only(top: 24),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            _buildAvatar(name, phone),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (phone != null && phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStatsRow(user.uid),
                      const SizedBox(height: 32),
                      _buildSectionHeader("profile.account_security".tr()),
                      _buildSettingsGroup([
                        _buildSettingTile(
                          icon: Icons.person_outline,
                          title: "Edit Profile Details",
                          subtitle: "Update your name and phone number",
                          onTap: () => _showEditProfileDialog(name, phone),
                        ),
                        _buildSettingTile(
                          icon: Icons.lock_outline,
                          title: "profile.change_password".tr(),
                          subtitle: "Change account password securely",
                          onTap: _showChangePasswordDialog,
                        ),
                        _buildSettingTile(
                          icon: Icons.security,
                          title: "profile.two_factor".tr(),
                          subtitle: "Add layer of security to login",
                          trailing: Switch(
                            value: twoFactorEnabled,
                            activeThumbColor: Colors.indigo,
                            onChanged: (val) async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update({'twoFactorEnabled': val});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          val ? "2FA Enabled" : "2FA Disabled"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Error: $e"),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader("profile.preferences".tr()),
                      _buildSettingsGroup([
                        _buildSettingTile(
                          icon: Icons.notifications_none,
                          title: "profile.notification_settings".tr(),
                          subtitle: "SOS, Safe Zone, and Speed notifications",
                          onTap: () => _showNotificationSettingsDialog(
                              notificationPrefs),
                        ),
                        _buildSettingTile(
                          icon: Icons.palette_outlined,
                          title: "App Theme",
                          subtitle: settings.isDarkMode
                              ? "Dark Theme Enabled"
                              : "Light Theme Enabled",
                          trailing: Text(
                            settings.isDarkMode ? "Dark" : "Light",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ),
                        _buildSettingTile(
                          icon: Icons.language,
                          title: "App Language",
                          subtitle: context.locale.languageCode == 'si'
                              ? "Sinhala Language"
                              : "English Language",
                          trailing: Text(
                            context.locale.languageCode == 'si'
                                ? "Sinhala"
                                : "English",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      if (_pairingCode != null) ...[
                        _buildSectionHeader("Paired Children"),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', isEqualTo: 'child')
                              .where('guardianIds', arrayContains: user.uid)
                              .snapshots(),
                          builder: (context, childSnapshot) {
                            if (childSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !childSnapshot.hasData) {
                              return _buildSettingsGroup([
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              ]);
                            }
                            if (!childSnapshot.hasData ||
                                childSnapshot.data!.docs.isEmpty) {
                              return _buildSettingsGroup([
                                const ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  title: Text(
                                    "No children paired yet",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 15),
                                  ),
                                  leading: Icon(Icons.info_outline,
                                      color: Colors.grey),
                                )
                              ]);
                            }
                            final children = childSnapshot.data!.docs;
                            return _buildSettingsGroup(
                              children.map((childDoc) {
                                final childData =
                                    childDoc.data() as Map<String, dynamic>;
                                final String childUid = childDoc.id;
                                final String childName =
                                    childData['name'] ?? 'Child';
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.face,
                                        color: Colors.blue, size: 20),
                                  ),
                                  title: Text(
                                    childName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
                                    ),
                                  ),
                                  subtitle: const Text(
                                      "Device Paired & Syncing",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  trailing: TextButton(
                                    onPressed: () => _confirmRemoveChild(
                                        childUid, childName),
                                    child: const Text(
                                      "Remove",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildSectionHeader("App Information"),
                      _buildSettingsGroup([
                        _buildSettingTile(
                          icon: Icons.info_outline,
                          title: "Version",
                          subtitle: "SafeKid v1.0.0 (Production)",
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Connected",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        _buildSettingTile(
                          icon: Icons.help_outline,
                          title: "Help & Support",
                          subtitle: "Contact support and read FAQs",
                          onTap: _showHelpSupportDialog,
                        ),
                        _buildSettingTile(
                          icon: Icons.description_outlined,
                          title: "Terms of Service",
                          subtitle: "Legal usage agreement terms",
                          onTap: _showTermsDialog,
                        ),
                        _buildSettingTile(
                          icon: Icons.privacy_tip_outlined,
                          title: "Privacy Policy",
                          subtitle: "Data collection rules & details",
                          onTap: _showPrivacyPolicyDialog,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader("profile.danger_zone".tr(),
                          isDanger: true),
                      _buildSettingsGroup([
                        _buildSettingTile(
                          icon: Icons.logout,
                          title: "profile.sign_out".tr(),
                          subtitle: "Sign out of the current session",
                          isDanger: true,
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text("Sign Out",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                content: const Text(
                                    "Are you sure you want to sign out from SafeKid?"),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text("Cancel",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D4ED8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text("Sign Out",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await AuthService().signOut();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const GuardianLoginScreen()),
                                  (route) => false,
                                );
                              }
                            }
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.delete_forever,
                          title: "profile.delete_account".tr(),
                          subtitle:
                              "Permanently delete account and all paired child data",
                          isDanger: true,
                          onTap: _showDeleteAccountDialog,
                        ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDanger
              ? Colors.red.withOpacity(0.1)
              : Colors.indigo.withOpacity(0.1),
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
          color: isDanger
              ? Colors.red
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, size: 20, color: Colors.grey)
              : null),
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
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: leftIcon != null
                      ? Icon(leftIcon, size: 16, color: Colors.white)
                      : leftText != null
                          ? Text(leftText!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16))
                          : const SizedBox.shrink(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: rightIcon != null
                      ? Icon(rightIcon, size: 16, color: Colors.white)
                      : rightText != null
                          ? Text(rightText!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16))
                          : const SizedBox.shrink(),
                ),
              ),
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

class ProfileLogo extends StatelessWidget {
  final double size;

  const ProfileLogo({super.key, this.size = 44.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: ProfileLogoPainter(),
    );
  }
}

class ProfileLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.53), w * 0.48, shadowPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, whitePaint);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.40);
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF38BDF8),
        Color(0xFF1D4ED8),
      ],
    );
    final Paint gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), w * 0.40, gradientPaint);

    final whiteFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final torsoPath = Path();
    torsoPath.moveTo(cx - w * 0.28, cy + h * 0.32);
    torsoPath.quadraticBezierTo(
        cx - w * 0.26, cy + h * 0.11, cx - w * 0.13, cy + h * 0.09);
    torsoPath.quadraticBezierTo(
        cx, cy + h * 0.13, cx + w * 0.13, cy + h * 0.09);
    torsoPath.quadraticBezierTo(
        cx + w * 0.26, cy + h * 0.11, cx + w * 0.28, cy + h * 0.32);
    torsoPath.quadraticBezierTo(
        cx, cy + h * 0.38, cx - w * 0.28, cy + h * 0.32);
    torsoPath.close();
    canvas.drawPath(torsoPath, whiteFillPaint);

    canvas.drawCircle(Offset(cx, cy - h * 0.09), w * 0.145, whiteFillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
