import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/http_fetch.dart';
import 'package:horceracing_ticket_qr_reader/race_netkeiba_result_parser.dart';
import 'package:horceracing_ticket_qr_reader/race_result_fetcher.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';
import 'package:horceracing_ticket_qr_reader/ticket_qr_parse.dart';

/// 地方馬券の返還サンプル（ネットワーク必須）
void main() {
  test('Oi umaren with scratched #4 is refunded', () async {
    final ticket = parseTicketFromPastedText(
      '1611000317000312003772201055410085993020811877216550406000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890160708',
    )!;
    expect(ticket['開催場'], '大井');
    expect(ticket['購入内容'], isNotEmpty);

    final race = await RaceResultFetcher.fetch(
      'https://db.netkeiba.com/race/202244020912',
    );
    // db に取消が無くても nar 補完で 4 番が入る想定
    expect(race.refundedHorseNumbers.contains(4), isTrue);

    final check = TicketPayoutChecker.checkPurchase(
      ticket,
      ticket['購入内容'].first,
      race,
    );
    expect(check.hasRefund, isTrue);
    expect(check.refundYen, 100);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Kawasaki wide 3-7 with scratched #3 is refunded', () async {
    final ticket = parseTicketFromPastedText(
      '16210006040003100039845430421800131531211202716102703070000800001234567890123456789012345678901',
    )!;
    expect(ticket['開催場'], '川崎');

    final race = await RaceResultFetcher.fetch(
      'https://db.netkeiba.com/race/202445070310',
    );
    expect(race.refundedHorseNumbers.contains(3), isTrue);

    final check = TicketPayoutChecker.checkPurchase(
      ticket,
      ticket['購入内容'].first,
      race,
    );
    expect(check.hasRefund, isTrue);
    expect(check.refundYen, 800);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('nar.netkeiba Torikeshi HTML parses horse 3 for Kawasaki', () async {
    final response = await HttpFetch.get(
      Uri.parse(
        'https://nar.netkeiba.com/race/result.html?race_id=202445070310',
      ),
    );
    expect(response.statusCode, 200);
    final parsed =
        RaceNetkeibaResultParser.parseRefundedHorses(response.body);
    expect(parsed.horses.contains(3), isTrue);
    expect(parsed.frames[3], 3);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
