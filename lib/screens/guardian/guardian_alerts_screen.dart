import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../widgets/convex_curve_clipper.dart';

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

  // Stores optimistic reaction states: { alertId: reactionEmoji }
  // A value of null is used for deselection (removed reaction).
  final Map<String, String?> _optimisticReactions = {};

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1D4ED8),
        toolbarHeight: 75,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AlertLogo(size: 44),
            const SizedBox(width: 12),
            Text(
              "alerts.title".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF1D4ED8),
        child: ClipPath(
          clipper: ConvexCurveClipper(),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.only(top: 24),
            child: _pairingCode == "Loading..."
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
                                    final currentReaction = _optimisticReactions.containsKey(docs[i].id)
                                        ? _optimisticReactions[docs[i].id]
                                        : data['reaction'] as String?;
      
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
      
                                    final isDark = Theme.of(context).brightness == Brightness.dark;
      
                                    if (!isActive) {
                                      accent = isDark ? Colors.blueGrey.shade400 : Colors.blueGrey;
                                      iconData = PhosphorIcons.checkCircle();
                                      bgColor = isDark ? Colors.blueGrey.withOpacity(0.15) : Colors.blueGrey.withOpacity(0.08);
                                    } else if (type == 'SOS') {
                                      accent = isDark ? Colors.red.shade300 : Colors.red;
                                      iconData = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
                                      bgColor = isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1);
                                    } else if (type == 'SPEED' || type == 'OVERSPEED') {
                                      accent = isDark ? Colors.orange.shade300 : Colors.orange;
                                      iconData = PhosphorIcons.gauge();
                                      bgColor = isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.withOpacity(0.1);
                                    } else if (type == 'ROUTE_ANOMALY') {
                                      accent = isDark ? Colors.purple.shade300 : Colors.purple;
                                      iconData = PhosphorIcons.brain();
                                      bgColor = isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.withOpacity(0.1);
                                    } else if (type == 'CHILD_MESSAGE') {
                                      accent = isDark ? Colors.indigo.shade300 : Colors.indigo;
                                      iconData = PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill);
                                      bgColor = isDark ? Colors.indigo.withOpacity(0.2) : Colors.indigo.withOpacity(0.1);
                                    } else {
                                      // Default for Zone or other active alerts
                                      accent = isDark ? Colors.amber.shade300 : Colors.amber.shade700;
                                      iconData = PhosphorIcons.mapPin();
                                      bgColor = isDark ? Colors.amber.withOpacity(0.2) : Colors.amber.withOpacity(0.1);
                                    }
      
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: type != 'CHILD_MESSAGE' ? _openMapDialog : null,
                                      child: Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: isActive ? accent.withOpacity(0.25) : Colors.transparent,
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
                                                    if (type == 'CHILD_MESSAGE') ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          _buildReactionEmojiButton(docs[i].id, '👍', currentReaction == '👍', currentReaction),
                                                          const SizedBox(width: 8),
                                                          _buildReactionEmojiButton(docs[i].id, '❤️', currentReaction == '❤️', currentReaction),
                                                          const SizedBox(width: 8),
                                                          _buildReactionEmojiButton(docs[i].id, '👌', currentReaction == '👌', currentReaction),
                                                          const SizedBox(width: 8),
                                                          _buildReactionEmojiButton(docs[i].id, '🙏', currentReaction == '🙏', currentReaction),
                                                        ],
                                                      ),
                                                    ],
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
                                              isActive
                                                  ? IconButton(
                                                      icon: Icon(
                                                        PhosphorIcons.checkCircle(),
                                                        color: accent,
                                                        size: 24,
                                                      ),
                                                      onPressed: () async {
                                                        // Resolve alert doc
                                                        await FirebaseFirestore.instance
                                                            .collection('alerts')
                                                            .doc(_pairingCode)
                                                            .collection('items')
                                                            .doc(docs[i].id)
                                                            .update({
                                                          'status': 'resolved',
                                                          'resolvedAt': FieldValue.serverTimestamp(),
                                                        });
      
                                                        // If SOS, clean up locations documents too
                                                        if (type == 'SOS') {
                                                          final locRef = FirebaseFirestore.instance
                                                              .collection('locations')
                                                              .doc(_pairingCode);
                                                          
                                                          await locRef.set({
                                                            'isSosActive': false,
                                                            'sosStatus': 'resolved',
                                                            'activeSosAlertId': FieldValue.delete(),
                                                            'sosResolvedAt': FieldValue.serverTimestamp(),
                                                          }, SetOptions(merge: true));
      
                                                          final childId = data['childId'];
                                                          if (childId != null && childId.isNotEmpty) {
                                                            await locRef.collection('devices').doc(childId).set({
                                                              'isSosActive': false,
                                                              'sosStatus': 'resolved',
                                                              'activeSosAlertId': FieldValue.delete(),
                                                              'sosResolvedAt': FieldValue.serverTimestamp(),
                                                            }, SetOptions(merge: true));
                                                          }
                                                        }
                                                      },
                                                    )
                                                  : Icon(
                                                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                                                      size: 20,
                                                      color: Colors.green.shade400,
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
          ),
        ),
      ),
    );
  }

  Widget _buildReactionEmojiButton(String alertId, String emoji, bool isSelected, String? currentReaction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        final previousReaction = currentReaction;
        final newReaction = isSelected ? null : emoji;

        // Apply optimistic update instantly
        setState(() {
          _optimisticReactions[alertId] = newReaction;
        });

        final docRef = FirebaseFirestore.instance
            .collection('alerts')
            .doc(_pairingCode)
            .collection('items')
            .doc(alertId);
        
        try {
          if (newReaction == null) {
            await docRef.update({'reaction': FieldValue.delete()});
          } else {
            await docRef.update({'reaction': emoji});
          }
          
          // Cleanup optimistic override once written successfully
          if (mounted) {
            setState(() {
              _optimisticReactions.remove(alertId);
            });
          }
        } catch (e) {
          debugPrint('Error updating reaction: $e');
          // Rollback on error
          if (mounted) {
            setState(() {
              _optimisticReactions[alertId] = previousReaction;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to update reaction. Check your connection."),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.indigo.withOpacity(0.3) : Colors.indigo.withOpacity(0.15))
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.indigo.shade300 : Colors.indigo)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
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

class AlertLogo extends StatelessWidget {
  final double size;

  const AlertLogo({super.key, this.size = 38.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: AlertLogoPainter(),
    );
  }
}

class AlertLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw a soft outer shadow for a premium 3D look
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.53), w * 0.48, shadowPaint);

    // 2. Draw thick white outer ring
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, whitePaint);

    // 3. Draw inner blue circle with linear gradient (cyan/light blue to royal blue)
    final rect = Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.40);
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF38BDF8), // Cyan / Sky blue at top
        Color(0xFF1D4ED8), // Royal blue at bottom
      ],
    );
    final Paint gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
      
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.40, gradientPaint);

    // 4. Draw rounded white warning triangle
    final ax = w * 0.5;
    final ay = h * 0.27;
    final bx = w * 0.73;
    final by = h * 0.67;
    final cx = w * 0.27;
    final cy = h * 0.67;

    // Scale factor for rounded corner endpoints
    const f = 0.16;
    
    final apvX = ax + f * (cx - ax);
    final apvY = ay + f * (cy - ay);
    final antX = ax + f * (bx - ax);
    final antY = ay + f * (by - ay);

    final bpvX = bx + f * (ax - bx);
    final bpvY = by + f * (ay - by);
    final bntX = bx + f * (cx - bx);
    final bntY = by + f * (cy - by);

    final cpvX = cx + f * (bx - cx);
    final cpvY = cy + f * (by - cy);
    final cntX = cx + f * (ax - cx);
    final cntY = cy + f * (ay - cy);

    final trianglePath = Path()
      ..moveTo(cntX, cntY)
      ..lineTo(apvX, apvY)
      ..quadraticBezierTo(ax, ay, antX, antY)
      ..lineTo(bpvX, bpvY)
      ..quadraticBezierTo(bx, by, bntX, bntY)
      ..lineTo(cpvX, cpvY)
      ..quadraticBezierTo(cx, cy, cntX, cntY)
      ..close();

    final trianglePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(trianglePath, trianglePaint);

    // 5. Draw blue exclamation mark inside the triangle (slightly tapered and rounded)
    final markPaint = Paint()
      ..color = const Color(0xFF1D4ED8) // Theme royal blue
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.052
      ..isAntiAlias = true;

    // Line part
    canvas.drawLine(
      Offset(ax, h * 0.44),
      Offset(ax, h * 0.56),
      markPaint,
    );

    // Dot part
    final dotPaint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(ax, h * 0.615), w * 0.03, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
