// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter/services.dart';
import 'package:geo_integrity_score/geo_integrity_score.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startMonitoring forwards to native layer', (
    WidgetTester tester,
  ) async {
    expect(
      () => GeoIntegrityScore.startMonitoring(),
      throwsA(isA<MissingPluginException>()),
    );
  });

  testWidgets('detectOnce forwards to native layer', (
    WidgetTester tester,
  ) async {
    expect(
      () => GeoIntegrityScore.detectOnce(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
