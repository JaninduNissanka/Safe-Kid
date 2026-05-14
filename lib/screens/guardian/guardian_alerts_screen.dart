import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GuardianAlertsScreen extends StatefulWidget {
  final VoidCallback onOpenMap;

  const GuardianAlertsScreen({super.key, required this.onOpenMap});

  @override
  State<GuardianAlertsScreen> createState() => _GuardianAlertsScreenState();
}

class _GuardianAlertsScreenState extends State<GuardianAlertsScreen> {
  String _pairingCode = "Loading...";

  // ✅ filter: all | active | resolved
  String _filter = "all";

  @override
  void initState() {
    super.initState();
    _fetchPairingCode();
  }

  Future<void> _fetchPairingCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final code = doc.data()?['pairingCode'] ?? "No Code";

    if (!mounted) return;
    setState(() => _pairingCode = code);
  }

  String _formatWhen(Timestamp? ts) {
    if (ts == null) return "Recent";
    final dt = ts.toDate();
    
    // Exact format: "17 Apr 2026, 08:30:45 PM"
    final day = dt.day.toString().padLeft(2, '0');
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final month = months[dt.month - 1];
    final year = dt.year;
    
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;

    return "$day $month $year, $hour:$minute:$second $ampm";
  }

  Future<void> _openMapDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("alerts.open_map_title".tr()),
        content: Text("alerts.open_map_content".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("alerts.cancel".tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("alerts.open".tr()),
          ),
        ],
      ),
    );

    if (ok == true) {
      widget.onOpenMap();
    }
  }

  // ✅ filter UI widget (3 buttons)
  Widget _buildFilterBar() {
    Widget chip(String label, String value) {
      final bool selected = _filter == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.blue : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? Colors.blue : (Theme.of(context).brightness == Brightness.light ? Colors.grey.shade300 : Colors.white10)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          chip("alerts.filter_all".tr(), "all"),
          const SizedBox(width: 8),
          chip("alerts.filter_active".tr(), "active"),
          const SizedBox(width: 8),
          chip("alerts.filter_resolved".tr(), "resolved"),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("alerts.title".tr())),
      body: _pairingCode == "Loading..."
          ? const Center(child: CircularProgressIndicator())
          : _pairingCode == "No Code"
              ? Center(child: Text("alerts.no_code".tr()))
              : Column(
                  children: [
                    _buildFilterBar(),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('alerts')
                            .doc(_pairingCode)
                            .collection('items')
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text("Error: ${snapshot.error}"));
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          // ✅ apply filter locally
                          final allDocs = snapshot.data!.docs;
                          final docs = allDocs.where((d) {
                            final status =
                                (d.data()['status'] ?? 'active') as String;
                            if (_filter == "all") return true;
                            if (_filter == "active") return status == "active";
                            if (_filter == "resolved") {
                              return status == "resolved";
                            }
                            return true;
                          }).toList();

                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                _filter == "all"
                                    ? "alerts.no_alerts".tr()
                                    : "alerts.no_filter_alerts".tr(args: [_filter.toUpperCase()]),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final data = docs[i].data();

                              final type = (data['type'] ?? '') as String;
                              final title =
                                  (data['title'] ?? 'Alert') as String;
                              final message = (data['message'] ?? '') as String;
                              final status =
                                  (data['status'] ?? 'active') as String;

                              final dynamic rawTime = data['createdAt'] ?? data['timestamp'];
                              final Timestamp? createdAt = rawTime is Timestamp ? rawTime : null;

                              final bool isActive = status == 'active';

                              // --- SEVERITY STYLING LOGIC ---
                              Color accent;
                              IconData iconData;
                              Color bgColor;

                              if (!isActive) {
                                accent = Colors.blueGrey.shade400;
                                iconData = PhosphorIcons.checkCircle();
                                bgColor = Colors.blueGrey.shade50;
                              } else if (type == 'SOS') {
                                accent = Colors.red;
                                iconData = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
                                bgColor = Colors.red.shade50;
                              } else if (type == 'SPEED') {
                                accent = Colors.orange;
                                iconData = PhosphorIcons.gauge();
                                bgColor = Colors.orange.shade50;
                              } else {
                                // Default for Zone or other active alerts
                                accent = Colors.amber.shade700;
                                iconData = PhosphorIcons.mapPin();
                                bgColor = Colors.amber.shade50;
                              }

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _openMapDialog,
                                child: Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isActive ? accent.withOpacity(0.2) : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  color: Theme.of(context).cardColor,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(iconData, color: accent, size: 28),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 15,
                                                        color: !isActive ? Colors.blueGrey.shade400 : null,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  _StatusChip(
                                                      isActive: isActive,
                                                      accent: accent),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                message,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: !isActive 
                                                      ? Colors.blueGrey.shade300 
                                                      : Theme.of(context).textTheme.bodyMedium?.color,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _formatWhen(createdAt),
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          PhosphorIcons.caretRight(),
                                          size: 18,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final Color accent;

  const _StatusChip({required this.isActive, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? accent.withOpacity(0.1) : Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? "alerts.status_active".tr() : "alerts.status_resolved".tr(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isActive ? accent : Colors.blueGrey.shade400,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
