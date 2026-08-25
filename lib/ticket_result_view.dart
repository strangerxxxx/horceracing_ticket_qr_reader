import 'package:flutter/material.dart';

import 'bet_type.dart';
import 'external_url.dart';
import 'local_race_url.dart';
import 'netkeiba_urls.dart';
import 'race_result.dart';
import 'race_result_fetcher.dart';
import 'ticket_payout_checker.dart';

/// 金額を3桁カンマ区切りで表示する
String _formatYen(int amount, {bool showSign = false}) {
  final sign = amount < 0
      ? '-'
      : (showSign && amount > 0 ? '+' : '');
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return '$sign$buffer円';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.replaceAll(',', ''));
  return null;
}
class TicketResultView extends StatefulWidget {
  final Map<String, dynamic> data;

  const TicketResultView({super.key, required this.data});

  @override
  State<TicketResultView> createState() => _TicketResultViewState();
}

class _TicketResultViewState extends State<TicketResultView> {
  RaceResult? _raceResult;
  List<PurchaseCheckResult?> _checkResults = [];
  bool _loading = false;
  String? _error;
  bool _resolvingUrl = false;
  String? _resolvedUrl;
  String? _urlResolveError;

  Map<String, dynamic> get data => widget.data;

  String? get _effectiveUrl =>
      _resolvedUrl ?? data['URL']?.toString();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant TicketResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _raceResult = null;
      _checkResults = [];
      _error = null;
      _resolvedUrl = null;
      _urlResolveError = null;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (data.containsKey('エラー')) return;

    if (data['URL'] != null) {
      await _loadRaceResult();
      return;
    }

