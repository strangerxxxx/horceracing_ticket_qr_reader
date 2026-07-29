import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// QR解析結果を表形式で表示するウィジェット
class TicketResultView extends StatelessWidget {
  final Map<String, dynamic> data;

  const TicketResultView({super.key, required this.data});

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

  List<Widget> _raceInfoRows(BuildContext context) {
    final rows = <Widget>[];

    void addRow(String label, dynamic value) {
      if (value == null) return;
      rows.add(_InfoRow(label: label, value: _formatValue(value)));
    }

    addRow('開催場', data['開催場']);

    if (data['年'] != null) {
      final year = data['年'];
      final yearStr = year is int && year < 100 ? '20$year' : year.toString();
      addRow(
        '開催',
        '$yearStr年 第${data['回']}回 第${data['日']}日 ${data['レース']}R',
      );
    }

    addRow('開催種別', data['開催種別']);
    addRow('券種', data['券種']);
    addRow('発売所', data['発売所']);
    addRow('マルチ', data['マルチ']);
    addRow('軸', data['軸']);
    addRow('着順指定', data['着順指定']);
    addRow('組合せ数', data['組合せ数']);

    if (data['URL'] != null) {
      rows.add(_UrlRow(url: data['URL'].toString()));
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
              _buildPurchaseItem(context, purchases[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseItem(BuildContext context, dynamic item) {
    if (item is! Map) return const SizedBox.shrink();

    final rows = <Widget>[];

    void addField(String label, dynamic value) {
      if (value == null) return;
      rows.add(_InfoRow(label: label, value: _formatValue(value)));
    }

    addField('式別', item['式別']);
    addField('馬番', item['馬番']);
    addField('ながし', item['ながし']);
    addField('軸', item['軸']);
    addField('相手', item['相手']);
    addField('ウラ', item['ウラ']);
    if (item['購入金額'] != null) {
      addField('購入金額', '${item['購入金額']}円');
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
        children: rows,
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
    if (value is List) {
      if (value.isEmpty) return '';
      if (value.first is int) {
        return (value as List<int>).join(', ');
      }
      if (value.first is List) {
        return value
            .map((inner) => (inner as List<int>).join(','))
            .join(' - ');
      }
    }
    return value.toString();
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
              onTap: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
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
