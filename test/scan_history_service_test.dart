import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scan_history_');
    ScanHistoryService.debugDirectory = tempDir;
  });

  tearDown(() async {
    ScanHistoryService.debugDirectory = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('corrupt history file is quarantined and load returns empty', () async {
    final file = File('${tempDir.path}${Platform.pathSeparator}scan_history.json');
    await file.writeAsString('{not-json');

    final entries = await ScanHistoryService.load();
    expect(entries, isEmpty);

    final corrupt = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.corrupt.'));
    expect(corrupt, isNotEmpty);
  });

  test('invalid entries are skipped', () async {
    final file = File('${tempDir.path}${Platform.pathSeparator}scan_history.json');
    await file.writeAsString('''
[
  {"id":"1","scannedAt":"2026-01-01T00:00:00.000","data":{"開催場":"東京","レース":1}},
  {"broken": true},
  {"id":"2","scannedAt":"not-a-date","data":{}}
]
''');

    final entries = await ScanHistoryService.load();
    expect(entries.length, 1);
    expect(entries.single.id, '1');
  });

  test('concurrent updates do not lose entries', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        ScanHistoryService.add({'開催場': '東京', 'レース': i + 1}),
    ]);

    final entries = await ScanHistoryService.load();
    expect(entries.length, 10);
  });

  test('keeps at most 100 entries', () async {
    for (var i = 0; i < 105; i++) {
      await ScanHistoryService.add({'開催場': '東京', 'レース': i + 1});
    }

    final entries = await ScanHistoryService.load();
    expect(entries.length, 100);
    expect(entries.first.data['レース'], 105);
    expect(entries.last.data['レース'], 6);
  });

  test('updateData patches nested purchase maps', () async {
    final id = await ScanHistoryService.add({
      '開催場': '東京',
      'レース': 11,
      '購入内容': [
        {
          '式別': '単勝',
          '馬番': [12],
          '購入金額': 100,
        },
      ],
    });

    await ScanHistoryService.updateData(id, {
      'レース名': 'プリンシパルS(L)',
      '開催日': '2025年5月4日',
    });

    final entries = await ScanHistoryService.load();
    final entry = entries.singleWhere((e) => e.id == id);
    expect(entry.data['レース名'], 'プリンシパルS(L)');
    expect(entry.data['開催日'], '2025年5月4日');
    expect(entry.data['購入内容'], isA<List>());
    final purchase = (entry.data['購入内容'] as List).first as Map;
    expect(purchase['式別'], '単勝');
    expect(purchase['馬番'], [12]);
  });

  test('delete and clear remove entries', () async {
    final id1 = await ScanHistoryService.add({'開催場': '東京', 'レース': 1});
    final id2 = await ScanHistoryService.add({'開催場': '中山', 'レース': 2});

    await ScanHistoryService.delete(id1);
    var entries = await ScanHistoryService.load();
    expect(entries.map((e) => e.id), [id2]);

    await ScanHistoryService.clear();
    entries = await ScanHistoryService.load();
    expect(entries, isEmpty);
  });

  test('restore puts deleted entry back with same id', () async {
    final id = await ScanHistoryService.add({'開催場': '東京', 'レース': 7});
    final original =
        (await ScanHistoryService.load()).singleWhere((e) => e.id == id);

    await ScanHistoryService.delete(id);
    expect(await ScanHistoryService.load(), isEmpty);

    await ScanHistoryService.restore(original);
    final restored = await ScanHistoryService.load();
    expect(restored, hasLength(1));
    expect(restored.single.id, id);
    expect(restored.single.data['レース'], 7);
  });

  test('round-trips nested formation horse numbers', () async {
    final id = await ScanHistoryService.add({
      '開催場': '大井',
      '場コード': '44',
      '券種': 'フォーメーション',
      '購入内容': [
        {
          '式別': '3連単',
          '馬番': [
            [1, 2],
            [3],
            [4, 5],
          ],
          '購入金額': 100,
        },
      ],
    });

    final entry =
        (await ScanHistoryService.load()).singleWhere((e) => e.id == id);
    final purchase = (entry.data['購入内容'] as List).first as Map;
    expect(purchase['馬番'], [
      [1, 2],
      [3],
      [4, 5],
    ]);
    expect(entry.ticket.purchases.single.numbers!.isNested, isTrue);
  });

  test('add replaces duplicate ticket keeping latest only', () async {
    await ScanHistoryService.add({
      'QR': 'dup-qr',
      '開催場': '東京',
      'レース': 1,
      '購入合計': 100,
    });
    await ScanHistoryService.add({
      'QR': 'dup-qr',
      '開催場': '東京',
      'レース': 1,
      '購入合計': 200,
    });

    final entries = await ScanHistoryService.load();
    expect(entries, hasLength(1));
    expect(entries.single.data['購入合計'], 200);
  });
}
