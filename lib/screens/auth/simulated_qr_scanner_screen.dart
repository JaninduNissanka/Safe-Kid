import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimulatedQrScannerScreen extends StatefulWidget {
  const SimulatedQrScannerScreen({super.key});

  @override
  State<SimulatedQrScannerScreen> createState() => _SimulatedQrScannerScreenState();
}

class _SimulatedQrScannerScreenState extends State<SimulatedQrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isDisposed = false;
  bool _isScanned = false;

  @override
  void dispose() {
    _isDisposed = true;
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned || _isDisposed) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        // Extract 6-digit pairing code from scanned QR string
        final RegExp regExp = RegExp(r'\b\d{6}\b');
        final match = regExp.firstMatch(rawValue);
        final String code = match != null ? match.group(0)! : rawValue.trim();

        _isScanned = true;
        if (mounted) {
          Navigator.pop(context, code);
        }
        break;
      }
    }
  }

  void _simulateScan() async {
    if (_isScanned) return;
    setState(() => _isScanned = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'guardian')
          .limit(20)
          .get();

      if (query.docs.isNotEmpty) {
        final sortedDocs = query.docs.toList();
        sortedDocs.sort((a, b) {
          final tA = a.data()['createdAt'] as Timestamp?;
          final tB = b.data()['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        final parentData = sortedDocs.first.data();
        final code = parentData['pairingCode'] as String?;

        if (mounted && code != null) {
          Navigator.pop(context, code);
          return;
        }
      }

      throw Exception("No active parent account found in database.");
    } catch (e) {
      if (mounted) {
        setState(() => _isScanned = false);
        final cleanMsg = e.toString().replaceAll("Exception: ", "").replaceAll(RegExp(r'\[.*?\]'), '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Demo Scan Failed: $cleanMsg"),
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
        title: const Text("Scan Parent's QR Code", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. REAL PHYSICAL CAMERA FEED
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
                      const SizedBox(height: 16),
                      const Text(
                        "Camera permission required for QR scanning.",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _simulateScan,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text("Use Quick Pairing Code"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. VIEWFINDER OVERLAY & SCANNING FRAME
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF97316), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // 3. HELPER INSTRUCTIONS & AUTO-SIMULATE BUTTON
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Point camera at Parent's QR Code",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _simulateScan,
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text("AUTO-SIMULATE FOR DEMO / TEST"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
