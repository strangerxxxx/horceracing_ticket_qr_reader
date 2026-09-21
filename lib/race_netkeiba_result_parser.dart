/// race.netkeiba.com / nar.netkeiba.com の結果HTMLから返還馬などを読む
class RaceNetkeibaResultParser {
  /// 取消・除外行の馬番と枠番
  static ({Set<int> horses, Map<int, int> frames, Map<int, String> names})
      parseRefundedHorses(String html) {
    final horses = <int>{};
    final frames = <int, int>{};
    final names = <int, String>{};

    final rowPattern = RegExp(
      r'<tr[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    );
    for (final rowMatch in rowPattern.allMatches(html)) {
      final full = rowMatch.group(0)!;
      final row = rowMatch.group(1)!;
      final isRefundRow = RegExp(
            r'Torikeshi',
            caseSensitive: false,
          ).hasMatch(full) ||
          RegExp(r'>(取消|除外)<').hasMatch(row);
      if (!isRefundRow) continue;

      final umaban = RegExp(
        r'class="Num[^"]*Txt_C[^"]*"[^>]*>\s*<div>(\d+)</div>',
        caseSensitive: false,
      ).firstMatch(row);
      final number = umaban != null ? int.tryParse(umaban.group(1)!) : null;
      if (number == null || number <= 0) continue;

      horses.add(number);

      final waku = RegExp(
        r'class="Num\s+Waku(\d+)',
        caseSensitive: false,
      ).firstMatch(row);
      if (waku != null) {
        final frame = int.tryParse(waku.group(1)!);
        if (frame != null && frame >= 1 && frame <= 8) {
          frames[number] = frame;
        }
      }

      final nameMatch = RegExp(
        r'class="HorseNameSpan"[^>]*>([^<]+)<',
        caseSensitive: false,
      ).firstMatch(row);
      if (nameMatch != null) {
        final name = nameMatch.group(1)!.trim();
        if (name.isNotEmpty) names[number] = name;
      }
    }

    return (horses: horses, frames: frames, names: names);
  }
}
