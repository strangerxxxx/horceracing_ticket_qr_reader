/// 馬券QRの解析結果（履歴JSONは従来どおり日本語キー）
class Ticket {
  final String? rawQr;
  final String? venueName;
  final String? venueCode;
  final String? meetingKind;
  final int? year;
  final int? round;
  final int? day;
  final int? raceNumber;
  final String? resultUrl;
  final String? ticketType;
  final String? salesOffice;
  final List<PurchaseItem> purchases;
  final bool? multi;
  final int? quickPickAxis;
  final String? finishSpecify;
  final int? combinationCount;
  final String? underDigits;
  final String? raceName;
  final String? raceDateLabel;
  final String? error;
  final String? errorDetail;

  const Ticket({
    this.rawQr,
    this.venueName,
    this.venueCode,
    this.meetingKind,
    this.year,
    this.round,
    this.day,
    this.raceNumber,
    this.resultUrl,
    this.ticketType,
    this.salesOffice,
    this.purchases = const [],
    this.multi,
    this.quickPickAxis,
    this.finishSpecify,
    this.combinationCount,
    this.underDigits,
    this.raceName,
    this.raceDateLabel,
    this.error,
    this.errorDetail,
  });

  bool get hasError => error != null && error!.isNotEmpty;

  factory Ticket.fromMap(Map<String, dynamic> map) {
    final purchasesRaw = map['購入内容'];
    final purchases = <PurchaseItem>[];
    if (purchasesRaw is List) {
      for (final item in purchasesRaw) {
        if (item is Map) {
          purchases.add(
            PurchaseItem.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return Ticket(
      rawQr: map['QR']?.toString(),
      venueName: map['開催場']?.toString(),
      venueCode: map['場コード']?.toString(),
      meetingKind: map['開催種別']?.toString(),
      year: _asInt(map['年']),
      round: _asInt(map['回']),
      day: _asInt(map['日']),
      raceNumber: _asInt(map['レース']),
      resultUrl: map['URL']?.toString(),
      ticketType: map['券種']?.toString(),
      salesOffice: map['発売所']?.toString(),
      purchases: purchases,
      multi: _asYesNo(map['マルチ']),
      quickPickAxis: _asInt(map['軸']),
      finishSpecify: map['着順指定']?.toString(),
      combinationCount: _asInt(map['組合せ数']),
      underDigits: map['下端番号']?.toString(),
      raceName: map['レース名']?.toString(),
      raceDateLabel: map['開催日']?.toString(),
      error: map['エラー']?.toString(),
      errorDetail: map['詳細']?.toString(),
    );
  }

  factory Ticket.error(String message, {String? detail}) {
    return Ticket(error: message, errorDetail: detail);
  }

  /// 履歴・UI互換の日本語キー Map
  Map<String, dynamic> toMap() {
    if (hasError) {
      return {
        'エラー': error,
        if (errorDetail != null) '詳細': errorDetail,
      };
    }

    return {
      if (rawQr != null) 'QR': rawQr,
      if (venueName != null) '開催場': venueName,
      if (venueCode != null) '場コード': venueCode,
      if (meetingKind != null) '開催種別': meetingKind,
      if (year != null) '年': year,
      if (round != null) '回': round,
      if (day != null) '日': day,
      if (raceNumber != null) 'レース': raceNumber,
      if (resultUrl != null) 'URL': resultUrl,
      if (ticketType != null) '券種': ticketType,
      if (salesOffice != null) '発売所': salesOffice,
      '購入内容': [for (final p in purchases) p.toMap()],
      if (multi != null) 'マルチ': multi! ? 'あり' : 'なし',
      if (quickPickAxis != null) '軸': quickPickAxis,
      if (finishSpecify != null) '着順指定': finishSpecify,
      if (combinationCount != null) '組合せ数': combinationCount,
      if (underDigits != null) '下端番号': underDigits,
      if (raceName != null) 'レース名': raceName,
      if (raceDateLabel != null) '開催日': raceDateLabel,
    };
  }

  Ticket copyWith({
    String? raceName,
    String? raceDateLabel,
    String? resultUrl,
    Map<String, dynamic>? extra,
  }) {
    final map = toMap();
    if (raceName != null) map['レース名'] = raceName;
    if (raceDateLabel != null) map['開催日'] = raceDateLabel;
    if (resultUrl != null) map['URL'] = resultUrl;
    if (extra != null) map.addAll(extra);
    return Ticket.fromMap(map);
  }
}

/// 購入内容1件
class PurchaseItem {
  final String? betType;
  final int? amountYen;
  final HorseNumbers? numbers;
  final bool? ura;
  final String? nagashiKind;
  final AxisNumbers? axis;
  final List<int>? partners;

  const PurchaseItem({
    this.betType,
    this.amountYen,
    this.numbers,
    this.ura,
    this.nagashiKind,
    this.axis,
    this.partners,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      betType: map['式別']?.toString(),
      amountYen: _asInt(map['購入金額']),
      numbers: HorseNumbers.tryParse(map['馬番']),
      ura: _asYesNo(map['ウラ']),
      nagashiKind: map['ながし']?.toString(),
      axis: AxisNumbers.tryParse(map['軸']),
      partners: map['相手'] == null ? null : _asIntList(map['相手']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (betType != null) '式別': betType,
      if (amountYen != null) '購入金額': amountYen,
      if (numbers != null) '馬番': numbers!.toJson(),
      if (ura != null) 'ウラ': ura! ? 'あり' : 'なし',
      if (nagashiKind != null) 'ながし': nagashiKind,
      if (axis != null) '軸': axis!.toJson(),
      if (partners != null) '相手': partners,
    };
  }

  /// TalkBack 向けの馬番説明（「馬番、…」の後半）
  String semanticNumbersDescription({required bool numberIsFrame}) {
    final kind = numberIsFrame ? '枠番' : '馬番';
    if (axis != null && partners != null) {
      final axisText = axis!.values.map((n) => '$kind$n').join('と');
      final partnerText = partners!.map((n) => '$kind$n').join('と');
      final nagashi = nagashiKind ?? 'ながし';
      if (nagashi.contains('2着')) {
        return '$nagashi。相手 $partnerText。軸 $axisText';
      }
      return '$nagashi。軸 $axisText。相手 $partnerText';
    }

    final nums = numbers;
    if (nums == null || nums.isEmpty) return 'なし';

    if (nums.isNested) {
      final slots = <String>[];
      for (var i = 0; i < nums.slots.length; i++) {
        final slot = nums.slots[i].map((n) => '$kind$n').join('と');
        slots.add('${i + 1}着候補 $slot');
      }
      final uraText = ura == true ? '。ウラあり' : '';
      return '${slots.join('。')}$uraText';
    }

    final flat = nums.flat.map((n) => '$kind$n').join('、');
    final uraText = ura == true ? '。ウラあり' : '';
    return '$flat$uraText';
  }
}

/// 馬番フィールド（平坦 or スロット入れ子）
class HorseNumbers {
  final List<int> flat;
  final List<List<int>> slots;
  final bool isNested;

  const HorseNumbers._({
    required this.flat,
    required this.slots,
    required this.isNested,
  });

  factory HorseNumbers.flatList(List<int> values) => HorseNumbers._(
        flat: values,
        slots: const [],
        isNested: false,
      );

  factory HorseNumbers.nested(List<List<int>> values) => HorseNumbers._(
        flat: const [],
        slots: values,
        isNested: true,
      );

  static HorseNumbers? tryParse(dynamic value) {
    if (value == null) return null;
    if (value is! List || value.isEmpty) {
      final n = _asInt(value);
      return n == null ? null : HorseNumbers.flatList([n]);
    }
    if (value.first is List) {
      return HorseNumbers.nested(
        value.map(_asIntList).toList(),
      );
    }
    return HorseNumbers.flatList(_asIntList(value));
  }

  bool get isEmpty => isNested ? slots.every((s) => s.isEmpty) : flat.isEmpty;

  dynamic toJson() => isNested ? slots : flat;
}

/// ながし軸（1頭 or 複数）
class AxisNumbers {
  final List<int> values;

  const AxisNumbers(this.values);

  static AxisNumbers? tryParse(dynamic value) {
    if (value == null) return null;
    final list = _asIntList(value);
    if (list.isEmpty) return null;
    return AxisNumbers(list);
  }

  dynamic toJson() => values.length == 1 ? values.first : values;
}

bool? _asYesNo(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  if (s == 'あり') return true;
  if (s == 'なし') return false;
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.replaceAll(',', ''));
  return null;
}

List<int> _asIntList(dynamic value) {
  if (value is! List) {
    final n = _asInt(value);
    return n == null ? <int>[] : [n];
  }
  return value.map(_asInt).whereType<int>().toList();
}
