import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_entry.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_query.dart';

void main() {
  ScanHistoryEntry entry({
    required String id,
    required DateTime scannedAt,
    required Map<String, dynamic> data,
  }) {
    return ScanHistoryEntry(id: id, scannedAt: scannedAt, data: data);
  }

  test('dedupeLatest keeps newest scan for same QR', () {
    final older = entry(
      id: '1',
      scannedAt: DateTime(2026, 1, 1),
      data: {'QR': 'same', '開催場': '東京', 'レース': 1, '購入合計': 100},
    );
    final newer = entry(
      id: '2',
      scannedAt: DateTime(2026, 1, 2),
      data: {'QR': 'same', '開催場': '東京', 'レース': 1, '購入合計': 200},
    );

    final result = ScanHistoryQuery.dedupeLatest([older, newer]);
    expect(result, hasLength(1));
    expect(result.single.id, '2');
    expect(result.single.purchaseTotalYen, 200);
  });

  test('filter by hit / miss / pending', () {
    final hit = entry(
      id: 'h',
      scannedAt: DateTime(2026, 1, 3),
      data: {
        '開催場': '東京',
        'レース': 1,
        '結果取得済': true,
        '的中件数': 1,
        '払戻合計': 620,
        '購入合計': 100,
      },
    );
    final miss = entry(
      id: 'm',
      scannedAt: DateTime(2026, 1, 2),
      data: {
        '開催場': '中山',
        'レース': 2,
        '結果取得済': true,
        '的中件数': 0,
        '払戻合計': 0,
        '購入合計': 200,
      },
    );
    final pending = entry(
      id: 'p',
      scannedAt: DateTime(2026, 1, 1),
      data: {'開催場': '阪神', 'レース': 3, '購入合計': 300},
    );
    final all = [hit, miss, pending];

    expect(
      ScanHistoryQuery.filter(entries: all, hitFilter: HistoryHitFilter.hit)
          .map((e) => e.id),
      ['h'],
    );
    expect(
      ScanHistoryQuery.filter(entries: all, hitFilter: HistoryHitFilter.miss)
          .map((e) => e.id),
      ['m'],
    );
    expect(
      ScanHistoryQuery.filter(
        entries: all,
        hitFilter: HistoryHitFilter.pending,
      ).map((e) => e.id),
      ['p'],
    );
  });

  test('search query matches venue and race name', () {
    final entries = [
      entry(
        id: '1',
        scannedAt: DateTime(2026, 1, 1),
        data: {'開催場': '東京', 'レース': 11, 'レース名': 'プリンシパルS(L)'},
      ),
      entry(
        id: '2',
        scannedAt: DateTime(2026, 1, 2),
        data: {'開催場': '中山', 'レース': 1, 'レース名': '皐月賞'},
      ),
    ];

    final filtered = ScanHistoryQuery.filter(entries: entries, query: 'プリンシパル');
    expect(filtered.single.id, '1');
  });

  test('sort by purchase and payout', () {
    final a = entry(
      id: 'a',
      scannedAt: DateTime(2026, 1, 1),
      data: {'開催場': '東京', '購入合計': 300, '払戻合計': 0, '結果取得済': true, '的中件数': 0},
    );
    final b = entry(
      id: 'b',
      scannedAt: DateTime(2026, 1, 2),
      data: {
        '開催場': '中山',
        '購入合計': 100,
        '払戻合計': 1000,
        '結果取得済': true,
        '的中件数': 1,
      },
    );

    final byPurchase = ScanHistoryQuery.sort(
      entries: [a, b],
      field: HistorySortField.purchase,
      ascending: true,
    );
    expect(byPurchase.map((e) => e.id), ['b', 'a']);

    final byPayout = ScanHistoryQuery.sort(
      entries: [a, b],
      field: HistorySortField.payout,
      ascending: false,
    );
    expect(byPayout.map((e) => e.id), ['b', 'a']);
  });

  test('totals sum purchase and payout for filtered list', () {
    final entries = [
      entry(
        id: '1',
        scannedAt: DateTime(2026, 1, 1),
        data: {
          '購入合計': 100,
          '払戻合計': 620,
          '結果取得済': true,
          '的中件数': 1,
          '開催場': '東京',
        },
      ),
      entry(
        id: '2',
        scannedAt: DateTime(2026, 1, 2),
        data: {
          '購入合計': 200,
          '払戻合計': 0,
          '結果取得済': true,
          '的中件数': 0,
          '開催場': '中山',
        },
      ),
      entry(
        id: '3',
        scannedAt: DateTime(2026, 1, 3),
        data: {'購入合計': 50, '開催場': '阪神'},
      ),
    ];

    final totals = ScanHistoryQuery.totals(entries);
    expect(totals.purchaseTotal, 350);
    expect(totals.payoutTotal, 620);
    expect(totals.knownPayoutCount, 2);
  });
}
