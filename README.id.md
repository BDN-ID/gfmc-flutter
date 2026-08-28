# gfmc_flutter

[![pub package](https://img.shields.io/pub/v/gfmc_flutter.svg)](https://pub.dev/packages/gfmc_flutter)

*Read this in other languages: [English](README.md).*

Plugin Flutter pembungkus GfmcSDK — SDK mini-program minicinema. Menanamkan
streaming, entitlement, dan top-up ke dalam target Android dan iOS aplikasi
Flutter-mu sebagai hub mandiri, tanpa perlu bikin `MethodChannel` sendiri.

**Versi native SDK yang dipin plugin ini:**

| Platform | Package native | Versi | Dideklarasikan di |
|---|---|---|---|
| Android | [`gfmc-sdk`](https://github.com/BDN-ID/gfmc-sdk) `com.sltr.gfmc:gfmc-sdk:1.2.6` | GfmcSDK `2.3.6` | blok `dependencies` di `android/build.gradle` |
| iOS | [`gfmc-ios`](https://github.com/BDN-ID/gfmc-ios) `JessicaSDK.xcframework` | `1.14.0` | `jessica_sdk_version`/`jessica_sdk_sha256` di `ios/gfmc_flutter.podspec` |

File-file itu satu-satunya tempat masing-masing dideklarasikan; cek langsung
kalau README ini pernah drift gak sinkron. Lihat README masing-masing repo
native buat tau apa yang berubah di tiap versi sebelum bump versi di sini.

---

## Install

Udah dipublish ke pub.dev — cara biasa:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter: ^0.2.0
```

atau:

```sh
flutter pub add gfmc_flutter
```

Mau pin ke git tag persis (misal buat ngikutin `main` pas development,
atau sengaja lewat pub.dev)? Repo yang sama, tinggal pilih cara:

```yaml
# pubspec.yaml
dependencies:
  gfmc_flutter:
    git:
      url: https://github.com/BDN-ID/gfmc-flutter.git
      ref: v0.2.0
```

### Versioning package

Ikut semver (`MAJOR.MINOR.PATCH`). Di pub.dev, constraint gaya `^0.2.0`
resolve dan upgrade cara biasa (`flutter pub upgrade`). Kalau pakai `ref:`
git:

- **Pin ke tag** (`ref: v0.2.0`), jangan `main`/`master` — kalau pakai ref
  branch, build-mu diam-diam ambil apa pun yang terbaru di situ, termasuk
  commit work-in-progress yang belum dirilis.
- **Upgrade manual.** Gak ada `pub upgrade` yang otomatis resolve ke "versi
  kompatibel terbaru" buat git dependency — ganti `ref:`-nya sendiri terus
  jalanin ulang `flutter pub get`.

Kedua cara — **cek [`CHANGELOG.md`](CHANGELOG.md) sebelum bump** — disiplin
yang sama kayak bump koordinat native `gfmc-sdk` (lihat "Versi native SDK"
di bawah). Tiap versi di sini berkorespondensi 1:1 sama git tag dan entry
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

### Podfile / target minimum iOS

Gak ada yang perlu ditambah ke `Podfile`-mu — `pod install` otomatis pakai
podspec plugin ini. Dua hal yang perlu diketahui:

- **`JessicaSDK.xcframework` diambil saat `pod install`**, bukan di-commit
  ke repo ini. `prepare_command` di `ios/gfmc_flutter.podspec` mengunduh
  rilis persis yang di-tag di
  [gfmc-ios](https://github.com/BDN-ID/gfmc-ios), verifikasi SHA-256-nya
  terhadap checksum yang dipin di sebelahnya, baru vendor masuk. `pod
  install` pertama setelah nambah plugin ini butuh akses jaringan ke
  `github.com`; kalau checksum-nya gak cocok, build gagal dengan jelas
  ketimbang vendor sesuatu yang gak terverifikasi.
- **Target deployment minimum iOS 15** (floor bawaan JessicaSDK sendiri) —
  podspec plugin ini set `s.platform = :ios, '15.0'`, jadi `ios/Podfile`
  aplikasimu juga butuh `platform :ios, '15.0'` (atau lebih tinggi), kalau
  enggak CocoaPods bakal gagal resolve.

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
print(version.artifactVersion); // Android: "1.2.6" koordinat Maven / iOS: "1.14.0" rilis XCFramework — yang dicatat/ditampilkan
print(version.name);            // versi internal SDK, bukan untuk partner (beda per platform, field sama)
```

Bump dependency native secara sengaja tiap kali mau ambil rilis SDK native
baru — di kedua platform itu pinned, bukan range mengambang, jadi rilis di
sisi native gak pernah diam-diam mengubah perilaku plugin ini di bawah
aplikasi host:

- Android: koordinat `com.sltr.gfmc:gfmc-sdk` di `android/build.gradle` —
  lihat [CHANGELOG gfmc-sdk](https://github.com/BDN-ID/gfmc-sdk#changelog).
- iOS: `jessica_sdk_version`/`jessica_sdk_sha256` di
  `ios/gfmc_flutter.podspec` (ambil checksum dari `Package.swift` di tag
  yang sesuai, jangan dari tempat lain) — lihat
  [rilis gfmc-ios](https://github.com/BDN-ID/gfmc-ios/releases).

---

## Known gaps (celah yang diketahui)

- **`closeMiniApp()` masih no-op di Android.** SDK Android native gak
  expose panggilan "tutup hub yang sedang terbuka" yang dipicu dari host
  — penutupan didorong dari dalam hub itu sendiri (tombol capsule, tombol
  back). Dicatat sebagai celah, bukan disembunyikan — lihat komentar
  `GfmcFlutterPlugin.kt`. **Di iOS ini beneran jalan** — `JessicaSDK.open()`
  ngembaliin `JessicaHubViewController` yang lagi ditampilkan, dan plugin
  ini yang dismiss.
- **`GfmcTokenProvider`** (varian refresh sinkron / `openWithTokenProvider`
  di Android) **gak punya padanan di Flutter.** Platform channel itu
  inherently async; memaksakan callback sinkron native→Dart lintas batas
  itu bukan sesuatu yang didukung Pigeon secara langsung. Cuma jalur async
  `GfmcTokenRefresher` (`setTokenRefresher` + `open`) yang tersambung —
  yang sudah mencakup kasus umum (panggilan ke backend host buat refresh
  token itu sendiri selalu async juga).
- **Beberapa opsi `JessicaSDKConfig` khusus iOS belum di-expose lewat
  `GfmcConfig`** — `isScreenCaptureProtected` (pakai default JessicaSDK
  sendiri, `true`), `hubURLOverride`, `additionalAllowedHosts`,
  `isWebInspectionEnabled`. Gak ada satu pun yang punya padanan di Android
  hari ini; tambahkan ke `GfmcConfigMessage` di `pigeons/gfmc_api.dart` kalau
  ada aplikasi host yang butuh salah satunya.
- **iOS belum pernah dibuild di toolchain Xcode beneran** (gak ada
  macOS/Xcode di environment mana pun yang megang repo ini sejauh ini).
  Ketiga file hasil generate (`lib/src/messages.g.dart`,
  `android/.../Messages.g.kt`, `ios/Classes/Messages.g.swift`) sekarang
  output asli `dart run pigeon` — sudah dijalankan beneran, bukan ditulis
  tangan lagi — dan sisi Android sudah dibuild beneran (`flutter build apk`
  ke artifact Maven `gfmc-sdk` yang di-pin, compile bersih). Jalanin codegen
  beneran juga nemu bug asli: schema-nya tadinya kasih nama method `init`,
  yang di Pigeon 22.7.4 di-emit tanpa escape jadi `func init(...)` di
  protocol Swift hasil generate — `init` itu reserved word di Swift, jadi
  gagal compile. Sudah diganti nama jadi `initialize` di
  `pigeons/gfmc_api.dart` (API publik `GfmcSdk.init()` di Dart gak
  kepengaruh). Yang masih belum diverifikasi: `pod install` + build Xcode
  beneran. Lakuin itu dan perbaiki error compile apa pun sebelum ship iOS.

## Produk in-app purchase (SKU)

Alur pembelian hub (`GfmcSkuSelectedEvent`, `GfmcPurchaseCompletedEvent`,
dll — lihat "Events" di atas) langsung nge-drive Google Play Billing /
StoreKit. Kedua store gak bakal kenal SKU sampai produk in-app-nya dibikin
manual — **ini bagian yang gak bisa dilakuin plugin ini**. Sebelum
pembelian bisa jalan di suatu build, bikin satu produk in-app per SKU di
bawah, pakai string persis sebagai product ID (termasuk huruf besar/kecil),
di kedua tempat:

- **Google Play Console** → app kamu → Monetize → Products → In-app products
- **App Store Connect** → app kamu → Monetize → In-App Purchases

**SKU (wajib, harus persis sama):**

- `1000p`
- `1500p`
- `2000p`
- `3000p`
- `4000p`
- `5000p`
- `10000p`
- `100000P` — perhatiin huruf `P` besar, beda dari yang lain; itu emang data
  asli dari backend, bukan typo di sini, dan product ID di sisi store harus
  persis sama termasuk huruf besarnya.

Hal lain di tiap produk — nama tampilan, harga, diskon — diatur terpisah
per store (Play Console / App Store Connect punya harga & lokalisasi
sendiri-sendiri) dan opsional buat disamain. Buat referensi, nilai katalog
backend pas ditulis:

| SKU | Nama | Point | Harga (IDR) | Harga diskon |
|---|---|---:|---:|---:|
| `1000p` | 1000 Point | 1.000 | 10.000 | 9.000 (10%) |
| `1500p` | JKT Point | 1.500 | 15.000 | — |
| `2000p` | 2000 Point | 2.000 | 19.900 | 9.950 (50%) |
| `3000p` | 3000 Point | 3.000 | 28.800 | — |
| `4000p` | 4000 Point | 4.000 | 37.700 | — |
| `5000p` | 5000 Point | 5.000 | 46.600 | — |
| `10000p` | 10000 | 10.000 | 100.000 | 80.000 (20%) |
| `100000P` | 100000 Point | 100.000 | 200.000 | 190.000 (5%) |

## Struktur repo

```
pigeons/gfmc_api.dart         Skema Pigeon — sumber kebenaran sebenarnya
lib/gfmc_flutter.dart         API publik (barrel export)
lib/src/                      implementasi API publik + glue hasil generate
android/                      modul library Android plugin ini
ios/                          modul library iOS plugin ini (podspec + Classes/)
example/                      aplikasi demo minimal (jalankan `flutter create .`
                               di dalam example/ dulu buat regenerate folder
                               platform-nya — itu gak di-commit)
```

## Changelog

Riwayat lengkap di [`CHANGELOG.md`](CHANGELOG.md). Tiap entry di situ
berkorespondensi 1:1 dengan satu git tag di repo ini (lihat "Versioning
package" di atas) — pin `ref:` di `pubspec.yaml` ke tag yang sesuai dengan
entry yang kamu mau.

- **0.2.0** (`v0.2.0`) — nambah iOS, membungkus `gfmc-ios`
  (`JessicaSDK.xcframework`) `1.14.0`. API Dart-nya sama kayak 0.1.0,
  sekarang jalan di kedua platform; lihat "Known gaps" di atas buat beberapa
  hal yang masih beda antara keduanya.
- **0.1.0** (`v0.1.0`) — versi awal. Membungkus `gfmc-sdk 1.2.6` (GfmcSDK
  2.3.6). `GfmcSdk.init`/`.open`/`.getVersion`/`.getConfig`,
  `setTokenRefresher`, dan `Stream<GfmcEvent>` terpadu untuk lifecycle
  hub/error/purchase/perubahan module/permintaan share/pemilihan SKU.
  Android saja.
