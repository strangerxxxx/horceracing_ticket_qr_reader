import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/http_fetch.dart';
import 'package:horceracing_ticket_qr_reader/race_result_cache.dart';
import 'package:horceracing_ticket_qr_reader/race_result_fetcher.dart';
import 'package:http/http.dart' as http;

void main() {
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('race_result_jra_fb_');
    RaceResultCache.debugDirectory = cacheDir;
  });

  tearDown(() async {
    HttpFetch.debugGet = null;
    HttpFetch.debugPost = null;
    RaceResultCache.debugDirectory = null;
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  test('fetch falls back to JRA when db has no payouts', () async {
    final detailHtml = File('test/fixtures/jra_race_result_sample.html')
        .readAsStringSync();
    final detailBytes =
        const ShiftJISCodec().encode(detailHtml);

    // netkeiba DB: メタのみ・払戻なし
    HttpFetch.debugGet = (uri, {headers}) async {
      const html = '''
<html><body>
<div class="data_intro">
<dl class="racedata fc"><dd><h1>2歳未勝利</h1></dd></dl>
<p class="smalltxt">2026年08月22日 3回新潟1日目</p>
</div>
</body></html>
''';
      return http.Response.bytes(
        const EucJPCodec().encode(html),
        200,
        headers: {'content-type': 'text/html'},
      );
    };

    HttpFetch.debugPost = (uri, {headers, body}) async {
      final cname = body?['cname'] ?? '';
      String html;
      if (cname == 'pw01sli00/AF') {
        html =
            "pw01srl10042026030120260822/BB pw01srl10012026020120260822/AA";
      } else if (cname.startsWith('pw01srl10')) {
        html =
            "pw01sde1004202603010120260822/1A pw01sde1004202603010220260822/CF";
      } else if (cname.startsWith('pw01sde10')) {
        return http.Response.bytes(
          detailBytes,
          200,
          headers: {'content-type': 'text/html; charset=Shift_JIS'},
        );
      } else {
        html = '';
      }
      return http.Response.bytes(
        const ShiftJISCodec().encode(html),
        200,
        headers: {'content-type': 'text/html; charset=Shift_JIS'},
      );
    };

    final result = await RaceResultFetcher.fetch(
      'https://db.netkeiba.com/race/202604030101',
      forceRefresh: true,
    );

    expect(result.hasResults, isTrue);
    expect(result.payoutsFor('単勝').single.combinationKey, '5');
    expect(result.payoutsFor('単勝').single.payoutPer100Yen, 140);
    expect(result.horseNamesByNumber[5], 'コスモイェーガー');
    expect(result.raceName, '2歳未勝利');
  });
}
