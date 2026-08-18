import 'package:flutter_test/flutter_test.dart';
import 'package:gfmc_flutter/gfmc_flutter.dart';

// Deliberately narrow: pure-Dart model behavior only. Testing GfmcSdk's
// static methods themselves needs a mocked GfmcHostApi via
// TestDefaultBinaryMessengerBinding — worth adding once the hand-written
// messages.g.dart above has been replaced by a real `dart run pigeon`
// output (see README's warning banner) so the mock is testing something
// trustworthy.
void main() {
  test('GfmcConfig defaults match the native SDK\'s own defaults', () {
    const config = GfmcConfig();
    expect(config.environment, GfmcEnv.production);
    expect(config.locale, 'en');
    expect(config.theme, GfmcTheme.auto);
    expect(config.enableLogging, false);
    expect(config.connectionTimeout, const Duration(seconds: 10));
  });

  test('GfmcVersion.toString includes the artifact version', () {
    const version = GfmcVersion(
      name: '2.3.6',
      versionCode: 12,
      artifactVersion: '1.2.6',
      displayName: '2.3.6 (12)',
    );
    expect(version.toString(), contains('1.2.6'));
  });
}
