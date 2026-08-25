import 'package:flutter/material.dart';

import 'a11y_widgets.dart';
import 'scan_history_entry.dart';
import 'scan_history_service.dart';
import 'ticket_result_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanHistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ScanHistoryService.load();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<void> _deleteEntry(ScanHistoryEntry entry) async {
    await ScanHistoryService.delete(entry.id);
    if (mounted) {
      setState(() {
        _entries.removeWhere((e) => e.id == entry.id);
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
    setState(() => _entries = []);
  }

  void _openDetail(ScanHistoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryDetailPage(
          entry: entry,
          onDeleted: () {
            setState(() {
              _entries.removeWhere((e) => e.id == entry.id);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('読み取り履歴'),
        actions: [
          if (_entries.isNotEmpty)
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
          : _entries.isEmpty
          ? Center(
              child: A11yStatusMessage(
                '履歴はありません',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                liveRegion: false,
              ),
            )
          : ListView.separated(
              itemCount: _entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _entries[index];
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
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    onDismissed: (_) => _deleteEntry(entry),
                    child: ListTile(
                      title: Text(entry.title),
                      subtitle: Text(
                        '${entry.subtitle}\n${entry.scannedAtLabel}',
                      ),
                      isThreeLine: true,
                      onTap: () => _openDetail(entry),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  final ScanHistoryEntry entry;
  final VoidCallback onDeleted;

  const HistoryDetailPage({
    super.key,
    required this.entry,
    required this.onDeleted,
  });

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

    await ScanHistoryService.delete(entry.id);
    onDeleted();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
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
              '読み取り日時: ${entry.scannedAtLabel}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TicketResultView(data: entry.data),
          ],
        ),
      ),
    );
  }
}
