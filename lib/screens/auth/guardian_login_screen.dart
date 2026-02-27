import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../guardian/guardian_shell.dart'; // ✅ CHANGED (was guardian_dashboard.dart)

class GuardianLoginScreen extends StatefulWidget {
  const GuardianLoginScreen({super.key});

  @override
  State<GuardianLoginScreen> createState() => _GuardianLoginScreenState();
}

class _GuardianLoginScreenState extends State<GuardianLoginScreen> {
  // Text controllers to read the inputs
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // The service that talks to Firebase
  final AuthService _auth = AuthService();

  // Loading state (to show spinner)
  bool _isLoading = false;

  // --- LOGIN LOGIC ---
  void _handleLogin() async {
    // 1. Basic Validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Call Firebase (Login)
    final String? error = await _auth.loginGuardian(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    // 3. Check Result
    if (error == null) {
      // ✅ SUCCESS -> go to the 5-tab dashboard shell
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GuardianShell()),
          (route) => false, // Clears the back button history
        );
      }
    } else {
      // FAILURE: Show the specific error from Firebase
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- REGISTER LOGIC (For new accounts) ---
  void _handleQuickRegister() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email/pass to register")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Call Firebase (Register)
    final String? error = await _auth.registerGuardian(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      "Parent User", // Default name
    );

    setState(() => _isLoading = false);

    if (error == null) {
      // SUCCESS
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account Created! Now click LOGIN."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // FAILURE
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parent Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Welcome Back",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Email Input
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),

              // Password Input
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 25),

              // Login Button
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          "LOGIN",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              // Register Button
              TextButton(
                onPressed: _handleQuickRegister,
                child: const Text("Don't have an account? Tap to REGISTER"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
