import 'package:flutter/material.dart';

class GuardianRulesScreen extends StatelessWidget {
  const GuardianRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rules")),
      body: const Center(
        child: Text("Speed limit / Dwell time / Alert cooldown settings."),
      ),
    );
  }
}
