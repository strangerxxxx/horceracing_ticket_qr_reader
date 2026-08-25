import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:horceracing_ticket_qr_reader/parse.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';

class QRScannerPage extends StatefulWidget {
  /// true の場合、画面表示後にギャラリー選択を開く
  final bool openGalleryOnStart;

  const QRScannerPage({super.key, this.openGalleryOnStart = false});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  // 2枚のQRコードを格納するリスト
  final List<String> _qrResults = [];

  // 処理済みフラグ: 2枚揃った後の余分なコールバックを無視する
  bool _processed = false;

  bool _analyzingImage = false;

  // MobileScannerController を明示的に保持して dispose する
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

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

  /// 文字列中に "0123456789" という連続した10桁の並びが何回出現するかを返す。
  /// この出現回数が多い方を後半QR（データ部）と判断し、連結順序の決定に使用する。
  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
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
    final image = await picker.pickImage(source: ImageSource.gallery);
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
        _showMessage('1枚目を読み取りました。もう1枚の画像を選ぶか、カメラで読み取ってください');
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _processTwoQRs(String first, String second) {
    Map<String, dynamic> parsedData;

    // "0123456789" の連続パターンが多い方が後半QR（データ部）なので後ろに置く
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

    try {
      debugPrint('Parse (preferred): $preferred');
      parsedData = _parse(preferred);
    } catch (_) {
      try {
        debugPrint('Parse (alt): $alt');
        parsedData = _parse(alt);
      } catch (e) {
        parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
        debugPrint('Read 1: $first');
        debugPrint('Read 2: $second');
      }
    }

    if (mounted) {
      Navigator.of(context).pop(parsedData);
    }
  }

  /// QR文字列の4文字目が "1" なら地方競馬フォーマット、それ以外はJRAフォーマット。
  Map<String, dynamic> _parse(String s) {
    if (s.substring(3, 4) == '1') {
      return parseHorseracingTicketQrLocal(s);
    } else {
      return parseHorseracingTicketQr(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコードを読み取る'),
        actions: [
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
          ),
          if (_qrResults.length == 1)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 48.0),
                child: Card(
                  color: Colors.black54,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Text(
                      '1枚目を読み取りました。2枚目をかざすか、画像を選んでください。',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if (_analyzingImage)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
