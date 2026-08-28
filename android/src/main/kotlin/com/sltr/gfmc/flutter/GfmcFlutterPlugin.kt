package com.sltr.gfmc.flutter

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import com.sltr.gfmc.GfmcModule
import com.sltr.gfmc.GfmcRefreshResult
import com.sltr.gfmc.GfmcSDK
import com.sltr.gfmc.GfmcSDKConfig
import com.sltr.gfmc.GfmcSDKEnv
import com.sltr.gfmc.GfmcSDKError
import com.sltr.gfmc.GfmcSDKListener
import com.sltr.gfmc.GfmcSDKTheme
import com.sltr.gfmc.GfmcSkuListener
import com.sltr.gfmc.GfmcTokenRefresher
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Dart-facing entry point. Registered automatically via pubspec.yaml's
 * `flutter.plugin.platforms.android.pluginClass` — hosts don't touch this
 * class directly, only lib/gfmc_flutter.dart's GfmcSdk facade.
 *
 * Implements GfmcHostApi (Dart -> native calls) directly, and owns a
 * GfmcFlutterApi instance (native -> Dart calls) built once attached to an
 * engine. GfmcSDK.open()/init() need a Context; ActivityAware is what makes
 * the *current* Activity available for that, since a FlutterPlugin's own
 * `context` from onAttachedToEngine is the Application context, not
 * something GfmcSDK.open() can start an Activity from reliably on every
 * Android version.
 */
class GfmcFlutterPlugin : FlutterPlugin, ActivityAware, GfmcHostApi {

    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var flutterApi: GfmcFlutterApi? = null

    // Non-null once GfmcSDK.init() has actually been called via [initialize]
    // below.
    // Guards against onSkuSelected/refreshToken/listener callbacks firing
    // into a torn-down engine after detach.
    private var attached = false

    // GfmcSDK.getConfig() exists but is `internal` in the AAR (compile-time
    // "Cannot access ... it is internal in 'com.sltr.gfmc.GfmcSDK'" against
    // gfmc-sdk 1.2.6) -- not something a consumer module can call. We track
    // the last config passed to [initialize] ourselves instead of reading it
    // back from the SDK.
    private var lastConfig: GfmcConfigMessage? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        flutterApi = GfmcFlutterApi(binding.binaryMessenger)
        GfmcHostApi.setUp(binding.binaryMessenger, this)
        attached = true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        GfmcHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // -- GfmcHostApi (Dart -> native) ----------------------------------------

    override fun initialize(config: GfmcConfigMessage) {
        val ctx = activity ?: applicationContext
            ?: throw IllegalStateException("GfmcFlutterPlugin.initialize() called before attaching to an engine")

        val sdkConfig = GfmcSDKConfig.Builder()
            .setEnvironment(config.environment.toSdkEnv())
            .setLocale(config.locale)
            .setTheme(config.theme.toSdkTheme())
            .enableLogging(config.enableLogging)
            .setConnectionTimeout(config.connectionTimeoutMs)
            .build()

        GfmcSDK.init(ctx, sdkConfig)
        GfmcSDK.setListener(ctx, sdkListener)
        GfmcSDK.setTokenRefresher(tokenRefresher)
        GfmcSDK.setSkuListener(skuListener)
        lastConfig = config
    }

    override fun open(jwt: String) {
        val ctx = activity ?: applicationContext
            ?: throw IllegalStateException("GfmcFlutterPlugin.open() called before attaching to an engine")
        GfmcSDK.open(ctx, jwt)
    }

    override fun closeMiniApp() {
        // GfmcSDK doesn't expose a "close the currently-open hub from the
        // outside" call today (closing is driven from inside the hub, via
        // its own capsule/back-press handling) -- this is intentionally a
        // documented no-op placeholder for now rather than a silent lie.
        // See jessica-sdk-android if a host-initiated close ever gets added.
    }

    override fun getVersion(): GfmcVersionMessage {
        val v = GfmcSDK.version
        return GfmcVersionMessage(
            name = v.name,
            versionCode = v.versionCode.toLong(),
            artifactVersion = v.artifactVersion,
            displayName = v.displayName,
        )
    }

