/// Mirrors `com.sltr.gfmc.GfmcSDKVersion`.
class GfmcVersion {
  const GfmcVersion({
    required this.name,
    required this.versionCode,
    required this.artifactVersion,
    required this.displayName,
  });

  /// Internal SDK semantic version, e.g. `"2.3.6"`. Not what a partner
  /// recognizes — see [artifactVersion].
  final String name;
  final int versionCode;

  /// The Maven coordinate this plugin's `android/build.gradle` pins, e.g.
  /// `"1.2.6"` — the number to show or log. Matches what
  /// `GfmcSDK.getArtifactVersion()`/the `GET_APP_VERSION` web bridge action
  /// report on the native side.
  final String artifactVersion;
  final String displayName;

  @override
  String toString() =>
      'GfmcVersion(name: $name, versionCode: $versionCode, '
      'artifactVersion: $artifactVersion)';
}
