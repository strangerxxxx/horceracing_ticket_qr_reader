/// netkeiba のレース URL（DB / 中央結果 / 地方結果）を組み立てる。
class NetkeibaUrls {
  static final _dbRaceIdPattern = RegExp(
    r'db\.netkeiba\.com/race/(\d+)',
    caseSensitive: false,
  );

  static const dbRaceBase = 'https://db.netkeiba.com/race/';
  static const jraResultBase =
      'https://race.netkeiba.com/race/result.html?race_id=';
  static const narResultBase =
      'https://nar.netkeiba.com/race/result.html?race_id=';

  /// `https://db.netkeiba.com/race/{id}` から race_id を取り出す。
  static String? raceIdFromDbUrl(String url) =>
      _dbRaceIdPattern.firstMatch(url)?.group(1);

  static int? westernYearFromRaceId(String raceId) {
    if (raceId.length < 4) return null;
    return int.tryParse(raceId.substring(0, 4));
  }

  /// race_id の場コードが中央（01〜10）か。
  static bool isJraRaceId(String raceId) {
    if (raceId.length < 6) return false;
    final jyo = int.tryParse(raceId.substring(4, 6));
    return jyo != null && jyo >= 1 && jyo <= 10;
  }

  static String dbUrl(String raceId) => '$dbRaceBase$raceId';

  static String jraResultUrl(String raceId) => '$jraResultBase$raceId';

  static String narResultUrl(String raceId) => '$narResultBase$raceId';

  /// 表示用 URL 一覧（先頭は常に DB。条件を満たせば結果ページも付ける）。
  ///
  /// - 中央・2008年以降: [race.netkeiba.com 結果](https://race.netkeiba.com/race/result.html?race_id=)
  /// - 地方・2016年以降: [nar.netkeiba.com 結果](https://nar.netkeiba.com/race/result.html?race_id=)
  static List<String> displayUrls(String dbUrl) {
    final raceId = raceIdFromDbUrl(dbUrl);
    if (raceId == null) return [dbUrl];

    final year = westernYearFromRaceId(raceId);
    if (year == null) return [dbUrl];

    final urls = <String>[dbUrl];
    if (isJraRaceId(raceId) && year >= 2008) {
      urls.add(jraResultUrl(raceId));
    }
    if (!isJraRaceId(raceId) && year >= 2016) {
      urls.add(narResultUrl(raceId));
    }
    return urls;
  }
}
