import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/notification_service.dart';
import 'guardian_dashboard.dart';
import 'guardian_alerts_screen.dart';
import 'guardian_zones_screen.dart';
import 'guardian_rules_screen.dart';
import 'guardian_settings_screen.dart';

class GuardianShell extends StatefulWidget {
  const GuardianShell({super.key});

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell> {
  int _index = 0;

  String _pairingCode = "Loading...";
  int _activeAlertsCount = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertsSub;

  @override
  void initState() {
    super.initState();
    _loadPairingCodeAndListenBadge();
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    super.dispose();
  }

  void _goToHome() {
    setState(() => _index = 0);
  }

  Future<void> _loadPairingCodeAndListenBadge() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final code = doc.data()?['pairingCode'] ?? "No Code";

    if (!mounted) return;
    setState(() => _pairingCode = code);

    // Start listening to active alerts
    if (code != "No Code") {
      _listenActiveAlertsCount(code);
    }
  }

  void _listenActiveAlertsCount(String pairingCode) {
    _alertsSub?.cancel();

    bool isFirstLoad = true;

    _alertsSub = FirebaseFirestore.instance
        .collection('alerts')
        .doc(pairingCode)
        .collection('items')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      
      setState(() => _activeAlertsCount = snap.docs.length);

      if (!isFirstLoad) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final title = data['title'] ?? '🚨 Security Alert';
              final msg = data['message'] ?? 'Please check the dashboard.';
              
              // Drop an OS-level notification!
              NotificationService().showNotification(
                id: change.doc.id.hashCode,
                title: title,
                body: msg,
              );
            }
          }
        }
      }
      isFirstLoad = false;
    });
  }

  Widget _badgeIcon({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? "99+" : "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const GuardianDashboard(),
      GuardianAlertsScreen(onOpenMap: _goToHome),
      const GuardianZonesScreen(),
      const GuardianRulesScreen(),
      const GuardianSettingsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: _badgeIcon(
                icon: Icons.notifications, count: _activeAlertsCount),
            label: "Alerts",
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.my_location), label: "Zones"),
          const BottomNavigationBarItem(icon: Icon(Icons.tune), label: "Rules"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}
