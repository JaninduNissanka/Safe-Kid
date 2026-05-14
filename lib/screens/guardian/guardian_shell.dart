import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/notification_service.dart';
import 'guardian_dashboard.dart';
import 'guardian_alerts_screen.dart';
import 'guardian_zones_screen.dart';
import 'guardian_rules_screen.dart';
import 'guardian_profile_screen.dart';

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

  Widget _badgeIcon({required Widget icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final unselectedColor = isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade400;

    final pages = [
      const GuardianDashboard(),
      GuardianAlertsScreen(onOpenMap: _goToHome),
      const GuardianZonesScreen(),
      GuardianRulesScreen(pairingCode: _pairingCode),
      const GuardianProfileScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBackgroundColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: navBackgroundColor,
          elevation: 0,
          selectedItemColor: const Color(0xFF5865F2), // Primary Blue
          unselectedItemColor: unselectedColor,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.house()),
              activeIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
              label: "navigation.home".tr(),
            ),
            BottomNavigationBarItem(
              icon: _badgeIcon(
                icon: Icon(PhosphorIcons.bell()),
                count: _activeAlertsCount,
              ),
              activeIcon: _badgeIcon(
                icon: Icon(PhosphorIcons.bell(PhosphorIconsStyle.fill)),
                count: _activeAlertsCount,
              ),
              label: "navigation.alerts".tr(),
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.crosshair()),
              activeIcon: Icon(PhosphorIcons.crosshair(PhosphorIconsStyle.fill)),
              label: "navigation.zones".tr(),
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.slidersHorizontal()),
              activeIcon: Icon(PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.fill)),
              label: "navigation.rules".tr(),
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIcons.user()),
              activeIcon: Icon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
              label: "navigation.profile".tr(),
            ),
          ],
        ),
      ),
    );
  }
}
