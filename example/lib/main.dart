import 'package:flutter/material.dart';
import 'package:gfmc_flutter/gfmc_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HubDemoPage());
  }
}

class HubDemoPage extends StatefulWidget {
  const HubDemoPage({super.key});

  @override
  State<HubDemoPage> createState() => _HubDemoPageState();
}

class _HubDemoPageState extends State<HubDemoPage> {
  String _status = 'not initialized';

  @override
  void initState() {
    super.initState();
    GfmcSdk.events.listen((event) {
      setState(() {
        _status = switch (event) {
          GfmcHubReadyEvent() => 'hub ready',
          GfmcHubClosedEvent() => 'hub closed',
          GfmcErrorEvent(code: final c, message: final m) => 'error: $c ($m)',
          GfmcPurchaseCompletedEvent(sku: final s) => 'purchased $s',
          GfmcPurchaseFailedEvent(reason: final r) => 'purchase failed: $r',
          GfmcModuleChangedEvent(module: final m) => 'module: $m',
          GfmcShareRequestedEvent() => 'share requested',
          GfmcSkuSelectedEvent(sku: final s) => 'sku selected: $s',
        };
      });
    });
  }

  Future<void> _initAndOpen() async {
    // SANDBOX here on purpose, matching this repo's own dummy host app
    // (jessica-native-dummy-host) — PRODUCTION_URL is still pending DNS as
    // of GfmcSDK 2.3.6. Swap to GfmcEnv.production once that's live.
    await GfmcSdk.init(
      config: const GfmcConfig(environment: GfmcEnv.sandbox, enableLogging: true),
    );

    // Real apps: fetch this from your own backend. This placeholder will
    // fail auth server-side but is enough to prove the plugin wiring works
    // end to end (hub opens, bridge round-trips, GfmcHubReadyEvent fires).
    GfmcSdk.setTokenRefresher(() async => 'replace-with-a-real-jwt');
    await GfmcSdk.open('replace-with-a-real-jwt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('gfmc_flutter example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initAndOpen,
              child: const Text('Open minicinema hub'),
            ),
          ],
        ),
      ),
    );
  }
}
