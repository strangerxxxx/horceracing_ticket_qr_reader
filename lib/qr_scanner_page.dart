import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:horceracing_ticket_qr_reader/parse.dart';
import 'package:horceracing_ticket_qr_reader/parse_local.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  // 2枚のQRコードを格納するリスト
  final List<String> _qrResults = [];

  // 処理済みフラグ: 2枚揃った後の余分なコールバックを無視する
  bool _processed = false;

  // MobileScannerController を明示的に保持して dispose する
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

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
    // 2枚処理済みなら以降のコールバックは無視する
    if (_processed) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;
      // 既に読み取り済みの値は重複して追加しない
      if (_qrResults.contains(rawValue)) continue;

      _qrResults.add(rawValue);

      if (_qrResults.length == 2) {
        _processed = true;
        _processTwoQRs(_qrResults[0], _qrResults[1]);
        return; // ループを抜けて以降のバーコードを処理しない
      }
    }
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

    // Navigator がまだ使える状態かチェックしてから pop する
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
      appBar: AppBar(title: const Text('QRコードを読み取る')),
      body: Stack(
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 1枚目を読み取った後、2枚目待ちのガイド表示
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
                      '1枚目を読み取りました。2枚目をかざしてください。',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
