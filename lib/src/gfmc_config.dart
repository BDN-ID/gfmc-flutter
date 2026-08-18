import 'gfmc_enums.dart';

/// Configuration passed to [GfmcSdk.init]. Mirrors
/// `com.sltr.gfmc.GfmcSDKConfig.Builder` — see jessica-sdk-android's README
/// for what each field actually does on the native side.
class GfmcConfig {
  const GfmcConfig({
    this.environment = GfmcEnv.production,
    this.locale = 'en',
    this.theme = GfmcTheme.auto,
    this.enableLogging = false,
    this.connectionTimeout = const Duration(seconds: 10),
  });

  final GfmcEnv environment;

  /// Defaults to `"en"` — matches the Android SDK's own default since
  /// 2.3.6 (it used to default to `"id"`; see jessica-sdk-android's
  /// CHANGELOG.md if a host relied on that).
  final String locale;
  final GfmcTheme theme;
  final bool enableLogging;
  final Duration connectionTimeout;
}
