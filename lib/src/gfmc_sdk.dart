import 'dart:async';

import 'gfmc_config.dart';
import 'gfmc_enums.dart';
import 'gfmc_events.dart';
import 'gfmc_version.dart';
import 'messages.g.dart';

/// Implementation your app provides to [GfmcSdk.setTokenRefresher]. Return
/// the fresh minicinema JWT, or throw to signal a refresh failure — mirrors
/// `com.sltr.gfmc.GfmcTokenRefresher` on the Android side.
typedef GfmcTokenRefresher = Future<String> Function();

class _FlutterApiImpl extends GfmcFlutterApi {
  _FlutterApiImpl(this._events);

  final StreamController<GfmcEvent> _events;
  GfmcTokenRefresher? refresher;

  @override
  void onHubReady() => _events.add(const GfmcHubReadyEvent());

  @override
  void onHubClosed() => _events.add(const GfmcHubClosedEvent());

  @override
  void onError(GfmcErrorMessage code, String message) =>
      _events.add(GfmcErrorEvent(code.toPublic(), message));

  @override
  void onPurchaseCompleted(String sku, String txId) =>
      _events.add(GfmcPurchaseCompletedEvent(sku, txId));

  @override
  void onPurchaseFailed(String reason) =>
      _events.add(GfmcPurchaseFailedEvent(reason));

  @override
  void onModuleChanged(GfmcModuleMessage module) =>
      _events.add(GfmcModuleChangedEvent(module.toPublic()));

  @override
  void onShareRequested(String url, String title) =>
      _events.add(GfmcShareRequestedEvent(url, title));

  @override
  void onSkuSelected(String sku) => _events.add(GfmcSkuSelectedEvent(sku));

  @override
  Future<String> refreshToken() {
    final r = refresher;
    if (r == null) {
      throw StateError(
        'GfmcSdk: web asked for a refreshed token but no refresher is '
        'registered. Call GfmcSdk.setTokenRefresher(...) before opening the '
        'hub if your JWTs expire during a session.',
      );
    }
    return r();
  }
}

/// Facade over GfmcSDK for Flutter apps. Static, matching the underlying
/// Android SDK's own singleton-object shape (`GfmcSDK`) — there is exactly
/// one hub per app, same as on native Android.
///
/// ```dart
/// await GfmcSdk.init(config: const GfmcConfig(environment: GfmcEnv.sandbox));
/// GfmcSdk.setTokenRefresher(() => myAuth.freshMinicinemaJwt());
/// GfmcSdk.events.listen((event) {
///   if (event is GfmcHubClosedEvent) { /* ... */ }
/// });
/// await GfmcSdk.open(jwt);
/// ```
abstract final class GfmcSdk {
  static final GfmcHostApi _host = GfmcHostApi();
  static final StreamController<GfmcEvent> _controller =
      StreamController<GfmcEvent>.broadcast();
  static final _FlutterApiImpl _flutterApiImpl = _FlutterApiImpl(_controller);
  static bool _wired = false;

  static void _ensureWired() {
    if (_wired) return;
    GfmcFlutterApi.setUp(_flutterApiImpl);
    _wired = true;
  }

  /// Broadcast stream of every event GfmcSDK reports — hub lifecycle,
  /// errors, purchases, module switches, share requests, SKU selections.
  /// Safe to listen before or after [init]; nothing is buffered from before
  /// a listener attaches, same as any other broadcast stream.
  static Stream<GfmcEvent> get events {
    _ensureWired();
    return _controller.stream;
  }

  /// Must be called once before [open]. Safe to call again to change
  /// config as long as no hub is currently open.
  static Future<void> init({GfmcConfig config = const GfmcConfig()}) async {
    _ensureWired();
    await _host.initialize(
      GfmcConfigMessage(
        environment: config.environment.toMessage(),
        locale: config.locale,
        theme: config.theme.toMessage(),
        enableLogging: config.enableLogging,
        connectionTimeoutMs: config.connectionTimeout.inMilliseconds,
      ),
    );
  }

