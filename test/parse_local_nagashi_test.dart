import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/parse.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';

void main() {
  test('地方 馬3連単 1・2着ながし', () {
    final result = parseHorseracingTicketQrLocal(
      '3621000711000404200000684140781761573120332501318793000000100000000000000010000000000000110000010010000000000010000012345678901234567890123456789012345678901234567890123456789012345678960475',
    );
    expect(result['券種'], 'ながし');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['ながし'], '1・2着ながし');
    expect(purchase['馬番'], [
      [7],
      [5],
      [1, 2, 8, 11],
    ]);
    expect(purchase['購入金額'], 100);
    expect(result['マルチ'], 'なし');
  });

  test('地方 馬3連単 1・3着ながし', () {
    final result = parseHorseracingTicketQrLocal(
      '3611000108000207220490221007531577964970373520614595000000100000000000000010000000000000000001000000000000000012345678901234567890123456789012345678901234567890123456789012345678901234560510',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['ながし'], '1・3着ながし');
    expect(purchase['馬番'], [
      [7],
      [5],
      [6],
    ]);
  });

  test('地方 馬3連単 3着ながし', () {
    final result = parseHorseracingTicketQrLocal(
      '4131000114000610217789551007746300294970613524812796010010000000000000010010000000000000000000010000000000000010345678901234567890123456789012345678901234567890123456789012345678901234560518',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬3連単');
    expect(purchase['ながし'], '3着ながし');
    expect(purchase['馬番'], [
      [2, 5],
      [2, 5],
      [8],
    ]);
  });

  test('JRA 3連単 1・2着ながしは従来どおり', () {
    final result = parseHorseracingTicketQr(
      '5060002504051020105873185426323830030665219100000100000000000010000000000000000001111011100000000000001056789012345678901234567890123456789012345678901234567890123456789012345678901234560513',
    );
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '3連単');
    expect(purchase['ながし'], '1・2着ながし');
    expect(purchase['馬番'], [
      [6],
      [1],
      [2, 3, 4, 5, 7, 8, 9],
    ]);
  });
}
