import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
  bool _isSaving = false;

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

    setState(() => _isSaving = true);
    
    await _authService.setSpeedLimit(
      pairingCode: widget.pairingCode,
      speedKmh: val.toInt(),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  // HELPER: Contextual Mapping
  Map<String, dynamic> _getContextualMapping(double val) {
    if (val <= 15) {
      return {
        'label': 'Walking / Running',
        'icon': PhosphorIcons.personSimpleWalk(),
        'color': Colors.green,
      };
    } else if (val <= 40) {
      return {
        'label': 'Bicycle / School Zone',
        'icon': PhosphorIcons.bicycle(),
        'color': Colors.blue,
      };
    } else if (val <= 80) {
      return {
        'label': 'City Driving',
        'icon': PhosphorIcons.car(),
        'color': Colors.orange,
      };
    } else {
      return {
        'label': 'Highway Speeds',
        'icon': PhosphorIcons.roadHorizon(),
        'color': Colors.red,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final contextData = _getContextualMapping(_currentLimit);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("rules.title".tr()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "rules.speed_title".tr(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              "rules.speed_desc".tr(),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // SPEED CARD
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // AUTO-SAVE INDICATOR
                  Positioned(
                    top: 20,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _isSaving ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Colors.blue, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            "Auto-saved",
                            style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // TELEMETRY READOUT
                        Column(
                          children: [
                            Text(
                              "${_currentLimit.toInt()}",
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).primaryColor,
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              "KM/H",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.blue,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // THE SLIDER
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 12,
                            activeTrackColor: Colors.blue.shade600,
                            inactiveTrackColor: Colors.blue.shade50,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15, elevation: 4),
                            overlayColor: Colors.blue.withOpacity(0.1),
                          ),
                          child: Slider(
                            value: _currentLimit,
                            min: 10,
                            max: 120,
                            divisions: 11,
                            onChanged: (val) {
                              setState(() => _currentLimit = val);
                            },
                            onChangeEnd: (val) {
                              _saveRule(val);
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // CONTEXTUAL INDICATOR
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: (contextData['color'] as Color).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (contextData['color'] as Color).withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(contextData['icon'] as IconData, color: contextData['color'] as Color, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                contextData['label'] as String,
                                style: TextStyle(
                                  color: contextData['color'] as Color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            // INFO BOX
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.info(), color: Colors.blue.shade700),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "rules.info".tr(),
                      style: TextStyle(
                        fontSize: 13, 
                        height: 1.5,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
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