    await _resolveLocalUrlIfNeeded();
  }

  Future<void> _resolveLocalUrlIfNeeded() async {
    final code = data['場コード']?.toString();
    final venue = data['開催場']?.toString();
    final year = _asInt(data['年']);
    final round = _asInt(data['回']);
    final day = _asInt(data['日']);
    final race = _asInt(data['レース']);

    if (code == null ||
        venue == null ||
        year == null ||
        round == null ||
        day == null ||
        race == null) {
      return;
    }

    setState(() {
      _resolvingUrl = true;
      _urlResolveError = null;
    });

    try {
      final url = await LocalRaceUrlResolver.resolve(
        racecourseCode: code,
        venueName: venue,
        year: year,
        round: round,
        day: day,
        race: race,
      );
      if (!mounted) return;

      if (url == null) {
        setState(() {
          _resolvingUrl = false;
          _urlResolveError = '開催日を特定できませんでした';
        });
        return;
      }

      setState(() {
        _resolvedUrl = url;
        _resolvingUrl = false;
      });
      await _loadRaceResult();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvingUrl = false;
        _urlResolveError = '開催日の取得に失敗しました';
      });
    }
  }

  Future<void> _loadRaceResult() async {
    final url = _effectiveUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await RaceResultFetcher.fetch(url);
      if (!mounted) return;

      final purchases = data['購入内容'];
      final checks = <PurchaseCheckResult?>[];
      if (purchases is List) {
        for (final item in purchases) {
          if (item is Map) {
            checks.add(
              TicketPayoutChecker.checkPurchase(data, item, result),
            );
          } else {
            checks.add(null);
          }
        }
      }

      setState(() {
        _raceResult = result;
        _checkResults = checks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'レース結果の取得に失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.containsKey('エラー')) {
      return _buildError(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSection(context, 'レース情報', _raceInfoRows(context)),
        const SizedBox(height: 16),
        _buildPurchaseSection(context),
        if (_effectiveUrl != null || _resolvingUrl || _urlResolveError != null) ...[
          const SizedBox(height: 16),
          _buildResultCheckSection(context),
        ],
        if (data['下端番号'] != null) ...[
          const SizedBox(height: 16),
          _buildSection(context, 'その他', [
            _InfoRow(label: '下端番号', value: data['下端番号'].toString()),
          ]),
        ],
        const SizedBox(height: 16),
        _buildQrSection(context),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['エラー'].toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            if (data['詳細'] != null) ...[
              const SizedBox(height: 8),
              Text(
                data['詳細'].toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCheckSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '的中判定',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '再取得',
                  onPressed: (_loading || _resolvingUrl)
                      ? null
                      : () async {
                          if (_effectiveUrl == null) {
                            await _resolveLocalUrlIfNeeded();
                          } else {
                            await _loadRaceResult();
                          }
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Divider(),
            if (_resolvingUrl)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Center(child: CircularProgressIndicator()),
                    SizedBox(height: 8),
                    Text('開催日を特定しています…'),
                  ],
                ),
              )
            else if (_urlResolveError != null && _effectiveUrl == null)
              Text(
                _urlResolveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_raceResult == null)
              Text(
                'レース結果を取得していません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else if (!_raceResult!.hasResults)
              Text(
                'レース結果がまだ公開されていません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              _buildOverallSummary(context),
              const SizedBox(height: 16),
              _buildOfficialPayouts(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverallSummary(BuildContext context) {
    final valid = _checkResults.whereType<PurchaseCheckResult>().toList();
    final hits = valid.where((r) => r.hit).length;
    final totalPayout = valid.fold<int>(0, (sum, r) => sum + r.payoutYen);
    final stake = TicketPayoutChecker.summarizeTicket(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hits > 0 ? '的中あり（$hits件）' : '的中なし',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: hits > 0
                ? Colors.red.shade700
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _InfoRow(label: '組合せ', value: '${stake.totalCombinationCount}点'),
        _InfoRow(label: '購入合計', value: _formatYen(stake.totalAmountYen)),
        _InfoRow(label: '払戻合計', value: _formatYen(totalPayout)),
        _InfoRow(
          label: '収支',
          value: _formatYen(
            totalPayout - stake.totalAmountYen,
            showSign: true,
          ),
        ),
      ],
    );
  }

  /// 購入した式別の公式当たり組合せと払戻（100円あたり）
  Widget _buildOfficialPayouts(BuildContext context) {
    final betTypes = _purchasedBetTypes();
    if (betTypes.isEmpty || _raceResult == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '公式払戻（購入した式別）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        for (final betType in betTypes) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildBetTypePayouts(context, betType),
          ),
        ],
      ],
    );
  }

  Widget _buildBetTypePayouts(BuildContext context, String betType) {
    final payouts = _raceResult!.payoutsFor(normalizeBetType(betType));
    if (payouts.isEmpty) {
      return _InfoRow(label: betType, value: '払戻なし');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          betType,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        for (final payout in payouts)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '${payout.combinationLabel}　${_formatYen(payout.payoutPer100Yen)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

  List<String> _purchasedBetTypes() {
    final purchases = data['購入内容'];
    if (purchases is! List) return [];

    final types = <String>[];
    for (final item in purchases) {
      if (item is! Map) continue;
      final betType = item['式別']?.toString();
      if (betType == null || betType.isEmpty) continue;
      if (!types.contains(betType)) {
        types.add(betType);
      }
    }
    return types;
  }

  List<Widget> _raceInfoRows(BuildContext context) {
    final rows = <Widget>[];

    void addRow(String label, dynamic value) {
      if (value == null) return;
      rows.add(_InfoRow(label: label, value: _formatValue(value)));
    }

    addRow('開催場', data['開催場']);

    if (data['年'] != null) {
      final year = _asInt(data['年']);
      final yearLabel = year == null
          ? data['年'].toString()
          : LocalRaceUrlResolver.formatYearLabelForTicket(data, year);
      addRow(
        '開催',
        '$yearLabel 第${data['回']}回 第${data['日']}日 ${data['レース']}R',
      );
    }

    addRow('開催種別', data['開催種別']);
    addRow('券種', data['券種']);
    addRow('発売所', data['発売所']);
    addRow('マルチ', data['マルチ']);
    addRow('軸', data['軸']);
    addRow('着順指定', data['着順指定']);
    addRow('組合せ数', data['組合せ数']);

    final url = _effectiveUrl;
    if (url != null) {
      for (final link in NetkeibaUrls.displayUrls(url)) {
        rows.add(_UrlRow(url: link));
      }
    } else if (_resolvingUrl) {
      rows.add(
        const _InfoRow(label: 'URL', value: '開催日を特定中…'),
      );
    } else if (_urlResolveError != null) {
      rows.add(_InfoRow(label: 'URL', value: _urlResolveError!));
    }

    return rows;
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> rows,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSection(BuildContext context) {
    final purchases = data['購入内容'];
    if (purchases is! List || purchases.isEmpty) {
      return const SizedBox.shrink();
    }

    final stake = TicketPayoutChecker.summarizeTicket(data);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '購入内容',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            for (var i = 0; i < purchases.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildPurchaseItem(
                context,
                purchases[i],
                i < _checkResults.length ? _checkResults[i] : null,
                i < stake.purchases.length ? stake.purchases[i] : null,
              ),
            ],
            const Divider(),
            _InfoRow(
              label: '合計点数',
              value: '${stake.totalCombinationCount}点',
            ),
            _InfoRow(
              label: '合計金額',
              value: _formatYen(stake.totalAmountYen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseItem(
    BuildContext context,
    dynamic item,
    PurchaseCheckResult? check,
    PurchaseStakeSummary? stake,
  ) {
    if (item is! Map) return const SizedBox.shrink();

    final rows = <Widget>[];

    void addField(String label, dynamic value) {
      if (value == null) return;
      rows.add(_InfoRow(label: label, value: _formatValue(value)));
    }

    addField('式別', item['式別']);
    addField('ながし', item['ながし']);

    final betType = item['式別']?.toString() ?? '';
    final ticketType = data['券種']?.toString() ?? '';
    final horsesText = _formatPurchaseHorses(
      item,
      betType: betType,
      ticketType: ticketType,
      horseNamesByNumber: _raceResult?.horseNamesByNumber,
    );
    if (horsesText != null) {
      addField('馬番', horsesText);
    }
    addField('ウラ', item['ウラ']);

    if (stake != null) {
      addField('組合せ数', '${stake.combinationCount}点');
      if (stake.unitAmountYen > 0) {
        addField(
          stake.combinationCount > 1 ? '単位金額' : '購入金額',
          _formatYen(stake.unitAmountYen),
        );
      }
      if (stake.combinationCount > 1) {
        addField('合計金額', _formatYen(stake.totalAmountYen));
      }
    } else {
      final amount = _asInt(item['購入金額']);
      if (amount != null) {
        addField('購入金額', _formatYen(amount));
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (check != null) ...[
            _HitBadge(result: check),
            const SizedBox(height: 8),
          ],
          ...rows,
        ],
      ),
    );
  }

  Widget _buildQrSection(BuildContext context) {
    if (data['QR'] == null) return const SizedBox.shrink();

    return ExpansionTile(
      title: const Text('QR生データ'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SelectableText(
            data['QR'].toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _formatValue(dynamic value) {
    if (value is int) return value.toString();
    if (value is String) return value;
    if (value is List) return _formatList(value);
    return value.toString();
  }

  static String _formatList(List list) {
    if (list.isEmpty) return '';
    if (list.first is List) {
      return list.map((inner) => _formatList(inner as List)).join(' / ');
    }
    return list.map((e) => e.toString()).join(', ');
  }

  /// 馬単・枠単・三連単など着順のある式別
  static bool _isOrderedBet(String betType) => isOrderedBetType(betType);

  static bool _isUnorderedBet(String betType) => isUnorderedBetType(betType);

  /// 購入内容の馬番表示文字列を組み立てる
  static String? _formatPurchaseHorses(
    Map item, {
    required String betType,
    required String ticketType,
    Map<int, String>? horseNamesByNumber,
  }) {
    final isBox = ticketType == 'ボックス';
    final ura = item['ウラ']?.toString() == 'あり';

    // ながし（軸・相手）は式別に関わらず → でつなぐ
    if (item['軸'] != null && item['相手'] != null) {
      final nagashi = item['ながし']?.toString() ?? '';
      final axisStr = _formatHorseGroup(item['軸']);
      final partnerStr = _formatHorseGroup(item['相手']);
      if (_isOrderedBet(betType) && nagashi.contains('2着')) {
        return '$partnerStr > $axisStr';
      }
      if (_isOrderedBet(betType)) {
        return '$axisStr > $partnerStr';
      }
      return '$axisStr → $partnerStr';
    }

    final horses = item['馬番'];
    if (horses is! List || horses.isEmpty) return null;

    // 単勝・複勝・応援馬券（中身は単勝/複勝）: `1 馬名`
    if (betType == '単勝' || betType == '複勝') {
      return _formatWinPlaceHorses(horses, horseNamesByNumber);
    }

    if (_isOrderedBet(betType)) {
      return _formatOrderedSlots(horses, ura: ura, isBox: isBox);
    }

    if (_isUnorderedBet(betType)) {
      return _formatUnorderedSlots(horses, isBox: isBox);
    }

    return _formatValue(horses);
  }

  /// 単勝・複勝: 馬番の後ろにレース結果の馬名を付ける
  static String _formatWinPlaceHorses(
    List horses,
    Map<int, String>? horseNamesByNumber,
  ) {
    return horses.map((e) {
      final number = e is int ? e : int.tryParse(e.toString());
      final label = number?.toString() ?? e.toString();
      if (number == null || horseNamesByNumber == null) return label;
      final name = horseNamesByNumber[number];
      if (name == null || name.isEmpty) return label;
      return '$label $name';
    }).join(', ');
  }

  static String _formatOrderedSlots(
    List list, {
    required bool ura,
    required bool isBox,
  }) {
    if (isBox) {
      return _formatBoxHorses(list);
    }
    if (ura && list.length == 2 && list.first is! List) {
      return '${list[0]} <> ${list[1]}';
    }
    if (list.first is List) {
      return list.map(_formatHorseGroup).join(' > ');
    }
    return list.map((e) => e.toString()).join(' > ');
  }

  /// 馬連・枠連・ワイド・三連複（ながし以外）: `1 - 2 - 3` / `1 - 2, 3 - 4`
  static String _formatUnorderedSlots(List list, {required bool isBox}) {
    if (isBox) {
      return _formatBoxHorses(list);
    }
    if (list.first is List) {
      return list.map(_formatHorseGroup).join(' - ');
    }
    return list.map((e) => e.toString()).join(' - ');
  }

  static String _formatBoxHorses(List list) {
    if (list.isNotEmpty && list.first is List) {
      return list
          .expand((inner) => inner is List ? inner : [inner])
          .map((e) => e.toString())
          .join(', ');
    }
    return list.map((e) => e.toString()).join(', ');
  }

  static String _formatHorseGroup(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    return value.toString();
  }
}

class _HitBadge extends StatelessWidget {
  final PurchaseCheckResult result;

  const _HitBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (result.hit) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      label = result.payoutYen > 0
          ? '的中  払戻 ${_formatYen(result.payoutYen)}'
          : '的中';
    } else if (result.note != null) {
      bg = Theme.of(context).colorScheme.surfaceContainerHighest;
      fg = Theme.of(context).colorScheme.onSurfaceVariant;
      label = result.note!;
    } else {
      bg = Theme.of(context).colorScheme.surfaceContainerHighest;
      fg = Theme.of(context).colorScheme.onSurfaceVariant;
      label = '外れ';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold),
          ),
          if (result.hit && result.matchedLabels.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '的中組合せ: ${result.matchedLabels.join(' / ')}',
              style: TextStyle(color: fg, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlRow extends StatelessWidget {
  final String url;

  const _UrlRow({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'URL',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => openExternalUrl(url),
              child: Text(
                url,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
