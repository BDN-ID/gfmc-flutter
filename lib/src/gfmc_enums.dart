/// Mirrors `com.sltr.gfmc.GfmcSDKEnv`. Selects the hub environment. See
/// jessica-sdk-android's CHANGELOG.md for which values currently resolve to
/// distinct hosts — as of SDK 2.3.6 all three still point at the same host.
enum GfmcEnv { production, sandbox, dev }

/// Mirrors `com.sltr.gfmc.GfmcSDKTheme`.
enum GfmcTheme { dark, light, auto }

/// Mirrors `com.sltr.gfmc.GfmcSDKError`. Delivered via [GfmcErrorEvent].
enum GfmcError {
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

/// Mirrors `com.sltr.gfmc.GfmcModule`.
enum GfmcModule { cinema, game, shop }
