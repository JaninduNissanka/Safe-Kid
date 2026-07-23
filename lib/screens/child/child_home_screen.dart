import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../auth/role_selection_screen.dart';
import '../../services/sensor_fusion_service.dart';
import '../../widgets/convex_curve_clipper.dart';

class ChildHomeScreen extends StatefulWidget {
  final String childName;
  final String pairingCode; // ✅ REQUIRED for SOS -> locations/{pairingCode}

  const ChildHomeScreen({
    super.key,
    required this.childName,
    required this.pairingCode,
  });

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  bool _isSosActive = false;
  StreamSubscription? _messageReactionSub;
  Map<String, dynamic>? _lastSentMessageData;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // ✅ Pass both UID and Pairing Code for Web Sync
      _locationService.startTracking(user.uid, widget.pairingCode, widget.childName);
    }
    _startMessageReactionListener();
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _messageReactionSub?.cancel();
    super.dispose();
  }

  void _startMessageReactionListener() {
    _messageReactionSub?.cancel();
    _messageReactionSub = FirebaseFirestore.instance
        .collection('alerts')
        .doc(widget.pairingCode)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final childMessages = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'CHILD_MESSAGE' &&
            data['childId'] == widget.childName.toLowerCase();
      }).toList();

      if (childMessages.isNotEmpty) {
        final doc = childMessages.first;
        final data = doc.data();
        if (mounted) {
          setState(() {
            _lastSentMessageData = {
              'id': doc.id,
              'message': data['message'] ?? '',
              'reaction': data['reaction'],
              'status': data['status'] ?? 'active',
              'createdAt': data['createdAt'],
            };
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastSentMessageData = null;
          });
        }
      }
    }, onError: (err) {
      debugPrint("Error listening to child messages reaction: $err");
    });
  }

  Future<void> _triggerSOS() async {
    setState(() => _isSosActive = !_isSosActive);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // ✅ Write SOS to locations/{pairingCode} with child details
      await _authService.setSos(
        pairingCode: widget.pairingCode,
        isActive: _isSosActive,
        childId: widget.childName.toLowerCase(),
        childName: widget.childName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSosActive ? "SOS SENT! Parent alerted!" : "SOS cancelled",
          ),
          backgroundColor: _isSosActive ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send SOS: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendChildMessage(String msg) async {
    try {
      final alertRef = FirebaseFirestore.instance
          .collection('alerts')
          .doc(widget.pairingCode)
          .collection('items')
          .doc();
      await alertRef.set({
        'type': 'CHILD_MESSAGE',
        'title': 'Message from ${widget.childName}',
        'message': msg,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'childId': widget.childName.toLowerCase(),
        'childName': widget.childName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sent: \"$msg\""),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send message: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChatDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Message to Parent", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Type your message here...",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _sendChildMessage(text);
              }
              Navigator.pop(c);
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatusCard() {
    if (_lastSentMessageData == null) return const SizedBox.shrink();

    final msg = _lastSentMessageData!['message'] as String;
    final reaction = _lastSentMessageData!['reaction'] as String?;
    final isReacted = reaction != null && reaction.isNotEmpty;
    final isResolved = _lastSentMessageData!['status'] == 'resolved';

    final Color borderColor = isReacted
        ? Colors.green.shade400
        : (isResolved ? Colors.green.shade300 : Colors.grey.shade300);
    final Color bgColor = isReacted
        ? Colors.green.shade50.withOpacity(0.5)
        : (isResolved ? Colors.green.shade50.withOpacity(0.2) : Colors.grey.shade50.withOpacity(0.5));
    final String statusText = isReacted
        ? "Parent reacted to your message"
        : (isResolved ? "Parent read your message" : "Sent to parent (unread)");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isReacted || isResolved ? Colors.green.shade100 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReacted || isResolved ? Icons.done_all : Icons.done,
              color: isReacted || isResolved ? Colors.green.shade700 : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isReacted || isResolved ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isReacted) ...[
            const SizedBox(width: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      reaction,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _locationService.stopTracking();
    await _authService.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  void _showSentMessagesHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag indicator
                  Container(
                    width: 45,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Title Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Message History",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Tap trash to delete, see parent reactions",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Stream Builder of sent messages
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('alerts')
                          .doc(widget.pairingCode)
                          .collection('items')
                          .orderBy('createdAt', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // Filter by type and childId in memory to prevent missing index crashes
                        final docs = snapshot.data!.docs.where((doc) {
                          final data = doc.data();
                          return data['type'] == 'CHILD_MESSAGE' &&
                              data['childId'] == widget.childName.toLowerCase();
                        }).toList();

                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.orange.shade200),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No messages sent yet",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Use the quick options to send updates to your parent.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final msg = data['message'] ?? '';
                            final reaction = data['reaction'] as String?;
                            final isReacted = reaction != null && reaction.isNotEmpty;
                            final isResolved = data['status'] == 'resolved';
                            final Timestamp? ts = data['createdAt'] as Timestamp?;

                            final String timeStr = ts != null
                                ? DateFormat('hh:mm a').format(ts.toDate())
                                : 'Just now';

                            Color cardBorderColor = isReacted
                                ? Colors.green.shade400
                                : (isResolved ? Colors.green.shade300 : Colors.grey.shade300);
                            Color cardBgColor = isReacted
                                ? Colors.green.shade50.withOpacity(0.5)
                                : (isResolved ? Colors.green.shade50.withOpacity(0.2) : Colors.grey.shade50.withOpacity(0.5));
                            String statusLabel = isReacted
                                ? "Reacted"
                                : (isResolved ? "Read" : "Delivered");

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorderColor, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  // Icon / Reaction
                                  if (isReacted)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        reaction,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    )
                                  else
                                    Icon(
                                      isResolved ? Icons.done_all : Icons.done,
                                      color: isResolved ? Colors.green.shade700 : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 12),
                                  // Text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$statusLabel • $timeStr",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isResolved ? Colors.green.shade800 : Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      // Confirm delete
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text("Delete message?", style: TextStyle(fontWeight: FontWeight.bold)),
                                          content: const Text("This will remove the message from your parent's alert list too."),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c, false),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(c, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await FirebaseFirestore.instance
                                            .collection('alerts')
                                            .doc(widget.pairingCode)
                                            .collection('items')
                                            .doc(doc.id)
                                            .delete();
                                      }
                                    },
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Child Mode (Tracking On)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: "Message History",
            onPressed: _showSentMessagesHistory,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        color: Colors.orange,
        child: ClipPath(
          clipper: ConvexCurveClipper(),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 24),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildMessageStatusCard(),
                      // Penguin Mascot Illustration
                      const Center(
                        child: PenguinMascot(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.childName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            "Location Sharing Active",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      // Activity Simulator Controls
                      const SizedBox(height: 16),
                      _buildActivitySimulator(),
                      const SizedBox(height: 24),
      
                      // Quick Message Title
                      const Text(
                        "Message to parent",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 15),
      
                      // Message Pills Wrap
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10.0,
                        runSpacing: 12.0,
                        children: [
                          QuickMessagePill(
                            label: "🏠 I'm home",
                            onTap: () => _sendChildMessage("🏠 I'm home"),
                          ),
                          QuickMessagePill(
                            label: "🎓 I'm at school",
                            onTap: () => _sendChildMessage("🎓 I'm at school"),
                          ),
                          QuickMessagePill(
                            label: "🚶 I'm walking",
                            onTap: () => _sendChildMessage("🚶 I'm walking"),
                          ),
                          QuickMessagePill(
                            label: "👍 Everything's ok",
                            onTap: () => _sendChildMessage("👍 Everything's ok"),
                          ),
                          QuickMessagePill(
                            label: "🚗 I'll be there soon",
                            onTap: () => _sendChildMessage("🚗 I'll be there soon"),
                          ),
                          QuickMessagePill(
                            label: "Chat",
                            onTap: _showChatDialog,
                          ),
                        ],
                      ),
      
                      const SizedBox(height: 28),
      
                      // SOS Emergency Button
                      GestureDetector(
                        onTap: _triggerSOS,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 140,
                          width: 140,
                          decoration: BoxDecoration(
                            color: _isSosActive ? const Color(0xFFEF5350) : const Color(0xFFFF8A80),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: (_isSosActive ? const Color(0xFFEF5350) : const Color(0xFFFF8A80)).withOpacity(0.4),
                                blurRadius: _isSosActive ? 35 : 25,
                                spreadRadius: _isSosActive ? 12 : 8,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "SOS",
                              style: TextStyle(
                                fontSize: 34,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "I am in danger",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySimulator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "🛠️ Activity Recognition Simulator",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _simButton("Stationary", 'stationary', Icons.accessibility_new_rounded),
              _simButton("Walk", 'walking', Icons.directions_walk_rounded),
              _simButton("Run", 'running', Icons.directions_run_rounded),
              _simButton("Drive", 'in_vehicle', Icons.directions_car_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simButton(String label, String activity, IconData icon) {
    final bool isCurrent = SensorFusionService().isSimulationMode &&
        SensorFusionService().simulatedActivity == activity;

    return InkWell(
      onTap: () {
        setState(() {
          SensorFusionService().enableSimulation(true, activity);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Simulated Activity: $label"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, color: isCurrent ? Colors.white : Colors.orange, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isCurrent ? Colors.white : Colors.orange.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickMessagePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const QuickMessagePill({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class PenguinMascot extends StatelessWidget {
  const PenguinMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange.shade500,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: PenguinStarPainter(),
        ),
      ),
    );
  }
}

class PenguinStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Radial gradient background
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.width / 2,
        [const Color(0xFFFFB74D), const Color(0xFFF57C00)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Legs
    final legPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.48, size.height * 0.8), Offset(size.width * 0.44, size.height * 0.95), legPaint);
    canvas.drawLine(Offset(size.width * 0.68, size.height * 0.8), Offset(size.width * 0.66, size.height * 0.95), legPaint);

    // Main Body
    final bodyPaint = Paint()..color = const Color(0xFF263238);
    canvas.save();
    canvas.translate(size.width * 0.58, size.height * 0.48);
    canvas.rotate(-0.06);
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: size.width * 0.58, height: size.height * 0.68);
    canvas.drawOval(bodyRect, bodyPaint);
    
    // Hair tufts
    final hairPaint = Paint()..color = const Color(0xFF263238);
    final hairPath = Path()
      ..moveTo(0, -size.height * 0.34)
      ..quadraticBezierTo(size.width * 0.12, -size.height * 0.4, size.width * 0.15, -size.height * 0.32)
      ..quadraticBezierTo(size.width * 0.05, -size.height * 0.3, 0, -size.height * 0.34);
    canvas.drawPath(hairPath, hairPaint);

    // Belly/Face white area
    final bellyPaint = Paint()..color = const Color(0xFFFFFDF9);
    final bellyRect = Rect.fromCenter(center: Offset(-size.width * 0.04, size.height * 0.06), width: size.width * 0.46, height: size.height * 0.52);
    canvas.drawOval(bellyRect, bellyPaint);
    canvas.restore();

    // CLOSED HAPPY EYES
    final eyePaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final leftEyePath = Path()
      ..moveTo(size.width * 0.44, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.49, size.height * 0.32, size.width * 0.54, size.height * 0.35);
    canvas.drawPath(leftEyePath, eyePaint);

    final rightEyePath = Path()
      ..moveTo(size.width * 0.63, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.32, size.width * 0.73, size.height * 0.35);
    canvas.drawPath(rightEyePath, eyePaint);

    // Cheeks
    final cheekPaint = Paint()..color = const Color(0xFFFF8A80).withOpacity(0.6);
    canvas.drawCircle(Offset(size.width * 0.41, size.height * 0.42), 6, cheekPaint);
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.42), 6, cheekPaint);

    // Beak
    final beakPaint = Paint()..color = const Color(0xFFF57C00);
    final beakRect = Rect.fromCenter(center: Offset(size.width * 0.58, size.height * 0.38), width: 18, height: 14);
    canvas.drawOval(beakRect, beakPaint);

    // Draw the Star
    final starCenter = Offset(size.width * 0.32, size.height * 0.56);
    canvas.save();
    canvas.translate(starCenter.dx, starCenter.dy);
    canvas.rotate(-0.1);
    
    final starPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    
    final starPath = _calculateStarPath(0, 0, 5, size.width * 0.24, size.width * 0.11);
    canvas.drawPath(starPath, starPaint);

    // Highlights
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromLTWH(-size.width * 0.12, -size.height * 0.06, 10, 6), highlightPaint);
    canvas.drawOval(Rect.fromLTWH(-size.width * 0.08, size.height * 0.04, 6, 4), highlightPaint);

    canvas.restore();

    // Hugging Arms
    final armPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;

    // Left Arm
    final leftArmPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.48)
      ..quadraticBezierTo(size.width * 0.12, size.height * 0.54, size.width * 0.2, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.32, size.height * 0.58, size.width * 0.34, size.height * 0.52)
      ..close();
    canvas.drawPath(leftArmPath, armPaint);

    // Right Arm
    final rightArmPath = Path()
      ..moveTo(size.width * 0.76, size.height * 0.48)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.55, size.width * 0.44, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.56, size.height * 0.72, size.width * 0.72, size.height * 0.62)
      ..close();
    canvas.drawPath(rightArmPath, armPaint);
  }

  Path _calculateStarPath(double cx, double cy, int points, double outerRadius, double innerRadius) {
    Path path = Path();
    double angle = math.pi / points;
    for (int i = 0; i < 2 * points; i++) {
      double r = (i % 2 == 0) ? outerRadius : innerRadius;
      double currAngle = i * angle - math.pi / 2;
      double x = cx + math.cos(currAngle) * r;
      double y = cy + math.sin(currAngle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
