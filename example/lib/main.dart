import 'package:flutter/material.dart';
import 'package:gfmc_flutter/gfmc_flutter.dart';

import 'dummy_auth_api.dart';

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
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _status = 'not logged in';
  final List<String> _log = [];

  // App-level auth (jessica-dummy-api), NOT what GfmcSdk.open wants.
  String? _appAccessToken;
  String? _appRefreshToken;

  // Minicinema session tokens — these are what GfmcSdk actually uses.
  String? _miniToken;
  String? _miniRefreshToken;

  bool _busy = false;

  void _append(String line) {
    setState(() {
      _log.insert(0, line);
      if (_log.length > 20) _log.removeLast();
    });
  }

  Future<void> _guard(String label, Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      _append('$label failed: $e');
      setState(() => _status = '$label failed');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _login() => _guard('login', () async {
        final json = await DummyAuthApi.login(
          _usernameCtrl.text,
          _passwordCtrl.text,
        );
        _appAccessToken =
            DummyAuthApi.extractToken(json, ['access_token', 'token']);
        _appRefreshToken =
            DummyAuthApi.extractToken(json, ['refresh_token']);
        if (_appAccessToken == null) {
          throw StateError('no access_token in response: $json');
        }
        _append('login ok, response keys: ${json.keys}');
        setState(() => _status = 'logged in as ${_usernameCtrl.text}');
      });

  Future<void> _refreshAppToken() => _guard('app refresh', () async {
        final token = _appRefreshToken;
        if (token == null) throw StateError('login first');
        final json = await DummyAuthApi.refresh(token);
        _appAccessToken =
            DummyAuthApi.extractToken(json, ['access_token', 'token']) ??
                _appAccessToken;
        _appRefreshToken =
            DummyAuthApi.extractToken(json, ['refresh_token']) ??
                _appRefreshToken;
        _append('app token refreshed');
        setState(() => _status = 'app token refreshed');
      });

  Future<void> _getMinicinemaToken() => _guard('minicinema token', () async {
        final token = _appAccessToken;
        if (token == null) throw StateError('login first');
        final json = await DummyAuthApi.minicinemaToken(token);
        _miniToken =
            DummyAuthApi.extractToken(json, ['access_token', 'token', 'jwt']);
        _miniRefreshToken =
            DummyAuthApi.extractToken(json, ['refresh_token']);
        if (_miniToken == null) {
          throw StateError('no token in minicinema response: $json');
        }
        _append('minicinema token ok, response keys: ${json.keys}');
        setState(() => _status = 'minicinema token acquired');
      });

  /// Wired into [GfmcSdk.setTokenRefresher] — called by the hub itself when
  /// the current minicinema JWT expires mid-session.
  Future<String> _refreshMinicinemaToken() async {
    final refreshToken = _miniRefreshToken;
    if (refreshToken == null) {
      throw StateError('no minicinema refresh_token to refresh with');
    }
    final json = await DummyAuthApi.minicinemaRefresh(refreshToken);
    final fresh =
        DummyAuthApi.extractToken(json, ['access_token', 'token', 'jwt']);
    if (fresh == null) {
      throw StateError('no token in minicinema refresh response: $json');
    }
    _miniToken = fresh;
    _miniRefreshToken =
        DummyAuthApi.extractToken(json, ['refresh_token']) ?? refreshToken;
    _append('minicinema token auto-refreshed');
    return fresh;
  }

  Future<void> _initAndOpen() => _guard('open hub', () async {
        final jwt = _miniToken;
        if (jwt == null) throw StateError('get minicinema token first');

        await GfmcSdk.init(
          config: const GfmcConfig(
            environment: GfmcEnv.sandbox,
            enableLogging: true,
          ),
        );
        GfmcSdk.setTokenRefresher(_refreshMinicinemaToken);
        await GfmcSdk.open(jwt);
        setState(() => _status = 'hub opening…');
      });

  @override
  void initState() {
    super.initState();
    GfmcSdk.events.listen((event) {
      final line = switch (event) {
        GfmcHubReadyEvent() => 'hub ready',
        GfmcHubClosedEvent() => 'hub closed',
        GfmcErrorEvent(code: final c, message: final m) => 'error: $c ($m)',
        GfmcPurchaseCompletedEvent(sku: final s) => 'purchased $s',
        GfmcPurchaseFailedEvent(reason: final r) => 'purchase failed: $r',
        GfmcModuleChangedEvent(module: final m) => 'module: $m',
        GfmcShareRequestedEvent() => 'share requested',
        GfmcSkuSelectedEvent(sku: final s) => 'sku selected: $s',
      };
      _append(line);
      setState(() => _status = line);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('gfmc_flutter example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'username'),
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _login,
                  child: const Text('1. Login'),
                ),
                ElevatedButton(
                  onPressed: _busy || _appRefreshToken == null
                      ? null
                      : _refreshAppToken,
                  child: const Text('2. Refresh app token'),
                ),
                ElevatedButton(
                  onPressed: _busy || _appAccessToken == null
                      ? null
                      : _getMinicinemaToken,
                  child: const Text('3. Get minicinema token'),
                ),
                ElevatedButton(
                  onPressed:
                      _busy || _miniToken == null ? null : _initAndOpen,
                  child: const Text('4. Open minicinema hub'),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(
                  _log[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
