import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/race_result_fetcher.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  const sampleHtml = '''
<html><body>
<dl class="pay_block">
<table class="pay_table_01" summary="払い戻し">
<tr>
<th class="tan">単勝</th>
<td>12</td>
<td class="txt_r">620</td>
<td class="txt_r">3</td>
</tr>
<tr>
<th class="fuku" align="center">複勝</th>
<td>12<br />2<br />1</td>
<td class="txt_r">220<br />1,200<br />1,440</td>
<td class="txt_r">3<br />11<br />13</td>
</tr>
<tr>
<th class="uren" align="center">馬連</th>
<td>2 - 12</td>
<td class="txt_r">22,790</td>
<td class="txt_r">53</td>
</tr>
<tr>
<th class="utan">馬単</th>
<td>12 → 2</td>
<td class="txt_r">37,200</td>
<td class="txt_r">92</td>
</tr>
<tr>
<th class="sanfuku">三連複</th>
<td>1 - 2 - 12</td>
<td class="txt_r">326,620</td>
<td class="txt_r">300</td>
</tr>
<tr>
<th class="santan">三連単</th>
<td>12 → 2 → 1</td>
<td class="txt_r">1,367,210</td>
<td class="txt_r">1549</td>
</tr>
</table>
</dl>
</body></html>
''';

  test('parseHtml extracts payouts', () {
    final result = RaceResultFetcher.parseHtml(
      sampleHtml,
      'https://db.netkeiba.com/race/202505020411',
    );

    expect(result.hasResults, isTrue);
    expect(result.payoutsFor('単勝').single.combinationKey, '12');
    expect(result.payoutsFor('単勝').single.payoutPer100Yen, 620);
    expect(result.payoutsFor('複勝').map((e) => e.combinationKey), ['12', '2', '1']);
    expect(result.payoutsFor('馬連').single.combinationKey, '2-12');
    expect(result.payoutsFor('馬単').single.combinationKey, '12>2');
    expect(result.payoutsFor('馬単').single.combinationLabel, '12 → 2');
    expect(result.payoutsFor('三連単').single.combinationKey, '12>2>1');
    expect(result.payoutsFor('三連単').single.combinationLabel, '12 → 2 → 1');
    expect(result.payoutsFor('馬連').single.combinationLabel, '2 - 12');
    expect(result.payoutsFor('三連複').single.combinationKey, '1-2-12');
  });

  test('checkPurchase detects win and loss', () {
    final race = RaceResultFetcher.parseHtml(
      sampleHtml,
      'https://db.netkeiba.com/race/202505020411',
    );

    final ticket = {'券種': '通常'};
    final win = TicketPayoutChecker.checkPurchase(
      ticket,
      {'式別': '単勝', '馬番': [12], '購入金額': 100},
      race,
    );
    expect(win.hit, isTrue);
    expect(win.payoutYen, 620);

    final lose = TicketPayoutChecker.checkPurchase(
      ticket,
      {'式別': '単勝', '馬番': [5], '購入金額': 100},
      race,
    );
    expect(lose.hit, isFalse);
    expect(lose.payoutYen, 0);

    final exacta = TicketPayoutChecker.checkPurchase(
      ticket,
      {'式別': '馬単', '馬番': [12, 2], '購入金額': 200},
      race,
    );
    expect(exacta.hit, isTrue);
    expect(exacta.payoutYen, 74400);
  });

  test('summarizePurchase counts combinations and total stake', () {
    final normal = TicketPayoutChecker.summarizePurchase(
      {'券種': '通常'},
      {'式別': '単勝', '馬番': [5], '購入金額': 1000},
    );
    expect(normal.combinationCount, 1);
    expect(normal.totalAmountYen, 1000);

    final ura = TicketPayoutChecker.summarizePurchase(
      {'券種': '通常'},
      {'式別': '馬単', '馬番': [1, 2], 'ウラ': 'あり', '購入金額': 100},
    );
    expect(ura.combinationCount, 2);
    expect(ura.totalAmountYen, 200);

    final box = TicketPayoutChecker.summarizePurchase(
      {'券種': 'ボックス'},
      {'式別': '馬連', '馬番': [1, 2, 3, 4], '購入金額': 100},
    );
    // C(4,2) = 6
    expect(box.combinationCount, 6);
    expect(box.totalAmountYen, 600);

    final ticket = TicketPayoutChecker.summarizeTicket({
      '券種': '通常',
      '購入内容': [
        {'式別': '単勝', '馬番': [1], '購入金額': 500},
        {'式別': '複勝', '馬番': [2], '購入金額': 200},
      ],
    });
    expect(ticket.totalCombinationCount, 2);
    expect(ticket.totalAmountYen, 700);
  });

  test('3連単 1・2着ながし マルチは基本点×6', () {
    // 馬番: 1着=10, 2着=14, 3着=1,2 → 基本2点
    // マルチあり → 2 × 6 = 12点
    final summary = TicketPayoutChecker.summarizePurchase(
      {'券種': 'ながし', 'マルチ': 'あり'},
      {
        '式別': '3連単',
        'ながし': '1・2着ながし',
        '馬番': [
          [10],
          [14],
          [1, 2],
        ],
        '購入金額': 100,
      },
    );
    expect(summary.combinationCount, 12);
    expect(summary.totalAmountYen, 1200);

    final combos = TicketPayoutChecker.expandCombinations(
      ticketType: 'ながし',
      betType: '3連単',
      purchase: {
        'ながし': '1・2着ながし',
        '馬番': [
          [10],
          [14],
          [1, 2],
        ],
      },
      multi: true,
    );
    expect(combos.length, 12);
    expect(combos.contains('10>14>1'), isTrue);
    expect(combos.contains('1>10>14'), isTrue);
    expect(combos.contains('10>14>2'), isTrue);
    expect(combos.contains('2>14>10'), isTrue);
  });
}
