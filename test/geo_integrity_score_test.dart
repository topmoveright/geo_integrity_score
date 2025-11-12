import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geo_integrity_score/geo_integrity_score.dart';
import 'package:geo_integrity_score/geo_integrity_score_method_channel.dart';
import 'package:geo_integrity_score/geo_integrity_score_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeGeoIntegrityScorePlatform
    with MockPlatformInterfaceMixin
    implements GeoIntegrityScorePlatform {
  MonitoringPolicy? lastStartPolicy;
  bool stopCalled = false;
  MonitoringPolicy? lastDetectPolicy;

  final StreamController<DetectionResult> _controller =
      StreamController<DetectionResult>.broadcast();

  @override
  Stream<DetectionResult> get detectionStream => _controller.stream;

  void emit(DetectionResult result) {
    _controller.add(result);
  }

  void dispose() {
    _controller.close();
  }

  @override
  Future<DetectionResult> detectOnce({MonitoringPolicy? policy}) async {
    lastDetectPolicy = policy;
    return DetectionResult(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        1700000000000,
        isUtc: true,
      ),
      fraudScore: 10,
      details: const {'MOCK_PROVIDER': 10},
      platform: 'android',
      location: const DetectionLocation(
        latitude: 37.422,
        longitude: -122.084,
        accuracyMeters: 6.5,
        altitudeMeters: 15.2,
        speedMetersPerSecond: 0.0,
      ),
    );
  }

  @override
  Future<void> startMonitoring(MonitoringPolicy policy) async {
    lastStartPolicy = policy;
  }

  @override
  Future<void> stopMonitoring() async {
    stopCalled = true;
  }
}

void main() {
  final GeoIntegrityScorePlatform initialPlatform =
      GeoIntegrityScorePlatform.instance;

  test('$MethodChannelGeoIntegrityScore is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGeoIntegrityScore>());
  });

  test('startMonitoring delegates to platform', () async {
    final fakePlatform = FakeGeoIntegrityScorePlatform();
    GeoIntegrityScorePlatform.instance = fakePlatform;
    addTearDown(() {
      fakePlatform.dispose();
      GeoIntegrityScorePlatform.instance = initialPlatform;
    });

    const policy = MonitoringPolicy.balanced();
    await GeoIntegrityScore.startMonitoring(policy: policy);

    expect(fakePlatform.lastStartPolicy?.mode, MonitoringMode.balanced);
    expect(
      fakePlatform.lastStartPolicy?.evaluationInterval,
      const Duration(seconds: 3),
    );
  });

  test('stopMonitoring delegates to platform', () async {
    final fakePlatform = FakeGeoIntegrityScorePlatform();
    GeoIntegrityScorePlatform.instance = fakePlatform;
    addTearDown(() {
      fakePlatform.dispose();
      GeoIntegrityScorePlatform.instance = initialPlatform;
    });

    await GeoIntegrityScore.stopMonitoring();

    expect(fakePlatform.stopCalled, isTrue);
  });

  test('detectOnce delegates to platform', () async {
    final fakePlatform = FakeGeoIntegrityScorePlatform();
    GeoIntegrityScorePlatform.instance = fakePlatform;
    addTearDown(() {
      fakePlatform.dispose();
      GeoIntegrityScorePlatform.instance = initialPlatform;
    });

    final result = await GeoIntegrityScore.detectOnce();

    expect(fakePlatform.lastDetectPolicy, isNull);
    expect(result.fraudScore, 10);
    expect(result.details['MOCK_PROVIDER'], 10);
  });

  test('detectionStream proxies platform stream', () async {
    final fakePlatform = FakeGeoIntegrityScorePlatform();
    GeoIntegrityScorePlatform.instance = fakePlatform;
    addTearDown(() {
      fakePlatform.dispose();
      GeoIntegrityScorePlatform.instance = initialPlatform;
    });

    final result = DetectionResult(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        1700000005000,
        isUtc: true,
      ),
      fraudScore: 75,
      details: const {'GEO_IMPOSSIBILITY': 35, 'ROOT_JAILBREAK': 40},
      platform: 'ios',
      location: const DetectionLocation(
        latitude: 35.0,
        longitude: 139.0,
        accuracyMeters: 4.2,
      ),
    );

    final expectation = expectLater(
      GeoIntegrityScore.detectionStream,
      emits(
        predicate<DetectionResult>(
          (event) =>
              event.fraudScore == 75 &&
              event.platform == 'ios' &&
              event.details['ROOT_JAILBREAK'] == 40 &&
              event.location?.latitude == 35.0 &&
              event.location?.longitude == 139.0,
        ),
      ),
    );

    fakePlatform.emit(result);

    await expectation;
  });
}
