import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'a11y_widgets.dart';
import 'bet_type.dart';
import 'external_url.dart';
import 'frame_color.dart';
import 'hit_colors.dart';
import 'http_fetch.dart';
import 'local_race_url.dart';
import 'netkeiba_urls.dart';
import 'race_result.dart';
import 'race_result_fetcher.dart';
import 'scan_history_service.dart';
import 'ticket.dart';
import 'ticket_payout_checker.dart';

/// 的中判定の永続化だけで変わるキー（再取得のトリガーにしない）
const _persistedMetaKeys = {
  'レース名',
  '開催日',
  '購入合計',
  '払戻合計',
  '的中件数',
  '結果取得済',
};

const _deepEquals = DeepCollectionEquality();

/// 馬券本体（開催・購入内容など）が同じか。メタ更新による再フェッチ抑止用。
@visibleForTesting
bool ticketDataCoreEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map<String, dynamic> core(Map<String, dynamic> source) => {
        for (final e in source.entries)
          if (!_persistedMetaKeys.contains(e.key)) e.key: e.value,
      };
  return _deepEquals.equals(core(a), core(b));
}

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
  final String? historyEntryId;
  final ValueChanged<Map<String, dynamic>>? onDataUpdated;
  final VoidCallback? onRescan;

  const TicketResultView({
    super.key,
    required this.data,
    this.historyEntryId,
    this.onDataUpdated,
    this.onRescan,
  });

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

  /// 古い非同期結果を捨てるための世代番号
  int _loadGeneration = 0;

  Map<String, dynamic> get data => widget.data;

  Ticket get ticket => Ticket.fromMap(data);

  String? get _effectiveUrl =>
      _resolvedUrl ?? ticket.resultUrl;

  bool get _canFetchRaceMeta {
    if (ticket.hasError) return false;
    if (ticket.resultUrl != null) return true;

    return ticket.venueCode != null &&
        ticket.venueName != null &&
        ticket.year != null &&
        ticket.round != null &&
        ticket.day != null &&
        ticket.raceNumber != null;
  }

  bool get _isFetchingRaceMeta => _loading || _resolvingUrl;

  String? _raceMetaDisplayValue(String? fromResult, String? fromData) {
    if (fromResult != null && fromResult.isNotEmpty) return fromResult;
    if (fromData != null && fromData.isNotEmpty) return fromData;
    if (!_canFetchRaceMeta) return null;
    if (_isFetchingRaceMeta) return '取得中 ...';
    if (_error != null || _urlResolveError != null) {
      return '取得できませんでした';
    }
    if (_raceResult != null) return null;
    return '取得中 ...';
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant TicketResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 払戻メタの書き戻しでは再取得しない（的中バッジの点滅を防ぐ）
    if (!ticketDataCoreEquals(oldWidget.data, widget.data)) {
      _loadGeneration++;
      _raceResult = null;
      _checkResults = [];
      _error = null;
      _resolvedUrl = null;
      _urlResolveError = null;
      _loading = false;
      _resolvingUrl = false;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    if (ticket.hasError) return;

    final generation = ++_loadGeneration;

    if (ticket.resultUrl != null) {
      await _loadRaceResult(generation: generation);
      return;
    }

    await _resolveLocalUrlIfNeeded(generation: generation);
  }

  Future<void> _resolveLocalUrlIfNeeded({required int generation}) async {
    final code = ticket.venueCode;
    final venue = ticket.venueName;
    final year = ticket.year;
    final round = ticket.round;
    final day = ticket.day;
    final race = ticket.raceNumber;

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
      final result = await LocalRaceUrlResolver.resolveDetailed(
        racecourseCode: code,
        venueName: venue,
        year: year,
        round: round,
        day: day,
        race: race,
      );
      if (!_isCurrentGeneration(generation)) return;

      if (!result.isSuccess) {
        setState(() {
          _resolvingUrl = false;
          _urlResolveError =
              result.failureReason ?? '開催日を特定できませんでした';
        });
        return;
      }

      setState(() {
        _resolvedUrl = result.url;
        _resolvingUrl = false;
      });
      await _loadRaceResult(generation: generation);
    } on HttpFetchException catch (e) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _resolvingUrl = false;
        _urlResolveError = e.message;
      });
    } catch (e) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _resolvingUrl = false;
        _urlResolveError = '開催日の取得に失敗しました';
      });
    }
  }

  bool _isCurrentGeneration(int generation) =>
      mounted && generation == _loadGeneration;

  Future<void> _loadRaceResult({
    bool forceRefresh = false,
    required int generation,
  }) async {
    final url = _effectiveUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await RaceResultFetcher.fetch(
        url,
        forceRefresh: forceRefresh,
      );
      if (!_isCurrentGeneration(generation)) return;

      final purchases = ticket.purchases;
      final checks = <PurchaseCheckResult?>[];
      for (final item in purchases) {
        checks.add(
          TicketPayoutChecker.checkPurchase(ticket, item, result),
        );
      }

      // 一度確定した判定を、一時的な未公開パースで上書きしない
      if (!result.hasResults &&
          _raceResult != null &&
          _raceResult!.hasResults &&
          !forceRefresh) {
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _raceResult = result;
        _checkResults = checks;
        _loading = false;
      });
      await _persistRaceMeta(result, checks);
    } on HttpFetchException catch (e) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _loading = false;
        _error = 'レース結果の取得に失敗しました';
      });
    }
  }

  Future<void> _persistRaceMeta(
    RaceResult result,
    List<PurchaseCheckResult?> checks,
  ) async {
    final updates = <String, dynamic>{};

    final raceName = result.raceName;
    if (raceName != null &&
        raceName.isNotEmpty &&
        data['レース名']?.toString() != raceName) {
      updates['レース名'] = raceName;
    }

    final raceDateLabel = result.raceDateLabel;
    if (raceDateLabel != null &&
        raceDateLabel.isNotEmpty &&
        data['開催日']?.toString() != raceDateLabel) {
      updates['開催日'] = raceDateLabel;
    }

    final stake = TicketPayoutChecker.summarizeTicket(ticket);
    if (data['購入合計'] != stake.totalAmountYen) {
      updates['購入合計'] = stake.totalAmountYen;
    }

    final removeKeys = <String>[];
    if (result.hasResults) {
      final valid = checks.whereType<PurchaseCheckResult>().toList();
      final hits = valid.where((r) => r.hit).length;
      final totalPayout = valid.fold<int>(0, (sum, r) => sum + r.payoutYen);
      if (data['払戻合計'] != totalPayout) updates['払戻合計'] = totalPayout;
      if (data['的中件数'] != hits) updates['的中件数'] = hits;
      if (data['結果取得済'] != true) updates['結果取得済'] = true;
    } else if (data['結果取得済'] == true) {
      // 既に確定済みなら、未公開扱いの一時結果で履歴ラベルを消さない
    } else {
      if (data['結果取得済'] != false) updates['結果取得済'] = false;
      if (data.containsKey('払戻合計') || data.containsKey('的中件数')) {
        removeKeys.addAll(['払戻合計', '的中件数']);
      }
    }

    if (updates.isEmpty && removeKeys.isEmpty) return;

    final merged = {...data, ...updates};
    for (final key in removeKeys) {
      merged.remove(key);
    }
    if (_deepEquals.equals(merged, data)) return;

    final historyEntryId = widget.historyEntryId;
    if (historyEntryId != null) {
      await ScanHistoryService.updateData(
        historyEntryId,
        updates,
        removeKeys: removeKeys,
      );
    }

    if (!mounted) return;
    widget.onDataUpdated?.call(merged);
  }

  @override
  Widget build(BuildContext context) {
    if (ticket.hasError) {
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
    final message = ticket.error ?? 'エラー';
    final detail = ticket.errorDetail;
    return Semantics(
      liveRegion: true,
      label: detail == null ? message : '$message。$detail',
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
              if (widget.onRescan != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onRescan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('もう一度読み取る'),
                ),
              ],
            ],
          ),
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
                  child: A11ySectionTitle(
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
                          final generation = ++_loadGeneration;
                          if (_effectiveUrl == null) {
                            await _resolveLocalUrlIfNeeded(
                              generation: generation,
                            );
                          } else {
                            await _loadRaceResult(
                              forceRefresh: true,
                              generation: generation,
                            );
                          }
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Divider(),
            if (_resolvingUrl)
              const A11yLoadingIndicator(message: '開催日を特定しています…')
            else if (_urlResolveError != null && _effectiveUrl == null)
              A11yStatusMessage(
                _urlResolveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_loading)
              const A11yLoadingIndicator(message: 'レース結果を取得しています…')
            else if (_error != null)
              A11yStatusMessage(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_raceResult == null)
              A11yStatusMessage(
                'レース結果を取得していません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                liveRegion: false,
              )
            else if (!_raceResult!.layoutRecognized)
              A11yStatusMessage(
                'レース結果ページの形式を解釈できませんでした。'
                'サイトの表示が変わった可能性があります。下のリンクから公式ページを確認し、'
                '再取得を試してください。',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (!_raceResult!.hasResults)
              A11yStatusMessage(
                'レース結果がまだ公開されていません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                liveRegion: false,
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
    final stake = TicketPayoutChecker.summarizeTicket(ticket);
    final labelStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    const valueStyle = TextStyle(fontWeight: FontWeight.w500);
    final summaryRows = [
      ('組合せ', '${stake.totalCombinationCount}点'),
      ('購入合計', _formatYen(stake.totalAmountYen)),
      ('払戻合計', _formatYen(totalPayout)),
      (
        '収支',
        _formatYen(
          totalPayout - stake.totalAmountYen,
          showSign: true,
        ),
      ),
    ];

    return Semantics(
      label: hits > 0 ? '的中あり、$hits件' : '的中なし',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hits > 0 ? '的中あり（$hits件）' : '的中なし',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: hits > 0
                  ? HitColors.foreground(context)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(80),
              1: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              for (final (label, value) in summaryRows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ExcludeSemantics(
                        child: Text(label, style: labelStyle),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Semantics(
                        label: '$label、$value',
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: valueStyle,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
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
        A11ySectionTitle(
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
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final payout in payouts)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
                    child: _buildPayoutCombination(
                      payout.combinationKey,
                      betType,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      label: '払戻 ${_formatYen(payout.payoutPer100Yen)}',
                      child: Text(
                        _formatYen(payout.payoutPer100Yen),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// 公式払戻の組合せキーを枠色バッジで表示する
  Widget _buildPayoutCombination(String key, String betType) {
    final numberIsFrame = _isFrameBet(betType);
    final ordered = _isOrderedBet(betType);
    final separator = ordered ? '>' : '-';
    final parts = key
        .split(separator)
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    if (parts.isEmpty) {
      return Text(key, style: const TextStyle(fontWeight: FontWeight.w500));
    }

    // 単勝・複勝: バッジ + 馬名
    if (betType == '単勝' || betType == '複勝') {
      final n = parts.first;
      final name = _raceResult?.horseName(n);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _numberBadge(n, numberIsFrame: false),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    final sepText = ordered ? ' > ' : ' - ';
    return _joinParts(
      [
        for (final n in parts)
          _numberBadge(n, numberIsFrame: numberIsFrame),
      ],
      sepText,
    );
  }

  List<String> _purchasedBetTypes() {
    final types = <String>[];
    for (final item in ticket.purchases) {
      final betType = item.betType;
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

    addRow('開催日', _raceMetaDisplayValue(
      _raceResult?.raceDateLabel,
      data['開催日']?.toString(),
    ));
    addRow('レース名', _raceMetaDisplayValue(
      _raceResult?.raceName,
      data['レース名']?.toString(),
    ));

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
            A11ySectionTitle(
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
    final purchases = ticket.purchases;
    if (purchases.isEmpty) {
      return const SizedBox.shrink();
    }

    final stake = TicketPayoutChecker.summarizeTicket(ticket);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            A11ySectionTitle(
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
                purchases[i].toMap(),
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
    final ticketType = ticket.ticketType ?? '';
    final numberIsFrame = _isFrameBet(betType);
    final purchaseItem = PurchaseItem.fromMap(Map<String, dynamic>.from(item));
    final horsesWidget = _buildPurchaseHorses(
      item,
      betType: betType,
      ticketType: ticketType,
    );
    if (horsesWidget != null) {
      rows.add(
        _InfoRow.widget(
          label: '馬番',
          semanticValue: purchaseItem.semanticNumbersDescription(
            numberIsFrame: numberIsFrame,
          ),
          child: horsesWidget,
        ),
      );
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
  bool _isOrderedBet(String betType) => isOrderedBetType(betType);

  bool _isUnorderedBet(String betType) => isUnorderedBetType(betType);

  bool _isFrameBet(String betType) => isFrameBetType(betType);

  Widget _numberBadge(int number, {required bool numberIsFrame}) {
    final frame = resolveFrameNumber(
      number: number,
      numberIsFrame: numberIsFrame,
      frameByHorseNumber: _raceResult?.frameByHorseNumber,
      fieldSize: _raceResult?.fieldSize,
    );
    return NumberBadge(
      number: number,
      frameNumber: frame,
      numberIsFrame: numberIsFrame,
    );
  }

  int? _asHorseNumber(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 購入内容の馬番・枠番表示
  Widget? _buildPurchaseHorses(
    Map item, {
    required String betType,
    required String ticketType,
  }) {
    final isBox = ticketType == 'ボックス';
    final ura = item['ウラ']?.toString() == 'あり';
    final numberIsFrame = _isFrameBet(betType);
    final names = _raceResult?.horseNamesByNumber;
    final orderedSep = _orderedSeparator(betType);

    // ながし（軸・相手）
    if (item['軸'] != null && item['相手'] != null) {
      final nagashi = item['ながし']?.toString() ?? '';
      final axis = _buildNumberGroup(item['軸'], numberIsFrame: numberIsFrame);
      final partner =
          _buildNumberGroup(item['相手'], numberIsFrame: numberIsFrame);
      if (_isOrderedBet(betType) && nagashi.contains('2着')) {
        return _joinParts([partner, axis], orderedSep);
      }
      if (_isOrderedBet(betType)) {
        return _joinParts([axis, partner], orderedSep);
      }
      return _joinParts([axis, partner], ' → ');
    }

    final horses = item['馬番'];
    if (horses is! List || horses.isEmpty) return null;

    if (betType == '単勝' || betType == '複勝') {
      return _buildWinPlaceHorses(horses, names);
    }

    if (_isOrderedBet(betType)) {
      return _buildOrderedSlots(
        horses,
        ura: ura,
        isBox: isBox,
        numberIsFrame: numberIsFrame,
        orderedSep: orderedSep,
      );
    }

    if (_isUnorderedBet(betType)) {
      return _buildUnorderedSlots(
        horses,
        isBox: isBox,
        numberIsFrame: numberIsFrame,
      );
    }

    return _buildNumberGroup(horses, numberIsFrame: numberIsFrame);
  }

  /// 3連単マルチは着順不定のため <> 、それ以外の連単系は >
  String _orderedSeparator(String betType) {
    final multi = data['マルチ']?.toString() == 'あり';
    if (multi && normalizeBetType(betType) == '三連単') {
      return ' <> ';
    }
    return ' > ';
  }

  Widget _buildWinPlaceHorses(List horses, Map<int, String>? names) {
    final parts = <Widget>[];
    for (final horse in horses) {
      final n = _asHorseNumber(horse);
      if (n == null) {
        parts.add(Text('$horse', style: const TextStyle(fontWeight: FontWeight.w500)));
        continue;
      }
      final name = names?[n];
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numberBadge(n, numberIsFrame: false),
            if (name != null && name.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      );
    }
    return _joinParts(parts, '');
  }

  Widget _buildOrderedSlots(
    List list, {
    required bool ura,
    required bool isBox,
    required bool numberIsFrame,
    required String orderedSep,
  }) {
    if (isBox) {
      return _buildBoxHorses(list, numberIsFrame: numberIsFrame);
    }
    if (ura && list.length == 2 && list.first is! List) {
      return _joinParts(
        [
          _buildNumberGroup(list[0], numberIsFrame: numberIsFrame),
          _buildNumberGroup(list[1], numberIsFrame: numberIsFrame),
        ],
        ' <> ',
      );
    }
    if (list.isNotEmpty && list.first is List) {
      return _joinParts(
        [
          for (final slot in list)
            _buildNumberGroup(slot, numberIsFrame: numberIsFrame),
        ],
        orderedSep,
      );
    }
    return _joinParts(
      [
        for (final e in list)
          _buildNumberGroup(e, numberIsFrame: numberIsFrame),
      ],
      orderedSep,
    );
  }

  Widget _buildUnorderedSlots(
    List list, {
    required bool isBox,
    required bool numberIsFrame,
  }) {
    if (isBox) {
      return _buildBoxHorses(list, numberIsFrame: numberIsFrame);
    }
    if (list.isNotEmpty && list.first is List) {
      return _joinParts(
        [
          for (final slot in list)
            _buildNumberGroup(slot, numberIsFrame: numberIsFrame),
        ],
        ' - ',
      );
    }
    return _joinParts(
      [
        for (final e in list)
          _buildNumberGroup(e, numberIsFrame: numberIsFrame),
      ],
      ' - ',
    );
  }

  Widget _buildBoxHorses(List list, {required bool numberIsFrame}) {
    final numbers = <dynamic>[];
    if (list.isNotEmpty && list.first is List) {
      for (final inner in list) {
        if (inner is List) {
          numbers.addAll(inner);
        } else {
          numbers.add(inner);
        }
      }
    } else {
      numbers.addAll(list);
    }
    return _buildNumberGroup(numbers, numberIsFrame: numberIsFrame);
  }

  Widget _buildNumberGroup(dynamic value, {required bool numberIsFrame}) {
    if (value is List) {
      return _joinParts(
        [
          for (final e in value)
            _buildNumberGroup(e, numberIsFrame: numberIsFrame),
        ],
        '',
      );
    }
    final n = _asHorseNumber(value);
    if (n == null) {
      return Text(
        value.toString(),
        style: const TextStyle(fontWeight: FontWeight.w500),
      );
    }
    return _numberBadge(n, numberIsFrame: numberIsFrame);
  }

  Widget _joinParts(List<Widget> parts, String separator) {
    if (parts.isEmpty) return const SizedBox.shrink();
    if (parts.length == 1) return parts.first;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: separator.isEmpty ? 4 : 0,
      runSpacing: 4,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0 && separator.isNotEmpty) A11ySeparatorText(separator),
          parts[i],
        ],
      ],
    );
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
      bg = HitColors.background(context);
      fg = HitColors.onBackground(context);
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
      label = 'はずれ';
    }

    final semanticLabel = result.hit && result.matchedLabels.isNotEmpty
        ? '$label。的中組合せ ${result.matchedLabels.join(' / ')}'
        : label;

    return Semantics(
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold),
              ),
            ),
            if (result.hit && result.matchedLabels.isNotEmpty) ...[
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: Text(
                  '的中組合せ: ${result.matchedLabels.join(' / ')}',
                  style: TextStyle(color: fg, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? semanticValue;

  const _InfoRow({required this.label, required this.value})
      : valueWidget = null,
        semanticValue = null;

  const _InfoRow.widget({
    required this.label,
    required Widget child,
    this.semanticValue,
  })  : value = null,
        valueWidget = child;

  @override
  Widget build(BuildContext context) {
    return A11yLabeledRow(
      label: label,
      value: value,
      valueWidget: valueWidget,
      semanticValue: semanticValue,
    );
  }
}

class _UrlRow extends StatelessWidget {
  final String url;

  const _UrlRow({required this.url});

  String _linkLabel(String url) {
    if (url.contains('race.netkeiba.com')) {
      return '中央競馬の結果ページをブラウザで開く';
    }
    if (url.contains('nar.netkeiba.com')) {
      return '地方競馬の結果ページをブラウザで開く';
    }
    return 'レース結果データベースをブラウザで開く';
  }

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
            child: A11yLinkText(
              label: _linkLabel(url),
              url: url,
              onTap: () => openExternalUrl(url),
            ),
          ),
        ],
      ),
    );
  }
}
