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
    expect(result.payoutsFor('3連単').single.combinationKey, '12>2>1');
    expect(result.payoutsFor('3連単').single.combinationLabel, '12 → 2 → 1');
    expect(result.payoutsFor('馬連').single.combinationLabel, '2 - 12');
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
}
