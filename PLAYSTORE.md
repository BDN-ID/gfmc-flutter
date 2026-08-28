# Preparing the example app for a Play Store release

`example/android/` is gitignored (see README's "Repo layout") — regenerated
locally via `flutter create .` inside `example/`, never committed. That
means every change below is **local to whoever's machine builds the
release** and has to be reapplied after any `flutter create .` regen. This
doc is the reapply checklist.

## 1. Application identity (permanent — can't change post-publish)

In `example/android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "id.bdn.jessica.flutter.dummyhost"
    defaultConfig {
        applicationId = "id.bdn.jessica.flutter.dummyhost"
        ...
```

**Also move `MainActivity.kt`.** Changing `namespace`/`applicationId` alone
does NOT move the actual Kotlin source — it still compiles under whatever
package its `package` statement declares, so the manifest's `.MainActivity`
resolves to `<new applicationId>.MainActivity` while the real class sits
under the old package, and the app crashes on launch with
`ClassNotFoundException`. Move the file and fix its `package` line to
match:

```sh
# from example/
mkdir -p android/app/src/main/kotlin/id/bdn/jessica/flutter/dummyhost
# move MainActivity.kt there, update its `package id.bdn.jessica.flutter.dummyhost` line,
# then delete the old now-empty package directory tree.
```

Confirmed by actually installing and launching on a physical device
(V2111) — this crashed before the move, ran clean after.

In `example/android/app/src/main/AndroidManifest.xml`, `<application
android:label="...">` — set to whatever the Play listing's app name should
be (currently "GFMC Dummy Host").

`example/pubspec.yaml`'s `version:` drives `versionName`/`versionCode`
(`versionName+versionCode`, e.g. `1.0.0+1`). Bump the `+N` on every release
you upload — Play Console rejects a re-upload with a versionCode it's
already seen.

## 2. Release signing

Generated once with:

```sh
keytool -genkeypair -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias dummyhost \
  -dname "CN=BDN, OU=Engineering, O=BDN, L=Jakarta, ST=DKI Jakarta, C=ID"
```

Note: modern `keytool` creates a PKCS12 keystore, which requires
store password == key password (it silently ignores a different
`-keypass`) — don't set them differently in `key.properties`.

`example/android/key.properties` (gitignored, alongside the `.jks` — see
`example/android/.gitignore`):

```properties
storePassword=<...>
keyPassword=<...>
keyAlias=dummyhost
storeFile=upload-keystore.jks
```

`build.gradle.kts` loads this file and wires a `release` signing config; if
`key.properties` is absent it silently falls back to the debug key (so
`flutter build apk --release` still works without it, but that build is
**not** upload-suitable). See the file's comments for the exact snippet —
it's already applied on this machine.

**The keystore + key.properties only exist locally right now.** Back both
up somewhere durable (password manager / secure storage) immediately —
losing them means losing the ability to ever ship an update to this same
Play Store listing again. Nothing about this can be recovered or reissued
by Google.

## 3. Windows-specific build workarounds

Both caused by this machine's paths containing spaces
(`C:\Users\<name with a space>\...`) — `flutter doctor`'s Android toolchain
check already flags this. Proper fix is moving the Android SDK (and
ideally not having a space in the Windows user profile path at all) to a
space-free path; these are workarounds until then.

- `example/android/gradle.properties`: `kotlin.incremental=false` — without
  it, `compileReleaseKotlin` throws `IllegalArgumentException: this and
  base files have different roots` when the plugin's pub-cache checkout
  (`C:\Users\...\Pub\Cache\git\...`) and the project are on different
  drives.
- `example/android/app/build.gradle.kts`'s `defaultConfig.ndk.debugSymbolLevel
  = "none"` — without it, `bundleRelease`'s native-symbol-stripping step
  fails outright.
- Even with both of the above, `flutter build appbundle --release` reports
  overall failure at a *separate*, later step: extracting native debug
  symbols into the bundle's `native-debug-symbols.zip` shells out to `java`
  without quoting a path containing a space, so it errors with `Could not
  find or load main class Wiradhika` (or whatever word follows the space in
  your path) and reports the whole build as failed. **The `.aab` itself is
  already written and correctly signed by that point** — verified locally
  with `jarsigner -verify` (`jar verified`, signed by the `dummyhost`
  alias). This only costs you the optional native-crash-symbolication file
  Play Console can use; it does not affect publishability. Confirm the
  artifact exists at
  `example/build/app/outputs/bundle/release/app-release.aab` before
  concluding a build actually failed.

## 4. What's still manual (Play Console, not this repo)

- **App icon** — still the default Flutter logo. Replace
  `example/android/app/src/main/res/mipmap-*/ic_launcher.png` (or regenerate
  via `flutter_launcher_icons`) with real artwork before submitting; Play
  review can reject a listing that looks unfinished.
- **Privacy policy URL** — required by Play Console for any app requesting
  login/network access. Needs a real, hosted policy; not something to
  fabricate here.
- **Content rating questionnaire, Data safety form, target audience,
  store listing copy/screenshots** — all filled in through Play Console
  directly.
- **Release track** — given this app currently talks to
  `jessica-dummy-api.bdn.id` (an explicitly-named throwaway/sandbox
  backend, not production) and has no real end-user login flow of its own,
  upload it to **Internal testing** or **Closed testing** first, not
  Production. Swap in a production auth backend and `GfmcEnv.production`
  before any public release.

## 5. Build commands

```sh
cd example
flutter build appbundle --release   # for Play Console upload
flutter build apk --release         # for sideloading / manual QA
```
