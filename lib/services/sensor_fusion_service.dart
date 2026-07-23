import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorFusionService {
  static final SensorFusionService _instance = SensorFusionService._internal();
  factory SensorFusionService() => _instance;
  SensorFusionService._internal();

  StreamSubscription? _sensorSub;
  final List<double> _magnitudes = [];
  double _currentSpeedKmh = 0.0;
  String _currentActivity = 'stationary';

  // Simulation override controls (ideal for emulators / testing)
  bool _isSimulationMode = false;
  String _simulatedActivity = 'stationary';

  final _activityController = StreamController<String>.broadcast();
  Stream<String> get activityStream => _activityController.stream;
  String get currentActivity => _currentActivity;

  bool get isSimulationMode => _isSimulationMode;
  String get simulatedActivity => _simulatedActivity;

  void start() {
    _sensorSub?.cancel();
    _sensorSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (_isSimulationMode) return;

      final double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _magnitudes.add(magnitude);
      if (_magnitudes.length > 15) {
        _magnitudes.removeAt(0);
      }

      _classifyActivity();
    });
  }

  void stop() {
    _sensorSub?.cancel();
    _sensorSub = null;
  }

  void updateSpeed(double speedKmh) {
    _currentSpeedKmh = speedKmh;
    if (!_isSimulationMode) {
      _classifyActivity();
    }
  }

  void enableSimulation(bool enabled, String activity) {
    _isSimulationMode = enabled;
    _simulatedActivity = activity;
    if (_isSimulationMode) {
      _setActivity(_simulatedActivity);
    } else {
      _classifyActivity();
    }
  }

  void _classifyActivity() {
    if (_isSimulationMode) {
      _setActivity(_simulatedActivity);
      return;
    }

    if (_magnitudes.isEmpty) {
      _setActivity('stationary');
      return;
    }

    // Calculate rolling magnitude variance (high-frequency motion index)
    final double mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final double sumOfSquares = _magnitudes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b);
    final double variance = sumOfSquares / _magnitudes.length;

    String activity = 'stationary';
    final double speed = _currentSpeedKmh;

    // SENSOR FUSION RULES:
    if (speed >= 15.0) {
      // Significant overall translation speed -> In a vehicle
      activity = 'in_vehicle';
    } else if (variance >= 1.5 && speed >= 5.0) {
      // High frequency vibration + running speed -> Running
      activity = 'running';
    } else if (variance >= 0.2) {
      // Moderate frequency vibration -> Walking
      activity = 'walking';
    } else {
      // Low vibration and slow speed -> Stationary
      activity = 'stationary';
    }

    _setActivity(activity);
  }

  void _setActivity(String newActivity) {
    if (_currentActivity != newActivity) {
      _currentActivity = newActivity;
      _activityController.add(_currentActivity);
    }
  }
}
