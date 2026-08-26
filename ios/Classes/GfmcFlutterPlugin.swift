import Flutter
import JessicaSDK
import UIKit

/// Dart-facing entry point. Registered automatically via pubspec.yaml's
/// `flutter.plugin.platforms.ios.pluginClass` — hosts don't touch this class
/// directly, only lib/gfmc_flutter.dart's GfmcSdk facade.
///
/// Implements GfmcHostApi (Dart -> native calls) directly, and owns a
/// GfmcFlutterApi instance (native -> Dart calls) built once attached to an
/// engine. Wraps JessicaSDK (https://github.com/BDN-ID/gfmc-ios) — see that
/// package's README for the native API this mirrors; mirrors
/// GfmcFlutterPlugin.kt on the Android side field-for-field where the two
/// SDKs' surfaces line up.
public class GfmcFlutterPlugin: NSObject, FlutterPlugin, GfmcHostApi {

  private var flutterApi: GfmcFlutterApi?

  // Non-nil once GfmcHostApi.init() has actually been called via [init]
  // below. Guards against skuListener/tokenRefresher/delegate callbacks
  // firing into a torn-down engine after detach.
  private var attached = false

  // Jessica.shared has no public getter for the config it was last
  // configure()'d with (same situation as GfmcSDK.getConfig() being
  // `internal` on Android — see GfmcFlutterPlugin.kt's comment). Track the
  // last config passed to [init] ourselves instead.
  private var lastConfig: GfmcConfigMessage?

  // The hub JessicaSDK.open() handed back, so [closeMiniApp] has something
  // to dismiss. Android has no such hook (open() there returns Unit) —
  // that's the "no-op placeholder" gap noted in Messages.g.kt; iOS doesn't
  // share it, since JessicaHubViewController is a real, dismissable
  // UIViewController.
  private weak var hubViewController: JessicaHubViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GfmcFlutterPlugin()
    instance.flutterApi = GfmcFlutterApi(binaryMessenger: registrar.messenger())
    GfmcHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    instance.attached = true
  }

  // -- GfmcHostApi (Dart -> native) ------------------------------------------

  // JessicaSDK's `Jessica` class is @MainActor-isolated end to end (see its
  // .swiftinterface). GfmcHostApi's methods are plain nonisolated protocol
  // requirements -- Pigeon has no notion of actor isolation -- but Flutter
  // guarantees platform-channel handlers run on the platform thread, which
  // on iOS *is* the main thread, so MainActor.assumeIsolated is a correct
  // (not a hopeful) escape hatch here, not a data-race risk.

  public func `init`(config: GfmcConfigMessage) throws {
    MainActor.assumeIsolated {
      let sdkConfig = JessicaSDKConfig(
        environment: config.environment.toSdkEnv(),
        locale: config.locale,
        theme: config.theme.toSdkTheme(),
        isLoggingEnabled: config.enableLogging,
        connectionTimeout: TimeInterval(config.connectionTimeoutMs) / 1000.0
      )

      Jessica.shared.configure(sdkConfig)
      Jessica.shared.setDelegate(self)
      Jessica.shared.setSKUListener(skuListener)
      Jessica.shared.setTokenRefresher(tokenRefresher)
    }
    lastConfig = config
  }

  public func open(jwt: String) throws {
    MainActor.assumeIsolated {
      let presenter = topViewController()
      hubViewController = Jessica.shared.open(from: presenter, jwt: jwt)
    }
  }

  public func closeMiniApp() throws {
    // Mirrors GfmcSDK.closeMiniApp() on Android in effect (see this file's
    // hubViewController comment for why the two sides differ underneath).
    MainActor.assumeIsolated {
      hubViewController?.dismiss(animated: true)
    }
    hubViewController = nil
  }

  public func getVersion() throws -> GfmcVersionMessage {
    let v = MainActor.assumeIsolated { Jessica.version }
    return GfmcVersionMessage(
      name: v.name,
      versionCode: Int64(v.build),
      artifactVersion: JessicaSDKVersion.packageVersion,
      displayName: v.displayName
    )
  }

  public func getConfig() throws -> GfmcConfigMessage? {
    return lastConfig
  }

  // -- Presenting view controller -------------------------------------------

  // JessicaHubViewController is presented modally, so JessicaSDK needs
  // *something* to present it from. There's no ActivityAware equivalent on
  // iOS to hand this a live UIViewController the way GfmcFlutterPlugin.kt
  // gets one from ActivityPluginBinding — walk the key window's presented
  // controller chain instead, same approach most Flutter plugins that
  // present UIKit view controllers use (e.g. image_picker, url_launcher_ios).
  @MainActor
  private func topViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  // -- JessicaSDK callbacks -> GfmcFlutterApi (native -> Dart) ---------------

  private lazy var skuListener: JessicaSKUListener = { [weak self] sku in
    guard let self, self.attached else { return }
    self.flutterApi?.onSkuSelected(sku: sku) { _ in }
  }

  private lazy var tokenRefresher: JessicaTokenRefresher = { [weak self] done in
    guard let self, self.attached, let api = self.flutterApi else {
      done(.failure(JessicaRefreshError("Flutter engine detached")))
      return
    }
    api.refreshToken { result in
      switch result {
      case .success(let jwt):
        done(.success(jwt))
      case .failure(let error):
        done(.failure(JessicaRefreshError(error.message ?? "refresh failed")))
      }
    }
  }
}

