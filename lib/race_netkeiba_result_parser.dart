/// race.netkeiba.com / nar.netkeiba.com の結果HTMLから返還馬などを読む。
///
/// 中央と地方で馬番セルの class が異なる:
/// - 中央: `Num WakuN`（枠）+ `Num Txt_C`（馬番）
/// - 地方: `Num WakuN`（枠）+ `Num Waku`（馬番・数字なし）
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

      final number = _parseHorseNumber(row);
      if (number == null || number <= 0) continue;
      horses.add(number);

      final frame = _parseFrame(row);
      if (frame != null) {
        frames[number] = frame;
      }

      final name = _parseHorseName(row);
      if (name != null) {
        names[number] = name;
      }
    }

    return (horses: horses, frames: frames, names: names);
  }

  /// `RaceData01` の「15:40発走」から発走時刻を読む
  static String? parsePostTime(String html) {
    final match = RegExp(
      r'class="RaceData01"[^>]*>\s*(\d{1,2}:\d{2})\s*発走',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    final raw = match.group(1)!;
    final parts = raw.split(':');
    if (parts.length != 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int? _parseHorseNumber(String row) {
    // 中央: Num Txt_C
    final jra = RegExp(
      r'class="Num[^"]*Txt_C[^"]*"[^>]*>\s*<div>(\d+)</div>',
      caseSensitive: false,
    ).firstMatch(row);
    if (jra != null) return int.tryParse(jra.group(1)!);

    // 地方: class="Num Waku"（Waku数字付きは枠番なので除外）
    final nar = RegExp(
      r'class="Num Waku"(?![0-9])[^>]*>\s*<div>(\d+)</div>',
      caseSensitive: false,
    ).firstMatch(row);
    if (nar != null) return int.tryParse(nar.group(1)!);

    return null;
  }

  static int? _parseFrame(String row) {
    final waku = RegExp(
      r'class="Num\s+Waku(\d+)',
      caseSensitive: false,
    ).firstMatch(row);
    if (waku == null) return null;
    final frame = int.tryParse(waku.group(1)!);
    if (frame == null || frame < 1 || frame > 8) return null;
    return frame;
  }

  static String? _parseHorseName(String row) {
    final span = RegExp(
      r'class="HorseNameSpan"[^>]*>([^<]+)<',
      caseSensitive: false,
    ).firstMatch(row);
    if (span != null) {
      final name = span.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }
    final title = RegExp(
      r'<a[^>]*title="([^"]+)"[^>]*>',
      caseSensitive: false,
    ).firstMatch(row);
    if (title != null) {
      final name = title.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }
    final horseName = RegExp(
      r'class="Horse_Name"[^>]*>[\s\S]*?<a[^>]*>([^<]+)</a>',
      caseSensitive: false,
    ).firstMatch(row);
    if (horseName != null) {
      final name = horseName.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }
}