  /// Opens the hub with a minicinema session JWT obtained from your own
  /// backend — NOT your app's own auth access token. Requires [init]
  /// first.
  static Future<void> open(String jwt) => _host.open(jwt);

  /// Registers the callback GfmcSDK calls when the current JWT expires.
  /// Register this before [open] if your sessions can outlive the JWT's
  /// lifetime — otherwise a session-expiry mid-playback has nothing to
  /// recover with.
  static void setTokenRefresher(GfmcTokenRefresher refresher) {
    _ensureWired();
    _flutterApiImpl.refresher = refresher;
  }

  static Future<GfmcVersion> getVersion() async {
    final v = await _host.getVersion();
    return GfmcVersion(
      name: v.name,
      versionCode: v.versionCode,
      artifactVersion: v.artifactVersion,
      displayName: v.displayName,
    );
  }

  static Future<GfmcConfig?> getConfig() async {
    final c = await _host.getConfig();
    if (c == null) return null;
    return GfmcConfig(
      environment: c.environment.toPublic(),
      locale: c.locale,
      theme: c.theme.toPublic(),
      enableLogging: c.enableLogging,
      connectionTimeout: Duration(milliseconds: c.connectionTimeoutMs),
    );
  }
}

// -- Enum <-> Message conversions -------------------------------------------

extension on GfmcEnv {
  GfmcEnvMessage toMessage() => switch (this) {
        GfmcEnv.production => GfmcEnvMessage.production,
        GfmcEnv.sandbox => GfmcEnvMessage.sandbox,
        GfmcEnv.dev => GfmcEnvMessage.dev,
      };
}

extension on GfmcEnvMessage {
  GfmcEnv toPublic() => switch (this) {
        GfmcEnvMessage.production => GfmcEnv.production,
        GfmcEnvMessage.sandbox => GfmcEnv.sandbox,
        GfmcEnvMessage.dev => GfmcEnv.dev,
      };
}

extension on GfmcTheme {
  GfmcThemeMessage toMessage() => switch (this) {
        GfmcTheme.dark => GfmcThemeMessage.dark,
        GfmcTheme.light => GfmcThemeMessage.light,
        GfmcTheme.auto => GfmcThemeMessage.auto,
      };
}

extension on GfmcThemeMessage {
  GfmcTheme toPublic() => switch (this) {
        GfmcThemeMessage.dark => GfmcTheme.dark,
        GfmcThemeMessage.light => GfmcTheme.light,
        GfmcThemeMessage.auto => GfmcTheme.auto,
      };
}

extension on GfmcErrorMessage {
  GfmcError toPublic() => switch (this) {
        GfmcErrorMessage.authFailed => GfmcError.authFailed,
        GfmcErrorMessage.networkError => GfmcError.networkError,
        GfmcErrorMessage.sessionExpired => GfmcError.sessionExpired,
        GfmcErrorMessage.sdkNotInitialized => GfmcError.sdkNotInitialized,
        GfmcErrorMessage.webviewUnavailable => GfmcError.webviewUnavailable,
        GfmcErrorMessage.webviewOutdated => GfmcError.webviewOutdated,
        GfmcErrorMessage.webviewRendererGone =>
          GfmcError.webviewRendererGone,
        GfmcErrorMessage.billingUnavailable => GfmcError.billingUnavailable,
        GfmcErrorMessage.purchaseFailed => GfmcError.purchaseFailed,
        GfmcErrorMessage.verifyFailed => GfmcError.verifyFailed,
      };
}

extension on GfmcModuleMessage {
  GfmcModule toPublic() => switch (this) {
        GfmcModuleMessage.cinema => GfmcModule.cinema,
        GfmcModuleMessage.game => GfmcModule.game,
        GfmcModuleMessage.shop => GfmcModule.shop,
      };
}
