import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin client for `jessica-dummy-api.bdn.id` — the throwaway backend used to
/// exercise the full auth chain this example needs before it can call
/// [GfmcSdk.open]:
///
/// 1. [login] — app-level username/password -> app access + refresh token.
/// 2. [refresh] — app refresh token -> fresh app access + refresh token.
/// 3. [minicinemaToken] — app access token -> minicinema session JWT (this
///    is the token GfmcSdk.open actually wants, NOT the app access token).
/// 4. [minicinemaRefresh] — minicinema refresh token -> fresh minicinema
///    JWT. Wire this into [GfmcSdk.setTokenRefresher].
class DummyAuthApi {
  DummyAuthApi._();

  static const _base = 'https://jessica-dummy-api.bdn.id/api/v1';
  static const _headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) => _post('$_base/auth/login', body: {
        'username': username,
        'password': password,
      });

  static Future<Map<String, dynamic>> refresh(String refreshToken) =>
      _post('$_base/auth/refresh', body: {'refresh_token': refreshToken});

  /// Body is intentionally empty — auth rides on the bearer header, matching
  /// the reference curl for this endpoint.
  static Future<Map<String, dynamic>> minicinemaToken(String accessToken) =>
      _post(
        '$_base/minicinema/token',
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $accessToken'},
        rawBody: '',
      );

  static Future<Map<String, dynamic>> minicinemaRefresh(
    String refreshToken,
  ) =>
      _post('$_base/minicinema/refresh', body: {'refresh_token': refreshToken});

  static Future<Map<String, dynamic>> _post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    String? rawBody,
  }) async {
    final res = await http.post(
      Uri.parse(url),
      headers: headers ?? _headers,
      body: rawBody ?? jsonEncode(body),
    );
    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw DummyAuthApiException(res.statusCode, res.body);
    }
    return decoded as Map<String, dynamic>;
  }

  /// Pulls a token out of a response body under whatever key the API used.
  /// jessica-dummy-api wraps its payloads in a top-level `data` object
  /// (`{"data": {"access_token": ...}}`), so this checks both the raw body
  /// and that nested object before giving up.
  static String? extractToken(Map<String, dynamic> json, List<String> keys) {
    for (final source in [json, if (json['data'] is Map) json['data'] as Map]) {
      for (final key in keys) {
        final v = source[key];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }
}

class DummyAuthApiException implements Exception {
  DummyAuthApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'DummyAuthApiException($statusCode): $body';
}
