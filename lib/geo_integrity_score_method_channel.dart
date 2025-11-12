import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'geo_integrity_score_platform_interface.dart';
import 'src/models.dart';

/// Method channel implementation for [GeoIntegrityScorePlatform].
class MethodChannelGeoIntegrityScore extends GeoIntegrityScorePlatform {
  /// Creates an instance that communicates with the default method channels.
  MethodChannelGeoIntegrityScore({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'geo_integrity_score';
  static const String _eventChannelName = 'geo_integrity_score/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<DetectionResult>? _cachedDetectionStream;

  /// Exposes the underlying [MethodChannel] for verification in tests.
  @visibleForTesting
  MethodChannel get methodChannel => _methodChannel;

  /// Exposes the underlying [EventChannel] for verification in tests.
  @visibleForTesting
  EventChannel get eventChannel => _eventChannel;

  DetectionResult _parseDetectionEvent(dynamic event) {
    if (event is Map) {
      return DetectionResult.fromMap(Map<dynamic, dynamic>.from(event));
    }
    throw PlatformException(
      code: 'INVALID_EVENT',
      message: 'Unsupported detection event payload: ${event.runtimeType}',
    );
  }

  @override
  Stream<DetectionResult> get detectionStream {
    _cachedDetectionStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<DetectionResult>(_parseDetectionEvent)
        .asBroadcastStream();
    return _cachedDetectionStream!;
  }

  @override
  Future<void> startMonitoring(MonitoringPolicy policy) {
    return _methodChannel.invokeMethod<void>('startMonitoring', policy.toMap());
  }

  @override
  Future<void> stopMonitoring() {
    return _methodChannel.invokeMethod<void>('stopMonitoring');
  }

  @override
  Future<DetectionResult> detectOnce({MonitoringPolicy? policy}) async {
    final dynamic raw = await _methodChannel.invokeMethod<dynamic>(
      'detectOnce',
      policy?.toMap(),
    );

    if (raw is Map) {
      return DetectionResult.fromMap(Map<dynamic, dynamic>.from(raw));
    }

    if (raw == null) {
      throw PlatformException(
        code: 'NO_RESULT',
        message: 'Native layer returned null for detectOnce',
      );
    }

    throw PlatformException(
      code: 'INVALID_RESULT',
      message:
          'Native layer returned unsupported detectOnce payload: ${raw.runtimeType}',
    );
  }
}
