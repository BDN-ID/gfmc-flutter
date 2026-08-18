# gfmc_flutter

*Read this in other languages: [English](README.md).*

Plugin Flutter pembungkus [GfmcSDK](https://github.com/BDN-ID/gfmc-sdk) — SDK
mini-program minicinema. Menanamkan streaming, entitlement, dan top-up Google
Play ke dalam target Android aplikasi Flutter-mu sebagai hub mandiri, tanpa
perlu bikin `MethodChannel` sendiri.

**Versi native SDK yang dipin plugin ini:** `com.sltr.gfmc:gfmc-sdk:1.2.6`
(GfmcSDK `2.3.6`) — diset di blok `dependencies` pada `android/build.gradle`.
Itu satu-satunya tempat versi ini dideklarasikan; cek file itu langsung kalau
README ini pernah drift gak sinkron dengannya. Lihat
[README gfmc-sdk sendiri](https://github.com/BDN-ID/gfmc-sdk#changelog) buat
tau apa yang berubah di tiap versi native sebelum bump versi di sini.

**Android saja untuk sekarang.** SDK iOS dari tim GfmcSDK ada di repo
terpisah yang belum terintegrasi — folder platform `ios/` plugin ini belum
ada. Manggil apa pun dari sini di target build iOS akan gagal di level
`MissingPluginException`, bukan diam-diam no-op.

---

## Install

Belum dipublish ke pub.dev — tambahkan sebagai git dependency:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter:
    git:
      url: https://github.com/BDN-ID/gfmc-flutter.git
      ref: v0.1.0
```

### Versioning package

Package ini ikut semver (`MAJOR.MINOR.PATCH`), tapi didistribusikan lewat
git tag repo ini, bukan pub.dev — jadi `pubspec.yaml` cuma bisa pin satu
`ref` pasti, bukan range gaya `^0.1.0`:

- **Pin ke tag** (`ref: v0.1.0`), jangan `main`/`master` — kalau pakai ref
  branch, build-mu diam-diam ambil apa pun yang terbaru di situ, termasuk
  commit work-in-progress yang belum dirilis.
- **Upgrade manual.** Gak ada `pub upgrade` yang otomatis resolve ke "versi
  kompatibel terbaru" kayak package pub.dev — ganti `ref:`-nya sendiri terus
  jalanin ulang `flutter pub get`.
- **Cek [`CHANGELOG.md`](CHANGELOG.md) sebelum bump** — disiplin yang sama
  kayak bump koordinat native `gfmc-sdk` (lihat "Versi native SDK" di
  bawah). Tiap tag di sini berkorespondensi 1:1 dengan satu entry
  `CHANGELOG.md`.

### Repository Gradle

Artifact Android GfmcSDK didistribusikan dari static Maven tree tanpa token
(lihat README [gfmc-sdk](https://github.com/BDN-ID/gfmc-sdk) sendiri), dan
`android/build.gradle` plugin ini sudah mendeklarasikannya lewat
`rootProject.allprojects`. **Kalau `android/settings.gradle.kts` aplikasimu
set `repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)`**
(default untuk aplikasi yang dibuat dari template Flutter/AGP terbaru), mode
itu melarang deklarasi repository per-project — termasuk yang ditambahkan
`build.gradle` plugin ini sendiri — dan Gradle bakal gagal resolve
`com.sltr.gfmc:gfmc-sdk` walau plugin ini sudah mendeklarasikan repo-nya.
Tambahkan ke `settings.gradle.kts` aplikasimu sendiri:

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

Kalau setup Gradle aplikasimu gak pakai `FAIL_ON_PROJECT_REPOS`, deklarasi
dari plugin ini sudah cukup dan kamu bisa skip ini — tapi menambahkannya
secara eksplisit gak ada ruginya dan menghilangkan ambiguitas.

### AndroidManifest

Gak ada yang perlu ditambah — `INTERNET`, `ACCESS_NETWORK_STATE`,
`com.android.vending.BILLING`, dan Activity/service milik hub otomatis
merge dari AAR `gfmc-sdk`, sama seperti untuk host Android native.

---

## Quick start

```dart
import 'package:gfmc_flutter/gfmc_flutter.dart';

// Sekali saja, misal di startup aplikasi:
await GfmcSdk.init(
  config: const GfmcConfig(environment: GfmcEnv.sandbox), // production kalau udah siap rilis
);

// Daftarkan sebelum open() kalau JWT-mu bisa expire di tengah sesi — GfmcSDK
// manggil ini saat yang sekarang expire.
GfmcSdk.setTokenRefresher(() => myAuth.freshMinicinemaJwt());

// Dengerin event lifecycle/purchase/error (lihat "Events" di bawah).
GfmcSdk.events.listen((event) {
  switch (event) {
    case GfmcHubClosedEvent():
      // user keluar dari hub
      break;
    case GfmcErrorEvent(code: final code, message: final message):
      log('gfmc error: $code $message');
    default:
      break;
  }
});

// jwt adalah session token minicinema dari backend KAMU — bukan access
// token auth aplikasimu sendiri.
await GfmcSdk.open(jwt);
```

## Events

Satu broadcast `Stream<GfmcEvent>` (`GfmcSdk.events`) mencakup semua yang
dilaporkan `com.sltr.gfmc.GfmcSDKListener` secara native — lifecycle hub,
error, purchase, ganti module, permintaan share, dan pemilihan SKU. Ini
sengaja dibuat satu stream, bukan delapan setter callback terpisah:
`switch` sealed-class Dart 3 kasih exhaustiveness checking di semua jenis
event dalam satu tempat, ketimbang callback native per jenis event yang
gampang kelupaan.

| Event | Mencerminkan | Terpicu saat |
|---|---|---|
| `GfmcHubReadyEvent` | `onHubReady()` | hub selesai loading |
| `GfmcHubClosedEvent` | `onHubClosed()` | hub ditutup |
| `GfmcErrorEvent` | `onError()` | lihat `GfmcError` untuk enum kodenya |
| `GfmcPurchaseCompletedEvent` | `onPurchaseCompleted()` | pembelian Play settled |
| `GfmcPurchaseFailedEvent` | `onPurchaseFailed()` | pembelian Play gagal |
| `GfmcModuleChangedEvent` | `onModuleChanged()` | user ganti module hub |
| `GfmcShareRequestedEvent` | `onShareRequested()` | lihat catatan di bawah |
| `GfmcSkuSelectedEvent` | (SKU listener) | web minta beli SKU (informational) |

`GfmcShareRequestedEvent`: tombol "Share" di menu capsule native
**dihapus** di GfmcSDK 2.3.6 (lihat baris `1.2.6` di
[tabel versi gfmc-sdk](https://github.com/BDN-ID/gfmc-sdk#versioning)) —
callback event/listener-nya masih ada di sisi native demi kompatibilitas
API, tapi gak ada lagi yang memicunya sekarang. Tetap dipertahankan di sini
dengan alasan yang sama.

## Versi native SDK

```dart
final version = await GfmcSdk.getVersion();
print(version.artifactVersion); // "1.2.6" — koordinat Maven, yang dicatat/ditampilkan
print(version.name);            // "2.3.6" — versi internal SDK, bukan untuk partner
```

Bump dependency `com.sltr.gfmc:gfmc-sdk` di `android/build.gradle` secara
sengaja tiap kali mau ambil rilis `jessica-sdk-android` baru — itu pinned,
bukan range mengambang, jadi rilis di sisi native gak pernah diam-diam
mengubah perilaku plugin ini di bawah aplikasi host. Cek
[CHANGELOG gfmc-sdk](https://github.com/BDN-ID/gfmc-sdk#changelog) buat tau
apa yang berubah sebelum bump.

---

## Known gaps (celah yang diketahui)

- **iOS belum diimplementasikan.** Folder `ios/` belum ada. Butuh API
  surface SDK iOS yang sebenarnya dulu sebelum bisa dibangun — repo ini
  gak punya visibilitas ke SDK itu.
- **`closeMiniApp()` masih no-op hari ini.** SDK Android native gak
  expose panggilan "tutup hub yang sedang terbuka" yang dipicu dari host
  — penutupan didorong dari dalam hub itu sendiri (tombol capsule, tombol
  back). Dicatat sebagai celah, bukan disembunyikan — lihat komentar
  `GfmcFlutterPlugin.closeMiniApp()`.
- **`GfmcTokenProvider`** (varian refresh sinkron / `openWithTokenProvider`
  di Android) **gak punya padanan di Flutter.** Platform channel itu
  inherently async; memaksakan callback sinkron native→Dart lintas batas
  itu bukan sesuatu yang didukung Pigeon secara langsung. Cuma jalur async
  `GfmcTokenRefresher` (`setTokenRefresher` + `open`) yang tersambung —
  yang sudah mencakup kasus umum (panggilan ke backend host buat refresh
  token itu sendiri selalu async juga).

## Struktur repo

```
pigeons/gfmc_api.dart         Skema Pigeon — sumber kebenaran sebenarnya
lib/gfmc_flutter.dart         API publik (barrel export)
lib/src/                      implementasi API publik + glue hasil generate
android/                      modul library Android plugin ini
example/                      aplikasi demo minimal (jalankan `flutter create .`
                               di dalam example/ dulu buat regenerate folder
                               platform-nya — itu gak di-commit)
```

## Changelog

Riwayat lengkap di [`CHANGELOG.md`](CHANGELOG.md). Tiap entry di situ
berkorespondensi 1:1 dengan satu git tag di repo ini (lihat "Versioning
package" di atas) — pin `ref:` di `pubspec.yaml` ke tag yang sesuai dengan
entry yang kamu mau.

- **0.1.0** (`v0.1.0`) — versi awal. Membungkus `gfmc-sdk 1.2.6` (GfmcSDK
  2.3.6). `GfmcSdk.init`/`.open`/`.getVersion`/`.getConfig`,
  `setTokenRefresher`, dan `Stream<GfmcEvent>` terpadu untuk lifecycle
  hub/error/purchase/perubahan module/permintaan share/pemilihan SKU.
  Android saja — lihat "Known gaps" di atas.
