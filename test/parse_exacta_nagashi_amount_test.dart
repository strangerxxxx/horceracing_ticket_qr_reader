import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/parse.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  test('馬単ながしの購入金額を読み取れる', () {
    // 1着ながし: 軸4 / 相手5,14 / 500円 × 2点
    final first = parseHorseracingTicketQr(
      '3090001704021220098511194685090900151611246100010000000000000000000000000000000000001000000001000000005456789012345678901234567890123456789012345678901234567890123456789012345678901234560517',
    );
    expect(first['券種'], 'ながし');
    final firstPurchase = (first['購入内容'] as List).first as Map;
    expect(firstPurchase['式別'], '馬単');
    expect(firstPurchase['ながし'], '1着ながし');
    expect(firstPurchase['軸'], [4]);
    expect(firstPurchase['相手'], [5, 14]);
    expect(firstPurchase['購入金額'], 500);
    final firstSummary = TicketPayoutChecker.summarizeTicket(first);
    expect(firstSummary.totalCombinationCount, 2);
    expect(firstSummary.totalAmountYen, 1000);

    // 2着ながし: 軸15 / 相手9 / 100円 × 1点
    final second = parseHorseracingTicketQr(
      '3070001903071020128275992986070700072985616200000000000000100000000000000000000000000000100000000000001456789012345678901234567890123456789012345678901234567890123456789012345678901234560539',
    );
    expect(second['券種'], 'ながし');
    final secondPurchase = (second['購入内容'] as List).first as Map;
    expect(secondPurchase['式別'], '馬単');
    expect(secondPurchase['ながし'], '2着ながし');
    expect(secondPurchase['軸'], [15]);
    expect(secondPurchase['相手'], [9]);
    expect(secondPurchase['購入金額'], 100);
    final secondSummary = TicketPayoutChecker.summarizeTicket(second);
    expect(secondSummary.totalCombinationCount, 1);
    expect(secondSummary.totalAmountYen, 100);
  });
}
