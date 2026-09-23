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

  test('error title and subtitle', () {
    final entry = ScanHistoryEntry(
      id: 'e',
      scannedAt: DateTime(2026, 1, 1),
      data: {'エラー': '解析に失敗しました'},
    );
    expect(entry.title, '解析エラー');
    expect(entry.subtitle, '解析に失敗しました');
  });

  test('subtitle prefers calendar date and post time', () {
    final entry = ScanHistoryEntry(
      id: '1',
      scannedAt: DateTime(2026, 1, 15, 12, 30),
      data: {
        '開催場': '阪神',
        'レース': 11,
        '年': 25,
        '回': 2,
        '日': 4,
        '券種': 'ながし',
        '開催日': '2025年4月6日',
        '発走時刻': '15:40',
        '購入内容': [
          {'式別': '3連単'},
        ],
      },
    );
    expect(entry.subtitle, contains('2025年4月6日 15:40'));
    expect(entry.subtitle, contains('ながし'));
  });
}
