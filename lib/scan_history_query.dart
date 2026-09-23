import 'dart:convert';

import 'local_race_url.dart';
import 'netkeiba_urls.dart';
import 'scan_history_entry.dart';
import 'ticket_payout_checker.dart';

/// 履歴一覧の的中フィルタ
enum HistoryHitFilter {
  all,
  hit,
  refund,
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
        HistoryHitFilter.refund => '返還',
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
        HistorySortField.raceDate => _compareRaceSortKey(
            a.raceSortKey,
            b.raceSortKey,
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
      if (result != 0) return ascending ? result : -result;
      // 同値時は読み込み日時で安定化
      final byScan = a.scannedAt.compareTo(b.scannedAt);
      return ascending ? byScan : -byScan;
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
      case HistoryHitFilter.refund:
        return entry.hasPayoutResult && (entry.refundCount ?? 0) > 0;
      case HistoryHitFilter.miss:
        return entry.hasPayoutResult &&
            (entry.hitCount ?? 0) == 0 &&
            (entry.refundCount ?? 0) == 0;
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
      t.postTime,
      entry.raceDateTimeLabel,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  static int _compareNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  static int _compareRaceSortKey(List<int> a, List<int> b) {
    final n = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final c = a[i].compareTo(b[i]);
      if (c != 0) return c;
    }
    return a.length.compareTo(b.length);
  }
}

extension ScanHistoryEntryPayout on ScanHistoryEntry {
  /// 購入合計（保存値、なければ券面から算出）
  int get purchaseTotalYen {
    final stored = _asInt(data['購入合計']);
    if (stored != null) return stored;
    return TicketPayoutChecker.summarizeTicket(ticket).totalAmountYen;
  }

  /// 払戻合計（未判定時は null）。返還分も含む。
  int? get payoutTotalYen => _asInt(data['払戻合計']);

  int? get hitCount => _asInt(data['的中件数']);

  int? get refundCount => _asInt(data['返還件数']);

  int? get refundTotalYen => _asInt(data['返還合計']);

  bool get hasPayoutResult {
    if (data['結果取得済'] == true) return true;
    return data.containsKey('払戻合計') && data['払戻合計'] != null;
  }

  bool get hasRefundResult => hasPayoutResult && (refundCount ?? 0) > 0;

  int? get profitYen {
    final payout = payoutTotalYen;
    if (payout == null) return null;
    return payout - purchaseTotalYen;
  }

  DateTime? get raceDateTime {
    final post = _postTimeParts();
    final calendar = _calendarDate();
    if (calendar != null) {
      return DateTime(
        calendar.year,
        calendar.month,
        calendar.day,
        post?.$1 ?? 0,
        post?.$2 ?? 0,
      );
    }
    return null;
  }

  /// レース日時ソート用キー。開催日が無くても年・回・日・レース・発走で順序を付ける。
  List<int> get raceSortKey {
    final post = _postTimeParts();
    final hour = post?.$1 ?? -1;
    final minute = post?.$2 ?? -1;
    final raceNo = ticket.raceNumber ?? 0;

    final calendar = _calendarDate();
    if (calendar != null) {
      // tier0: 絶対日付
      return [
        0,
        calendar.year,
        calendar.month,
        calendar.day,
        hour,
        minute,
        raceNo,
      ];
    }

    final year = ticket.year != null
        ? LocalRaceUrlResolver.toWesternYear(ticket.year!)
        : 0;
    // tier1: 開催回・日ベース（券面から常に取れる）
    return [
      1,
      year,
      ticket.round ?? 0,
      ticket.day ?? 0,
      hour,
      minute,
      raceNo,
    ];
  }

  /// 履歴一覧向けのレース日時表示（開催日・発走時刻を優先）。
  String get raceDateTimeLabel {
    final post = ticket.postTime;
    final calendar = _calendarDate();
    if (calendar != null) {
      final date =
          '${calendar.year}年${calendar.month}月${calendar.day}日';
      if (post != null && post.isNotEmpty) return '$date $post発走';
      return date;
    }

    final t = ticket;
    if (t.year == null) {
      if (post != null && post.isNotEmpty) return '発走 $post';
      return 'レース日時不明';
    }
    final yearStr =
        LocalRaceUrlResolver.formatYearLabelForTicket(data, t.year!);
    final parts = <String>[
      yearStr,
      if (t.round != null) '第${t.round}回',
      if (t.day != null) '第${t.day}日',
      if (t.raceNumber != null) '${t.raceNumber}R',
    ];
    var label = parts.join(' ');
    if (post != null && post.isNotEmpty) {
      label = '$label · $post発走';
    }
    return label;
  }

  DateTime? _calendarDate() {
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

    final fromUrl = NetkeibaUrls.calendarDateFromDbUrl(ticket.resultUrl);
    if (fromUrl != null) return fromUrl;

    return null;
  }

  (int, int)? _postTimeParts() {
    final post = ticket.postTime;
    if (post == null) return null;
    final tm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(post);
    if (tm == null) return null;
    return (int.parse(tm.group(1)!), int.parse(tm.group(2)!));
  }

  String get hitSummaryLabel {
    if (!hasPayoutResult) return '未判定';
    final hits = hitCount ?? 0;
    final refunds = refundCount ?? 0;
    if (hits > 0 && refunds > 0) return '的中$hits件・返還あり';
    if (hits > 0) return '的中$hits件';
    if (refunds > 0) {
      return refunds == 1 ? '返還あり' : '返還あり（$refunds件）';
    }
    return 'はずれ';
  }

  String get moneySummaryLabel {
    final purchase = _formatYen(purchaseTotalYen);
    final payout = payoutTotalYen;
    if (payout == null) return '購入 $purchase';
    final refund = refundTotalYen;
    if (refund != null && refund > 0) {
      return '購入 $purchase · 払戻 ${_formatYen(payout)}（返還 ${_formatYen(refund)}）';
    }
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
