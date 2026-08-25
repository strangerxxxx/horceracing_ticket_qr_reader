import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/race_result.dart';
import 'package:horceracing_ticket_qr_reader/race_result_cache.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('race_result_cache_');
    RaceResultCache.debugDirectory = tempDir;
  });

  tearDown(() async {
    RaceResultCache.debugDirectory = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  RaceResult sample({required bool hasResults}) {
    return RaceResult(
      url: 'https://race.netkeiba.com/race/result.html?race_id=202605020101',
      payoutsByBetType: hasResults
          ? {
              '単勝': [
                const PayoutEntry(
                  combinationKey: '1',
                  combinationLabel: '1',
                  payoutPer100Yen: 350,
                ),
              ],
            }
          : const {},
      hasResults: hasResults,
      horseNamesByNumber: const {1: 'テスト馬'},
      frameByHorseNumber: const {1: 1},
      fieldSize: 16,
      raceName: 'テストS',
      raceDateLabel: '2026年5月2日',
    );
  }

  test('RaceResult JSON round-trip', () {
    final original = sample(hasResults: true);
    final restored = RaceResult.fromJson(original.toJson());

    expect(restored.url, original.url);
    expect(restored.hasResults, isTrue);
    expect(restored.raceName, 'テストS');
    expect(restored.horseNamesByNumber[1], 'テスト馬');
    expect(restored.frameByHorseNumber[1], 1);
    expect(restored.payoutsFor('単勝').single.payoutPer100Yen, 350);
  });

  test('cache hit returns stored result with payouts', () async {
    final url = sample(hasResults: true).url;
    await RaceResultCache.write(url, sample(hasResults: true));

    final cached = await RaceResultCache.read(url);
    expect(cached, isNotNull);
    expect(cached!.raceName, 'テストS');
    expect(cached.hasResults, isTrue);
  });

  test('incomplete result is fresh within TTL', () async {
    final url = sample(hasResults: false).url;
    await RaceResultCache.write(url, sample(hasResults: false));

    final cached = await RaceResultCache.read(url);
    expect(cached, isNotNull);
    expect(cached!.hasResults, isFalse);
  });

  test('corrupt cache is ignored', () async {
    final url = 'https://example.com/race';
    await RaceResultCache.write(url, sample(hasResults: true));
    final files = tempDir.listSync().whereType<File>().toList();
    expect(files, isNotEmpty);
    await files.first.writeAsString('not-json');

    expect(await RaceResultCache.read(url), isNull);
  });
}
