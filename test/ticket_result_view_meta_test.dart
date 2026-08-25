import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/ticket_result_view.dart';

void main() {
  Map<String, dynamic> ticketCore() => {
        '開催場': '東京',
        '場コード': '05',
        '年': 2026,
        '回': 2,
        '日': 1,
        'レース': 1,
        'URL': 'https://example.com/race',
        '券種': '通常',
        '購入内容': [
          {
            '式別': '単勝',
            '馬番': [1],
            '購入金額': 100,
          },
        ],
      };

  test('meta-only updates keep ticket core equal', () {
    final base = ticketCore();
    final withMeta = {
      ...base,
      'レース名': 'テストS',
      '開催日': '2026年5月2日',
      '購入合計': 100,
      '払戻合計': 0,
      '的中件数': 0,
      '結果取得済': true,
    };

    expect(ticketDataCoreEquals(base, withMeta), isTrue);
  });

  test('purchase change breaks ticket core equality', () {
    final a = ticketCore();
    final b = {
      ...ticketCore(),
      '購入内容': [
        {
          '式別': '複勝',
          '馬番': [2],
          '購入金額': 100,
        },
      ],
    };

    expect(ticketDataCoreEquals(a, b), isFalse);
  });

  test('identical maps are equal', () {
    final a = ticketCore();
    final b = ticketCore();
    expect(ticketDataCoreEquals(a, b), isTrue);
  });
}
