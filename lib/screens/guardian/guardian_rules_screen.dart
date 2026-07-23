import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/convex_curve_clipper.dart';

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
  bool _isEnabled = true;

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
      final speedLimit = (doc.data()?['speedLimitKmh'] ?? 40.0).toDouble();
      setState(() {
        if (speedLimit >= 999.0) {
          _isEnabled = false;
          _currentLimit = 40.0; // Fallback display default
        } else {
          _isEnabled = true;
          _currentLimit = speedLimit;
        }
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
      speedKmh: _isEnabled ? val.toInt() : 999,
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  void _toggleEnabled(bool value) {
    setState(() {
      _isEnabled = value;
    });
    _saveRule(_currentLimit);
  }

  Map<String, dynamic> _getContextualMapping(double val) {
    if (!_isEnabled) {
      return {
        'label': 'Alerts Disabled',
        'icon': PhosphorIcons.bellSlash(),
        'color': Colors.grey,
        'desc': 'Muted. The child can travel in any vehicle without generating alarms.',
      };
    }
    if (val <= 15) {
      return {
        'label': 'Walking / Running',
        'icon': PhosphorIcons.personSimpleWalk(),
        'color': Colors.green,
        'desc': 'Alerts you if the child runs excessively fast or boards a skateboard/bicycle.',
      };
    } else if (val <= 40) {
      return {
        'label': 'Bicycle / School Zone',
        'icon': PhosphorIcons.bicycle(),
        'color': Colors.blue,
        'desc': 'Ideal boundary checks for cycling and crossing slow school zones.',
      };
    } else if (val <= 80) {
      return {
        'label': 'City Driving',
        'icon': PhosphorIcons.car(),
        'color': Colors.orange,
        'desc': 'Alerts if the child enters a moving car, bus, or taxi inside standard city roads.',
      };
    } else {
      return {
        'label': 'Highway Speeds',
        'icon': PhosphorIcons.roadHorizon(),
        'color': Colors.red,
        'desc': 'Recommended for fast commutes. Alerts only at high highway speeds.',
      };
    }
  }

  Widget _buildRoundButton({required IconData icon, VoidCallback? onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: onPressed != null ? Colors.blue : Colors.grey,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPresetCard(
    String title,
    double speed,
    IconData icon,
    bool isActive,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String subtitle = "";
    if (speed == 15) subtitle = "Runs, skateboards";
    if (speed == 40) subtitle = "Cycling, school zone";
    if (speed == 60) subtitle = "City bus & car";
    if (speed == 100) subtitle = "Highways & trains";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isEnabled
            ? () {
                setState(() {
                  _currentLimit = speed;
                });
                _saveRule(_currentLimit);
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? color
                  : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15)),
              width: isActive ? 2.5 : 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Opacity(
            opacity: _isEnabled ? 1.0 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: isActive ? color : Colors.blueGrey, size: 24),
                    if (isActive)
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? color : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${speed.toInt()} km/h",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isActive ? color : Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contextData = _isLoading ? null : _getContextualMapping(_currentLimit);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1D4ED8),
        toolbarHeight: 75,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RulesLogo(size: 44),
            const SizedBox(width: 12),
            Text(
              "rules.title".tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF1D4ED8),
        child: ClipPath(
          clipper: ConvexCurveClipper(),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.only(top: 24),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
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
                        const SizedBox(height: 24),

                        // MASTER SWITCH CARD
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isEnabled
                                  ? Colors.blue.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SwitchListTile(
                            title: const Text(
                              "Speed Monitoring Alerts",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              _isEnabled
                                  ? "Velocity thresholds are being tracked"
                                  : "Velocity alerts are currently disabled",
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: _isEnabled,
                            activeThumbColor: Colors.blue,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isEnabled ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isEnabled ? PhosphorIcons.shieldCheck() : PhosphorIcons.shieldWarning(),
                                color: _isEnabled ? Colors.blue : Colors.grey,
                              ),
                            ),
                            onChanged: _toggleEnabled,
                          ),
                        ),
                        const SizedBox(height: 24),
            
                        // SPEED CARD
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
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
                                        "Saved",
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
                                    
                                    // TELEMETRY READOUT WITH BUTTONS
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildRoundButton(
                                          icon: Icons.remove,
                                          onPressed: _isEnabled && _currentLimit > 10
                                              ? () {
                                                  setState(() {
                                                    _currentLimit = (_currentLimit - 5).clamp(10, 120);
                                                  });
                                                  _saveRule(_currentLimit);
                                                }
                                              : null,
                                        ),
                                        const SizedBox(width: 24),
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 140,
                                              height: 140,
                                              child: CircularProgressIndicator(
                                                value: _isEnabled ? (_currentLimit - 10) / 110 : 0.0,
                                                strokeWidth: 8,
                                                backgroundColor: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.08),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _isEnabled ? (contextData!['color'] as Color) : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _isEnabled ? "${_currentLimit.toInt()}" : "--",
                                                  style: TextStyle(
                                                    fontSize: 48,
                                                    fontWeight: FontWeight.w900,
                                                    color: _isEnabled
                                                        ? (contextData!['color'] as Color)
                                                        : Colors.grey,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                Text(
                                                  "KM/H",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: _isEnabled ? Colors.blueGrey : Colors.grey,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 24),
                                        _buildRoundButton(
                                          icon: Icons.add,
                                          onPressed: _isEnabled && _currentLimit < 120
                                              ? () {
                                                  setState(() {
                                                    _currentLimit = (_currentLimit + 5).clamp(10, 120);
                                                  });
                                                  _saveRule(_currentLimit);
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // THE SLIDER
                                    SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 8,
                                        activeTrackColor: _isEnabled ? (contextData!['color'] as Color) : Colors.grey.shade400,
                                        inactiveTrackColor: _isEnabled 
                                            ? (contextData!['color'] as Color).withValues(alpha: 0.1) 
                                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                                        thumbColor: Colors.white,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14, elevation: 4),
                                        overlayColor: _isEnabled 
                                            ? (contextData!['color'] as Color).withValues(alpha: 0.12) 
                                            : Colors.transparent,
                                      ),
                                      child: Slider(
                                        value: _currentLimit,
                                        min: 10,
                                        max: 120,
                                        divisions: 22, // Steps of 5 km/h
                                        onChanged: _isEnabled
                                            ? (val) {
                                                setState(() => _currentLimit = val);
                                              }
                                            : null,
                                        onChangeEnd: _isEnabled
                                            ? (val) {
                                                _saveRule(val);
                                              }
                                            : null,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // CONTEXTUAL MODE DETAILS CARD
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: (contextData!['color'] as Color).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: (contextData['color'] as Color).withValues(alpha: 0.15)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(contextData['icon'] as IconData, color: contextData['color'] as Color, size: 24),
                                              const SizedBox(width: 12),
                                              Text(
                                                contextData['label'] as String,
                                                style: TextStyle(
                                                  color: contextData['color'] as Color,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            contextData['desc'] as String,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
                        const SizedBox(height: 24),

                        // PRESET QUICK SELECTIONS
                        Text(
                          "Quick Modes".toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                        const SizedBox(height: 12),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                          children: [
                            _buildPresetCard('Walking', 15, PhosphorIcons.personSimpleWalk(), _currentLimit == 15 && _isEnabled, Colors.green),
                            _buildPresetCard('Cycling', 40, PhosphorIcons.bicycle(), _currentLimit == 40 && _isEnabled, Colors.blue),
                            _buildPresetCard('City Road', 60, PhosphorIcons.car(), _currentLimit == 60 && _isEnabled, Colors.orange),
                            _buildPresetCard('Highway', 100, PhosphorIcons.roadHorizon(), _currentLimit == 100 && _isEnabled, Colors.red),
                          ],
                        ),
            
                        const SizedBox(height: 24),
                        
                        // INFO BOX
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withValues(alpha: 0.5),
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
          ),
        ),
      ),
    );
  }
}

class RulesLogo extends StatelessWidget {
  final double size;

  const RulesLogo({super.key, this.size = 44.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: RulesLogoPainter(),
    );
  }
}

class RulesLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.53), w * 0.48, shadowPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, whitePaint);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.40);
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF38BDF8),
        Color(0xFF1D4ED8),
      ],
    );
    final Paint gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), w * 0.40, gradientPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(Offset(cx - w * 0.26, cy - h * 0.15), Offset(cx - w * 0.10, cy - h * 0.15), linePaint);
    canvas.drawLine(Offset(cx - w * 0.26, cy - h * 0.06), Offset(cx - w * 0.04, cy - h * 0.06), linePaint);
    canvas.drawLine(Offset(cx - w * 0.26, cy + h * 0.03), Offset(cx + w * 0.02, cy + h * 0.03), linePaint);
    canvas.drawLine(Offset(cx - w * 0.26, cy + h * 0.12), Offset(cx - w * 0.12, cy + h * 0.12), linePaint);
    canvas.drawLine(Offset(cx - w * 0.26, cy + h * 0.21), Offset(cx - w * 0.20, cy + h * 0.21), linePaint);

    final runnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawLine(Offset(cx + w * 0.05, cy - h * 0.08), Offset(cx - w * 0.05, cy + h * 0.07), runnerPaint);

    final leftArmPath = Path()
      ..moveTo(cx + w * 0.05, cy - h * 0.08)
      ..lineTo(cx - w * 0.08, cy - h * 0.08)
      ..lineTo(cx - w * 0.16, cy - h * 0.02);
    canvas.drawPath(leftArmPath, runnerPaint);

    final rightArmPath = Path()
      ..moveTo(cx + w * 0.05, cy - h * 0.08)
      ..lineTo(cx + w * 0.16, cy - h * 0.03)
      ..lineTo(cx + w * 0.25, cy + h * 0.04);
    canvas.drawPath(rightArmPath, runnerPaint);

    final leftLegPath = Path()
      ..moveTo(cx - w * 0.05, cy + h * 0.07)
      ..lineTo(cx - w * 0.18, cy + h * 0.08)
      ..lineTo(cx - w * 0.25, cy + h * 0.18);
    canvas.drawPath(leftLegPath, runnerPaint);

    final rightLegPath = Path()
      ..moveTo(cx - w * 0.05, cy + h * 0.07)
      ..lineTo(cx + w * 0.06, cy + h * 0.12)
      ..lineTo(cx + w * 0.02, cy + h * 0.28);
    canvas.drawPath(rightLegPath, runnerPaint);

    final headPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx + w * 0.14, cy - h * 0.15), w * 0.065, headPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
