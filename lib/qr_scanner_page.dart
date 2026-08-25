import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'a11y_widgets.dart';
import 'parse.dart';
import 'parse_local.dart';

class QRScannerPage extends StatefulWidget {
  /// true の場合、画面表示後にギャラリー選択を開く
  final bool openGalleryOnStart;

  /// true の場合、読み取り成功後も画面を閉じず次の馬券を受け付ける
  final bool continuousMode;

  /// 続けて読むモードで解析成功したときに呼ばれる
  final ValueChanged<Map<String, dynamic>>? onTicketParsed;

  const QRScannerPage({
    super.key,
    this.openGalleryOnStart = false,
    this.continuousMode = false,
    this.onTicketParsed,
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final List<String> _qrResults = [];
  bool _processed = false;
  bool _analyzingImage = false;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  static const _guideText =
      '馬券のQRコードは2枚あります。両方を枠内にかざすか、2枚が写った画像を選んでください。';

  @override
  void initState() {
    super.initState();
    if (widget.openGalleryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAndAnalyzeImage();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _countSequence(String s) {
    const sequence = '0123456789';
    return RegExp(sequence).allMatches(s).length;
  }

  void _resetScan() {
    setState(() {
      _qrResults.clear();
      _processed = false;
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) {
        _showMessage('ライトを切り替えられませんでした');
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processed || _analyzingImage) return;
    _ingestBarcodes(capture);
  }

  void _ingestBarcodes(BarcodeCapture capture) {
    if (_processed) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;
      if (_qrResults.contains(rawValue)) continue;

      _qrResults.add(rawValue);

      if (_qrResults.length == 2) {
        _processed = true;
        _processTwoQRs(_qrResults[0], _qrResults[1]);
        return;
      }
    }

    if (mounted && _qrResults.length == 1) {
      setState(() {});
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    if (_processed || _analyzingImage) return;

    if (kIsWeb) {
      _showMessage('Webでは画像からの読み取りに対応していません');
      return;
    }

    final picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(source: ImageSource.gallery);
    } on PlatformException catch (e) {
      if (_isPermissionDenied(e)) {
        await _showPermissionDeniedDialog(forPhotos: true);
      } else {
        _showMessage('画像を選択できませんでした');
      }
      return;
    }

    if (image == null || !mounted) return;

    setState(() => _analyzingImage = true);

    try {
      final capture = await _controller.analyzeImage(
        image.path,
        formats: const [BarcodeFormat.qrCode],
      );

      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        _showMessage('画像からQRコードを検出できませんでした');
        return;
      }

      final before = _qrResults.length;
      _ingestBarcodes(capture);

      if (_processed) return;

      final added = _qrResults.length - before;
      if (added == 0) {
        _showMessage('新しいQRコードは検出されませんでした');
      } else if (_qrResults.length == 1) {
        _showMessage(
          '1枚目を読み取りました。もう1枚の画像を選ぶか、カメラで読み取ってください',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('画像の解析に失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() => _analyzingImage = false);
      }
    }
  }

  bool _isPermissionDenied(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    return code.contains('permission') ||
        code.contains('access') ||
        message.contains('permission') ||
        message.contains('denied') ||
        message.contains('access');
  }

  Future<void> _showPermissionDeniedDialog({required bool forPhotos}) async {
    if (!mounted) return;
    final title = forPhotos ? '写真へのアクセス' : 'カメラへのアクセス';
    final body = forPhotos
        ? '画像から読み取るには、設定で写真へのアクセスを許可してください。'
        : 'QRコードを読み取るには、設定でカメラへのアクセスを許可してください。';

    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _processTwoQRs(String first, String second) async {
    final int count1 = _countSequence(first);
    final int count2 = _countSequence(second);

    final String preferred;
    final String alt;
    if (count1 > count2) {
      preferred = second + first;
      alt = first + second;
    } else {
      preferred = first + second;
      alt = second + first;
    }

    Map<String, dynamic>? parsedData;

    try {
      debugPrint('Parse (preferred): $preferred');
      parsedData = _parse(preferred);
    } catch (_) {
      try {
        debugPrint('Parse (alt): $alt');
        parsedData = _parse(alt);
      } catch (e) {
        debugPrint('Read 1: $first');
        debugPrint('Read 2: $second');
        debugPrint('Parse error: $e');
      }
    }

    if (!mounted) return;

    if (parsedData == null) {
      await _showParseErrorDialog();
      return;
    }

    if (widget.continuousMode) {
      widget.onTicketParsed?.call(parsedData);
      _showMessage('読み取りました。次の馬券をかざしてください');
      _resetScan();
      return;
    }

    Navigator.of(context).pop(parsedData);
  }

  Future<void> _showParseErrorDialog() async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解析に失敗しました'),
        content: const Text(
          '2枚のQRコードを読み取れませんでした。'
          'もう一度読み取るか、画面を閉じてください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('やり直す'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (retry == true) {
      _resetScan();
    } else {
      Navigator.of(context).pop();
    }
  }

  Map<String, dynamic> _parse(String s) {
    if (s.substring(3, 4) == '1') {
      return parseHorseracingTicketQrLocal(s);
    }
    return parseHorseracingTicketQr(s);
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = denied
        ? 'カメラの使用が許可されていません'
        : (error.errorDetails?.message ?? 'カメラを起動できませんでした');

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '画像から読み取ることもできます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (denied)
                FilledButton(
                  onPressed: () => AppSettings.openAppSettings(),
                  child: const Text('設定を開く'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _analyzingImage ? null : _pickAndAnalyzeImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('画像から読み取り'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    final text = _qrResults.isEmpty
        ? _guideText
        : '1枚目を読み取りました（${_qrResults.length}/2）。'
            '2枚目をかざすか、画像を選んでください。';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Semantics(
          liveRegion: true,
          label: text,
          child: Card(
            color: Colors.black54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_qrResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _resetScan,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'やり直す',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.continuousMode ? '続けて読み取り' : 'QRコードを読み取る'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'ライトをオフ' : 'ライトをオン',
                onPressed: unavailable ? null : _toggleTorch,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
              );
            },
          ),
          IconButton(
            tooltip: 'やり直す',
            onPressed: (_qrResults.isEmpty && !_processed) ? null : _resetScan,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '画像から読み取り',
            onPressed: _analyzingImage ? null : _pickAndAnalyzeImage,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _buildCameraError,
          ),
          _buildStatusBanner(),
          if (_analyzingImage)
            const ColoredBox(
              color: Colors.black45,
              child: Center(
                child: A11yLoadingIndicator(message: '画像を解析しています…'),
              ),
            ),
        ],
      ),
    );
  }
}
