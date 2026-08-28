// Pigeon schema — the source of truth for the generated platform-channel
// glue. This file is NOT the plugin's runtime code; it's input to codegen.
//
// Regenerate after any change here:
//   dart run pigeon --input pigeons/gfmc_api.dart
//
// That overwrites:
//   lib/src/messages.g.dart
//   android/src/main/kotlin/com/sltr/gfmc/flutter/Messages.g.kt
//   ios/Classes/Messages.g.swift
//
// The three generated files are real `dart run pigeon` output (pigeon
// 22.7.4) — regenerate and diff after any schema change, same as any other
// generated code.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/sltr/gfmc/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.sltr.gfmc.flutter'),
    swiftOut: 'ios/Classes/Messages.g.swift',
    dartPackageName: 'gfmc_flutter',
  ),
)

// -- Enums ------------------------------------------------------------------
// Mirror com.sltr.gfmc.GfmcSDKEnv / GfmcSDKTheme / GfmcSDKError / GfmcModule
// 1:1. Keep these in lockstep with the Android SDK's own enums — if it adds
// a value, add it here in the same position (Pigeon enums are ordinal-coded
// on the wire, so appending is safe; reordering or deleting is not).
//
// GfmcErrorMessage is a superset of iOS's JessicaSDKError (JessicaSDK
// 1.14.0 has no webviewOutdated/webviewRendererGone case — WKWebView update
// checks are an Android-only concern there) — ios/Classes/GfmcFlutterPlugin
// .swift's mapper only ever produces the 8 values that exist on both sides.

enum GfmcEnvMessage { production, sandbox, dev }

enum GfmcThemeMessage { dark, light, auto }

enum GfmcErrorMessage {
  authFailed,
  networkError,
  sessionExpired,
  sdkNotInitialized,
  webviewUnavailable,
  webviewOutdated,
  webviewRendererGone,
  billingUnavailable,
  purchaseFailed,
  verifyFailed,
}

enum GfmcModuleMessage { cinema, game, shop }

// -- Data classes -------------------------------------------------------

class GfmcConfigMessage {
  GfmcConfigMessage({
    this.environment = GfmcEnvMessage.production,
    this.locale = 'en',
    this.theme = GfmcThemeMessage.auto,
    this.enableLogging = false,
    this.connectionTimeoutMs = 10000,
  });

  GfmcEnvMessage environment;
  String locale;
  GfmcThemeMessage theme;
  bool enableLogging;
  int connectionTimeoutMs;
}

class GfmcVersionMessage {
  GfmcVersionMessage({
    required this.name,
    required this.versionCode,
    required this.artifactVersion,
    required this.displayName,
  });

  /// Internal SDK semantic version, e.g. "2.3.6". NOT what a host app
  /// should show a partner — see [artifactVersion].
  String name;
  int versionCode;

  /// The Maven coordinate this plugin's Android dependency actually pins,
  /// e.g. "1.2.6" — what GfmcSDK.getArtifactVersion()/GET_APP_VERSION report
  /// on the native side. This is the number to show or log.
  String artifactVersion;
  String displayName;
}

// -- Host API (Dart calls native) -------------------------------------------

@HostApi()
abstract class GfmcHostApi {
  /// Must be called once before [open]. Safe to call again to change config
  /// (e.g. switching environment) as long as no hub is currently open.
  ///
  /// Named `initialize`, not `init` — `init` is a reserved word in Swift, and
  /// Pigeon 22.7.4 emits it unescaped (`func init(...)`) in the generated
  /// `GfmcHostApi` protocol, which fails to compile. Confirmed by actually
  /// running `dart run pigeon` against this schema (see this repo's
  /// `Messages.g.swift` header). The public Dart-facing name is unaffected —
  /// `GfmcSdk.init()` in lib/src/gfmc_sdk.dart just calls `_host.initialize`
  /// underneath.
  void initialize(GfmcConfigMessage config);

  /// Opens the hub with a minicinema session JWT obtained from your own
  /// backend — NOT your app's own auth access token. Requires [initialize]
  /// first and a token refresher registered on the Dart side (see
  /// GfmcFlutterApi.refreshToken) if you expect long sessions.
  void open(String jwt);

  /// Native-side "close" — same effect as the user tapping the capsule's
  /// close button. No-op if no hub is currently open.
  void closeMiniApp();

  GfmcVersionMessage getVersion();

  /// Null if [initialize] hasn't been called yet.
  GfmcConfigMessage? getConfig();
}

// -- Flutter API (native calls Dart) -----------------------------------------

@FlutterApi()
abstract class GfmcFlutterApi {
  void onHubReady();
  void onHubClosed();
  void onError(GfmcErrorMessage code, String message);
  void onPurchaseCompleted(String sku, String txId);
  void onPurchaseFailed(String reason);
  void onModuleChanged(GfmcModuleMessage module);
  void onShareRequested(String url, String title);

  /// Informational only — does not gate the Google Play billing flow, which
  /// runs natively regardless of what this returns.
  void onSkuSelected(String sku);

  /// Native asks Dart for a fresh minicinema JWT when the current one
  /// expires. Implement this to call your own backend and return the new
  /// token; throw (or let the Future fail) to signal a refresh failure —
  /// the native side maps that to the same "refresh failed" outcome as
  /// GfmcTokenRefresher.fail(reason) on the Android side.
  @async
  String refreshToken();
}
