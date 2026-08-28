# gfmc_flutter

[![pub package](https://img.shields.io/pub/v/gfmc_flutter.svg)](https://pub.dev/packages/gfmc_flutter)

*Read this in other languages: [Bahasa Indonesia](README.id.md).*

Flutter plugin wrapping GfmcSDK — the minicinema mini-program SDK. Embeds
streaming, entitlements and top-ups inside your Flutter app's Android and
iOS targets as a self-contained hub, without hand-rolling a `MethodChannel`
yourself.

**Native SDK versions pinned by this plugin:**

| Platform | Native package | Version | Declared in |
|---|---|---|---|
| Android | [`gfmc-sdk`](https://github.com/BDN-ID/gfmc-sdk) `com.sltr.gfmc:gfmc-sdk:1.2.6` | GfmcSDK `2.3.6` | `android/build.gradle`'s `dependencies` block |
| iOS | [`gfmc-ios`](https://github.com/BDN-ID/gfmc-ios) `JessicaSDK.xcframework` | `1.14.0` | `ios/gfmc_flutter.podspec`'s `jessica_sdk_version`/`jessica_sdk_sha256` |

Those files are the only places each is declared; check them directly if
this README ever drifts out of sync. See each native repo's own README for
what a version bump actually changed before bumping it here.

---

## Install

Published on pub.dev — the normal way:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter: ^0.2.0
```

or:

```sh
flutter pub add gfmc_flutter
```

Prefer to pin an exact git tag instead (e.g. to track `main` during
development, or to bypass pub.dev entirely)? Same repo, either way:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter:
    git:
      url: https://github.com/BDN-ID/gfmc-flutter.git
      ref: v0.2.0
```

### Package versioning

Follows semver (`MAJOR.MINOR.PATCH`). On pub.dev, a `^0.2.0`-style
constraint resolves and upgrades the normal way (`flutter pub upgrade`).
If you're pinning a git `ref:` instead:

- **Pin a tag** (`ref: v0.2.0`), not `main`/`master` — a branch ref means your
  build silently picks up whatever's newest on it, including unreleased
  work-in-progress commits.
- **Upgrading is manual.** There's no `pub upgrade` auto-resolving to "latest
  compatible" for a git dependency — bump the `ref:` yourself and re-run
  `flutter pub get`.

Either way, **check [`CHANGELOG.md`](CHANGELOG.md) before bumping** — same
discipline as bumping the native `gfmc-sdk` coordinate (see "Native SDK
version" below). Each version here corresponds 1:1 with both a git tag and
a `CHANGELOG.md` entry.

### Gradle repository

GfmcSDK's Android artifact is distributed from a token-free static Maven
tree (see [gfmc-sdk](https://github.com/BDN-ID/gfmc-sdk)'s own README), and
this plugin's `android/build.gradle` already declares it via
`rootProject.allprojects`. **If your app's `android/settings.gradle.kts`
sets `repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)`** (the
default for apps created with a recent Flutter/AGP template), that mode
disallows per-project repository declarations — including the one this
plugin's own `build.gradle` adds — and Gradle will fail to resolve
`com.sltr.gfmc:gfmc-sdk` even though this plugin declares the repo. Add it
to your app's own `settings.gradle.kts` instead:

```kotlin
// android/settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://raw.githubusercontent.com/BDN-ID/gfmc-sdk/gh-pages/") }
    }
}
```

If your app's Gradle setup doesn't use `FAIL_ON_PROJECT_REPOS`, the plugin's
own declaration is enough and you can skip this — but adding it explicitly
costs nothing and removes the ambiguity.

### AndroidManifest

Nothing to add — `INTERNET`, `ACCESS_NETWORK_STATE`,
`com.android.vending.BILLING`, and the hub's own Activity/services merge in
automatically from the `gfmc-sdk` AAR, same as for a native Android host.

### iOS Podfile / minimum target

Nothing to add to your `Podfile` — `pod install` picks up this plugin's own
podspec automatically. Two things worth knowing:

- **`JessicaSDK.xcframework` is fetched at `pod install` time**, not
  committed to this repo. `ios/gfmc_flutter.podspec`'s `prepare_command`
  downloads the exact release tagged in
  [gfmc-ios](https://github.com/BDN-ID/gfmc-ios), verifies its SHA-256
  against the checksum pinned alongside it, and vendors it in. A first
  `pod install` after adding this plugin therefore needs network access to
  `github.com`; a checksum mismatch fails the build loudly instead of
  vendoring something unverified.
- **Minimum deployment target is iOS 15** (JessicaSDK's own floor) — this
  plugin's podspec sets `s.platform = :ios, '15.0'`, so your app's own
  `ios/Podfile` needs `platform :ios, '15.0'` (or higher) too, or CocoaPods
  will fail to resolve.

---

## Quick start

```dart
import 'package:gfmc_flutter/gfmc_flutter.dart';

// Once, e.g. in your app's startup:
await GfmcSdk.init(
  config: const GfmcConfig(environment: GfmcEnv.sandbox), // production once ready to ship
);

// Register before open() if your JWTs can expire mid-session — GfmcSDK
// calls this when the current one does.
GfmcSdk.setTokenRefresher(() => myAuth.freshMinicinemaJwt());

// Listen for lifecycle/purchase/error events (see "Events" below).
GfmcSdk.events.listen((event) {
  switch (event) {
    case GfmcHubClosedEvent():
      // user left the hub
      break;
    case GfmcErrorEvent(code: final code, message: final message):
      log('gfmc error: $code $message');
    default:
      break;
  }
});

// jwt is a minicinema session token from YOUR backend — not your app's own
// auth access token.
await GfmcSdk.open(jwt);
```

## Events

One broadcast `Stream<GfmcEvent>` (`GfmcSdk.events`) covers everything
`com.sltr.gfmc.GfmcSDKListener` reports natively — hub lifecycle, errors,
purchases, module switches, share requests, and SKU selection. This is
deliberately one stream rather than eight separate callback setters:
Dart 3's sealed-class `switch` gives you exhaustiveness checking across all
event kinds in one place, instead of an easy-to-forget native-side callback
per event type.

| Event | Mirrors | Fires when |
|---|---|---|
| `GfmcHubReadyEvent` | `onHubReady()` | hub finished loading |
| `GfmcHubClosedEvent` | `onHubClosed()` | hub closed |
| `GfmcErrorEvent` | `onError()` | see `GfmcError` for the code enum |
| `GfmcPurchaseCompletedEvent` | `onPurchaseCompleted()` | Play purchase settled |
| `GfmcPurchaseFailedEvent` | `onPurchaseFailed()` | Play purchase failed |
| `GfmcModuleChangedEvent` | `onModuleChanged()` | user switched hub module |
| `GfmcShareRequestedEvent` | `onShareRequested()` | see note below |
| `GfmcSkuSelectedEvent` | (SKU listener) | web asked to buy a SKU (informational) |

`GfmcShareRequestedEvent`: the native capsule menu's "Share" button was
**removed** in GfmcSDK 2.3.6 (see the `1.2.6` row in
[gfmc-sdk's version table](https://github.com/BDN-ID/gfmc-sdk#versioning)) —
the underlying event/listener callback still exists on the native side for
API compatibility, but nothing triggers it anymore today. Kept here for the
same reason.

## Native SDK version

```dart
final version = await GfmcSdk.getVersion();
print(version.artifactVersion); // Android: "1.2.6" Maven coordinate / iOS: "1.14.0" XCFramework release — what to log/show
print(version.name);            // internal SDK version, not partner-facing (differs per platform, same field)
```

Bump the native dependency deliberately with each native SDK release you
want to pick up — on both platforms it's pinned, not a floating range, so a
native-side release never silently changes this plugin's behavior
underneath a host app:

- Android: `android/build.gradle`'s `com.sltr.gfmc:gfmc-sdk` coordinate —
  see [gfmc-sdk's CHANGELOG](https://github.com/BDN-ID/gfmc-sdk#changelog).
- iOS: `ios/gfmc_flutter.podspec`'s `jessica_sdk_version`/
  `jessica_sdk_sha256` (take the checksum from the matching tag's own
  `Package.swift`, not from anywhere else) — see
  [gfmc-ios's releases](https://github.com/BDN-ID/gfmc-ios/releases).

---

## Known gaps

- **`closeMiniApp()` is a no-op on Android.** The native Android SDK doesn't
  expose a host-initiated "close the currently open hub" call — closing is
  driven from inside the hub itself (capsule button, back press). Filed as
  a gap, not silently hidden — see `GfmcFlutterPlugin.kt`'s comment. **On
  iOS it does work** — `JessicaSDK.open()` hands back the presented
  `JessicaHubViewController`, which this plugin dismisses.
- **`GfmcTokenProvider` (the synchronous refresh variant /
  `openWithTokenProvider` on Android) has no Flutter equivalent.** Platform
  channels are inherently async; forcing a synchronous native→Dart callback
  across that boundary isn't something Pigeon supports directly. Only the
  async `GfmcTokenRefresher` path (`setTokenRefresher` + `open`) is wired up
  — which covers the common case (a host backend call to refresh a token is
  itself always async anyway).
- **A handful of iOS-only `JessicaSDKConfig` knobs aren't exposed through
  `GfmcConfig` yet** — `isScreenCaptureProtected` (defaults to JessicaSDK's
  own default, `true`), `hubURLOverride`, `additionalAllowedHosts`,
  `isWebInspectionEnabled`. None have an Android counterpart today; add them
  to `pigeons/gfmc_api.dart`'s `GfmcConfigMessage` if a host app needs one.
- **iOS hasn't been built against a real Xcode toolchain** (no macOS/Xcode
  available in any environment that's touched this repo so far). All three
  generated files (`lib/src/messages.g.dart`,
  `android/.../Messages.g.kt`, `ios/Classes/Messages.g.swift`) are now real
  `dart run pigeon` output — confirmed by actually running it, not
  hand-written — and the Android side has been built for real (`flutter
  build apk` against the pinned `gfmc-sdk` Maven artifact compiles clean).
  Running codegen for real also caught a genuine bug: the schema originally
  named a method `init`, which Pigeon 22.7.4 emits unescaped as `func
  init(...)` in the generated Swift protocol — `init` is a reserved word in
  Swift, so that failed to compile. Renamed to `initialize` in
  `pigeons/gfmc_api.dart` throughout (the public `GfmcSdk.init()` Dart API
  is unaffected). What's still unverified: `pod install` + an actual Xcode
  build. Do that and fix up any compile errors before shipping iOS.

## In-app purchase products (SKUs)

The hub's purchase flow (`GfmcSkuSelectedEvent`, `GfmcPurchaseCompletedEvent`
etc. — see "Events" above) drives Google Play Billing / StoreKit directly.
Neither store knows about a SKU until a matching in-app product is created
for it by hand — **this plugin can't do that part**. Before purchases work
on a given build, create one in-app product per SKU below, using the exact
string as the product ID (case included), in both:

- **Google Play Console** → your app → Monetize → Products → In-app products
- **App Store Connect** → your app → Monetize → In-App Purchases

**SKUs (required, must match exactly):**

- `1000p`
- `1500p`
- `2000p`
- `3000p`
- `4000p`
- `5000p`
- `10000p`
- `100000P` — note the capital `P`, unlike the rest; that's the backend's
  actual data, not a typo here, and the store-side product ID has to match
  it exactly.

Everything else about each product — display name, price, discount — is
set independently per store (Play Console / App Store Connect handle their
own pricing and localization) and optional to mirror. For reference, the
backend's own catalog values at the time of writing:

| SKU | Name | Points | Price (IDR) | Discounted price |
|---|---|---:|---:|---:|
| `1000p` | 1000 Point | 1,000 | 10,000 | 9,000 (10%) |
| `1500p` | JKT Point | 1,500 | 15,000 | — |
| `2000p` | 2000 Point | 2,000 | 19,900 | 9,950 (50%) |
| `3000p` | 3000 Point | 3,000 | 28,800 | — |
| `4000p` | 4000 Point | 4,000 | 37,700 | — |
| `5000p` | 5000 Point | 5,000 | 46,600 | — |
| `10000p` | 10000 | 10,000 | 100,000 | 80,000 (20%) |
| `100000P` | 100000 Point | 100,000 | 200,000 | 190,000 (5%) |

## Repo layout

```
pigeons/gfmc_api.dart         Pigeon schema — the actual source of truth
lib/gfmc_flutter.dart         public API (barrel export)
lib/src/                      public API implementation + generated glue
android/                      the plugin's Android library module
ios/                          the plugin's iOS library module (podspec + Classes/)
example/                      minimal demo app (run `flutter create .`
                               inside example/ first to regenerate its
                               platform folders — those aren't checked in)
```

Preparing `example/` for a real Play Store upload (signing, applicationId,
Windows-specific build workarounds) is documented separately in
[`PLAYSTORE.md`](PLAYSTORE.md) rather than here, since it only applies to
that gitignored, regenerable app shell.

## Changelog

Full history in [`CHANGELOG.md`](CHANGELOG.md). Each entry there corresponds
1:1 with a git tag on this repo (see "Package versioning" above) — pin
`pubspec.yaml`'s `ref:` to the tag matching the entry you want.

- **0.2.0** (`v0.2.0`) — adds iOS, wrapping `gfmc-ios`
  (`JessicaSDK.xcframework`) `1.14.0`. Same Dart API as 0.1.0 now works on
  both platforms; see "Known gaps" above for the handful of things that
  still differ between them.
- **0.1.0** (`v0.1.0`) — initial version. Wraps `gfmc-sdk 1.2.6` (GfmcSDK
  2.3.6). `GfmcSdk.init`/`.open`/`.getVersion`/`.getConfig`,
  `setTokenRefresher`, and a unified `Stream<GfmcEvent>` for hub lifecycle/
  errors/purchases/module changes/share requests/SKU selection. Android
  only.
