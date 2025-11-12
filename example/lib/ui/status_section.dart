import 'package:flutter/material.dart';
import 'package:geo_integrity_score/geo_integrity_score.dart';

import '../example_data.dart';
import '../formatters.dart';
import 'compact_button_style.dart';

class StatusSectionData {
  const StatusSectionData({
    required this.permissionGranted,
    required this.permissionDeniedForever,
    required this.checkingPermissions,
    required this.monitoring,
    required this.scenarioInProgress,
    required this.scenarioName,
    required this.selectedEnvironment,
    required this.currentEnvironment,
    required this.detection,
    required this.error,
  });

  final bool permissionGranted;
  final bool permissionDeniedForever;
  final bool checkingPermissions;
  final bool monitoring;
  final bool scenarioInProgress;
  final String scenarioName;
  final TestEnvironment selectedEnvironment;
  final TestEnvironment currentEnvironment;
  final DetectionResult? detection;
  final String? error;
}

class StatusSection extends StatelessWidget {
  const StatusSection({
    required this.data,
    required this.onToggleMonitoring,
    required this.onDetectOnce,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onEnvironmentChanged,
    super.key,
  });

  final StatusSectionData data;
  final VoidCallback onToggleMonitoring;
  final VoidCallback onDetectOnce;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final ValueChanged<TestEnvironment> onEnvironmentChanged;

  @override
  Widget build(BuildContext context) {
    final DetectionResult? detection = data.detection;
    final DetectionLocation? location = detection?.location;
    final ButtonStyle buttonStyle = compactButtonStyle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (!data.permissionGranted)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.checkingPermissions
                    ? 'Checking location permission...'
                    : 'Location permission is required.',
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  TextButton(
                    style: buttonStyle,
                    onPressed: data.checkingPermissions
                        ? null
                        : onRequestPermission,
                    child: Text(
                      data.checkingPermissions ? 'Checking...' : 'Request',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (data.permissionDeniedForever)
                    TextButton(
                      style: buttonStyle,
                      onPressed: onOpenSettings,
                      child: const Text('Open Settings'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        _EnvironmentSelector(
          selectedEnvironment: data.selectedEnvironment,
          onChanged: onEnvironmentChanged,
        ),
        const SizedBox(height: 6),
        _LabelValue(
          label: 'Monitoring',
          value: data.monitoring ? 'Active' : 'Idle',
        ),
        if (data.monitoring)
          _LabelValue(label: 'Scenario', value: data.scenarioName),
        _LabelValue(label: 'Environment', value: data.currentEnvironment.label),
        if (data.error != null)
          _LabelValue(label: 'Last Error', value: data.error!),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            TextButton(
              style: buttonStyle,
              onPressed: (!data.permissionGranted || data.scenarioInProgress)
                  ? null
                  : onToggleMonitoring,
              child: Text(
                data.monitoring ? 'Stop Monitoring' : 'Start Monitoring',
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: buttonStyle,
              onPressed: (!data.permissionGranted || data.scenarioInProgress)
                  ? null
                  : onDetectOnce,
              child: const Text('Detect Once'),
            ),
          ],
        ),
        if (detection != null) ...<Widget>[
          const SizedBox(height: 6),
          _LabelValue(label: 'Fraud Score', value: '${detection.fraudScore}'),
          _LabelValue(label: 'Platform', value: detection.platform),
          _LabelValue(
            label: 'Timestamp',
            value: formatLocalTimestamp(detection.timestamp),
          ),
          if (location != null)
            _LabelValue(
              label: 'Location',
              value:
                  '${formatCoordinate(location.latitude)}, '
                  '${formatCoordinate(location.longitude)}',
            ),
          if (location?.accuracyMeters != null)
            _LabelValue(
              label: 'Accuracy',
              value: formatDistance(location!.accuracyMeters!),
            ),
          if (location?.altitudeMeters != null)
            _LabelValue(
              label: 'Altitude',
              value: formatAltitude(location!.altitudeMeters!),
            ),
          if (location?.speedMetersPerSecond != null)
            _LabelValue(
              label: 'Speed',
              value: formatSpeed(location!.speedMetersPerSecond!),
            ),
          if (detection.details.isNotEmpty)
            _LabelValue(
              label: 'Signals',
              value: detection.details.entries
                  .map(
                    (MapEntry<String, int> entry) =>
                        '${entry.key}:${entry.value}',
                  )
                  .join(', '),
            ),
        ],
      ],
    );
  }
}

class _EnvironmentSelector extends StatelessWidget {
  const _EnvironmentSelector({
    required this.selectedEnvironment,
    required this.onChanged,
  });

  final TestEnvironment selectedEnvironment;
  final ValueChanged<TestEnvironment> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Test Environment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust scenarios for emulator or device runs.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DropdownButton<TestEnvironment>(
          value: selectedEnvironment,
          onChanged: (TestEnvironment? value) {
            if (value != null) {
              onChanged(value);
            }
          },
          items: TestEnvironment.values
              .map(
                (TestEnvironment environment) =>
                    DropdownMenuItem<TestEnvironment>(
                      value: environment,
                      child: Text(environment.label),
                    ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value');
  }
}
