import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ticket_qr_parse.dart';

/// QR生文字列を貼り付けて馬券を解析する画面
class PasteTicketPage extends StatefulWidget {
  const PasteTicketPage({super.key});

  @override
  State<PasteTicketPage> createState() => _PasteTicketPageState();
}

class _PasteTicketPageState extends State<PasteTicketPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = 'クリップボードに文字がありません');
      return;
    }
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      _error = null;
    });
  }

  void _parse() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'QRの文字列を入力または貼り付けてください');
      return;
    }

    final result = parseTicketFromPastedText(text);
    if (result == null || result.containsKey('エラー')) {
      setState(() {
        _error = result?['エラー']?.toString() ??
            '解析できませんでした。結合済みの文字列、または2枚分を改行区切りで貼り付けてください。';
      });
      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文字列を貼り付けて解析'),
        actions: [
          IconButton(
            tooltip: 'クリップボードから貼り付け',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'カメラで読んだQRの生データ（数字の並び）を貼り付けて解析できます。\n'
                '・結合済みの1本、または\n'
                '・2枚分を改行で区切った文字列\n'
                'に対応しています。',
                style: TextStyle(color: muted, height: 1.45),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ここにQR文字列を貼り付け',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('クリップボードから'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _parse,
                      icon: const Icon(Icons.check),
                      label: const Text('解析する'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
