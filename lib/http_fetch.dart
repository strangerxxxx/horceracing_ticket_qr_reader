import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// HTTP 取得の共通エラー（ユーザー向けメッセージ付き）
class HttpFetchException implements Exception {
  final String message;

  const HttpFetchException(this.message);

  @override
  String toString() => message;
}

/// タイムアウト付き HTTP GET / POST
class HttpFetch {
  static const timeout = Duration(seconds: 20);
  static const userAgent =
      'Mozilla/5.0 (compatible; HorseRacingTicketQrReader/1.0)';

  /// テスト差し替え用
  static Future<http.Response> Function(Uri uri, {Map<String, String>? headers})?
      debugGet;

  /// テスト差し替え用（form body は Map）
  static Future<http.Response> Function(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? body,
  })? debugPost;

  static Future<http.Response> get(Uri uri) async {
    try {
      final getter = debugGet;
      final response = getter != null
          ? await getter(uri, headers: {'User-Agent': userAgent})
              .timeout(timeout)
          : await http
              .get(uri, headers: {'User-Agent': userAgent})
              .timeout(timeout);
      return response;
    } on TimeoutException {
      throw const HttpFetchException('接続がタイムアウトしました');
    } on SocketException {
      throw const HttpFetchException('ネットワークに接続できません');
    } on HttpFetchException {
      rethrow;
    } on http.ClientException {
      throw const HttpFetchException('通信に失敗しました');
    } catch (_) {
      throw const HttpFetchException('通信に失敗しました');
    }
  }

  /// `application/x-www-form-urlencoded` の POST
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? body,
  }) async {
    try {
      final headers = {
        'User-Agent': userAgent,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      final poster = debugPost;
      final response = poster != null
          ? await poster(uri, headers: headers, body: body).timeout(timeout)
          : await http.post(uri, headers: headers, body: body).timeout(timeout);
      return response;
    } on TimeoutException {
      throw const HttpFetchException('接続がタイムアウトしました');
    } on SocketException {
      throw const HttpFetchException('ネットワークに接続できません');
    } on HttpFetchException {
      rethrow;
    } on http.ClientException {
      throw const HttpFetchException('通信に失敗しました');
    } catch (_) {
      throw const HttpFetchException('通信に失敗しました');
    }
  }
}
