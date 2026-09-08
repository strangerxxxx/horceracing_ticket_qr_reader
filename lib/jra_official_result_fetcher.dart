import 'package:charset/charset.dart';

import 'http_fetch.dart';
import 'netkeiba_urls.dart';
import 'race_result.dart';
import 'race_result_fetcher.dart';

/// JRA 公式（jra.go.jp）のレース結果ページから払戻・馬名・メタを取得する。
///
/// 公式サイトは `cname` 付き POST でページ遷移する。チェックサムは推測せず、
/// 開催一覧 → レース一覧から実在する cname を拾う。
class JraOfficialResultFetcher {
  static const accessUrl = 'https://www.jra.go.jp/JRADB/accessS.html';
  static const meetingListCname = 'pw01sli00/AF';

  static const _betTypeByClass = {
    'win': '単勝',
    'place': '複勝',
    'wakuren': '枠連',
    'umaren': '馬連',
    'wide': 'ワイド',
    'umatan': '馬単',
    'trio': '三連複',
    'tierce': '三連単',
  };

  /// [raceId]（例: `202604030101`）から公式結果を取得する。
  /// [sourceUrl] はキャッシュキー用（通常は db.netkeiba の URL）。
  static Future<RaceResult> fetchByRaceId(
    String raceId, {
    required String sourceUrl,
  }) async {
    final parts = parseRaceId(raceId);
    if (parts == null) {
      return RaceResult(
        url: sourceUrl,
        payoutsByBetType: const {},
        hasResults: false,
        layoutRecognized: false,
      );
    }

    final meetingHtml = await _postHtml(meetingListCname);
    final meetingCname = findMeetingCname(meetingHtml, parts);
    if (meetingCname == null) {
      return RaceResult(
        url: sourceUrl,
        payoutsByBetType: const {},
        hasResults: false,
        layoutRecognized: false,
      );
    }

    final raceListHtml = await _postHtml(meetingCname);
    final detailCname = findRaceDetailCname(raceListHtml, parts);
    if (detailCname == null) {
      return RaceResult(
        url: sourceUrl,
        payoutsByBetType: const {},
        hasResults: false,
        layoutRecognized: false,
      );
    }

    final detailHtml = await _postHtml(detailCname);
    return parseHtml(detailHtml, sourceUrl);
  }

  /// race_id = YYYY + 場(2) + 回(2) + 日(2) + レース(2)
  static JraRaceIdParts? parseRaceId(String raceId) {
    if (!NetkeibaUrls.isJraRaceId(raceId) || raceId.length < 12) return null;
    final year = raceId.substring(0, 4);
    final jyo = raceId.substring(4, 6);
    final kai = raceId.substring(6, 8);
    final nichi = raceId.substring(8, 10);
    final race = raceId.substring(10, 12);
    if ([year, jyo, kai, nichi, race].any((e) => int.tryParse(e) == null)) {
      return null;
    }
    return JraRaceIdParts(
      year: year,
      jyo: jyo,
      kai: kai,
      nichi: nichi,
      race: race,
    );
  }

