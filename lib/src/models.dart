import 'package:meta/meta.dart';

/// Identifies the monitoring mode presets used by the plugin.
enum MonitoringMode {
  /// Highest sampling frequency for rapid spoofing detection.
  aggressive,

  /// Balanced sampling cadence for everyday usage.
  balanced,

  /// Reduced sampling frequency to preserve battery life.
  lowPower,

  /// Lightweight mode intended for on-demand evaluations.
  onDemand,
}

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

  /// Builds a [MonitoringPolicy] with arbitrary timing parameters.
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

  /// Preset optimized for rapid spoofing detection with higher power usage.
  const MonitoringPolicy.aggressive()
    : this._(
        mode: MonitoringMode.aggressive,
        evaluationInterval: const Duration(seconds: 1),
        sensorWarmup: const Duration(milliseconds: 300),
        autoStopOnIdle: false,
        speedThreshold: 120,
      );

  /// Default preset balancing responsiveness and energy consumption.
  const MonitoringPolicy.balanced()
    : this._(
        mode: MonitoringMode.balanced,
        evaluationInterval: const Duration(seconds: 3),
        sensorWarmup: const Duration(milliseconds: 500),
        autoStopOnIdle: true,
        speedThreshold: 100,
      );

  /// Lower frequency preset that prioritizes battery savings.
  const MonitoringPolicy.lowPower()
    : this._(
        mode: MonitoringMode.lowPower,
        evaluationInterval: const Duration(seconds: 8),
        sensorWarmup: const Duration(milliseconds: 800),
        autoStopOnIdle: true,
        speedThreshold: 90,
      );

  /// Lightweight preset intended for burst evaluations.
  const MonitoringPolicy.onDemand()
    : this._(
        mode: MonitoringMode.onDemand,
        evaluationInterval: const Duration(seconds: 2),
        sensorWarmup: const Duration(milliseconds: 400),
        autoStopOnIdle: true,
        speedThreshold: 100,
      );

  /// Monitoring mode that determines native-side presets.
  final MonitoringMode mode;

  /// Interval between evaluation cycles.
  final Duration evaluationInterval;

  /// Warm-up duration before sampling motion sensors.
  final Duration sensorWarmup;

  /// Whether monitoring should halt automatically when idle.
  final bool autoStopOnIdle;

  /// Speed threshold in meters per second considered suspicious.
  final double speedThreshold;

  /// Serializes this policy into a plain map sent to the platform layer.
  Map<String, Object> toMap() {
    return <String, Object>{
      'mode': mode.name,
      'evaluationIntervalMillis': evaluationInterval.inMilliseconds,
      'sensorWarmupMillis': sensorWarmup.inMilliseconds,
      'autoStopOnIdle': autoStopOnIdle,
      'speedThreshold': speedThreshold,
    };
  }

  /// Returns a copy of this policy with selectively replaced fields.
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
  /// Creates a new [DetectionLocation] with optional accuracy metadata.
  const DetectionLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMetersPerSecond,
  });

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Optional horizontal accuracy in meters.
  final double? accuracyMeters;

  /// Optional altitude in meters above sea level.
  final double? altitudeMeters;

  /// Optional instantaneous speed in meters per second.
  final double? speedMetersPerSecond;

  /// Parses a [DetectionLocation] from a map received from the platform side.
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

  /// Converts this location to a JSON-safe representation.
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
  /// Constructs a [DetectionResult] produced by a native detector.
  const DetectionResult({
    required this.timestamp,
    required this.fraudScore,
    required this.details,
    required this.platform,
    this.location,
  });

  /// UTC timestamp representing when the detection was produced.
  final DateTime timestamp;

  /// Aggregated spoofing score assigned by the native layer.
  final int fraudScore;

  /// Individual check scores indexed by detail keys.
  final Map<String, int> details;

  /// Origin platform for the detection (for example "android" or "ios").
  final String platform;

  /// Optional geographic metadata accompanying the detection.
  final DetectionLocation? location;

  /// Parses a [DetectionResult] from a platform channel payload.
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

  /// Converts this result into a JSON-safe structure for persistence or tests.
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
