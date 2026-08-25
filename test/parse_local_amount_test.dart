import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';

void main() {
  test('地方 馬番連単の購入金額を200円と読む', () {
    final result = parseHorseracingTicketQrLocal(
      '1621000711000405000000774142200068573120333259418110400000036040600002000012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890160654',
    );

    expect(result['開催場'], '川崎');
    expect(result['発売所'], '川崎競馬場');
    expect(result['券種'], '通常');

    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(2));

    final win = purchases[0] as Map;
    expect(win['式別'], '単勝');
    expect(win['馬番'], [4]);
    expect(win['購入金額'], 300);

    final exacta = purchases[1] as Map;
    expect(exacta['式別'], '馬番連単');
    expect(exacta['馬番'], [4, 6]);
    expect(exacta['購入金額'], 200);
    expect(exacta.containsKey('ウラ'), isFalse);
  });

  test('川崎発売のJRA京都通常馬券を読む', () {
    final result = parseHorseracingTicketQrLocal(
      '5081000801000111000011704144000098133120332271310210300000000510300000000250103000000500001234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560554',
    );

    expect(result['開催場'], 'JRA京都');
    expect(result['発売所'], '川崎競馬場');
    expect(result['年'], 8);
    expect(result['回'], 1);
    expect(result['日'], 1);
    expect(result['レース'], 11);
    expect(result['券種'], '通常');
    expect(result['URL'], 'https://db.netkeiba.com/race/202608010111');

    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(3));

    expect(purchases[0], {
      '式別': '単勝',
      '馬番': [3],
      '購入金額': 500,
    });
    expect(purchases[1], {
      '式別': '単勝',
      '馬番': [3],
      '購入金額': 200,
    });
    expect(purchases[2], {
      '式別': '普通馬複',
      '馬番': [1, 3],
      '購入金額': 500,
    });
  });

  test('船橋 馬3連複3点と複勝の金額を読む', () {
    final result = parseHorseracingTicketQrLocal(
      '3571000708000107000001854131039205373130899783812380410110000180809100000180809110000120400000000100001234567890123456789012345678901234567890123456789012345678901234567890123456789012360606',
    );

    expect(result['開催場'], '船橋');
    expect(result['発売所'], '船橋競馬場');
    expect(result['券種'], '通常');

    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(4));

    expect(purchases[0], {
      '式別': '馬3連複',
      '馬番': [4, 10, 11],
      '購入金額': 100,
    });
    expect(purchases[1], {
      '式別': '馬3連複',
      '馬番': [8, 9, 10],
      '購入金額': 100,
    });
    expect(purchases[2], {
      '式別': '馬3連複',
      '馬番': [8, 9, 11],
      '購入金額': 100,
    });
    expect(purchases[3], {
      '式別': '複勝',
      '馬番': [4],
      '購入金額': 100,
    });
  });
}
