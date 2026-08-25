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

  const RaceResult({
    required this.url,
    required this.payoutsByBetType,
    required this.hasResults,
    this.horseNamesByNumber = const {},
    this.frameByHorseNumber = const {},
    this.fieldSize,
  });

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