  /// 開催一覧 HTML から `pw01srl10...` を探す
  static String? findMeetingCname(String html, JraRaceIdParts parts) {
    final prefix = 'pw01srl10${parts.jyo}${parts.year}${parts.kai}${parts.nichi}';
    final pattern = RegExp(
      '${RegExp.escape(prefix)}\\d{8}/[0-9A-Fa-f]{2}',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(0);
  }

  /// レース一覧 HTML から `pw01sde10...` を探す
  static String? findRaceDetailCname(String html, JraRaceIdParts parts) {
    final prefix =
        'pw01sde10${parts.jyo}${parts.year}${parts.kai}${parts.nichi}${parts.race}';
    final pattern = RegExp(
      '${RegExp.escape(prefix)}\\d{8}/[0-9A-Fa-f]{2}',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(0);
  }

  /// テスト・デバッグ用に公開
  static RaceResult parseHtml(String html, String url) {
    final table = parseRaceTable(html);
    final meta = parseRaceMeta(html);
    final payoutsByBetType = parsePayouts(html);

    final hasTable = table.horseNamesByNumber.isNotEmpty;
    final hasMeta = (meta.raceName != null && meta.raceName!.isNotEmpty) ||
        (meta.raceDateLabel != null && meta.raceDateLabel!.isNotEmpty);
    final hasRefund = RegExp(
      r'class="[^"]*refund_area[^"]*"',
      caseSensitive: false,
    ).hasMatch(html);
    final layoutRecognized =
        hasTable || hasMeta || hasRefund || payoutsByBetType.isNotEmpty;

    return RaceResult(
      url: url,
      payoutsByBetType: payoutsByBetType,
      hasResults: payoutsByBetType.isNotEmpty,
      horseNamesByNumber: table.horseNamesByNumber,
      frameByHorseNumber: table.frameByHorseNumber,
      fieldSize: table.fieldSize,
      raceName: meta.raceName,
      raceDateLabel: meta.raceDateLabel,
      layoutRecognized: layoutRecognized,
    );
  }

  static Map<String, List<PayoutEntry>> parsePayouts(String html) {
    final areaMatch = RegExp(
      r'class="[^"]*refund_area[^"]*"[\s\S]*?(?=<div class="horse_prof_area"|<div class="bottom_nav_area"|$)',
      caseSensitive: false,
    ).firstMatch(html);
    if (areaMatch == null) return const {};

    final area = areaMatch.group(0)!;
    final payoutsByBetType = <String, List<PayoutEntry>>{};

    final itemPattern = RegExp(
      r'<li class="([^"]+)">\s*<dl>[\s\S]*?<dd>([\s\S]*?)</dd>',
      caseSensitive: false,
    );

    for (final match in itemPattern.allMatches(area)) {
      final className = match.group(1)!.split(RegExp(r'\s+')).first;
      final betType = _betTypeByClass[className];
      if (betType == null) continue;

      final entries = <PayoutEntry>[];
      final linePattern = RegExp(
        r'<div class="line">\s*'
        r'<div class="num">([^<]*)</div>\s*'
        r'<div class="yen">([\s\S]*?)</div>',
        caseSensitive: false,
      );

      for (final line in linePattern.allMatches(match.group(2)!)) {
        final rawLabel = _normalizeSpaces(line.group(1)!);
        if (rawLabel.isEmpty) continue;
        final payout = _parseYen(line.group(2)!);
        if (payout <= 0) continue;

        final key =
            RaceResultFetcher.normalizeCombinationKey(rawLabel, betType);
        if (key.isEmpty) continue;

        entries.add(
          PayoutEntry(
            combinationKey: key,
            combinationLabel:
                RaceResultFetcher.formatCombinationLabel(key, betType),
            payoutPer100Yen: payout,
          ),
        );
      }

      if (entries.isNotEmpty) {
        payoutsByBetType[betType] = entries;
      }
    }

    return payoutsByBetType;
  }

  static RaceMetaInfo parseRaceMeta(String html) {
    String? raceName;
    final nameMatch = RegExp(
      r'class="race_name"[^>]*>([\s\S]*?)</span>',
      caseSensitive: false,
    ).firstMatch(html);
    if (nameMatch != null) {
      final name = _normalizeSpaces(_stripTags(nameMatch.group(1)!));
      if (name.isNotEmpty) raceName = name;
    }

    String? raceDateLabel;
    final dateMatch = RegExp(
      r'class="cell date"[^>]*>([\s\S]*?)</div>',
      caseSensitive: false,
    ).firstMatch(html);
    if (dateMatch != null) {
      final raw = _normalizeSpaces(_stripTags(dateMatch.group(1)!));
      final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(raw);
      if (m != null) {
        final y = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final d = int.parse(m.group(3)!);
        raceDateLabel = '$y年$mo月$d日';
      }
    }

    return RaceMetaInfo(raceName: raceName, raceDateLabel: raceDateLabel);
  }

  static RaceTableInfo parseRaceTable(String html) {
    final names = <int, String>{};
    final frames = <int, int>{};

    final rowPattern = RegExp(r'<tr>([\s\S]*?)</tr>', caseSensitive: false);
    for (final rowMatch in rowPattern.allMatches(html)) {
      final row = rowMatch.group(1)!;
      final numMatch = RegExp(
        r'<td class="num"[^>]*>([\s\S]*?)</td>',
        caseSensitive: false,
      ).firstMatch(row);
      final horseMatch = RegExp(
        r'<td class="horse"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)</a>',
        caseSensitive: false,
      ).firstMatch(row);
      if (numMatch == null || horseMatch == null) continue;

      final number = int.tryParse(_normalizeSpaces(_stripTags(numMatch.group(1)!)));
      if (number == null || number <= 0) continue;

      final name = _normalizeSpaces(_stripTags(horseMatch.group(1)!));
      if (name.isNotEmpty) {
        names[number] = name;
      }

      final wakuMatch = RegExp(
        r'<td class="waku"[^>]*>([\s\S]*?)</td>',
        caseSensitive: false,
      ).firstMatch(row);
      if (wakuMatch != null) {
        final wakuText = wakuMatch.group(1)!;
        final alt = RegExp(r'枠(\d+)').firstMatch(wakuText);
        final frame = alt != null
            ? int.tryParse(alt.group(1)!)
            : int.tryParse(_normalizeSpaces(_stripTags(wakuText)));
        if (frame != null && frame >= 1 && frame <= 8) {
          frames[number] = frame;
        }
      }
    }

    final fieldSize =
        names.isEmpty ? null : names.keys.reduce((a, b) => a > b ? a : b);

    return RaceTableInfo(
      horseNamesByNumber: names,
      frameByHorseNumber: frames,
      fieldSize: fieldSize,
    );
  }

  static Future<String> _postHtml(String cname) async {
    final response = await HttpFetch.post(
      Uri.parse(accessUrl),
      body: {'cname': cname},
    );
    if (response.statusCode != 200) {
      throw HttpFetchException(
        'JRA公式の取得に失敗しました（HTTP ${response.statusCode}）',
      );
    }
    return const ShiftJISCodec(allowMalformed: true)
        .decode(response.bodyBytes);
  }

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _normalizeSpaces(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _parseYen(String text) {
    final digits = _stripTags(text).replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }
}

/// JRA race_id の構成要素
class JraRaceIdParts {
  final String year;
  final String jyo;
  final String kai;
  final String nichi;
  final String race;

  const JraRaceIdParts({
    required this.year,
    required this.jyo,
    required this.kai,
    required this.nichi,
    required this.race,
  });
}
