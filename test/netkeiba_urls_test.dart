import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/netkeiba_urls.dart';

void main() {
  test('raceIdFromDbUrl extracts id', () {
    expect(
      NetkeibaUrls.raceIdFromDbUrl(
        'https://db.netkeiba.com/race/202607030112',
      ),
      '202607030112',
    );
  });

  test('isJraRaceId uses jyo code 01-10', () {
    expect(NetkeibaUrls.isJraRaceId('202607030112'), isTrue);
    expect(NetkeibaUrls.isJraRaceId('202665010901'), isFalse);
  });

  test('displayUrls adds JRA result page from 2008', () {
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/202607030112'),
      [
        'https://db.netkeiba.com/race/202607030112',
        'https://race.netkeiba.com/race/result.html?race_id=202607030112',
      ],
    );
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/200707030112'),
      ['https://db.netkeiba.com/race/200707030112'],
    );
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/200807030112'),
      [
        'https://db.netkeiba.com/race/200807030112',
        'https://race.netkeiba.com/race/result.html?race_id=200807030112',
      ],
    );
  });

  test('displayUrls adds NAR result page from 2016', () {
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/202665010901'),
      [
        'https://db.netkeiba.com/race/202665010901',
        'https://nar.netkeiba.com/race/result.html?race_id=202665010901',
      ],
    );
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/201565010901'),
      ['https://db.netkeiba.com/race/201565010901'],
    );
    expect(
      NetkeibaUrls.displayUrls('https://db.netkeiba.com/race/201665010901'),
      [
        'https://db.netkeiba.com/race/201665010901',
        'https://nar.netkeiba.com/race/result.html?race_id=201665010901',
      ],
    );
  });
}