    override fun getConfig(): GfmcConfigMessage? = lastConfig

    // -- GfmcSDK callbacks -> GfmcFlutterApi (native -> Dart) --------------

    private val sdkListener = object : GfmcSDKListener {
        override fun onHubReady() {
            if (attached) flutterApi?.onHubReady { }
        }
        override fun onHubClosed() {
            if (attached) flutterApi?.onHubClosed { }
        }
        override fun onError(code: GfmcSDKError, message: String) {
            if (attached) flutterApi?.onError(code.toMessage(), message) { }
        }
        override fun onPurchaseCompleted(sku: String, txId: String) {
            if (attached) flutterApi?.onPurchaseCompleted(sku, txId) { }
        }
        override fun onPurchaseFailed(reason: String) {
            if (attached) flutterApi?.onPurchaseFailed(reason) { }
        }
        override fun onModuleChanged(module: GfmcModule) {
            if (attached) flutterApi?.onModuleChanged(module.toMessage()) { }
        }
        override fun onShareRequested(url: String, title: String) {
            if (attached) flutterApi?.onShareRequested(url, title) { }
        }
    }

    private val skuListener = GfmcSkuListener { sku ->
        if (attached) flutterApi?.onSkuSelected(sku) { }
    }

    private val tokenRefresher = GfmcTokenRefresher { result: GfmcRefreshResult ->
        val api = flutterApi
        if (!attached || api == null) {
            result.fail("Flutter engine detached")
            return@GfmcTokenRefresher
        }
        api.refreshToken { refreshResult ->
            refreshResult.fold(
                onSuccess = { jwt -> result.emit(jwt) },
                onFailure = { error -> result.fail(error.message ?: "refresh failed") },
            )
        }
    }
}

// -- Enum conversions ---------------------------------------------------

private fun GfmcEnvMessage.toSdkEnv(): GfmcSDKEnv = when (this) {
    GfmcEnvMessage.PRODUCTION -> GfmcSDKEnv.PRODUCTION
    GfmcEnvMessage.SANDBOX -> GfmcSDKEnv.SANDBOX
    GfmcEnvMessage.DEV -> GfmcSDKEnv.DEV
}

private fun GfmcThemeMessage.toSdkTheme(): GfmcSDKTheme = when (this) {
    GfmcThemeMessage.DARK -> GfmcSDKTheme.DARK
    GfmcThemeMessage.LIGHT -> GfmcSDKTheme.LIGHT
    GfmcThemeMessage.AUTO -> GfmcSDKTheme.AUTO
}

private fun GfmcSDKError.toMessage(): GfmcErrorMessage = when (this) {
    GfmcSDKError.AUTH_FAILED -> GfmcErrorMessage.AUTH_FAILED
    GfmcSDKError.NETWORK_ERROR -> GfmcErrorMessage.NETWORK_ERROR
    GfmcSDKError.SESSION_EXPIRED -> GfmcErrorMessage.SESSION_EXPIRED
    GfmcSDKError.SDK_NOT_INITIALIZED -> GfmcErrorMessage.SDK_NOT_INITIALIZED
    GfmcSDKError.WEBVIEW_UNAVAILABLE -> GfmcErrorMessage.WEBVIEW_UNAVAILABLE
    GfmcSDKError.WEBVIEW_OUTDATED -> GfmcErrorMessage.WEBVIEW_OUTDATED
    GfmcSDKError.WEBVIEW_RENDERER_GONE -> GfmcErrorMessage.WEBVIEW_RENDERER_GONE
    GfmcSDKError.BILLING_UNAVAILABLE -> GfmcErrorMessage.BILLING_UNAVAILABLE
    GfmcSDKError.PURCHASE_FAILED -> GfmcErrorMessage.PURCHASE_FAILED
    GfmcSDKError.VERIFY_FAILED -> GfmcErrorMessage.VERIFY_FAILED
}

private fun GfmcModule.toMessage(): GfmcModuleMessage = when (this) {
    GfmcModule.CINEMA -> GfmcModuleMessage.CINEMA
    GfmcModule.GAME -> GfmcModuleMessage.GAME
    GfmcModule.SHOP -> GfmcModuleMessage.SHOP
}
