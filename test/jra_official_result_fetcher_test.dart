import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/jra_official_result_fetcher.dart';

void main() {
  late String sampleHtml;

  setUpAll(() {
    sampleHtml = File('test/fixtures/jra_race_result_sample.html')
        .readAsStringSync();
  });

  test('parseRaceId extracts JRA parts', () {
    final parts = JraOfficialResultFetcher.parseRaceId('202604030101');
    expect(parts, isNotNull);
    expect(parts!.year, '2026');
    expect(parts.jyo, '04');
    expect(parts.kai, '03');
    expect(parts.nichi, '01');
    expect(parts.race, '01');
  });

  test('parseRaceId rejects NAR ids', () {
    expect(JraOfficialResultFetcher.parseRaceId('202645010101'), isNull);
  });

  test('findMeetingCname matches prefix with date checksum', () {
    const html = '''
<a onclick="doAction('/JRADB/accessS.html','pw01srl10042026030120260822/BB')">新潟</a>
<a onclick="doAction('/JRADB/accessS.html','pw01srl10012026020120260822/AA')">札幌</a>
''';
    final parts = JraOfficialResultFetcher.parseRaceId('202604030101')!;
    expect(
      JraOfficialResultFetcher.findMeetingCname(html, parts),
      'pw01srl10042026030120260822/BB',
    );
  });

  test('findRaceDetailCname matches race number', () {
    const html = '''
<a href="/JRADB/accessS.html?CNAME=pw01sde1004202603010120260822/1A">1R</a>
<a href="/JRADB/accessS.html?CNAME=pw01sde1004202603010220260822/CF">2R</a>
''';
    final parts = JraOfficialResultFetcher.parseRaceId('202604030101')!;
    expect(
      JraOfficialResultFetcher.findRaceDetailCname(html, parts),
      'pw01sde1004202603010120260822/1A',
    );
  });

  test('parseHtml extracts payouts meta and horses from JRA HTML', () {
    final result = JraOfficialResultFetcher.parseHtml(
      sampleHtml,
      'https://db.netkeiba.com/race/202604030101',
    );

    expect(result.hasResults, isTrue);
    expect(result.layoutRecognized, isTrue);
    expect(result.raceName, '2歳未勝利');
    expect(result.raceDateLabel, '2026年8月22日');

    expect(result.horseNamesByNumber[5], 'コスモイェーガー');
    expect(result.horseNamesByNumber[2], 'アニエーネ');
    expect(result.frameByHorseNumber[5], 5);
    expect(result.frameByHorseNumber[2], 2);

    expect(result.payoutsFor('単勝').single.combinationKey, '5');
    expect(result.payoutsFor('単勝').single.payoutPer100Yen, 140);
    expect(
      result.payoutsFor('複勝').map((e) => e.combinationKey),
      ['5', '2'],
    );
    expect(result.payoutsFor('馬連').single.combinationKey, '2-5');
    expect(result.payoutsFor('馬単').single.combinationKey, '5>2');
    expect(result.payoutsFor('ワイド').map((e) => e.combinationKey), [
      '2-5',
      '4-5',
      '2-4',
    ]);
    expect(result.payoutsFor('三連複').single.combinationKey, '2-4-5');
    expect(result.payoutsFor('三連単').single.combinationKey, '5>2>4');
    expect(result.payoutsFor('三連単').single.payoutPer100Yen, 2190);
  });
}
