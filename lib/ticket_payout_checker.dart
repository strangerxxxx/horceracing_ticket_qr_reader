import 'race_result.dart';
import 'race_result_fetcher.dart';

/// 購入内容とレース払戻を照合する
class TicketPayoutChecker {
  static PurchaseCheckResult checkPurchase(
    Map ticketData,
    Map purchase,
    RaceResult raceResult,
  ) {
    if (!raceResult.hasResults) {
      return PurchaseCheckResult.unavailable('レース結果がまだ公開されていません');
    }

    final betType = purchase['式別']?.toString();
    if (betType == null || betType.isEmpty) {
      return PurchaseCheckResult.unavailable('式別が不明です');
    }

    // 地方競馬の「馬番連単」は馬単と同じ扱い
    final normalizedBetType = betType == '馬番連単' ? '馬単' : betType;
    final payouts = raceResult.payoutsFor(normalizedBetType);
    if (payouts.isEmpty) {
      return PurchaseCheckResult.unavailable('$betType の払戻が見つかりません');
    }

    final amount = _asInt(purchase['購入金額']) ?? 0;
    if (amount <= 0) {
      return PurchaseCheckResult.unavailable('購入金額が不明です');
    }

    final ticketType = ticketData['券種']?.toString() ?? '通常';
    final multi = ticketData['マルチ']?.toString() == 'あり';
    final combinations = _expandCombinations(
      ticketType: ticketType,
      betType: normalizedBetType,
      purchase: purchase,
      multi: multi,
    );

    if (combinations.isEmpty) {
      return PurchaseCheckResult.unavailable('照合可能な組合せを展開できませんでした');
    }

    final payoutByKey = {
      for (final p in payouts) p.combinationKey: p,
    };

    var totalPayout = 0;
    final matched = <String>[];
    for (final key in combinations) {
      final hit = payoutByKey[key];
      if (hit == null) continue;
      totalPayout += hit.payoutPer100Yen * (amount ~/ 100);
      matched.add(hit.combinationLabel);
    }

    if (matched.isEmpty) {
      return PurchaseCheckResult.miss();
    }

    return PurchaseCheckResult(
      hit: true,
      payoutYen: totalPayout,
      matchedLabels: matched.toSet().toList(),
    );
  }

  static Set<String> _expandCombinations({
    required String ticketType,
    required String betType,
    required Map purchase,
    required bool multi,
  }) {
    final ordered = betType == '馬単' || betType == '3連単';
    final size = _combinationSize(betType);
    if (size == null) return {};

    switch (ticketType) {
      case 'ボックス':
        return _expandBox(_asIntList(purchase['馬番']), size, ordered);
      case 'フォーメーション':
        return _expandFormation(_asIntListList(purchase['馬番']), size, ordered);
      case 'ながし':
        return _expandNagashi(purchase, betType, multi);
      case 'クイックピック':
        return _expandQuickPick(_asIntListList(purchase['馬番']), size, ordered);
      default:
        return _expandNormal(purchase, betType, size, ordered);
    }
  }

  static Set<String> _expandNormal(
    Map purchase,
    String betType,
    int size,
    bool ordered,
  ) {
    final horses = _asIntList(purchase['馬番']);
    final keys = <String>{};

    if (horses.length >= size) {
      keys.add(
        RaceResultFetcher.keyFromNumbers(
          horses.take(size).toList(),
          ordered: ordered,
        ),
      );
    }

    // 馬単のウラ
    if (betType == '馬単' &&
        purchase['ウラ']?.toString() == 'あり' &&
        horses.length >= 2) {
      keys.add(
        RaceResultFetcher.keyFromNumbers(
          [horses[1], horses[0]],
          ordered: true,
        ),
      );
    }

    return keys;
  }

  static Set<String> _expandBox(List<int> horses, int size, bool ordered) {
    final keys = <String>{};
    for (final combo in _combinations(horses, size)) {
      if (ordered) {
        for (final perm in _permutations(combo)) {
          keys.add(RaceResultFetcher.keyFromNumbers(perm, ordered: true));
        }
      } else {
        keys.add(RaceResultFetcher.keyFromNumbers(combo, ordered: false));
      }
    }
    return keys;
  }

  static Set<String> _expandFormation(
    List<List<int>> slots,
    int size,
    bool ordered,
  ) {
    if (slots.length < size) return {};
    final usedSlots = slots.take(size).toList();
    final keys = <String>{};

    void dfs(int depth, List<int> current, Set<int> used) {
      if (depth == size) {
        keys.add(
          RaceResultFetcher.keyFromNumbers(
            List<int>.from(current),
            ordered: ordered,
          ),
        );
        return;
      }
      for (final n in usedSlots[depth]) {
        if (used.contains(n)) continue;
        current.add(n);
        used.add(n);
        dfs(depth + 1, current, used);
        used.remove(n);
        current.removeLast();
      }
    }

    dfs(0, [], {});
    return keys;
  }

