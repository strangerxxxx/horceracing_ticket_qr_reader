import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'a11y_widgets.dart';
import 'history_page.dart';
import 'image_ticket_reader.dart';
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
  bool _readingImages = false;

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

  Future<void> _openQRScanner() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => QRScannerPage(
          onTicketParsed: (data) {
            _handleParsedTicket(data);
          },
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _handleParsedTicket(result);
    }
  }

  Future<void> _pickFromImages({required bool multiple}) async {
    if (_readingImages) return;
    setState(() => _readingImages = true);

    try {
      final picked = await ImageTicketReader.pickImages(multiple: multiple);
      if (!mounted) return;

      if (picked == null) {
        await _showPhotoPermissionDeniedDialog();
        return;
      }
      if (picked.isEmpty) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: A11yLoadingIndicator(message: '画像を解析しています…'),
              ),
            ),
          ),
        ),
      );

      final outcome = await ImageTicketReader.parseImages(picked);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (outcome.ticket != null) {
        await _handleParsedTicket(outcome.ticket!);
        return;
      }

      if (outcome.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.message!)),
        );
      }
    } catch (_) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の解析に失敗しました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _readingImages = false);
      }
    }
  }

  Future<void> _showPhotoPermissionDeniedDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写真へのアクセス'),
        content: const Text(
          '画像から読み取るには、設定で写真へのアクセスを許可してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
    if (open == true) {
      await AppSettings.openAppSettings();
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '馬券QRリーダー',
      applicationVersion: '0.5.0',
      applicationLegalese: 'MIT License',
      children: const [
        SizedBox(height: 16),
        Text(
          '本アプリは非公式です。JRA・地方競馬・netkeiba 等との提携はありません。',
        ),
        SizedBox(height: 12),
        Text(
          '馬券QRの仕様は公開されていないため、読み取り結果が常に正しいとは限りません。',
        ),
        SizedBox(height: 12),
        Text(
          'レース結果・払戻の照合は netkeiba の公開ページを参照しています。'
          '地方競馬の開催日特定には keiba.go.jp の月次データを利用します。'
          'サイトの仕様変更により表示や的中判定が崩れることがあります。',
        ),
        SizedBox(height: 12),
        Text(
          '払戻や的中の最終確認は、必ず公式の窓口・サイトで行ってください。',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬券QRリーダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'このアプリについて',
            onPressed: _showAbout,
          ),
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
                  child: Semantics(
                    button: true,
                    label: 'QRコード読み取り',
                    hint:
                        'カメラで馬券のQRコード2枚を読み取ります。画面内で続けて読むに切り替えられます',
                    child: ElevatedButton.icon(
                      onPressed: _openQRScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('QRコード読み取り'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '画像から読み取り',
                    hint: 'タップで1枚、長押しで複数の画像を選べます',
                    child: ElevatedButton.icon(
                      onPressed: _readingImages
                          ? null
                          : () => _pickFromImages(multiple: false),
                      onLongPress: _readingImages
                          ? null
                          : () => _pickFromImages(multiple: true),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('画像から読み取り'),
                    ),
                  ),
                ),
              ],
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
                        onRescan: _openQRScanner,
                      )
                    : _HomeEmptyState(
                        onScan: _openQRScanner,
                        onPickImage: () => _pickFromImages(multiple: false),
                        onPickImagesMulti: () =>
                            _pickFromImages(multiple: true),
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
  final VoidCallback onPickImagesMulti;

  const _HomeEmptyState({
    required this.onScan,
    required this.onPickImage,
    required this.onPickImagesMulti,
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
              '2枚が写った画像を選んでください。長押しで複数画像も選べます。',
              style: TextStyle(color: muted, height: 1.5),
              liveRegion: true,
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'カメラで読み取る',
              hint: '馬券のQRコード2枚をカメラで読み取ります',
              child: TextButton(
                onPressed: onScan,
                child: const Text('カメラで読み取る'),
              ),
            ),
            Semantics(
              button: true,
              label: '画像から読み取る',
              hint: 'タップで1枚、長押しで複数の画像を選びます',
              child: TextButton(
                onPressed: onPickImage,
                onLongPress: onPickImagesMulti,
                child: const Text('画像から読み取る'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '非公式アプリです。データ出典などの注意は右上の「このアプリについて」から確認できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
