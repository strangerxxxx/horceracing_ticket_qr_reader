import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/local_race_url.dart';

void main() {
  test('buildUrl uses western date and netkeiba jyo code', () {
    expect(
      LocalRaceUrlResolver.buildUrl(
        westernYear: 2026,
        jyoCd: '65',
        monthDay: '0109',
        race: 1,
      ),
      'https://db.netkeiba.com/race/202665010901',
    );
    expect(
      LocalRaceUrlResolver.buildUrl(
        westernYear: 2026,
        jyoCd: '65',
        monthDay: '0802',
        race: 2,
      ),
      'https://db.netkeiba.com/race/202665080202',
    );
  });

  test('isReiwaFiscalYear treats small years as Reiwa fiscal year', () {
    expect(LocalRaceUrlResolver.isReiwaFiscalYear(7), isTrue);
    expect(LocalRaceUrlResolver.isReiwaFiscalYear(1), isTrue);
    expect(LocalRaceUrlResolver.isReiwaFiscalYear(41), isFalse);
  });

  test('parseRoundDayFromHtmlBytes reads EUC-JP 回/日目', () {
    // "20回帯広(ば)5日目" in EUC-JP, digits are ASCII
    final bytes = <int>[
      ...'xx'.codeUnits,
      ...'20'.codeUnits,
      0xB2, 0xF3, // 回
      0xC2, 0xD3, 0xB9, 0xAD, // 帯広
      ...'('.codeUnits,
      0xA4, 0xD0, // ば (approx; pattern allows gap)
      ...')'.codeUnits,
      ...'5'.codeUnits,
      0xC6, 0xFC, 0xCC, 0xDC, // 日目
    ];

    final parsed = LocalRaceUrlResolver.parseRoundDayFromHtmlBytes(bytes);
    expect(parsed, isNotNull);
    expect(parsed!.$1, 20);
    expect(parsed.$2, 5);
  });

  test('parseVenueDatesFromZipBytes extracts matching venue dates', () {
    final csv = utf8.encode(
      '\uFEFF競馬場,競走年月日,レース番号\n'
      '帯広ば,20260109,1\n'
      '帯広ば,20260109,2\n'
      '門別,20260109,1\n'
      '大井,20260110,1\n',
    );
    final archive = Archive()
      ..addFile(
        ArchiveFile('202601_racelist.csv', csv.length, csv),
      );
    final zipBytes = ZipEncoder().encode(archive);

    final dates = LocalRaceUrlResolver.parseVenueDatesFromZipBytes(
      Uint8List.fromList(zipBytes),
      '帯広',
    );
    expect(dates, {'20260109'});
  });
}
