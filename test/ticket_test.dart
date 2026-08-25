import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/ticket.dart';

void main() {
  test('Ticket round-trips Japanese-key maps', () {
    final original = {
      'QR': 'abc',
      '開催場': '東京',
      '年': 26,
      '回': 1,
      '日': 2,
      'レース': 11,
      '券種': 'ながし',
      'マルチ': 'あり',
      '購入内容': [
        {
          '式別': '馬単',
          '購入金額': 100,
          'ながし': '1着ながし',
          '軸': 5,
          '相手': [1, 2, 3],
          'ウラ': 'なし',
        },
      ],
    };

    final ticket = Ticket.fromMap(original);
    expect(ticket.venueName, '東京');
    expect(ticket.multi, isTrue);
    expect(ticket.purchases.single.axis!.values, [5]);
    expect(ticket.purchases.single.partners, [1, 2, 3]);

    final restored = Ticket.fromMap(ticket.toMap());
    expect(restored.toMap()['開催場'], '東京');
    expect(restored.toMap()['マルチ'], 'あり');
    expect(restored.purchases.single.betType, '馬単');
  });

  test('semanticNumbersDescription explains nagashi', () {
    final item = PurchaseItem.fromMap({
      '式別': '馬単',
      'ながし': '1着ながし',
      '軸': 7,
      '相手': [1, 2],
    });

    expect(
      item.semanticNumbersDescription(numberIsFrame: false),
      '1着ながし。軸 馬番7。相手 馬番1と馬番2',
    );
  });

  test('nested formation numbers semantic summary', () {
    final item = PurchaseItem.fromMap({
      '式別': '3連単',
      '馬番': [
        [1, 2],
        [3],
        [4, 5],
      ],
    });

    expect(
      item.semanticNumbersDescription(numberIsFrame: false),
      '1着候補 馬番1と馬番2。2着候補 馬番3。3着候補 馬番4と馬番5',
    );
  });
}
