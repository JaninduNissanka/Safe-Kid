import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../guardian/guardian_shell.dart';
import '../../widgets/safekid_logo.dart';
import '../../widgets/convex_curve_clipper.dart';

class GuardianLoginScreen extends StatefulWidget {
  const GuardianLoginScreen({super.key});

  @override
  State<GuardianLoginScreen> createState() => _GuardianLoginScreenState();
}

class _GuardianLoginScreenState extends State<GuardianLoginScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleEmailLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final error = await _auth.signInWithEmail(
      _emailController.text.trim(), 
      _passwordController.text.trim()
    );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GuardianShell()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!), backgroundColor: Colors.red),
      );
    }
  }

  void _handleEmailRegister() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password to register")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final error = await _auth.registerWithEmail(
      _emailController.text.trim(), 
      _passwordController.text.trim()
    );
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully! Please Sign In now."), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!), backgroundColor: Colors.red),
      );
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final error = await _auth.signInWithGoogle();
    setState(() => _isLoading = false);

    if (error == null && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GuardianShell()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error!), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1D4ED8), // Royal Blue header background
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
                    // Silhouette Logo
                    const Center(child: SafeKidLogo(size: 110)),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome to SafeKid", 
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Secure tracking and smart rules for your family",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                    // Form Container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextField(
                            controller: _emailController,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              labelText: "Email Address", 
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.blue),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                            decoration: InputDecoration(
                              labelText: "Password", 
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Solid blue gradient Sign In Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleEmailLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                                  : const Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Text Link to Register
                          TextButton(
                            onPressed: _isLoading ? null : _handleEmailRegister,
                            child: Text(
                              "Don't have an account? Tap to REGISTER",
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // OR divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade300, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text("OR", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey.shade300, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Corporate Google Sign-In Button
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide.none,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Custom Drawn Google G Silhouette
                            CustomPaint(
                              size: const Size(20, 20),
                              painter: GoogleGLogoPainter(),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Sign in with Google", 
                              style: TextStyle(
                                  fontSize: 15, 
                                  color: isDark ? Colors.white : Colors.black87, 
                                  fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

// Google G logo custom painter
class GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Draw colorful segments of the Google G logo
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = w * 0.5;
    final cy = h * 0.5;
    final r = w * 0.5;

    // Red Arc (Top)
    paint.color = const Color(0xFFEA4335);
    final pathRed = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - r * 0.7, cy - r * 0.7)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), -2.35, 1.57, false)
      ..close();
    canvas.drawPath(pathRed, paint);

    // Yellow Arc (Left)
    paint.color = const Color(0xFFFBBC05);
    final pathYellow = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - r * 0.7, cy + r * 0.7)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), -3.927, 1.57, false)
      ..close();
    canvas.drawPath(pathYellow, paint);

    // Green Arc (Bottom)
    paint.color = const Color(0xFF34A853);
    final pathGreen = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + r * 0.9, cy + r * 0.4)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), -5.497, 1.57, false)
      ..close();
    canvas.drawPath(pathGreen, paint);

    // Blue segment + bar (Right)
    paint.color = const Color(0xFF4285F4);
    final pathBlue = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + r, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), 0.0, -0.785, false)
      ..close();
    canvas.drawPath(pathBlue, paint);

    final pathBlueBar = Path()
      ..moveTo(cx, cy - r * 0.2)
      ..lineTo(cx + r, cy - r * 0.2)
      ..lineTo(cx + r, cy + r * 0.2)
      ..lineTo(cx, cy + r * 0.2)
      ..close();
    canvas.drawPath(pathBlueBar, paint);

    // Cover inner circle (white)
    final coverPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.5, coverPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
