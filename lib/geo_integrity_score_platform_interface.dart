import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'geo_integrity_score_method_channel.dart';
import 'src/models.dart';

/// Defines the platform interface that native implementations must extend.
abstract class GeoIntegrityScorePlatform extends PlatformInterface {
  /// Creates an instance locked to the default platform interface token.
  GeoIntegrityScorePlatform() : super(token: _token);

  static final Object _token = Object();

  static GeoIntegrityScorePlatform _instance = MethodChannelGeoIntegrityScore();

  /// Active platform implementation used by the Dart-facing API.
  static GeoIntegrityScorePlatform get instance => _instance;

  /// Replaces the active platform implementation after token verification.
  static set instance(GeoIntegrityScorePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream emitting detection results from the native layers.
  Stream<DetectionResult> get detectionStream;

  /// Starts monitoring using the provided [MonitoringPolicy].
  Future<void> startMonitoring(MonitoringPolicy policy);

  /// Stops the monitoring pipeline and releases native resources.
  Future<void> stopMonitoring();

  /// Performs a one-off detection cycle using an optional [policy].
  Future<DetectionResult> detectOnce({MonitoringPolicy? policy});
}
