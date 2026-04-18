import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        title: const Text("Open Live Map?"),
        content:
            const Text("Go to Home tab to view the child location on the map."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Open"),
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
              color: selected ? Colors.blue : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black87,
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
          chip("All", "all"),
          const SizedBox(width: 8),
          chip("Active", "active"),
          const SizedBox(width: 8),
          chip("Resolved", "resolved"),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alerts")),
      body: _pairingCode == "Loading..."
          ? const Center(child: CircularProgressIndicator())
          : _pairingCode == "No Code"
              ? const Center(child: Text("No pairing code found."))
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
                                    ? "No alerts yet."
                                    : "No ${_filter.toUpperCase()} alerts.",
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

                              final bool isSos = type == 'SOS';
                              final bool isActive = status == 'active';

                              final Color accent = isSos
                                  ? (isActive ? Colors.red : Colors.grey)
                                  : (isActive ? Colors.orange : Colors.grey);

                              final IconData icon = isSos
                                  ? Icons.warning_rounded
                                  : Icons.notifications;

                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _openMapDialog,
                                child: Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              accent.withOpacity(0.15),
                                          child: Icon(icon, color: accent),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: isSos && isActive
                                                            ? Colors.red
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                  _StatusChip(
                                                      isActive: isActive,
                                                      accent: accent),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(message,
                                                  style: const TextStyle(
                                                      color: Colors.black87)),
                                              const SizedBox(height: 6),
                                              Text(
                                                _formatWhen(createdAt),
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            isActive ? accent.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? "ACTIVE" : "RESOLVED",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isActive ? accent : Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }
}
