import 'package:meta/meta.dart';

/// Identifies the monitoring mode presets used by the plugin.
enum MonitoringMode { aggressive, balanced, lowPower, onDemand }

/// Configuration that instructs the native layer how aggressively it should
/// sample sensors and evaluate location data.
@immutable
class MonitoringPolicy {
  const MonitoringPolicy._({
    required this.mode,
    required this.evaluationInterval,
    required this.sensorWarmup,
    required this.autoStopOnIdle,
    required this.speedThreshold,
  });

  const MonitoringPolicy.custom({
    required Duration evaluationInterval,
    required Duration sensorWarmup,
    required bool autoStopOnIdle,
    required double speedThreshold,
  }) : this._(
         mode: MonitoringMode.onDemand,
         evaluationInterval: evaluationInterval,
         sensorWarmup: sensorWarmup,
         autoStopOnIdle: autoStopOnIdle,
         speedThreshold: speedThreshold,
       );

  const MonitoringPolicy.aggressive()
    : this._(
        mode: MonitoringMode.aggressive,
        evaluationInterval: const Duration(seconds: 1),
        sensorWarmup: const Duration(milliseconds: 300),
        autoStopOnIdle: false,
        speedThreshold: 120,
      );

  const MonitoringPolicy.balanced()
    : this._(
        mode: MonitoringMode.balanced,
        evaluationInterval: const Duration(seconds: 3),
        sensorWarmup: const Duration(milliseconds: 500),
        autoStopOnIdle: true,
        speedThreshold: 100,
      );

  const MonitoringPolicy.lowPower()
    : this._(
        mode: MonitoringMode.lowPower,
        evaluationInterval: const Duration(seconds: 8),
        sensorWarmup: const Duration(milliseconds: 800),
        autoStopOnIdle: true,
        speedThreshold: 90,
      );

  const MonitoringPolicy.onDemand()
    : this._(
        mode: MonitoringMode.onDemand,
        evaluationInterval: const Duration(seconds: 2),
        sensorWarmup: const Duration(milliseconds: 400),
        autoStopOnIdle: true,
        speedThreshold: 100,
      );

  final MonitoringMode mode;
  final Duration evaluationInterval;
  final Duration sensorWarmup;
  final bool autoStopOnIdle;
  final double speedThreshold;

  Map<String, Object> toMap() {
    return <String, Object>{
      'mode': mode.name,
      'evaluationIntervalMillis': evaluationInterval.inMilliseconds,
      'sensorWarmupMillis': sensorWarmup.inMilliseconds,
      'autoStopOnIdle': autoStopOnIdle,
      'speedThreshold': speedThreshold,
    };
  }

  MonitoringPolicy copyWith({
    MonitoringMode? mode,
    Duration? evaluationInterval,
    Duration? sensorWarmup,
    bool? autoStopOnIdle,
    double? speedThreshold,
  }) {
    return MonitoringPolicy._(
      mode: mode ?? this.mode,
      evaluationInterval: evaluationInterval ?? this.evaluationInterval,
      sensorWarmup: sensorWarmup ?? this.sensorWarmup,
      autoStopOnIdle: autoStopOnIdle ?? this.autoStopOnIdle,
      speedThreshold: speedThreshold ?? this.speedThreshold,
    );
  }
}

/// Standardized container for geographic coordinates emitted by native layers.
@immutable
class DetectionLocation {
  const DetectionLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMetersPerSecond,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMetersPerSecond;

  factory DetectionLocation.fromMap(Map<dynamic, dynamic> raw) {
    double? parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
      return null;
    }

    final latitude = parseDouble(raw['latitude']);
    final longitude = parseDouble(raw['longitude']);
    if (latitude == null || longitude == null) {
      throw ArgumentError(
        'latitude and longitude are required in location payload.',
      );
    }

    return DetectionLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters:
          parseDouble(raw['accuracyMeters']) ?? parseDouble(raw['accuracy']),
      altitudeMeters:
          parseDouble(raw['altitudeMeters']) ?? parseDouble(raw['altitude']),
      speedMetersPerSecond:
          parseDouble(raw['speedMetersPerSecond']) ?? parseDouble(raw['speed']),
    );
  }

  Map<String, Object> toJson() {
    final Map<String, Object> json = <String, Object>{
      'latitude': latitude,
      'longitude': longitude,
    };
    if (accuracyMeters != null) {
      json['accuracyMeters'] = accuracyMeters!;
    }
    if (altitudeMeters != null) {
      json['altitudeMeters'] = altitudeMeters!;
    }
    if (speedMetersPerSecond != null) {
      json['speedMetersPerSecond'] = speedMetersPerSecond!;
    }
    return json;
  }
}

/// Encapsulates the result of a detection cycle produced by the native layers.
@immutable
class DetectionResult {
  const DetectionResult({
    required this.timestamp,
    required this.fraudScore,
    required this.details,
    required this.platform,
    this.location,
  });

  final DateTime timestamp;
  final int fraudScore;
  final Map<String, int> details;
  final String platform;
  final DetectionLocation? location;

  factory DetectionResult.fromMap(Map<dynamic, dynamic> raw) {
    final timestampValue = raw['timestamp'];
    final locationPayload = raw['location'];
    return DetectionResult(
      timestamp: timestampValue is int
          ? DateTime.fromMillisecondsSinceEpoch(timestampValue, isUtc: true)
          : DateTime.now().toUtc(),
      fraudScore: (raw['fraudScore'] as num?)?.toInt() ?? 0,
      details: Map<String, int>.fromEntries(
        (raw['details'] as Map? ?? const <dynamic, dynamic>{}).entries.map(
          (entry) => MapEntry(
            entry.key.toString(),
            (entry.value as num?)?.toInt() ?? 0,
          ),
        ),
      ),
      platform: raw['platform']?.toString() ?? 'unknown',
      location: locationPayload is Map
          ? DetectionLocation.fromMap(locationPayload)
          : null,
    );
  }

  Map<String, Object> toJson() {
    final Map<String, Object> json = <String, Object>{
      'timestamp': timestamp.millisecondsSinceEpoch,
      'fraudScore': fraudScore,
      'details': details,
      'platform': platform,
    };
    if (location != null) {
      json['location'] = location!.toJson();
    }
    return json;
  }
}
