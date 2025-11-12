import 'dart:async';

import 'geo_integrity_score_platform_interface.dart';
import 'src/models.dart';
export 'src/models.dart'
    show DetectionResult, DetectionLocation, MonitoringMode, MonitoringPolicy;

/// Provides access to fraud detection utilities exposed by the native layers.
///
/// This class provides a unified interface to the Geo Integrity Score plugin
/// features, allowing you to start and stop monitoring, perform single detection
/// passes, and access the stream of detection results.
class GeoIntegrityScore {
  /// Private constructor to prevent instantiation.
  GeoIntegrityScore._();

  /// Lazily resolves the active platform implementation.
  ///
  /// This getter returns the singleton instance of the platform implementation,
  /// which provides access to the native layers.
  static GeoIntegrityScorePlatform get _platform =>
      GeoIntegrityScorePlatform.instance;

  /// Stream of detection results emitted by the native layers.
  ///
  /// This stream provides a continuous flow of detection results, allowing you
  /// to react to changes in the device's location and integrity status.
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
