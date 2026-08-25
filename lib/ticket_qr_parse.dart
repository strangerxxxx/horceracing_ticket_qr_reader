import 'parse.dart';
import 'parse_local.dart';
import 'ticket.dart';

/// 2枚のQR生文字列から馬券Mapを組み立てる
Map<String, dynamic>? parseTicketFromTwoQrs(String first, String second) {
  final count1 = _countSequence(first);
  final count2 = _countSequence(second);

  final String preferred;
  final String alt;
  if (count1 > count2) {
    preferred = second + first;
    alt = first + second;
  } else {
    preferred = first + second;
    alt = second + first;
  }

  try {
    return _parseCombined(preferred);
  } catch (_) {
    try {
      return _parseCombined(alt);
    } catch (_) {
      return null;
    }
  }
}

/// 貼り付けテキストから馬券を解析する。
///
/// 受け付ける形式:
/// - 結合済みの1本のQRペイロード
/// - 2枚分のQRを改行（または空白）区切りで並べたもの
Map<String, dynamic>? parseTicketFromPastedText(String raw) {
  final segments = _extractQrSegments(raw);
  if (segments.isEmpty) return null;

  if (segments.length >= 2) {
    final fromPair = parseTicketFromTwoQrs(segments[0], segments[1]);
    if (fromPair != null) return fromPair;
  }

  final combined = segments.length == 1 ? segments.first : segments.join();
  try {
    return _parseCombined(combined);
  } catch (_) {
    return null;
  }
}

/// 貼り付け文面からQRっぽい断片を取り出す
List<String> _extractQrSegments(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  // 改行区切りを優先（2枚を別行で貼る想定）
  final byLine = trimmed
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (byLine.length >= 2) {
    return byLine;
  }

  if (byLine.length == 1) {
    final only = byLine.first;
    // 1行に空白区切りで2本ある場合
    final bySpace = only
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (bySpace.length >= 2 && bySpace.every(_looksLikeQrPayload)) {
      return bySpace;
    }
    return [only];
  }

  return const [];
}

bool _looksLikeQrPayload(String s) {
  if (s.length < 20) return false;
  // 馬券QRはほぼ数字列
  final digits = RegExp(r'\d').allMatches(s).length;
  return digits / s.length >= 0.8;
}

int _countSequence(String s) {
  const sequence = '0123456789';
  return RegExp(sequence).allMatches(s).length;
}

Map<String, dynamic> _parseCombined(String s) {
  final raw = s.length > 4 && s.substring(3, 4) == '1'
      ? parseHorseracingTicketQrLocal(s)
      : parseHorseracingTicketQr(s);
  return Ticket.fromMap(raw).toMap();
}
