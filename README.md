# gfmc_flutter

Flutter plugin wrapping [GfmcSDK](https://github.com/BDN-ID/gfmc-sdk) — the
minicinema mini-program SDK. Embeds streaming, entitlements and Google Play
top-ups inside your Flutter app's Android target as a self-contained hub,
without hand-rolling a `MethodChannel` yourself.

**Native SDK version pinned by this plugin:** `com.sltr.gfmc:gfmc-sdk:1.2.6`
(GfmcSDK `2.3.6`) — set in `android/build.gradle`'s `dependencies` block.
That's the only place it's declared; check that file directly if this README
ever drifts out of sync with it. See
[gfmc-sdk's own README](https://github.com/BDN-ID/gfmc-sdk#changelog) for
what each native version actually changed before bumping it here.

**Android only for now.** The GfmcSDK team's iOS SDK lives in a separate,
not-yet-integrated repo — this plugin's `ios/` platform folder doesn't exist
yet. Calling anything here from an iOS build target will fail at the
`MissingPluginException` level, not silently no-op.

---

## Install

Not published to pub.dev — add it as a git dependency:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter:
    git:
      url: https://github.com/BDN-ID/gfmc-flutter.git
      ref: v0.1.0
```

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
**removed** in GfmcSDK 2.3.6 (see jessica-sdk-android's CHANGELOG.md) — the
underlying event/listener callback still exists on the native side for API
compatibility, but nothing triggers it anymore today. Kept here for the same
reason.

## Versioning

```dart
final version = await GfmcSdk.getVersion();
print(version.artifactVersion); // "1.2.6" — the Maven coordinate, what to log/show
print(version.name);            // "2.3.6" — internal SDK version, not partner-facing
```

Bump `android/build.gradle`'s `com.sltr.gfmc:gfmc-sdk` dependency
deliberately with each `jessica-sdk-android` release you want to pick up —
it's pinned, not a floating range, so a native-side release never silently
changes this plugin's behavior underneath a host app. Check
[gfmc-sdk's CHANGELOG](https://github.com/BDN-ID/gfmc-sdk#changelog) for
what changed before bumping.

---

## Known gaps

- **iOS is not implemented.** No `ios/` folder exists. Needs the iOS
  GfmcSDK's actual API surface before it can be built — this repo doesn't
  have visibility into that SDK.
- **`closeMiniApp()` is a no-op today.** The native Android SDK doesn't
  expose a host-initiated "close the currently open hub" call — closing is
  driven from inside the hub itself (capsule button, back press). Filed as
  a gap, not silently hidden — see `GfmcFlutterPlugin.closeMiniApp()`'s
  comment.
- **`GfmcTokenProvider` (the synchronous refresh variant /
  `openWithTokenProvider` on Android) has no Flutter equivalent.** Platform
  channels are inherently async; forcing a synchronous native→Dart callback
  across that boundary isn't something Pigeon supports directly. Only the
  async `GfmcTokenRefresher` path (`setTokenRefresher` + `open`) is wired up
  — which covers the common case (a host backend call to refresh a token is
  itself always async anyway).
## Repo layout

```
pigeons/gfmc_api.dart         Pigeon schema — the actual source of truth
lib/gfmc_flutter.dart         public API (barrel export)
lib/src/                      public API implementation + generated glue
android/                      the plugin's Android library module
example/                      minimal demo app (run `flutter create .`
                               inside example/ first to regenerate its
                               platform folders — those aren't checked in)
```

## Changelog

Full history in [`CHANGELOG.md`](CHANGELOG.md).

- **0.1.0** — initial version. Wraps `gfmc-sdk 1.2.6` (GfmcSDK 2.3.6).
  `GfmcSdk.init`/`.open`/`.getVersion`/`.getConfig`, `setTokenRefresher`,
  and a unified `Stream<GfmcEvent>` for hub lifecycle/errors/purchases/
  module changes/share requests/SKU selection. Android only — see "Known
  gaps" above.
