import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/http_fetch.dart';
import 'package:horceracing_ticket_qr_reader/local_race_url.dart';
import 'package:http/http.dart' as http;

void main() {
  tearDown(() {
    HttpFetch.debugGet = null;
    HttpFetch.debugPost = null;
  });

  test('HttpFetch maps TimeoutException to user message', () async {
    HttpFetch.debugGet = (uri, {headers}) =>
        Future.error(TimeoutException('slow'));

    expect(
      () => HttpFetch.get(Uri.parse('https://example.com')),
      throwsA(
        isA<HttpFetchException>().having(
          (e) => e.message,
          'message',
          '接続がタイムアウトしました',
        ),
      ),
    );
  });

  test('HttpFetch.post maps TimeoutException to user message', () async {
    HttpFetch.debugPost = (uri, {headers, body}) =>
        Future.error(TimeoutException('slow'));

    expect(
      () => HttpFetch.post(
        Uri.parse('https://example.com'),
        body: {'cname': 'x'},
      ),
      throwsA(
        isA<HttpFetchException>().having(
          (e) => e.message,
          'message',
          '接続がタイムアウトしました',
        ),
      ),
    );
  });

  test('HttpFetch maps SocketException to user message', () async {
    HttpFetch.debugGet = (uri, {headers}) =>
        Future.error(const SocketException('offline'));

    expect(
      () => HttpFetch.get(Uri.parse('https://example.com')),
      throwsA(
        isA<HttpFetchException>().having(
          (e) => e.message,
          'message',
          'ネットワークに接続できません',
        ),
      ),
    );
  });

  test('HttpFetch maps ClientException to user message', () async {
    HttpFetch.debugGet = (uri, {headers}) =>
        Future.error(http.ClientException('broken'));

    expect(
      () => HttpFetch.get(Uri.parse('https://example.com')),
      throwsA(
        isA<HttpFetchException>().having(
          (e) => e.message,
          'message',
          '通信に失敗しました',
        ),
      ),
    );
  });

  test('resolveDetailed fails for unknown racecourse code', () async {
    final result = await LocalRaceUrlResolver.resolveDetailed(
      racecourseCode: '99',
      venueName: '不明',
      year: 7,
      round: 1,
      day: 1,
      race: 1,
    );

    expect(result.isSuccess, isFalse);
    expect(result.failureReason, '未対応の競馬場コードです');
  });

  test('resolveDetailed fails for invalid round/day/race', () async {
    final result = await LocalRaceUrlResolver.resolveDetailed(
      racecourseCode: '36',
      venueName: '帯広',
      year: 7,
      round: 0,
      day: 1,
      race: 1,
    );

    expect(result.isSuccess, isFalse);
    expect(result.failureReason, contains('開催情報'));
  });
}
