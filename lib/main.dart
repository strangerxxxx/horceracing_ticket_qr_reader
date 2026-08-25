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
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("ja", "JP")],
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

  void _openQRScanner({bool openGalleryOnStart = false}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => QRScannerPage(openGalleryOnStart: openGalleryOnStart),
      ),
    );

    if (result != null) {
      await ScanHistoryService.add(result);
      setState(() {
        parsedResult = result;
      });
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
        title: const Text("馬券QRリーダー"),
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
                    child: const Text("QRコード読み取り"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openQRScanner(openGalleryOnStart: true),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text("画像から読み取り"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: parsedResult != null
                    ? TicketResultView(data: parsedResult!)
                    : Center(
                        child: A11yStatusMessage(
                          'QRコードを読み取ってください',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          liveRegion: false,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
