import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../child/child_home_screen.dart';
import '../child/child_waiting_screen.dart';
import 'simulated_qr_scanner_screen.dart';
import '../../widgets/convex_curve_clipper.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  void _openQrScanner() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SimulatedQrScannerScreen()),
    );
    if (code != null) {
      setState(() {
        _codeController.text = code;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Magic QR Code Scanned successfully! ✨"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _handleConnect() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();

    if (code.length != 6 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write down your name and type the 6-digit magic code! 🧩"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _auth.loginChild(code, name);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        if (user.role == 'child') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Yay! Connected to your parents! 🎉"),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildHomeScreen(
                childName: user.name,
                pairingCode: code,
              ),
            ),
          );
        } else if (user.role == 'child_pending') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sent request! Waiting for parents to say yes... ⏳"),
              backgroundColor: Colors.orange,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildWaitingScreen(
                childName: name,
                pairingCode: code,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Oops! That code isn't matching. Ask your parents for the code! 🥺"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      final errorMsg = e.toString().replaceAll("Exception: ", "");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFFFBEB);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF97316), // Playful Orange header background
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored Header Area
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 28.0),
                child: Column(
                  children: [
                    // Back Button
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                          tooltip: "Back to Role Selection",
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Playful Happy Shield Custom Painter
                    const Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: HappyShieldPainter(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Hey Kiddo! 👋",
                      style: TextStyle(
                        fontSize: 32, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Let's connect your phone to your parent's radar!",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            // Curved body
            ClipPath(
              clipper: ConvexCurveClipper(),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Container(
                color: scaffoldBgColor,
                padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Friendly cartoon card container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: 0.2),
                          width: 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Kid name field label
                          Text(
                            "Write your name here:",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "e.g. Johnnie",
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFFEF3C7),
                              prefixIcon: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFF97316)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Code field label
                          Text(
                            "Type the 6-digit magic code:",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(height: 8),

                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              letterSpacing: 8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEA580C),
                            ),
                            decoration: InputDecoration(
                              hintText: "000000",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400, 
                                letterSpacing: 2, 
                                fontWeight: FontWeight.normal,
                                fontSize: 20,
                              ),
                              counterText: "",
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFFEF3C7),
                              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFF97316)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C)),
                                onPressed: _openQrScanner,
                                tooltip: "Scan QR Code",
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 28),
                          
                          // CONNECT button (puffy style)
                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFB923C), Color(0xFFF97316)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF97316).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _handleConnect,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      "LET'S CONNECT! 🚀",
                                      style: TextStyle(
                                        fontSize: 18, 
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cartoon character painter: A happy smiling orange shield holding a location balloon
class HappyShieldPainter extends CustomPainter {
  const HappyShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, cy + h * 0.05), w * 0.4, shadowPaint);

    // Draw main shield shape
    final shieldPaint = Paint()
      ..color = const Color(0xFFFB923C) // Bright orange
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final shieldPath = Path();
    shieldPath.moveTo(cx, cy - h * 0.40); // Top center
    shieldPath.quadraticBezierTo(cx + w * 0.28, cy - h * 0.42, cx + w * 0.35, cy - h * 0.20); // Top right
    shieldPath.quadraticBezierTo(cx + w * 0.35, cy + h * 0.10, cx, cy + h * 0.42); // Bottom right
    shieldPath.quadraticBezierTo(cx - w * 0.35, cy + h * 0.10, cx - w * 0.35, cy - h * 0.20); // Bottom left
    shieldPath.quadraticBezierTo(cx - w * 0.28, cy - h * 0.42, cx, cy - h * 0.40); // Top left
    shieldPath.close();
    canvas.drawPath(shieldPath, shieldPaint);

    // Draw inner cheeks (rosy pink circles)
    final cheekPaint = Paint()
      ..color = const Color(0xFFFCA5A5) // Soft pink
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx - w * 0.15, cy + h * 0.05), w * 0.05, cheekPaint);
    canvas.drawCircle(Offset(cx + w * 0.15, cy + h * 0.05), w * 0.05, cheekPaint);

    // Draw eyes (two happy black arcs/circles)
    final eyePaint = Paint()
      ..color = const Color(0xFF1E293B) // Dark blue-gray
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    
    // Left eye (winking or happy circle)
    canvas.drawCircle(Offset(cx - w * 0.13, cy - h * 0.06), w * 0.045, eyePaint);
    // Right eye
    canvas.drawCircle(Offset(cx + w * 0.13, cy - h * 0.06), w * 0.045, eyePaint);

    // Draw highlights in eyes (white shine dots)
    final shinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - w * 0.15, cy - h * 0.08), w * 0.015, shinePaint);
    canvas.drawCircle(Offset(cx + w * 0.11, cy - h * 0.08), w * 0.015, shinePaint);

    // Draw big smiley mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    
    final mouthPath = Path();
    mouthPath.moveTo(cx - w * 0.09, cy + h * 0.04);
    mouthPath.quadraticBezierTo(cx, cy + h * 0.16, cx + w * 0.09, cy + h * 0.04);
    canvas.drawPath(mouthPath, mouthPaint);

    // Draw happy tiny tongue inside mouth
    final tonguePaint = Paint()
      ..color = const Color(0xFFEF4444) // Red
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final tonguePath = Path()
      ..moveTo(cx - w * 0.04, cy + h * 0.10)
      ..quadraticBezierTo(cx, cy + h * 0.17, cx + w * 0.04, cy + h * 0.10)
      ..quadraticBezierTo(cx, cy + h * 0.12, cx - w * 0.04, cy + h * 0.10)
      ..close();
    canvas.drawPath(tonguePath, tonguePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
