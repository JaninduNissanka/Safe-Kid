import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimulatedQrScannerScreen extends StatefulWidget {
  const SimulatedQrScannerScreen({super.key});

  @override
  State<SimulatedQrScannerScreen> createState() => _SimulatedQrScannerScreenState();
}

class _SimulatedQrScannerScreenState extends State<SimulatedQrScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _simulateScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      // Fetch the most recently created/active parent user doc to get their code
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'guardian')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final parentData = query.docs.first.data();
        final code = parentData['pairingCode'] as String?;
        
        // Wait 1.5 seconds for visual scanning laser effect
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted && code != null) {
          Navigator.pop(context, code);
          return;
        }
      }
      
      throw Exception("No active parents found in database");
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Simulated Scan Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Simulate QR Scanner", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background simulation graphics
          Center(
            child: Opacity(
              opacity: 0.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_outlined, size: 100, color: Colors.white),
                  const SizedBox(height: 20),
                  Text(
                    _isScanning ? "READING MATRIX DATA..." : "VIEWFINDER SIMULATED",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  )
                ],
              ),
            ),
          ),

          // Scanning Target Frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Laser Line Animation
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: 242 * _animationController.value,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom simulated action triggers
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Column(
              children: [
                const Text(
                  "Point at parent's QR code or tap below to auto-simulate.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                _isScanning
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange))
                    : ElevatedButton.icon(
                        onPressed: _simulateScan,
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        label: const Text("SIMULATE SCAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
