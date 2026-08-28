# Changelog

## 0.2.2

Docs-only patch — no plugin code changes.

- README.md/README.id.md: new "In-app purchase products (SKUs)" section —
  the exact SKU strings that must be created as matching in-app products in
  Google Play Console and App Store Connect before purchases work. SKUs are
  called out as the required part; name/price/discount are the backend
  catalog's own reference values, explicitly optional to mirror since each
  store sets its own pricing/localization independently.

## 0.2.1

Docs-only patch — no plugin code changes.

- README.md/README.id.md: lead with the pub.dev install
  (`gfmc_flutter: ^0.2.0` / `flutter pub add gfmc_flutter`) now that this
  package is actually published there; keep the git `ref:` install as an
  alternative. Add a pub.dev version badge.
- Add `PLAYSTORE.md`: how to prepare `example/` for a real Play Store
  upload (applicationId, release signing, Windows-path-with-spaces build
  workarounds, and the `MainActivity.kt` package-move gotcha when changing
  `applicationId`).
- `example/`: depend on `gfmc_flutter` via pub.dev instead of a git `ref:`,
  demonstrating the normal consumer install path.

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
- Ran `dart run pigeon` for real against `pigeons/gfmc_api.dart` for the
  first time (all three generated files were previously hand-written).
  Found and fixed a real bug: the `GfmcHostApi.init` method's name collided
  with Swift's `init` keyword, which Pigeon emits unescaped and fails to
  compile — renamed to `initialize` internally (`GfmcSdk.init()`, the public
  Dart API, is unchanged). Android side additionally verified with a real
  `flutter build apk` against the pinned `gfmc-sdk` artifact. iOS still
  hasn't been built with an actual Xcode toolchain — see README's "Known
  gaps".

## 0.1.0

Initial version. Wraps `com.sltr.gfmc:gfmc-sdk:1.2.6` (GfmcSDK 2.3.6).

- `GfmcSdk.init` / `.open` / `.getVersion` / `.getConfig`
- `GfmcSdk.setTokenRefresher` for the async JWT-refresh flow
- `GfmcSdk.events` — unified `Stream<GfmcEvent>` covering hub lifecycle,
  errors, purchases, module changes, share requests, SKU selection
- Android only. No `ios/` platform folder yet — see README's "Known gaps".
