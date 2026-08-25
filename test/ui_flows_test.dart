import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/history_page.dart';
import 'package:horceracing_ticket_qr_reader/hit_colors.dart';
import 'package:horceracing_ticket_qr_reader/race_result_cache.dart';
import 'package:horceracing_ticket_qr_reader/race_result_fetcher.dart';
import 'package:horceracing_ticket_qr_reader/scan_history_service.dart';
import 'package:horceracing_ticket_qr_reader/ticket_result_view.dart';

const _sampleHtml = '''
<html><body>
<div class="data_intro">
<dl class="racedata fc">
<dt>11 R</dt>
<dd>
<h1>プリンシパルS(L)</h1>
</dd>
</dl>
<p class="smalltxt">2025年05月04日 2回東京4日目</p>
</div>
<table class="race_table_01 nk_tb_common">
<tr><th>着</th><th>枠</th><th>馬番</th><th>馬名</th></tr>
<tr>
<td class="txt_r">1</td>
<td class="w2ml"><span>2</span></td>
<td class="txt_r">12</td>
<td class="txt_l"><a href="/horse/2022100001/">テストホース</a></td>
</tr>
</table>
<dl class="pay_block">
<table class="pay_table_01" summary="払い戻し">
<tr>
<th class="tan">単勝</th>
<td>12</td>
<td class="txt_r">620</td>
<td class="txt_r">3</td>
</tr>
</table>
</dl>
</body></html>
''';

void main() {
  late Directory historyDir;
  late Directory cacheDir;

  setUp(() async {
    historyDir = await Directory.systemTemp.createTemp('history_ui_');
    cacheDir = await Directory.systemTemp.createTemp('race_cache_ui_');
    ScanHistoryService.debugDirectory = historyDir;
    RaceResultCache.debugDirectory = cacheDir;
  });

  tearDown(() async {
    ScanHistoryService.debugDirectory = null;
    RaceResultCache.debugDirectory = null;
    if (await historyDir.exists()) {
      await historyDir.delete(recursive: true);
    }
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  testWidgets('HistoryPage shows empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HistoryPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('読み取り履歴'), findsOneWidget);
    expect(find.text('履歴はありません'), findsOneWidget);
  });

  testWidgets('HistoryPage lists title with race name', (tester) async {
    await ScanHistoryService.add({
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
    });

    await tester.pumpWidget(const MaterialApp(home: HistoryPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('東京 11R プリンシパルS(L)'), findsOneWidget);
    expect(find.textContaining('通常'), findsOneWidget);
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

  testWidgets('TicketResultView shows hit summary from cached race result', (
    tester,
  ) async {
    const url = 'https://db.netkeiba.com/race/202505020411';
    final result = RaceResultFetcher.parseHtml(_sampleHtml, url);
    await RaceResultCache.write(url, result);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TicketResultView(
              data: {
                '開催場': '東京',
                '年': 25,
                '回': 2,
                '日': 4,
                'レース': 11,
                'URL': url,
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('的中あり'), findsOneWidget);
    expect(find.textContaining('プリンシパルS(L)'), findsWidgets);
  });

  testWidgets('HitColors follow ColorScheme in light and dark', (tester) async {
    late Color lightFg;
    late Color darkFg;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
        ),
        home: Builder(
          builder: (context) {
            lightFg = HitColors.foreground(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        ),
        home: Builder(
          builder: (context) {
            darkFg = HitColors.foreground(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(lightFg, isNot(equals(darkFg)));
    expect(lightFg, isNot(equals(Colors.red.shade700)));
  });
}