// -- JessicaSDKDelegate -----------------------------------------------------

extension GfmcFlutterPlugin: JessicaSDKDelegate {
  public func jessicaHubDidBecomeReady() {
    guard attached else { return }
    flutterApi?.onHubReady { _ in }
  }

  public func jessicaHubDidClose() {
    guard attached else { return }
    hubViewController = nil
    flutterApi?.onHubClosed { _ in }
  }

  public func jessicaHub(didRequestShare url: URL, title: String) {
    guard attached else { return }
    flutterApi?.onShareRequested(url: url.absoluteString, title: title) { _ in }
  }

  public func jessicaHub(didFailWith error: JessicaSDKError, message: String) {
    guard attached else { return }
    flutterApi?.onError(code: error.toMessage(), message: message) { _ in }
  }

  public func jessicaHub(didChangeModule module: JessicaModule) {
    guard attached else { return }
    flutterApi?.onModuleChanged(module: module.toMessage()) { _ in }
  }

  public func jessicaHub(didCompletePurchase sku: String, transactionId: String) {
    guard attached else { return }
    flutterApi?.onPurchaseCompleted(sku: sku, txId: transactionId) { _ in }
  }

  public func jessicaHub(didFailPurchase reason: String) {
    guard attached else { return }
    flutterApi?.onPurchaseFailed(reason: reason) { _ in }
  }
}

// -- Enum conversions ---------------------------------------------------

private extension GfmcEnvMessage {
  func toSdkEnv() -> JessicaEnvironment {
    switch self {
    case .production: return .production
    case .sandbox: return .sandbox
    case .dev: return .dev
    }
  }
}

private extension GfmcThemeMessage {
  func toSdkTheme() -> JessicaTheme {
    switch self {
    case .dark: return .dark
    case .light: return .light
    case .auto: return .auto
    }
  }
}

// JessicaSDKError (iOS) has no webviewOutdated/webviewRendererGone case --
// see pigeons/gfmc_api.dart's comment on GfmcErrorMessage.
private extension JessicaSDKError {
  func toMessage() -> GfmcErrorMessage {
    switch self {
    case .authFailed: return .authFailed
    case .networkError: return .networkError
    case .sessionExpired: return .sessionExpired
    case .sdkNotInitialized: return .sdkNotInitialized
    case .webViewUnavailable: return .webviewUnavailable
    case .billingUnavailable: return .billingUnavailable
    case .purchaseFailed: return .purchaseFailed
    case .verifyFailed: return .verifyFailed
    }
  }
}

private extension JessicaModule {
  func toMessage() -> GfmcModuleMessage {
    switch self {
    case .cinema: return .cinema
    case .game: return .game
    case .shop: return .shop
    }
  }
}
