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

int _countSequence(String s) {
  const sequence = '0123456789';
  return RegExp(sequence).allMatches(s).length;
}

Map<String, dynamic> _parseCombined(String s) {
  final raw = s.substring(3, 4) == '1'
      ? parseHorseracingTicketQrLocal(s)
      : parseHorseracingTicketQr(s);
  return Ticket.fromMap(raw).toMap();
}
