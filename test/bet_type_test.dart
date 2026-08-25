import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/bet_type.dart';
import 'package:horceracing_ticket_qr_reader/race_result.dart';
import 'package:horceracing_ticket_qr_reader/ticket_payout_checker.dart';

void main() {
  test('normalizeBetType maps local names to netkeiba names', () {
    expect(normalizeBetType('枠番連複'), '枠連');
    expect(normalizeBetType('枠番連単'), '枠単');
    expect(normalizeBetType('枠連複'), '枠連');
    expect(normalizeBetType('枠連単'), '枠単');
    expect(normalizeBetType('普通馬複'), '馬連');
    expect(normalizeBetType('馬番連単'), '馬単');
    expect(normalizeBetType('馬3連複'), '三連複');
    expect(normalizeBetType('馬3連単'), '三連単');
    expect(normalizeBetType('3連複'), '三連複');
    expect(normalizeBetType('3連単'), '三連単');
    expect(normalizeBetType('単勝'), '単勝');
  });

  test('isUnorderedBetType covers 馬連 枠連 ワイド 三連複', () {
    expect(isUnorderedBetType('普通馬複'), isTrue);
    expect(isUnorderedBetType('枠番連複'), isTrue);
    expect(isUnorderedBetType('ワイド'), isTrue);
    expect(isUnorderedBetType('馬3連複'), isTrue);
    expect(isUnorderedBetType('馬番連単'), isFalse);
    expect(isUnorderedBetType('単勝'), isFalse);
  });

  test('checkPurchase uses local bet type aliases against netkeiba payouts', () {
    final race = RaceResult(
      url: 'https://db.netkeiba.com/race/dummy',
      hasResults: true,
      payoutsByBetType: {
        '馬単': [
          const PayoutEntry(
            combinationKey: '3>7',
            combinationLabel: '3 → 7',
            payoutPer100Yen: 1200,
          ),
        ],
        '馬連': [
          const PayoutEntry(
            combinationKey: '3-7',
            combinationLabel: '3 - 7',
            payoutPer100Yen: 800,
          ),
        ],
        '枠連': [
          const PayoutEntry(
            combinationKey: '2-5',
            combinationLabel: '2 - 5',
            payoutPer100Yen: 500,
          ),
        ],
        '枠単': [
          const PayoutEntry(
            combinationKey: '2>5',
            combinationLabel: '2 → 5',
            payoutPer100Yen: 900,
          ),
        ],
        '三連複': [
          const PayoutEntry(
            combinationKey: '1-3-7',
            combinationLabel: '1 - 3 - 7',
            payoutPer100Yen: 5000,
          ),
        ],
        '三連単': [
          const PayoutEntry(
            combinationKey: '3>7>1',
            combinationLabel: '3 → 7 → 1',
            payoutPer100Yen: 20000,
          ),
        ],
      },
    );

    final ticket = {'券種': '通常'};

    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '馬番連単',
          '馬番': [3, 7],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      1200,
    );
    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '普通馬複',
          '馬番': [3, 7],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      800,
    );
    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '枠番連複',
          '馬番': [2, 5],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      500,
    );
    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '枠番連単',
          '馬番': [2, 5],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      900,
    );
    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '馬3連複',
          '馬番': [1, 3, 7],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      5000,
    );
    expect(
      TicketPayoutChecker.checkPurchase(
        ticket,
        {
          '式別': '馬3連単',
          '馬番': [3, 7, 1],
          '購入金額': 100,
        },
        race,
      ).payoutYen,
      20000,
    );
  });
}
