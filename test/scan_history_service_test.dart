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
}
