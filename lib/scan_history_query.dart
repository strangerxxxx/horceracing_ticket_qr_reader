import 'dart:convert';

import 'scan_history_entry.dart';
import 'ticket_payout_checker.dart';

/// 履歴一覧の的中フィルタ
enum HistoryHitFilter {
  all,
  hit,
  miss,
  pending,
}

/// 履歴一覧のソート項目
enum HistorySortField {
  scannedAt,
  raceDate,
  purchase,
  payout,
  profit,
  venue,
}

extension HistoryHitFilterLabel on HistoryHitFilter {
  String get label => switch (this) {
        HistoryHitFilter.all => 'すべて',
        HistoryHitFilter.hit => '的中',
        HistoryHitFilter.miss => 'はずれ',
        HistoryHitFilter.pending => '未判定',
      };
}

extension HistorySortFieldLabel on HistorySortField {
  String get label => switch (this) {
        HistorySortField.scannedAt => '読み込み日時',
        HistorySortField.raceDate => 'レース日時',
        HistorySortField.purchase => '購入金額',
        HistorySortField.payout => '払戻金額',
        HistorySortField.profit => '収支',
        HistorySortField.venue => '開催場',
      };
}

/// 履歴の重複排除・検索・ソート
class ScanHistoryQuery {
  /// 同一馬券の指紋（QR優先、なければ開催・購入内容）
  static String fingerprint(Map<String, dynamic> data) {
    final qr = data['QR']?.toString();
    if (qr != null && qr.isNotEmpty) return 'qr:$qr';

    final under = data['下端番号']?.toString() ?? '';
    final purchases = data['購入内容'];
    final purchasesJson = purchases == null ? '' : jsonEncode(purchases);
    return [
      'c',
      data['開催場'],
      data['場コード'],
      data['年'],
      data['回'],
      data['日'],
      data['レース'],
      data['券種'],
      under,
      purchasesJson,
    ].join('|');
  }

  /// 同じ指紋は最新の読み込みのみ残す
  static List<ScanHistoryEntry> dedupeLatest(List<ScanHistoryEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    final seen = <String>{};
    final result = <ScanHistoryEntry>[];
    for (final entry in sorted) {
      final key = fingerprint(entry.data);
      if (!seen.add(key)) continue;
      result.add(entry);
    }
    return result;
  }

  static List<ScanHistoryEntry> filter({
    required List<ScanHistoryEntry> entries,
    String query = '',
    HistoryHitFilter hitFilter = HistoryHitFilter.all,
  }) {
    final q = query.trim().toLowerCase();
    return [
      for (final entry in entries)
        if (_matchesHitFilter(entry, hitFilter) && _matchesQuery(entry, q))
          entry,
    ];
  }

  static List<ScanHistoryEntry> sort({
    required List<ScanHistoryEntry> entries,
    required HistorySortField field,
    required bool ascending,
  }) {
    final list = [...entries];
    int cmp(ScanHistoryEntry a, ScanHistoryEntry b) {
      final result = switch (field) {
        HistorySortField.scannedAt => a.scannedAt.compareTo(b.scannedAt),
        HistorySortField.raceDate => _compareNullableDate(
            a.raceDateTime,
            b.raceDateTime,
          ),
        HistorySortField.purchase =>
          a.purchaseTotalYen.compareTo(b.purchaseTotalYen),
        HistorySortField.payout => _compareNullableInt(
            a.payoutTotalYen,
            b.payoutTotalYen,
          ),
        HistorySortField.profit => _compareNullableInt(a.profitYen, b.profitYen),
        HistorySortField.venue =>
          (a.ticket.venueName ?? '').compareTo(b.ticket.venueName ?? ''),
      };
      return ascending ? result : -result;
    }

    list.sort(cmp);
    return list;
  }

  static ({int purchaseTotal, int payoutTotal, int knownPayoutCount}) totals(
    List<ScanHistoryEntry> entries,
  ) {
    var purchase = 0;
    var payout = 0;
    var known = 0;
    for (final entry in entries) {
      purchase += entry.purchaseTotalYen;
      final p = entry.payoutTotalYen;
      if (p != null) {
        payout += p;
        known++;
      }
    }
    return (
      purchaseTotal: purchase,
      payoutTotal: payout,
      knownPayoutCount: known,
    );
  }

  static bool _matchesHitFilter(ScanHistoryEntry entry, HistoryHitFilter filter) {
    switch (filter) {
      case HistoryHitFilter.all:
        return true;
      case HistoryHitFilter.hit:
        return entry.hasPayoutResult && (entry.hitCount ?? 0) > 0;
      case HistoryHitFilter.miss:
        return entry.hasPayoutResult && (entry.hitCount ?? 0) == 0;
      case HistoryHitFilter.pending:
        return !entry.hasPayoutResult;
    }
  }

  static bool _matchesQuery(ScanHistoryEntry entry, String q) {
    if (q.isEmpty) return true;
    final t = entry.ticket;
    final haystack = [
      entry.title,
      entry.subtitle,
      t.venueName,
      t.raceName,
      t.raceDateLabel,
      t.ticketType,
      t.salesOffice,
      for (final p in t.purchases) p.betType,
      entry.hitSummaryLabel,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  static int _compareNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  static int _compareNullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

extension ScanHistoryEntryPayout on ScanHistoryEntry {
  /// 購入合計（保存値、なければ券面から算出）
  int get purchaseTotalYen {
    final stored = _asInt(data['購入合計']);
    if (stored != null) return stored;
    return TicketPayoutChecker.summarizeTicket(ticket).totalAmountYen;
  }

  /// 払戻合計（未判定時は null）
  int? get payoutTotalYen => _asInt(data['払戻合計']);

  int? get hitCount => _asInt(data['的中件数']);

  bool get hasPayoutResult {
    if (data['結果取得済'] == true) return true;
    return data.containsKey('払戻合計') && data['払戻合計'] != null;
  }

  int? get profitYen {
    final payout = payoutTotalYen;
    if (payout == null) return null;
    return payout - purchaseTotalYen;
  }

  DateTime? get raceDateTime {
    final label = ticket.raceDateLabel;
    if (label != null) {
      final m = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(label);
      if (m != null) {
        return DateTime(
          int.parse(m.group(1)!),
          int.parse(m.group(2)!),
          int.parse(m.group(3)!),
        );
      }
    }
    return null;
  }

  String get hitSummaryLabel {
    if (!hasPayoutResult) return '未判定';
    final hits = hitCount ?? 0;
    if (hits > 0) return '的中$hits件';
    return 'はずれ';
  }

  String get moneySummaryLabel {
    final purchase = _formatYen(purchaseTotalYen);
    final payout = payoutTotalYen;
    if (payout == null) return '購入 $purchase';
    return '購入 $purchase · 払戻 ${_formatYen(payout)}';
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.replaceAll(',', ''));
  return null;
}

String _formatYen(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  return '$sign$buffer円';
}