  static Set<String> _expandQuickPick(
    List<List<int>> combos,
    int size,
    bool ordered,
  ) {
    final keys = <String>{};
    for (final combo in combos) {
      if (combo.length < size) continue;
      keys.add(
        RaceResultFetcher.keyFromNumbers(
          combo.take(size).toList(),
          ordered: ordered,
        ),
      );
    }
    return keys;
  }

  static Set<String> _expandNagashi(
    Map purchase,
    String betType,
    bool multi,
  ) {
    final nagashi = purchase['ながし']?.toString() ?? '';
    final axis = purchase['軸'];
    final partners = _asIntList(purchase['相手']);
    final horses = _asIntListList(purchase['馬番']);

    switch (betType) {
      case '馬連':
      case 'ワイド':
      case '枠連':
        return _expandAxisOneNagashi(axis, partners, ordered: false);
      case '馬単':
        if (nagashi.contains('1着')) {
          return _expandAxisOneNagashi(axis, partners, ordered: true, axisFirst: true);
        }
        if (nagashi.contains('2着')) {
          return _expandAxisOneNagashi(axis, partners, ordered: true, axisFirst: false);
        }
        // 軸が複数ある場合など
        return _expandAxisOneNagashi(axis, partners, ordered: true, axisFirst: true);
      case '3連複':
        if (nagashi.contains('軸2頭')) {
          final axes = _asIntList(axis);
          return _expandTrioAxisTwo(axes, partners);
        }
        return _expandTrioAxisOne(axis, partners);
      case '3連単':
        return _expandTrifectaNagashi(nagashi, horses, multi);
      default:
        return {};
    }
  }

  static Set<String> _expandAxisOneNagashi(
    dynamic axis,
    List<int> partners, {
    required bool ordered,
    bool axisFirst = true,
  }) {
    final axes = _asIntList(axis);
    if (axes.isEmpty || partners.isEmpty) return {};
    final keys = <String>{};
    for (final a in axes) {
      for (final p in partners) {
        if (a == p) continue;
        final nums = axisFirst ? [a, p] : [p, a];
        keys.add(RaceResultFetcher.keyFromNumbers(nums, ordered: ordered));
      }
    }
    return keys;
  }

  static Set<String> _expandTrioAxisOne(dynamic axis, List<int> partners) {
    final axes = _asIntList(axis);
    if (axes.isEmpty || partners.length < 2) return {};
    final keys = <String>{};
    for (final a in axes) {
      for (final pair in _combinations(partners.where((p) => p != a).toList(), 2)) {
        keys.add(
          RaceResultFetcher.keyFromNumbers([a, ...pair], ordered: false),
        );
      }
    }
    return keys;
  }

  static Set<String> _expandTrioAxisTwo(List<int> axes, List<int> partners) {
    if (axes.length < 2 || partners.isEmpty) return {};
    final keys = <String>{};
    for (final p in partners) {
      if (axes.contains(p)) continue;
      keys.add(
        RaceResultFetcher.keyFromNumbers([...axes.take(2), p], ordered: false),
      );
    }
    return keys;
  }

  static Set<String> _expandTrifectaNagashi(
    String nagashi,
    List<List<int>> slots,
    bool multi,
  ) {
    // 3連単ながしは 馬番 が着順ごとのリストになることが多い
    if (slots.length >= 3) {
      final keys = _expandFormation(slots, 3, true);
      if (multi) {
        // マルチ: 着順スロットの順列も追加
        final all = slots.expand((e) => e).toSet().toList()..sort();
        keys.addAll(_expandBox(all, 3, true));
      }
      return keys;
    }
    return {};
  }

  static int? _combinationSize(String betType) {
    switch (betType) {
      case '単勝':
      case '複勝':
        return 1;
      case '枠連':
      case '馬連':
      case '馬単':
      case 'ワイド':
        return 2;
      case '3連複':
      case '3連単':
        return 3;
      default:
        return null;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<int> _asIntList(dynamic value) {
    if (value is! List) {
      final n = _asInt(value);
      return n == null ? <int>[] : [n];
    }
    return value.map(_asInt).whereType<int>().toList();
  }

  static List<List<int>> _asIntListList(dynamic value) {
    if (value is! List) return [];
    if (value.isEmpty) return [];
    if (value.first is List) {
      return value.map(_asIntList).toList();
    }
    return [ _asIntList(value) ];
  }

  static Iterable<List<int>> _combinations(List<int> items, int r) sync* {
    if (r <= 0 || r > items.length) return;
    final n = items.length;
    final indices = List<int>.generate(r, (i) => i);
    yield [for (final i in indices) items[i]];
    while (true) {
      var i = r - 1;
      while (i >= 0 && indices[i] == i + n - r) {
        i--;
      }
      if (i < 0) return;
      indices[i]++;
      for (var j = i + 1; j < r; j++) {
        indices[j] = indices[j - 1] + 1;
      }
      yield [for (final idx in indices) items[idx]];
    }
  }

  static Iterable<List<int>> _permutations(List<int> items) sync* {
    if (items.isEmpty) {
      yield <int>[];
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final rest = [...items]..removeAt(i);
      for (final perm in _permutations(rest)) {
        yield [items[i], ...perm];
      }
    }
  }
}
