import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/jra_official_result_fetcher.dart';
import 'package:horceracing_ticket_qr_reader/race_netkeiba_result_parser.dart';
import 'package:horceracing_ticket_qr_reader/race_result.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  test('race.netkeiba Torikeshi row yields refunded horse and frame', () {
    const html = '''
<tr class="Torikeshi HorseList">
<td class="Result_Num"><div class="Rank">除外</div></td>
<td class="Num Waku4"><div>4</div></td>
<td class="Num Txt_C"><div>7</div></td>
<td class="Horse_Info"><span class="Horse_Name">
<span class="HorseNameSpan">テーオーローズ</span></span></td>
</tr>
''';
    final parsed = RaceNetkeibaResultParser.parseRefundedHorses(html);
    expect(parsed.horses, {7});
    expect(parsed.frames[7], 4);
    expect(parsed.names[7], 'テーオーローズ');
  });

  test('JRA HTML 除外行と返還告知から馬番7を読む', () {
    const html = '''
<table><tr>
<td class="place">除外</td>
<td class="waku"><img alt="枠4青" /></td>
<td class="num">7</td>
<td class="horse"><a href="#">テーオーローズ</a></td>
</tr>
<tr>
<td class="place">13</td>
<td class="waku"><img alt="枠4青" /></td>
<td class="num">6</td>
<td class="horse"><a href="#">他馬</a></td>
</tr></table>
<div><dt>返還</dt><dd><p><strong class="red">返還馬番　7番　返還同枠　4枠</strong></p></dd></div>
<div class="refund_area"><ul><li class="win"><dl><dt>単勝</dt><dd>
<div class="line"><div class="num">15</div><div class="yen">500<span class="unit">円</span></div></div>
</dd></dl></li></ul></div>
''';
    final result = JraOfficialResultFetcher.parseHtml(
      html,
      'https://db.netkeiba.com/race/202609040704',
    );
    expect(result.refundedHorseNumbers, {7});
    expect(result.frameByHorseNumber[7], 4);
    expect(result.frameByHorseNumber[6], 4);
  });

  test('馬番を含む組合せだけ返還（全通りではない）', () {
    final race = RaceResult(
      url: 'https://example.com',
      hasResults: true,
      refundedHorseNumbers: {3},
      payoutsByBetType: {
        '三連単': [
          const PayoutEntry(
            combinationKey: '1>5>4',
            combinationLabel: '1 → 5 → 4',
            payoutPer100Yen: 1000,
          ),
        ],
      },
    );

    final ticket = {'券種': '通常'};
    final withRefund = TicketPayoutChecker.checkPurchase(
      ticket,
      {
        '式別': '3連単',
        '馬番': [1, 5, 3],
        '購入金額': 200,
      },
      race,
    );
    expect(withRefund.hit, isFalse);
    expect(withRefund.hasRefund, isTrue);
    expect(withRefund.refundYen, 200);
    expect(withRefund.refundedLabels, isNotEmpty);

    final withoutRefund = TicketPayoutChecker.checkPurchase(
      ticket,
      {
        '式別': '3連単',
        '馬番': [1, 5, 4],
        '購入金額': 200,
      },
      race,
    );
    expect(withoutRefund.hit, isTrue);
    expect(withoutRefund.hasRefund, isFalse);
    expect(withoutRefund.payoutYen, 2000);
  });

  test('枠連は同枠に他馬1頭ならゾロ目のみ返還', () {
    final race = RaceResult(
      url: 'https://example.com',
      hasResults: true,
      refundedHorseNumbers: {7},
      frameByHorseNumber: {
        6: 4,
        7: 4,
        1: 1,
        2: 2,
      },
      payoutsByBetType: {
        '枠連': [
          const PayoutEntry(
            combinationKey: '2-4',
            combinationLabel: '2 - 4',
            payoutPer100Yen: 800,
          ),
        ],
      },
    );

    final ticket = {'券種': '通常'};
    final sameFrame = TicketPayoutChecker.checkPurchase(
      ticket,
      {
        '式別': '枠連',
        '馬番': [4, 4],
        '購入金額': 100,
      },
      race,
    );
    expect(sameFrame.hasRefund, isTrue);
    expect(sameFrame.refundYen, 100);
    expect(sameFrame.hit, isFalse);

    final other = TicketPayoutChecker.checkPurchase(
      ticket,
      {
        '式別': '枠連',
        '馬番': [2, 4],
        '購入金額': 100,
      },
      race,
    );
    expect(other.hasRefund, isFalse);
    expect(other.hit, isTrue);
    expect(other.payoutYen, 800);
  });

  test('ボックス三連複は取消馬を含む点だけ返還', () {
    final race = RaceResult(
      url: 'https://example.com',
      hasResults: true,
      refundedHorseNumbers: {1},
      payoutsByBetType: {
        '三連複': [
          const PayoutEntry(
            combinationKey: '4-6-10',
            combinationLabel: '4 - 6 - 10',
            payoutPer100Yen: 5000,
          ),
        ],
      },
    );

    final result = TicketPayoutChecker.checkPurchase(
      {
        '券種': 'ボックス',
      },
      {
        '式別': '3連複',
        '馬番': [1, 4, 6, 10],
        '購入金額': 100,
      },
      race,
    );

    // C(4,3)=4点。1を含む3点返還、4-6-10 は的中
    expect(result.hasRefund, isTrue);
    expect(result.refundYen, 300);
    expect(result.hit, isTrue);
    expect(result.payoutYen, 5000);
    expect(result.totalReturnYen, 5300);
  });
}
