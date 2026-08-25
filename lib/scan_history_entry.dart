import 'local_race_url.dart';
import 'ticket.dart';

/// 読み取り履歴の1件分
class ScanHistoryEntry {
  final String id;
  final DateTime scannedAt;
  final Map<String, dynamic> data;

  const ScanHistoryEntry({
    required this.id,
    required this.scannedAt,
    required this.data,
  });

  /// 型付きチケット（履歴JSONは日本語キーのまま）
  Ticket get ticket => Ticket.fromMap(data);

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      data: _deepConvertMap(Map<dynamic, dynamic>.from(json['data'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scannedAt': scannedAt.toIso8601String(),
        'data': data,
      };

  String get title {
    final t = ticket;
    if (t.hasError) return '解析エラー';

    final parts = <String>[];
    final venue = t.venueName ?? '';
    if (venue.isNotEmpty) parts.add(venue);
    if (t.raceNumber != null) parts.add('${t.raceNumber}R');
    final raceName = t.raceName;
    if (raceName != null && raceName.isNotEmpty) parts.add(raceName);

    if (parts.isNotEmpty) return parts.join(' ');
    return '読み取り結果';
  }

  String get subtitle {
    final t = ticket;
    if (t.hasError) {
      return t.error ?? '';
    }

    final parts = <String>[];

    if (t.year != null) {
      final yearStr = LocalRaceUrlResolver.formatYearLabelForTicket(data, t.year!);
      parts.add('$yearStr 第${t.round}回 第${t.day}日');
    }
    if (t.ticketType != null) {
      parts.add(t.ticketType!);
    }

    if (t.purchases.isNotEmpty) {
      final firstType = t.purchases.first.betType;
      if (firstType != null) parts.add(firstType);
      if (t.purchases.length > 1) {
        parts.add('他${t.purchases.length - 1}件');
      }
    }

    return parts.join(' · ');
  }

  String get scannedAtLabel {
    final m = scannedAt.minute.toString().padLeft(2, '0');
    return '${scannedAt.year}/${scannedAt.month}/${scannedAt.day} '
        '${scannedAt.hour}:$m';
  }
}

Map<String, dynamic> _deepConvertMap(Map<dynamic, dynamic> map) {
  return {
    for (final entry in map.entries)
      entry.key.toString(): _deepConvertValue(entry.value),
  };
}

dynamic _deepConvertValue(dynamic value) {
  if (value is Map) {
    return _deepConvertMap(Map<dynamic, dynamic>.from(value));
  }
  if (value is List) {
    return value.map(_deepConvertValue).toList();
  }
  return value;
}
