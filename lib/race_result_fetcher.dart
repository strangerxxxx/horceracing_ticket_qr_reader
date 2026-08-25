import 'package:charset/charset.dart';
import 'package:http/http.dart' as http;

import 'bet_type.dart';
import 'race_result.dart';
import 'race_result_cache.dart';

/// `race_table_01` のパース結果
class RaceTableInfo {
  final Map<int, String> horseNamesByNumber;
  final Map<int, int> frameByHorseNumber;
  final int? fieldSize;

  const RaceTableInfo({
    this.horseNamesByNumber = const {},
    this.frameByHorseNumber = const {},
    this.fieldSize,
  });
}

/// レース名・開催日のパース結果
class RaceMetaInfo {
  final String? raceName;
  final String? raceDateLabel;

  const RaceMetaInfo({this.raceName, this.raceDateLabel});
}

/// netkeiba のレース結果ページから払戻を取得する
class RaceResultFetcher {
  static const _userAgent =
      'Mozilla/5.0 (compatible; HorseRacingTicketQrReader/1.0)';

  /// th の class → 式別名（netkeiba 表記）
  static const _betTypeByClass = {
    'tan': '単勝',
    'fuku': '複勝',
    'waku': '枠連',
    'wakutan': '枠単',
    'uren': '馬連',
    'wide': 'ワイド',
    'utan': '馬単',
    'sanfuku': '三連複',
    'santan': '三連単',
  };

  static Future<RaceResult> fetch(
    String url, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await RaceResultCache.read(url);
      if (cached != null) return cached;
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception('レース結果の取得に失敗しました (${response.statusCode})');
    }

