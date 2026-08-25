import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/bet_type.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  test('馬3連単 1着ながし（11 > 2, 3, 10 > 2, 3, 10）', () {
    final result = parseHorseracingTicketQrLocal(
      '4621000711000410200008334144073426603120335934913994000000000010000000011000000100000000011000000100000000000020000012345678901234567890123456789012345678901234567890123456789012345678960482',
    );
    expect(result['券種'], 'ながし');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['ながし'], '1着ながし');
    expect(purchase['馬番'], [
      [11],
      [2, 3, 10],
      [2, 3, 10],
    ]);
    expect(purchase['購入金額'], 200);
  });

  test('馬3連単ボックスはカンマ区切りで点数を数える', () {
    final result = parseHorseracingTicketQrLocal(
      '3361000720000508100001104110158703272600924301516390408100000000000000000001000012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560613',
    );
    expect(result['券種'], 'ボックス');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['馬番'], [4, 8, 10]);
    expect(purchase['購入金額'], 100);
    expect(
      TicketPayoutChecker.summarizePurchase(result, purchase).combinationCount,
      6, // P(3,3)=6
    );
  });

  test('枠番連単ボックス', () {
    final result = parseHorseracingTicketQrLocal(
      '1611000515000410100501823051170034143000022421614640306000000000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560632',
    );
    expect(result['券種'], 'ボックス');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '枠番連単');
    expect(purchase['馬番'], [3, 6]);
    expect(normalizeBetType(purchase['式別'] as String), '枠単');
  });

  test('馬番連単ウラあり', () {
    final result = parseHorseracingTicketQrLocal(
      '4611000108000211023869981007520018174970373484514361413010000100001234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123412345678901234560707',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬番連単');
    expect(purchase['馬番'], [14, 13]);
    expect(purchase['ウラ'], 'あり');
    expect(purchase['購入金額'], 100);
  });

  test('枠番連単 平成29年券', () {
    final result = parseHorseracingTicketQrLocal(
      '1561002902000509011415261021770042733110689701714340707000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345612345678901234560701',
    );
    expect(result['開催場'], '浦和');
    expect(result['年'], 29);
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '枠番連単');
    expect(purchase['馬番'], [7, 7]);
    expect(purchase['購入金額'], 100);
  });

  test('馬3連複 軸2頭ながし', () {
    final result = parseHorseracingTicketQrLocal(
      '3361000720000505200002064110181250432600923861913283000000010000000000000000001000000000000011000000000000000010000012345678901234567890123456789012345678901234567890123456789012345678960461',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連複');
    expect(purchase['ながし'], '軸2頭ながし');
    expect(purchase['軸'], [8, 9]);
    expect(purchase['相手'], [5, 6]);
    expect(purchase['購入金額'], 100);
  });

  test('馬3連複 軸1頭ながし', () {
    final result = parseHorseracingTicketQrLocal(
      '4571000104000411221349011020259393454000217594317687000000000100000000000000000000000000010010010000000000000010000012345678901234567890123456789012345678901234567890123456789012345678960483',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連複');
    expect(purchase['ながし'], '軸1頭ながし');
    expect(purchase['軸'], [10]);
    expect(purchase['相手'], [2, 5, 8]);
    expect(purchase['購入金額'], 100);
  });

  test('枠番連複ながし 8→1', () {
    final result = parseHorseracingTicketQrLocal(
      '5031000102000812220517801020265642614000231214619731000000010000000000000000000000000000100000000000000000000010000012345678901234567890123456789012345678901234567890123456789012345678960451',
    );
    expect(result['券種'], 'ながし');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '枠番連複');
    expect(purchase['ながし'], 'ながし');
    expect(purchase['軸'], [8]);
    expect(purchase['相手'], [1]);
    expect(purchase['購入金額'], 100);
  });

  test('フォーマット1 枠番連複ながし 1→2,4,5,7,8 各100円', () {
    final result = parseHorseracingTicketQrLocal(
      '1131000113000610209867881003098282644800533299315331010000101011011000000000089012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560663',
    );
    expect(result['券種'], 'ながし');
    expect(result['開催場'], '園田');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '枠番連複');
    expect(purchase['ながし'], 'ながし');
    expect(purchase['軸'], 1);
    expect(purchase['相手'], [2, 4, 5, 7, 8]);
    expect(purchase['購入金額'], 100);
    expect(
      TicketPayoutChecker.summarizePurchase(result, purchase).combinationCount,
      5,
    );
  });

  test('普通馬複ながし 5→6,9,11,13 各100円', () {
    final result = parseHorseracingTicketQrLocal(
      '1571000708000110200007734130185769583130903760214551050000100000100101010000000001234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123460633',
    );
    expect(result['券種'], 'ながし');
    expect(result['開催場'], '船橋');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '普通馬複');
    expect(purchase['ながし'], 'ながし');
    expect(purchase['軸'], 5);
    expect(purchase['相手'], [6, 9, 11, 13]);
    expect(purchase['購入金額'], 100);
    expect(
      TicketPayoutChecker.summarizePurchase(result, purchase).combinationCount,
      4,
    );
  });

  test('応援馬券 14番 単勝・複勝各100円', () {
    final result = parseHorseracingTicketQrLocal(
      '5071000103000811520442291020290099964000231398211511400000012140000001000012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890160658',
    );
    expect(result['券種'], '応援馬券');
    expect(result['開催場'], 'JRA中京');
    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(2));
    expect(purchases[0], {
      '式別': '単勝',
      '馬番': [14],
      '購入金額': 100,
    });
    expect(purchases[1], {
      '式別': '複勝',
      '馬番': [14],
      '購入金額': 100,
    });
  });
}
