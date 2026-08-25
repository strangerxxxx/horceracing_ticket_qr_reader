/// 1件の払戻情報（式別ごとの的中組合せ）
class PayoutEntry {
  /// 正規化した組合せキー（例: "12", "2-12", "12>2>1"）
  final String combinationKey;

  /// 表示用の組合せ文字列
  final String combinationLabel;

  /// 100円あたりの払戻金額
  final int payoutPer100Yen;

  const PayoutEntry({
    required this.combinationKey,
    required this.combinationLabel,
    required this.payoutPer100Yen,
  });

  factory PayoutEntry.fromJson(Map<String, dynamic> json) {
    return PayoutEntry(
      combinationKey: json['combinationKey'] as String,
      combinationLabel: json['combinationLabel'] as String,
      payoutPer100Yen: json['payoutPer100Yen'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'combinationKey': combinationKey,
        'combinationLabel': combinationLabel,
        'payoutPer100Yen': payoutPer100Yen,
      };
}

/// レース結果（払戻）
class RaceResult {
  final String url;
  final Map<String, List<PayoutEntry>> payoutsByBetType;
  final bool hasResults;

  /// 馬番 → 馬名（レース結果表から取得。無い場合は空）
  final Map<int, String> horseNamesByNumber;

  /// 馬番 → 枠番（レース結果表から取得。無い場合は空）
  final Map<int, int> frameByHorseNumber;

  /// 出走頭数（結果表から判明した最大馬番。不明時は null）
  final int? fieldSize;

  /// レース名（例: プリンシパルS(L)）
  final String? raceName;

  /// 開催年月日の表示用（例: 2025年5月4日）
  final String? raceDateLabel;

  /// netkeiba の想定HTML構造を認識できたか（壊れたときの警告用）
  final bool layoutRecognized;

  const RaceResult({
    required this.url,
    required this.payoutsByBetType,
    required this.hasResults,
    this.horseNamesByNumber = const {},
    this.frameByHorseNumber = const {},
    this.fieldSize,
    this.raceName,
    this.raceDateLabel,
    this.layoutRecognized = true,
  });

  factory RaceResult.fromJson(Map<String, dynamic> json) {
    final payoutsRaw = json['payoutsByBetType'] as Map? ?? {};
    final payoutsByBetType = <String, List<PayoutEntry>>{
      for (final entry in payoutsRaw.entries)
        entry.key.toString(): [
          for (final item in (entry.value as List? ?? const []))
            if (item is Map)
              PayoutEntry.fromJson(Map<String, dynamic>.from(item)),
        ],
    };

    final namesRaw = json['horseNamesByNumber'] as Map? ?? {};
    final framesRaw = json['frameByHorseNumber'] as Map? ?? {};
    final hasResults =
        json['hasResults'] as bool? ?? payoutsByBetType.isNotEmpty;

    return RaceResult(
      url: json['url'] as String,
      payoutsByBetType: payoutsByBetType,
      hasResults: hasResults,
      horseNamesByNumber: {
        for (final entry in namesRaw.entries)
          int.parse(entry.key.toString()): entry.value.toString(),
      },
      frameByHorseNumber: {
        for (final entry in framesRaw.entries)
          int.parse(entry.key.toString()): entry.value is int
              ? entry.value as int
              : int.parse(entry.value.toString()),
      },
      fieldSize: json['fieldSize'] as int?,
      raceName: json['raceName'] as String?,
      raceDateLabel: json['raceDateLabel'] as String?,
      layoutRecognized: json['layoutRecognized'] as bool? ??
          (hasResults ||
              namesRaw.isNotEmpty ||
              json['raceName'] != null ||
              json['raceDateLabel'] != null),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'payoutsByBetType': {
          for (final entry in payoutsByBetType.entries)
            entry.key: [for (final p in entry.value) p.toJson()],
        },
        'hasResults': hasResults,
        'horseNamesByNumber': {
          for (final entry in horseNamesByNumber.entries)
            entry.key.toString(): entry.value,
        },
        'frameByHorseNumber': {
          for (final entry in frameByHorseNumber.entries)
            entry.key.toString(): entry.value,
        },
        'fieldSize': fieldSize,
        'raceName': raceName,
        'raceDateLabel': raceDateLabel,
        'layoutRecognized': layoutRecognized,
      };

  List<PayoutEntry> payoutsFor(String betType) =>
      payoutsByBetType[betType] ?? const [];

  String? horseName(int number) => horseNamesByNumber[number];
}

/// 購入内容1件の照合結果
class PurchaseCheckResult {
  final bool hit;
  final int payoutYen;
  final List<String> matchedLabels;
  final String? note;

  const PurchaseCheckResult({
    required this.hit,
    required this.payoutYen,
    this.matchedLabels = const [],
    this.note,
  });

  factory PurchaseCheckResult.miss({String? note}) =>
      PurchaseCheckResult(hit: false, payoutYen: 0, note: note);

  factory PurchaseCheckResult.unavailable(String note) =>
      PurchaseCheckResult(hit: false, payoutYen: 0, note: note);
}
