import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  test('フォーマット5 馬番連単の複数口と金額', () {
    final result = parseHorseracingTicketQrLocal(
      '5021000102000602018391091020310052014000229544617660711000000160712000000160709000000260710000000160107000000160103000000160108000000160112000000100001234567890123456789012345678901234560396',
    );
    expect(result['券種'], '通常');
    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(8));
    expect(purchases[0], {
      '式別': '馬番連単',
      '馬番': [7, 11],
      'ウラ': 'なし',
      '購入金額': 100,
    });
    expect(purchases[2], {
      '式別': '馬番連単',
      '馬番': [7, 9],
      'ウラ': 'なし',
      '購入金額': 200,
    });
    expect(purchases[7], {
      '式別': '馬番連単',
      '馬番': [1, 12],
      'ウラ': 'なし',
      '購入金額': 100,
    });
  });

  test('フォーマット1 馬番連単のウラあり', () {
    final result = parseHorseracingTicketQrLocal(
      '1611000110000511017789641007740083364970613732211260811000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345612345678901234560701',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬番連単');
    expect(purchase['馬番'], [8, 11]);
    expect(purchase['購入金額'], 100);
    expect(purchase['ウラ'], 'あり');
    expect(
      TicketPayoutChecker.summarizePurchase(result, purchase).combinationCount,
      2,
    );
  });

  test('馬番連単 1着ながし 5→2 100円', () {
    final result = parseHorseracingTicketQrLocal(
      '1131000114000610217789631007742594524970613731413161050000101000000000000000089012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560660',
    );
    expect(result['券種'], 'ながし');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬番連単');
    expect(purchase['ながし'], '1着ながし');
    expect(purchase['軸'], 5);
    expect(purchase['相手'], [2]);
    expect(purchase['購入金額'], 100);
  });

  test('馬番連単 2着ながし 13→14 100円', () {
    final result = parseHorseracingTicketQrLocal(
      '1491000105000610221592571007506563224970373420211062140000100000000000010000089012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560644',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬番連単');
    expect(purchase['ながし'], '2着ながし');
    expect(purchase['軸'], 14);
    expect(purchase['相手'], [13]);
    expect(purchase['購入金額'], 100);
    final keys = TicketPayoutChecker.summarizePurchase(result, purchase);
    expect(keys.combinationCount, 1);
  });

  test('フォーマット4 馬3連単 1・2着ながしマルチ', () {
    final result = parseHorseracingTicketQrLocal(
      '4131000113000608205117331001602997024800532290911191000001000000000000000000000100000000101100010000000000000011345678901234567890123456789012345678901234567890123456789012345678901234560483',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['ながし'], '1・2着ながし');
    expect(purchase['馬番'], [
      [6],
      [10],
      [1, 3, 4, 8],
    ]);
    expect(result['マルチ'], 'あり');
  });
}
