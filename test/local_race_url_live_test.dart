@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/local_race_url.dart';

void main() {
  test(
    'resolves 帯広 令和7年度 20回5日 to db.netkeiba URL',
    () async {
      final url = await LocalRaceUrlResolver.resolve(
        racecourseCode: '36',
        venueName: '帯広',
        year: 7,
        round: 20,
        day: 5,
        race: 1,
      );
      expect(url, 'https://db.netkeiba.com/race/202665010901');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
