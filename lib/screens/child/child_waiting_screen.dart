import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'child_home_screen.dart';
import '../auth/role_selection_screen.dart';

class ChildWaitingScreen extends StatefulWidget {
  final String childName;
  final String pairingCode;

  const ChildWaitingScreen({
    super.key,
    required this.childName,
    required this.pairingCode,
  });

  @override
  State<ChildWaitingScreen> createState() => _ChildWaitingScreenState();
}

class _ChildWaitingScreenState extends State<ChildWaitingScreen> {
  final AuthService _auth = AuthService();
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _listenToPairingStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _listenToPairingStatus() {
    final requestId = "${widget.pairingCode}_${widget.childName.toLowerCase()}";
    _statusSubscription = _auth.pairingRequestStatusStream(requestId).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      if (status == 'accepted') {
        _statusSubscription?.cancel();
        _navigateToHome();
      } else if (status == 'rejected') {
        _statusSubscription?.cancel();
        _showRejectionDialog();
      }
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChildHomeScreen(
          childName: widget.childName,
          pairingCode: widget.pairingCode,
        ),
      ),
    );
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Connection Declined", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Your parent has declined this connection request. Please try again with the correct pairing code or name."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCancel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleCancel() async {
    _statusSubscription?.cancel();
    // Delete the request from DB on cancel to keep DB clean
    final requestId = "${widget.pairingCode}_${widget.childName.toLowerCase()}";
    try {
      await FirebaseFirestore.instance
          .collection('pairings')
          .doc('requests')
          .collection('items')
          .doc(requestId)
          .delete();
    } catch (e) {
      print("Error deleting pairing request on cancel: $e");
    }

    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pairing Status", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.white),
            onPressed: _handleCancel,
            tooltip: "Cancel pairing",
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Premium Visual Container with Circular Loading animation
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Waiting for Approval",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow("Child Name", widget.childName),
                    const Divider(height: 20),
                    _buildInfoRow("Pairing Code", widget.pairingCode),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Ask your parent to approve the request for '${widget.childName}' on their guardian dashboard.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "CANCEL REQUEST",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
