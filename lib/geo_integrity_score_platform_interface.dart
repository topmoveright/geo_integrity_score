import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'geo_integrity_score_method_channel.dart';
import 'src/models.dart';

abstract class GeoIntegrityScorePlatform extends PlatformInterface {
  GeoIntegrityScorePlatform() : super(token: _token);

  static final Object _token = Object();

  static GeoIntegrityScorePlatform _instance = MethodChannelGeoIntegrityScore();

  static GeoIntegrityScorePlatform get instance => _instance;

  static set instance(GeoIntegrityScorePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<DetectionResult> get detectionStream;

  Future<void> startMonitoring(MonitoringPolicy policy);

  Future<void> stopMonitoring();

  Future<DetectionResult> detectOnce({MonitoringPolicy? policy});
}
