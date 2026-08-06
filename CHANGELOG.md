# Changelog

## 0.1.0

Initial version. Wraps `com.sltr.gfmc:gfmc-sdk:1.2.6` (GfmcSDK 2.3.6).

- `GfmcSdk.init` / `.open` / `.getVersion` / `.getConfig`
- `GfmcSdk.setTokenRefresher` for the async JWT-refresh flow
- `GfmcSdk.events` — unified `Stream<GfmcEvent>` covering hub lifecycle,
  errors, purchases, module changes, share requests, SKU selection
- Android only. No `ios/` platform folder yet — see README's "Known gaps".
- Pigeon-generated platform-channel glue was hand-written (no Dart/Flutter
  SDK available when this was authored) — regenerate and diff before
  trusting it; see README's warning banner.
