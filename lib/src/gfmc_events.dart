import 'gfmc_enums.dart';

/// Base type for everything delivered on [GfmcSdk.events]. Switch on the
/// runtime type (or use a `switch` pattern in Dart 3) to handle each kind —
/// mirrors `com.sltr.gfmc.GfmcSDKListener`'s callbacks 1:1.
sealed class GfmcEvent {
  const GfmcEvent();
}

/// The hub finished loading and is showing content.
class GfmcHubReadyEvent extends GfmcEvent {
  const GfmcHubReadyEvent();
}

/// The hub was closed (user tapped the capsule's close button, pressed
/// back at the root, or the host itself asked GfmcSDK to close it).
class GfmcHubClosedEvent extends GfmcEvent {
  const GfmcHubClosedEvent();
}

class GfmcErrorEvent extends GfmcEvent {
  const GfmcErrorEvent(this.code, this.message);
  final GfmcError code;
  final String message;
}

/// A Google Play purchase settled successfully. The web side calls its own
/// backend's top-up endpoint after this fires — this event is informational
/// on the Flutter side, not something you need to act on to complete the
/// purchase.
class GfmcPurchaseCompletedEvent extends GfmcEvent {
  const GfmcPurchaseCompletedEvent(this.sku, this.txId);
  final String sku;
  final String txId;
}

class GfmcPurchaseFailedEvent extends GfmcEvent {
  const GfmcPurchaseFailedEvent(this.reason);
  final String reason;
}

class GfmcModuleChangedEvent extends GfmcEvent {
  const GfmcModuleChangedEvent(this.module);
  final GfmcModule module;
}

class GfmcShareRequestedEvent extends GfmcEvent {
  const GfmcShareRequestedEvent(this.url, this.title);
  final String url;
  final String title;
}

/// Informational: the web asked the user to buy [sku]. Does not gate the
/// Google Play billing flow, which runs natively regardless.
class GfmcSkuSelectedEvent extends GfmcEvent {
  const GfmcSkuSelectedEvent(this.sku);
  final String sku;
}
