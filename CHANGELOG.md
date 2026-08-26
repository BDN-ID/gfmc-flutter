# Changelog

## 0.2.0

Adds iOS, wrapping [`gfmc-ios`](https://github.com/BDN-ID/gfmc-ios)
(`JessicaSDK.xcframework`) `1.14.0`.

- `ios/` platform folder: podspec (fetches + checksum-verifies the pinned
  XCFramework release at `pod install` time) and `Classes/` plugin
  implementation
- Same Dart API as 0.1.0 now works on both platforms — see README's "Known
  gaps" for the handful of things that still differ (`closeMiniApp()` is a
  real close on iOS but a no-op on Android; a few iOS-only `JessicaSDKConfig`
  knobs aren't exposed through `GfmcConfig` yet)

## 0.1.0

Initial version. Wraps `com.sltr.gfmc:gfmc-sdk:1.2.6` (GfmcSDK 2.3.6).

- `GfmcSdk.init` / `.open` / `.getVersion` / `.getConfig`
- `GfmcSdk.setTokenRefresher` for the async JWT-refresh flow
- `GfmcSdk.events` — unified `Stream<GfmcEvent>` covering hub lifecycle,
  errors, purchases, module changes, share requests, SKU selection
- Android only. No `ios/` platform folder yet — see README's "Known gaps".