    // netkeiba は EUC-JP。馬名表示のため正しくデコードする。
    final html = const EucJPCodec(true).decode(response.bodyBytes);
    final result = parseHtml(html, url);
    try {
      await RaceResultCache.write(url, result);
    } catch (_) {
      // キャッシュ失敗しても表示は続行する
    }
    return result;
  }

  /// テスト・デバッグ用に公開
  static RaceResult parseHtml(String html, String url) {
    final table = parseRaceTable(html);
    final meta = parseRaceMeta(html);

    final payBlockMatch = RegExp(
      r'class="pay_block"[\s\S]*?</dl>',
      caseSensitive: false,
    ).firstMatch(html);

    if (payBlockMatch == null) {
      return RaceResult(
        url: url,
        payoutsByBetType: const {},
        hasResults: false,
        horseNamesByNumber: table.horseNamesByNumber,
        frameByHorseNumber: table.frameByHorseNumber,
        fieldSize: table.fieldSize,
        raceName: meta.raceName,
        raceDateLabel: meta.raceDateLabel,
      );
    }

    final payBlock = payBlockMatch.group(0)!;
    final payoutsByBetType = <String, List<PayoutEntry>>{};

    final rowPattern = RegExp(
      r'<tr>\s*<th[^>]*class="([^"]+)"[^>]*>[\s\S]*?</th>\s*'
      r'<td[^>]*>([\s\S]*?)</td>\s*'
      r'<td[^>]*>([\s\S]*?)</td>',
      caseSensitive: false,
    );

    for (final match in rowPattern.allMatches(payBlock)) {
      final className = match.group(1)!.split(RegExp(r'\s+')).first;
      final betType = _betTypeByClass[className];
      if (betType == null) continue;

      final comboCells = _splitBr(match.group(2)!);
      final payoutCells = _splitBr(match.group(3)!);

      final entries = <PayoutEntry>[];
      for (var i = 0; i < comboCells.length; i++) {
        final rawLabel = _normalizeSpaces(comboCells[i]);
        if (rawLabel.isEmpty) continue;
        final payoutText = i < payoutCells.length ? payoutCells[i] : '';
        final payout = _parseYen(payoutText);
        if (payout <= 0) continue;

        final key = normalizeCombinationKey(rawLabel, betType);
        if (key.isEmpty) continue;

        entries.add(
          PayoutEntry(
            combinationKey: key,
            combinationLabel: formatCombinationLabel(key, betType),
            payoutPer100Yen: payout,
          ),
        );
      }

      if (entries.isNotEmpty) {
        payoutsByBetType[betType] = entries;
      }
    }

    return RaceResult(
      url: url,
      payoutsByBetType: payoutsByBetType,
      hasResults: payoutsByBetType.isNotEmpty,
      horseNamesByNumber: table.horseNamesByNumber,
      frameByHorseNumber: table.frameByHorseNumber,
      fieldSize: table.fieldSize,
      raceName: meta.raceName,
      raceDateLabel: meta.raceDateLabel,
    );
  }

  /// レース名・開催年月日を読む
  static RaceMetaInfo parseRaceMeta(String html) {
    String? raceName;
    final nameMatch = RegExp(
      r'class="racedata[^"]*"[\s\S]*?<dd>[\s\S]*?<h1>([\s\S]*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (nameMatch != null) {
      final name = _normalizeSpaces(
        _stripTags(nameMatch.group(1)!.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')),
      );
      if (name.isNotEmpty) raceName = name;
    }

    String? raceDateLabel;
    final smallMatch = RegExp(
      r'class="smalltxt"[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    ).firstMatch(html);
    if (smallMatch != null) {
      final small = _normalizeSpaces(
        _stripTags(
          smallMatch
              .group(1)!
              .replaceAll('&nbsp;', ' ')
              .replaceAll(RegExp(r'&#\d+;'), ' '),
        ),
      );
      final dateMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(small);
      if (dateMatch != null) {
        final y = int.parse(dateMatch.group(1)!);
        final m = int.parse(dateMatch.group(2)!);
        final d = int.parse(dateMatch.group(3)!);
        raceDateLabel = '$y年$m月$d日';
      }
    }

    return RaceMetaInfo(raceName: raceName, raceDateLabel: raceDateLabel);
  }

  /// `race_table_01` から馬番・枠番・馬名を読む
  static RaceTableInfo parseRaceTable(String html) {
    final tableMatch = RegExp(
      r'class="race_table_01[^"]*"[\s\S]*?</table>',
      caseSensitive: false,
    ).firstMatch(html);
    if (tableMatch == null) return const RaceTableInfo();

    final names = <int, String>{};
    final frames = <int, int>{};
    final rowPattern = RegExp(r'<tr>([\s\S]*?)</tr>', caseSensitive: false);

    for (final rowMatch in rowPattern.allMatches(tableMatch.group(0)!)) {
      final row = rowMatch.group(1)!;
      final nameMatch = RegExp(
        r'<a href="/horse/[^"]*"[^>]*>([^<]+)</a>',
        caseSensitive: false,
      ).firstMatch(row);
      if (nameMatch == null) continue;

      final tds = RegExp(r'<td[^>]*>([\s\S]*?)</td>', caseSensitive: false)
          .allMatches(row)
          .map((m) => _normalizeSpaces(_stripTags(m.group(1)!)))
          .toList();
      // 着順 / 枠番 / 馬番 / 馬名 ...
      if (tds.length < 3) continue;
      final frame = int.tryParse(tds[1]);
      final number = int.tryParse(tds[2]);
      if (number == null || number <= 0) continue;

      final name = _normalizeSpaces(nameMatch.group(1)!);
      if (name.isNotEmpty) {
        names[number] = name;
      }
      if (frame != null && frame >= 1 && frame <= 8) {
        frames[number] = frame;
      }
    }

    final fieldSize = names.isEmpty
        ? null
        : names.keys.reduce((a, b) => a > b ? a : b);

    return RaceTableInfo(
      horseNamesByNumber: names,
      frameByHorseNumber: frames,
      fieldSize: fieldSize,
    );
  }

  /// 後方互換: 馬番→馬名のみ
  static Map<int, String> parseHorseNames(String html) =>
      parseRaceTable(html).horseNamesByNumber;

  /// 表示文字列を照合用キーに正規化する
  static String normalizeCombinationKey(String raw, String betType) {
    // Shift_JIS 由来の区切り文字が壊れても、数字列は残るのでそれを使う
    final numbers = RegExp(r'\d+')
        .allMatches(raw)
        .map((m) => int.parse(m.group(0)!).toString())
        .toList();
    if (numbers.isEmpty) return '';

    final ordered = isOrderedBetType(betType);
    if (ordered) {
      return numbers.join('>');
    }

    final sorted = [...numbers]
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return sorted.join('-');
  }

  static String keyFromNumbers(List<int> numbers, {required bool ordered}) {
    if (ordered) {
      return numbers.map((n) => n.toString()).join('>');
    }
    final sorted = [...numbers]..sort();
    return sorted.map((n) => n.toString()).join('-');
  }

  /// 照合キーから表示用ラベルを作る（文字化けしない区切り文字を使う）
  static String formatCombinationLabel(String key, String betType) {
    final ordered = isOrderedBetType(betType);
    if (ordered) {
      return key.split('>').join(' → ');
    }
    return key.split('-').join(' - ');
  }

  static List<String> _splitBr(String html) {
    return html
        .split(RegExp(r'<br\s*/?>', caseSensitive: false))
        .map(_stripTags)
        .map(_normalizeSpaces)
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _normalizeSpaces(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _parseYen(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }
}
