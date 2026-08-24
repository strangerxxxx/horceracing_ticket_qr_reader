import 'package:http/http.dart' as http;

import 'race_result.dart';

/// netkeiba のレース結果ページから払戻を取得する
class RaceResultFetcher {
  static const _userAgent =
      'Mozilla/5.0 (compatible; HorseRacingTicketQrReader/1.0)';

  /// th の class → 式別名
  static const _betTypeByClass = {
    'tan': '単勝',
    'fuku': '複勝',
    'waku': '枠連',
    'uren': '馬連',
    'wide': 'ワイド',
    'utan': '馬単',
    'sanfuku': '3連複',
    'santan': '3連単',
  };

  static Future<RaceResult> fetch(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw Exception('レース結果の取得に失敗しました (${response.statusCode})');
    }

    // 払戻テーブルの class / 数字は ASCII なので、バイト列を Latin-1 として扱える
    final html = String.fromCharCodes(response.bodyBytes);
    return parseHtml(html, url);
  }

  /// テスト・デバッグ用に公開
  static RaceResult parseHtml(String html, String url) {
    final payBlockMatch = RegExp(
      r'class="pay_block"[\s\S]*?</dl>',
      caseSensitive: false,
    ).firstMatch(html);

    if (payBlockMatch == null) {
      return RaceResult(url: url, payoutsByBetType: const {}, hasResults: false);
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
    );
  }

  /// 表示文字列を照合用キーに正規化する
  static String normalizeCombinationKey(String raw, String betType) {
    // Shift_JIS 由来の区切り文字が壊れても、数字列は残るのでそれを使う
    final numbers = RegExp(r'\d+')
        .allMatches(raw)
        .map((m) => int.parse(m.group(0)!).toString())
        .toList();
    if (numbers.isEmpty) return '';

    final ordered = betType == '馬単' || betType == '3連単' || betType == '馬番連単';
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
    final ordered = betType == '馬単' || betType == '3連単' || betType == '馬番連単';
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
