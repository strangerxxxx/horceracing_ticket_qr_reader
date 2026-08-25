import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_entry.dart';

void main() {
  test('title includes venue, race number, and race name', () {
    final entry = ScanHistoryEntry(
      id: '1',
      scannedAt: DateTime(2026, 1, 15, 12, 30),
      data: {
        '開催場': '東京',
        'レース': 1,
        'レース名': 'プリンシパルS(L)',
      },
    );

    expect(entry.title, '東京 1R プリンシパルS(L)');
  });

  test('title omits race name when not stored', () {
    final entry = ScanHistoryEntry(
      id: '1',
      scannedAt: DateTime(2026, 1, 15, 12, 30),
      data: {
        '開催場': '東京',
        'レース': 1,
      },
    );

    expect(entry.title, '東京 1R');
  });

  test('subtitle does not include race name', () {
    final entry = ScanHistoryEntry(
      id: '1',
      scannedAt: DateTime(2026, 1, 15, 12, 30),
      data: {
        '年': 2026,
        '回': 1,
        '日': 2,
        '券種': '通常',
        'レース名': 'プリンシパルS(L)',
        '購入内容': [
          {'式別': '単勝'},
        ],
      },
    );

    expect(entry.subtitle, '2026年 第1回 第2日 · 通常 · 単勝');
  });
}
