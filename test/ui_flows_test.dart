import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/history_page.dart';
import 'package:horceracing_ticket_qr_reader/hit_colors.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_entry.dart';
import 'package:horceracing_ticket_qr_reader/ticket_result_view.dart';

void main() {
  testWidgets('HistoryPage shows empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(loader: () async => []),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('読み取り履歴'), findsOneWidget);
    expect(find.text('履歴はありません'), findsOneWidget);
  });

  testWidgets('HistoryPage lists title with race name and payout summary', (
    tester,
  ) async {
    final entry = ScanHistoryEntry(
      id: '1',
      scannedAt: DateTime(2025, 5, 4, 12),
      data: {
        '開催場': '東京',
        'レース': 11,
        'レース名': 'プリンシパルS(L)',
        '年': 2025,
        '回': 2,
        '日': 4,
        '券種': '通常',
        '購入内容': [
          {'式別': '単勝'},
        ],
        '購入合計': 100,
        '払戻合計': 620,
        '的中件数': 1,
        '結果取得済': true,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(loader: () async => [entry]),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('東京 11R プリンシパルS(L)'), findsOneWidget);
    expect(find.textContaining('的中1件'), findsOneWidget);
    expect(find.textContaining('払戻 620円'), findsOneWidget);
  });

  testWidgets('HistoryPage shows filter totals', (tester) async {
    final entries = [
      ScanHistoryEntry(
        id: '1',
        scannedAt: DateTime(2025, 5, 4, 12),
        data: {
          '開催場': '東京',
          'レース': 1,
          '購入合計': 100,
          '払戻合計': 620,
          '的中件数': 1,
          '結果取得済': true,
        },
      ),
      ScanHistoryEntry(
        id: '2',
        scannedAt: DateTime(2025, 5, 5, 12),
        data: {
          '開催場': '中山',
          'レース': 2,
          '購入合計': 200,
          '払戻合計': 0,
          '的中件数': 0,
          '結果取得済': true,
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryPage(loader: () async => entries),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('的中'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('合計購入 100円'), findsOneWidget);
    expect(find.textContaining('合計払戻 620円'), findsOneWidget);
  });

  testWidgets('TicketResultView shows parse error and rescan action', (
    tester,
  ) async {
    var rescanned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketResultView(
            data: const {'エラー': '解析に失敗しました', '詳細': 'bad qr'},
            onRescan: () => rescanned = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('解析に失敗しました'), findsOneWidget);
    expect(find.text('bad qr'), findsOneWidget);
    await tester.tap(find.text('もう一度読み取る'));
    expect(rescanned, isTrue);
  });

  testWidgets('TicketResultView shows race info without network', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TicketResultView(
              data: {
                '開催場': '東京',
                '年': 26,
                '回': 1,
                '日': 2,
                'レース': 11,
                '券種': '通常',
                '購入内容': [
                  {
                    '式別': '単勝',
                    '馬番': [12],
                    '購入金額': 100,
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('レース情報'), findsOneWidget);
    expect(find.text('東京'), findsWidgets);
    expect(find.text('購入内容'), findsOneWidget);
    expect(find.text('単勝'), findsOneWidget);
  });

  testWidgets('HitColors follow ColorScheme error tokens', (tester) async {
    late ColorScheme scheme;
    late Color fg;
    late Color bg;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
        ),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            fg = HitColors.foreground(context);
            bg = HitColors.background(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(fg, scheme.error);
    expect(bg, scheme.errorContainer);
  });
}
