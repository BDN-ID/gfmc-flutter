/// Flutter plugin for GfmcSDK — embeds the minicinema mini-program
/// (streaming, entitlements, Google Play top-ups) inside a Flutter app's
/// Android target.
///
/// See the package README for setup and jessica-sdk-android's own README
/// for what each concept means on the native side this wraps.
library gfmc_flutter;

export 'src/gfmc_config.dart';
export 'src/gfmc_enums.dart';
export 'src/gfmc_events.dart';
export 'src/gfmc_sdk.dart' show GfmcSdk, GfmcTokenRefresher;
export 'src/gfmc_version.dart';
