import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geo_integrity_score/geo_integrity_score.dart';
import 'package:permission_handler/permission_handler.dart';

import 'example_data.dart';
import 'ui/log_section.dart';
import 'ui/scenario_section.dart';
import 'ui/status_section.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<DetectionResult>? _subscription;
  DetectionResult? _latestDetection;
  bool _monitoring = false;
  String? _error;
  final List<ScenarioLogEntry> _logs = <ScenarioLogEntry>[];
  bool _scenarioInProgress = false;
  TestEnvironment _selectedEnvironment = TestEnvironment.emulator;
  ExampleScenario? _activeMonitoringScenario;
  TestEnvironment? _activeMonitoringEnvironment;
  bool _permissionGranted = false;
  bool _permissionDeniedForever = false;
  bool _checkingPermissions = false;

  static const String _manualMonitoringLabel = 'Manual Monitoring';
  static const String _manualDetectLabel = 'Manual Detect Once';

  @override
  void initState() {
    super.initState();
    unawaited(_ensurePermissions());
  }

  Future<void> _toggleMonitoring() async {
    if (!await _ensurePermissionsBeforeAction()) {
      return;
    }
    if (_monitoring) {
      await _stopMonitoring();
      return;
    }

    await _startMonitoringWithPolicy(
      const MonitoringPolicy.balanced(),
      label: _manualMonitoringLabel,
      scenario: null,
      environment: _selectedEnvironment,
    );
  }

  Future<void> _stopMonitoring() async {
    final TestEnvironment environment =
        _activeMonitoringEnvironment ?? _selectedEnvironment;
    final String label =
        _activeMonitoringScenario?.name ?? _manualMonitoringLabel;

    try {
      await GeoIntegrityScore.stopMonitoring();
    } catch (error) {
      final String message = error.toString();
      setState(() {
        _error = message;
      });
      _addLogEntry(label: label, environment: environment, error: message);
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      setState(() {
        _monitoring = false;
        _activeMonitoringScenario = null;
        _activeMonitoringEnvironment = null;
      });
    }
  }

  Future<void> _startMonitoringWithPolicy(
    MonitoringPolicy policy, {
    required String label,
    required ExampleScenario? scenario,
    required TestEnvironment environment,
  }) async {
    final MonitoringPolicy effectivePolicy = policy.copyWith(
      autoStopOnIdle: false,
    );
    try {
      await GeoIntegrityScore.startMonitoring(policy: effectivePolicy);
      await _subscription?.cancel();
      _subscription = GeoIntegrityScore.detectionStream.listen(
        _handleDetectionEvent,
        onError: _handleDetectionError,
      );

      setState(() {
        _monitoring = true;
        _error = null;
        _activeMonitoringScenario = scenario;
        _activeMonitoringEnvironment = environment;
      });

      _addLogEntry(
        label: label,
        environment: environment,
        monitoringStarted: true,
      );
    } catch (error) {
      final String message = error.toString();
      setState(() {
        _error = message;
      });
      _addLogEntry(label: label, environment: environment, error: message);
    }
  }

  Future<void> _runDetectOnce({ExampleScenario? scenario}) async {
    if (!await _ensurePermissionsBeforeAction()) {
      return;
    }
    final TestEnvironment environment = _selectedEnvironment;
    final MonitoringPolicy? policyOverride = scenario?.detectPolicy;
    final String label = scenario?.name ?? _manualDetectLabel;

    try {
      final result = await GeoIntegrityScore.detectOnce(
        policyOverride: policyOverride,
      );
      setState(() {
        _latestDetection = result;
        _error = null;
      });
      _addLogEntry(label: label, environment: environment, detection: result);
    } catch (error) {
      final String message = error.toString();
      setState(() {
        _error = message;
      });
      _addLogEntry(label: label, environment: environment, error: message);
    }
  }

  void _handleDetectionEvent(DetectionResult event) {
    setState(() {
      _latestDetection = event;
      _error = null;
    });

    final String label =
        _activeMonitoringScenario?.name ?? _manualMonitoringLabel;
    final TestEnvironment environment =
        _activeMonitoringEnvironment ?? _selectedEnvironment;

    _addLogEntry(label: label, environment: environment, detection: event);
  }

  void _handleDetectionError(Object error, StackTrace stackTrace) {
    final String message = error.toString();
    setState(() {
      _error = message;
    });

    final String label =
        _activeMonitoringScenario?.name ?? _manualMonitoringLabel;
    final TestEnvironment environment =
        _activeMonitoringEnvironment ?? _selectedEnvironment;

    _addLogEntry(label: label, environment: environment, error: message);
  }

  void _addLogEntry({
    required String label,
    required TestEnvironment environment,
    DetectionResult? detection,
    String? error,
    bool monitoringStarted = false,
  }) {
    setState(() {
      _logs.add(
        ScenarioLogEntry(
          timestamp: DateTime.now().toUtc(),
          label: label,
          environment: environment,
          detection: detection,
          error: error,
          monitoringStarted: monitoringStarted,
        ),
      );
      if (_logs.length > 50) {
        _logs.removeRange(0, _logs.length - 50);
      }
    });
  }

  Future<void> _runScenario(ExampleScenario scenario) async {
    if (_scenarioInProgress) {
      return;
    }

    if (!await _ensurePermissionsBeforeAction()) {
      return;
    }

    setState(() {
      _scenarioInProgress = true;
    });

    try {
      if (scenario.usesMonitoring) {
        if (_monitoring) {
          await _stopMonitoring();
        }
        await _startMonitoringWithPolicy(
          scenario.monitoringPolicy ?? const MonitoringPolicy.balanced(),
          label: scenario.name,
          scenario: scenario,
          environment: _selectedEnvironment,
        );
      } else {
        await _runDetectOnce(scenario: scenario);
      }
    } finally {
      setState(() {
        _scenarioInProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wideLayout = constraints.maxWidth >= 900;
              final List<ScenarioLogEntry> recentLogs = _logs.reversed
                  .take(15)
                  .toList(growable: false);

              final StatusSectionData statusData = StatusSectionData(
                permissionGranted: _permissionGranted,
                permissionDeniedForever: _permissionDeniedForever,
                checkingPermissions: _checkingPermissions,
                monitoring: _monitoring,
                scenarioInProgress: _scenarioInProgress,
                scenarioName:
                    _activeMonitoringScenario?.name ?? _manualMonitoringLabel,
                selectedEnvironment: _selectedEnvironment,
                currentEnvironment:
                    _activeMonitoringEnvironment ?? _selectedEnvironment,
                detection: _latestDetection,
                error: _error,
              );

              final Widget statusSection = StatusSection(
                data: statusData,
                onToggleMonitoring: _toggleMonitoring,
                onDetectOnce: () => _runDetectOnce(),
                onRequestPermission: _ensurePermissions,
                onOpenSettings: openAppSettings,
                onEnvironmentChanged: (TestEnvironment value) {
                  setState(() {
                    _selectedEnvironment = value;
                  });
                },
              );

              final Widget scenarioSection = ScenarioSection(
                scenarios: kExampleScenarios,
                selectedEnvironment: _selectedEnvironment,
                permissionGranted: _permissionGranted,
                scenarioInProgress: _scenarioInProgress,
                onRunScenario: _runScenario,
              );

              final Widget logSection = LogSection(logs: recentLogs);

              final Widget content = wideLayout
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              statusSection,
                              const SizedBox(height: 12),
                              Expanded(child: logSection),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: scenarioSection),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        statusSection,
                        const SizedBox(height: 12),
                        Flexible(child: scenarioSection),
                        const SizedBox(height: 12),
                        Flexible(child: logSection),
                      ],
                    );

              return DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _ensurePermissions() async {
    setState(() {
      _checkingPermissions = true;
    });

    Future<bool> checkGranted() async {
      final List<PermissionStatus> statuses = await Future.wait(
        <Future<PermissionStatus>>[
          Permission.location.status,
          Permission.locationWhenInUse.status,
        ],
      );
      return statuses.any((PermissionStatus status) => status.isGranted);
    }

    Future<bool> checkPermanentlyDenied() async {
      final List<PermissionStatus> statuses = await Future.wait(
        <Future<PermissionStatus>>[
          Permission.location.status,
          Permission.locationWhenInUse.status,
        ],
      );
      return statuses.any(
        (PermissionStatus status) => status.isPermanentlyDenied,
      );
    }

    var granted = await checkGranted();
    if (!granted) {
      await <Permission>[
        Permission.location,
        Permission.locationWhenInUse,
      ].request();
      granted = await checkGranted();
    }
    final bool permanentlyDenied = await checkPermanentlyDenied();

    if (!mounted) {
      return;
    }

    setState(() {
      _permissionGranted = granted;
      _permissionDeniedForever = permanentlyDenied;
      _checkingPermissions = false;
    });
  }

  Future<bool> _ensurePermissionsBeforeAction() async {
    if (_permissionGranted) {
      return true;
    }
    await _ensurePermissions();
    if (_permissionGranted) {
      return true;
    }
    setState(() {
      _error =
          'Location permission is required to run monitoring or detection scenarios.';
    });
    return false;
  }
}
