import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_integrity_score/geo_integrity_score_method_channel.dart';
import 'package:geo_integrity_score/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelGeoIntegrityScore', () {
    late MethodChannelGeoIntegrityScore platform;
    late MethodChannel channel;
    final MethodCodec codec = const StandardMethodCodec();
    MethodCall? lastMethodCall;
    late TestDefaultBinaryMessenger tester;
    late void Function(dynamic event) emitEvent;

    setUp(() {
      tester =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      channel = const MethodChannel('geo_integrity_score');
      emitEvent = (_) {};
      lastMethodCall = null;

      tester.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        lastMethodCall = methodCall;
        switch (methodCall.method) {
          case 'startMonitoring':
            return null;
          case 'stopMonitoring':
            return null;
          case 'detectOnce':
            return <String, dynamic>{
              'timestamp': 1700000000000,
              'fraudScore': 5,
              'details': <String, int>{'MOCK_PROVIDER': 5},
              'platform': 'android',
              'location': <String, Object>{
                'latitude': 37.422,
                'longitude': -122.084,
                'accuracyMeters': 6.5,
                'altitudeMeters': 15.2,
                'speedMetersPerSecond': 0.0,
              },
            };
          default:
            throw PlatformException(code: 'UNKNOWN_METHOD');
        }
      });

      tester.setMockMessageHandler('geo_integrity_score/events', (
        ByteData? message,
      ) async {
        final MethodCall call = codec.decodeMethodCall(message);
        switch (call.method) {
          case 'listen':
            emitEvent = (dynamic event) {
              tester.handlePlatformMessage(
                'geo_integrity_score/events',
                codec.encodeSuccessEnvelope(event),
                (_) {},
              );
            };
            return codec.encodeSuccessEnvelope(null);
          case 'cancel':
            emitEvent = (_) {};
            return codec.encodeSuccessEnvelope(null);
          default:
            throw PlatformException(code: 'UNKNOWN_STREAM_METHOD');
        }
      });

      platform = MethodChannelGeoIntegrityScore(
        methodChannel: channel,
        eventChannel: const EventChannel('geo_integrity_score/events'),
      );
    });

    tearDown(() {
      tester.setMockMethodCallHandler(channel, null);
      tester.setMockMessageHandler('geo_integrity_score/events', null);
    });

    test('startMonitoring sends policy payload', () async {
      await platform.startMonitoring(const MonitoringPolicy.aggressive());

      expect(lastMethodCall?.method, 'startMonitoring');
      expect(lastMethodCall?.arguments, containsPair('mode', 'aggressive'));
    });

    test('stopMonitoring delegates to native layer', () async {
      await platform.stopMonitoring();

      expect(lastMethodCall?.method, 'stopMonitoring');
    });

    test('detectOnce parses result map', () async {
      final result = await platform.detectOnce();

      expect(lastMethodCall?.method, 'detectOnce');
      expect(result.fraudScore, 5);
      expect(result.details['MOCK_PROVIDER'], 5);
      expect(result.location, isNotNull);
      expect(result.location?.latitude, closeTo(37.422, 0.0001));
      expect(result.location?.longitude, closeTo(-122.084, 0.0001));
    });

    test('detectionStream emits parsed events', () async {
      final expectation = expectLater(
        platform.detectionStream,
        emits(
          isA<DetectionResult>()
              .having((r) => r.platform, 'platform', 'ios')
              .having(
                (r) => r.location?.latitude,
                'latitude',
                closeTo(35.0, 0.001),
              )
              .having(
                (r) => r.location?.longitude,
                'longitude',
                closeTo(139.0, 0.001),
              ),
        ),
      );

      emitEvent(<String, dynamic>{
        'timestamp': 1700000005000,
        'fraudScore': 45,
        'details': <String, int>{'GEO_IMPOSSIBILITY': 35, 'ROOT_JAILBREAK': 10},
        'platform': 'ios',
        'location': <String, Object>{
          'latitude': 35.0,
          'longitude': 139.0,
          'accuracyMeters': 4.2,
        },
      });

      await expectation;
    });
  });
}
