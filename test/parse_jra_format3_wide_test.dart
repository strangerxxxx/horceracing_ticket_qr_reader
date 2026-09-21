import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/parse.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';
import 'package:horceracing_ticket_qr_reader/ticket_qr_parse.dart';

void main() {
  // フォーマット3・通常: ワイド 8-10 200円 + 3連複 8-10-15 100円
  // （馬番欄の余りスロット00を読み飛ばさないと金額がズレる）
  const payload =
      '3060002604061000355450173495321330024711957081000000028081015000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234560678';

  test('format3 通常のワイド+3連複を正しく読む', () {
    final result = parseHorseracingTicketQr(payload);

    expect(result['開催場'], '中山');
    expect(result['年'], 26);
    expect(result['回'], 4);
    expect(result['日'], 6);
    expect(result['レース'], 10);
    expect(result['券種'], '通常');

    final purchases = result['購入内容'] as List;
    expect(purchases, hasLength(2));

    final wide = purchases[0] as Map;
    expect(wide['式別'], 'ワイド');
    expect(wide['馬番'], [8, 10]);
    expect(wide['購入金額'], 200);

    final trio = purchases[1] as Map;
    expect(trio['式別'], '3連複');
    expect(trio['馬番'], [8, 10, 15]);
    expect(trio['購入金額'], 100);

    final summary = TicketPayoutChecker.summarizeTicket(result);
    expect(summary.totalAmountYen, 300);
  });

  test('same payload parses via paste helper', () {
    final result = parseTicketFromPastedText(payload);
    expect(result, isNotNull);
    final purchases = result!['購入内容'] as List;
    expect(purchases, hasLength(2));
    expect((purchases[0] as Map)['購入金額'], 200);
    expect((purchases[1] as Map)['購入金額'], 100);
  });
}
