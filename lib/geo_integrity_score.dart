import 'dart:async';

import 'geo_integrity_score_platform_interface.dart';
import 'src/models.dart';
export 'src/models.dart'
    show DetectionResult, DetectionLocation, MonitoringMode, MonitoringPolicy;

/// Provides access to the Geo Integrity Score plugin features from Dart.
class GeoIntegrityScore {
  GeoIntegrityScore._();

  static GeoIntegrityScorePlatform get _platform =>
      GeoIntegrityScorePlatform.instance;

  /// Stream of detection results emitted by the native layers.
  static Stream<DetectionResult> get detectionStream =>
      _platform.detectionStream;

  /// Starts monitoring with the provided [MonitoringPolicy].
  static Future<void> startMonitoring({
    MonitoringPolicy policy = const MonitoringPolicy.balanced(),
  }) {
    return _platform.startMonitoring(policy);
  }

  /// Stops any ongoing monitoring session.
  static Future<void> stopMonitoring() {
    return _platform.stopMonitoring();
  }

  /// Performs a single detection pass using an optional [policyOverride].
  static Future<DetectionResult> detectOnce({
    MonitoringPolicy? policyOverride,
  }) {
    return _platform.detectOnce(policy: policyOverride);
  }
}
