import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'a11y_widgets.dart';
import 'history_page.dart';
import 'qr_scanner_page.dart';
import 'scan_history_service.dart';
import 'ticket_result_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '馬券QRリーダー',
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(primary: Colors.green),
      ),
      themeMode: ThemeMode.system,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? parsedResult;
  String? _currentHistoryId;
  bool _continuousMode = false;

  Future<void> _handleParsedTicket(Map<String, dynamic> result) async {
    if (result.containsKey('エラー')) {
      setState(() {
        parsedResult = result;
        _currentHistoryId = null;
      });
      return;
    }

    final id = await ScanHistoryService.add(result);
    if (!mounted) return;
    setState(() {
      parsedResult = result;
      _currentHistoryId = id;
    });
  }

  Future<void> _openQRScanner({bool openGalleryOnStart = false}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => QRScannerPage(
          openGalleryOnStart: openGalleryOnStart,
          continuousMode: _continuousMode,
          onTicketParsed: _continuousMode
              ? (data) {
                  _handleParsedTicket(data);
                }
              : null,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _handleParsedTicket(result);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬券QRリーダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '履歴',
            onPressed: _openHistory,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openQRScanner(),
                    child: const Text('QRコード読み取り'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openQRScanner(openGalleryOnStart: true),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('画像から読み取り'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('続けて読む'),
              subtitle: const Text('読み取り後もスキャナを閉じず、次の馬券を続けて読めます'),
              value: _continuousMode,
              onChanged: (value) => setState(() => _continuousMode = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: parsedResult != null
                    ? TicketResultView(
                        data: parsedResult!,
                        historyEntryId: _currentHistoryId,
                        onDataUpdated: (updated) {
                          setState(() => parsedResult = updated);
                        },
                        onRescan: () => _openQRScanner(),
                      )
                    : _HomeEmptyState(
                        onScan: () => _openQRScanner(),
                        onPickImage: () =>
                            _openQRScanner(openGalleryOnStart: true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onPickImage;

  const _HomeEmptyState({
    required this.onScan,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            A11yStatusMessage(
              '馬券のQRコードは2枚あります。両方をカメラでかざすか、'
              '2枚が写った画像を選んでください。',
              style: TextStyle(color: muted, height: 1.5),
              liveRegion: false,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onScan,
              child: const Text('カメラで読み取る'),
            ),
            TextButton(
              onPressed: onPickImage,
              child: const Text('画像から読み取る'),
            ),
          ],
        ),
      ),
    );
  }
}
