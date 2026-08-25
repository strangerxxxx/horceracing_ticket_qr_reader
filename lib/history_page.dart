import 'package:flutter/material.dart';

import 'a11y_widgets.dart';
import 'hit_colors.dart';
import 'scan_history_entry.dart';
import 'scan_history_query.dart';
import 'scan_history_service.dart';
import 'ticket_result_view.dart';

class HistoryPage extends StatefulWidget {
  /// テスト差し替え用。未指定時は [ScanHistoryService.load]
  final Future<List<ScanHistoryEntry>> Function()? loader;

  const HistoryPage({super.key, this.loader});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanHistoryEntry> _allEntries = [];
  bool _loading = true;
  String _query = '';
  HistoryHitFilter _hitFilter = HistoryHitFilter.all;
  HistorySortField _sortField = HistorySortField.scannedAt;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loader = widget.loader ?? ScanHistoryService.load;
      final entries = await loader();
      if (mounted) {
        setState(() {
          _allEntries = ScanHistoryQuery.dedupeLatest(entries);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allEntries = [];
          _loading = false;
        });
      }
    }
  }

  List<ScanHistoryEntry> get _visibleEntries {
    final filtered = ScanHistoryQuery.filter(
      entries: _allEntries,
      query: _query,
      hitFilter: _hitFilter,
    );
    return ScanHistoryQuery.sort(
      entries: filtered,
      field: _sortField,
      ascending: _sortAscending,
    );
  }

  Future<void> _deleteEntry(ScanHistoryEntry entry) async {
    await ScanHistoryService.delete(entry.id);
    if (mounted) {
      setState(() {
        _allEntries.removeWhere((e) => e.id == entry.id);
      });
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除'),
        content: const Text('すべての読み取り履歴を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ScanHistoryService.clear();
    setState(() => _allEntries = []);
  }

  void _openDetail(ScanHistoryEntry entry) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => HistoryDetailPage(
              entry: entry,
              onDeleted: () {
                setState(() {
                  _allEntries.removeWhere((e) => e.id == entry.id);
                });
              },
            ),
          ),
        )
        .then((_) => _load());
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _hitFilter != HistoryHitFilter.all;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;
    final totals = ScanHistoryQuery.totals(visible);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('読み取り履歴'),
        actions: [
          if (_allEntries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'すべて削除',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: A11yLoadingIndicator(message: '履歴を読み込んでいます…'),
            )
          : _allEntries.isEmpty
          ? Center(
              child: A11yStatusMessage(
                '履歴はありません',
                style: TextStyle(color: muted),
                liveRegion: false,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '開催場・レース名・券種などで検索',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      for (final filter in HistoryHitFilter.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter.label),
                            selected: _hitFilter == filter,
                            onSelected: (_) =>
                                setState(() => _hitFilter = filter),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '並び替え',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<HistorySortField>(
                              value: _sortField,
                              isExpanded: true,
                              items: [
                                for (final field in HistorySortField.values)
                                  DropdownMenuItem(
                                    value: field,
                                    child: Text(field.label),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _sortField = value);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: _sortAscending ? '昇順' : '降順',
                        onPressed: () => setState(
                          () => _sortAscending = !_sortAscending,
                        ),
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasActiveFilter || visible.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _hasActiveFilter
                            ? '表示 ${visible.length}件 · '
                                '合計購入 ${_formatYen(totals.purchaseTotal)} · '
                                '合計払戻 ${_formatYen(totals.payoutTotal)}'
                            : '${visible.length}件',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: A11yStatusMessage(
                            '条件に一致する履歴はありません',
                            style: TextStyle(color: muted),
                            liveRegion: false,
                          ),
                        )
                      : ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = visible[index];
                            return Semantics(
                              hint: '左にスワイプして削除できます',
                              child: Dismissible(
                                key: ValueKey(entry.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Theme.of(context).colorScheme.error,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Icon(
                                    Icons.delete,
                                    color:
                                        Theme.of(context).colorScheme.onError,
                                  ),
                                ),
                                onDismissed: (_) => _deleteEntry(entry),
                                child: ListTile(
                                  title: Text(entry.title),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.subtitle),
                                      Text(
                                        '${entry.hitSummaryLabel} · ${entry.moneySummaryLabel}',
                                      ),
                                      Text(
                                        entry.scannedAtLabel,
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: entry.hasPayoutResult &&
                                          (entry.hitCount ?? 0) > 0
                                      ? Icon(
                                          Icons.check_circle,
                                          color: HitColors.foreground(context),
                                        )
                                      : null,
                                  onTap: () => _openDetail(entry),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
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
}

class HistoryDetailPage extends StatefulWidget {
  final ScanHistoryEntry entry;
  final VoidCallback onDeleted;

  const HistoryDetailPage({
    super.key,
    required this.entry,
    required this.onDeleted,
  });

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.entry.data);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除'),
        content: const Text('この読み取り履歴を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ScanHistoryService.delete(widget.entry.id);
    widget.onDeleted();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '削除',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '読み取り日時: ${widget.entry.scannedAtLabel}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TicketResultView(
              data: _data,
              historyEntryId: widget.entry.id,
              onDataUpdated: (updated) {
                setState(() => _data = updated);
              },
            ),
          ],
        ),
      ),
    );
  }
}
