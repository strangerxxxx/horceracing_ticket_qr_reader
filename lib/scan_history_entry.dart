import 'local_race_url.dart';

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
    if (data.containsKey('エラー')) return '解析エラー';

    final venue = data['開催場']?.toString() ?? '';
    final race = data['レース'];
    final raceName = data['レース名']?.toString();

    final parts = <String>[];
    if (venue.isNotEmpty) parts.add(venue);
    if (race != null) parts.add('${race}R');
    if (raceName != null && raceName.isNotEmpty) parts.add(raceName);

    if (parts.isNotEmpty) return parts.join(' ');
    return '読み取り結果';
  }

  String get subtitle {
    if (data.containsKey('エラー')) {
      return data['エラー'].toString();
    }

    final parts = <String>[];

    if (data['年'] != null) {
      final year = data['年'];
      final yearStr = year is int
          ? LocalRaceUrlResolver.formatYearLabelForTicket(data, year)
          : '$year年';
      parts.add('$yearStr 第${data['回']}回 第${data['日']}日');
    }
    if (data['券種'] != null) {
      parts.add(data['券種'].toString());
    }

    final purchases = data['購入内容'];
    if (purchases is List && purchases.isNotEmpty) {
      final first = purchases.first;
      if (first is Map && first['式別'] != null) {
        parts.add(first['式別'].toString());
      }
      if (purchases.length > 1) {
        parts.add('他${purchases.length - 1}件');
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
