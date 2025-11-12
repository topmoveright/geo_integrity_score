import 'package:geo_integrity_score/geo_integrity_score.dart';

enum TestEnvironment { emulator, physical }

extension TestEnvironmentLabel on TestEnvironment {
  String get label {
    switch (this) {
      case TestEnvironment.emulator:
        return 'Emulator';
      case TestEnvironment.physical:
        return 'Physical Device';
    }
  }
}

class ExampleScenario {
  const ExampleScenario.monitoring({
    required this.id,
    required this.name,
    required this.description,
    required this.monitoringPolicy,
    required this.recommendedEnvironments,
  }) : usesMonitoring = true,
       detectPolicy = null;

  const ExampleScenario.detectOnce({
    required this.id,
    required this.name,
    required this.description,
    required this.recommendedEnvironments,
    this.detectPolicy,
  }) : usesMonitoring = false,
       monitoringPolicy = null;

  final String id;
  final String name;
  final String description;
  final bool usesMonitoring;
  final MonitoringPolicy? monitoringPolicy;
  final MonitoringPolicy? detectPolicy;
  final List<TestEnvironment> recommendedEnvironments;
}

class ScenarioLogEntry {
  const ScenarioLogEntry({
    required this.timestamp,
    required this.label,
    required this.environment,
    this.detection,
    this.error,
    this.monitoringStarted = false,
  });

  final DateTime timestamp;
  final String label;
  final TestEnvironment environment;
  final DetectionResult? detection;
  final String? error;
  final bool monitoringStarted;
}

const List<ExampleScenario> kExampleScenarios = <ExampleScenario>[
  ExampleScenario.monitoring(
    id: 'monitor-balanced',
    name: 'Balanced Continuous Monitoring',
    description:
        'Starts a balanced monitoring session suited for emulators or low-risk validation.',
    monitoringPolicy: MonitoringPolicy.balanced(),
    recommendedEnvironments: <TestEnvironment>[
      TestEnvironment.emulator,
      TestEnvironment.physical,
    ],
  ),
  ExampleScenario.monitoring(
    id: 'monitor-aggressive',
    name: 'Aggressive Monitoring (Field)',
    description:
        'Enables aggressive monitoring to capture edge cases on real hardware.',
    monitoringPolicy: MonitoringPolicy.aggressive(),
    recommendedEnvironments: <TestEnvironment>[TestEnvironment.physical],
  ),
  ExampleScenario.detectOnce(
    id: 'detect-balanced',
    name: 'Single Detection (Balanced)',
    description:
        'Runs a single detection pass using the balanced defaults to validate the integration.',
    detectPolicy: MonitoringPolicy.balanced(),
    recommendedEnvironments: <TestEnvironment>[
      TestEnvironment.emulator,
      TestEnvironment.physical,
    ],
  ),
  ExampleScenario.detectOnce(
    id: 'detect-aggressive',
    name: 'Single Detection (Aggressive)',
    description:
        'Performs a single aggressive detection for high-sensitivity validation on devices.',
    detectPolicy: MonitoringPolicy.aggressive(),
    recommendedEnvironments: <TestEnvironment>[TestEnvironment.physical],
  ),
];
