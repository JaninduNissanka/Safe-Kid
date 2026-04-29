import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class GuardianRulesScreen extends StatefulWidget {
  final String pairingCode;
  const GuardianRulesScreen({super.key, required this.pairingCode});

  @override
  State<GuardianRulesScreen> createState() => _GuardianRulesScreenState();
}

class _GuardianRulesScreenState extends State<GuardianRulesScreen> {
  final AuthService _authService = AuthService();
  double _currentLimit = 40.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRules();
  }

  Future<void> _loadCurrentRules() async {
    if (widget.pairingCode == "Loading..." || widget.pairingCode == "No Code") {
      setState(() => _isLoading = false);
      return;
    }

    final doc = await _authService.rulesStream(widget.pairingCode).first;
    if (doc.exists) {
      setState(() {
        _currentLimit = (doc.data()?['speedLimitKmh'] ?? 40.0).toDouble();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRule(double val) async {
    if (widget.pairingCode == "No Code") return;

    await _authService.setSpeedLimit(
      pairingCode: widget.pairingCode,
      speedKmh: val.toInt(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚀 Speed Limit Updated!"),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Parental Rules"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Speed & Telemetry",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Set a threshold to receive instant alerts if the child exceeds a safe speed (e.g. they enter a vehicle).",
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // SPEED CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Limit Threshold", style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_currentLimit.toInt()} KM/H",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _currentLimit,
                    min: 10,
                    max: 120,
                    divisions: 11,
                    label: "${_currentLimit.round()} km/h",
                    activeColor: Colors.blue,
                    inactiveColor: Colors.blue.shade100,
                    onChanged: (val) {
                      setState(() => _currentLimit = val);
                    },
                    onChangeEnd: (val) {
                      _saveRule(val);
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("10 km/h", style: TextStyle(fontSize: 10, color: Colors.blue)),
                      Text("120 km/h", style: TextStyle(fontSize: 10, color: Colors.blue)),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            // INFO BOX
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "To avoid false alarms (GPS bounce), the system only triggers an alert after 3 consecutive readings above the limit.",
                      style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.light ? Colors.brown : Colors.amber.shade100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
