import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'ticket_qr_parse.dart';

/// ギャラリー画像からの馬券読み取り結果
class ImageTicketReadResult {
  final Map<String, dynamic>? ticket;
  final String? message;
  final bool cancelled;
  final bool permissionDenied;

  const ImageTicketReadResult._({
    this.ticket,
    this.message,
    this.cancelled = false,
    this.permissionDenied = false,
  });

  factory ImageTicketReadResult.cancelled() =>
      const ImageTicketReadResult._(cancelled: true);

  factory ImageTicketReadResult.permissionDenied() =>
      const ImageTicketReadResult._(permissionDenied: true);

  factory ImageTicketReadResult.failure(String message) =>
      ImageTicketReadResult._(message: message);

  factory ImageTicketReadResult.success(Map<String, dynamic> ticket) =>
      ImageTicketReadResult._(ticket: ticket);
}

/// カメラを起動せず、ギャラリー画像だけから馬券QRを読む
class ImageTicketReader {
  /// 画像を選ぶ。キャンセルは空リスト、権限拒否は null。
  static Future<List<XFile>?> pickImages({required bool multiple}) async {
    if (kIsWeb) return const [];

    final picker = ImagePicker();
    try {
      if (multiple) {
        return await picker.pickMultiImage();
      }
      final one = await picker.pickImage(source: ImageSource.gallery);
      return one == null ? const [] : [one];
    } on PlatformException catch (e) {
      if (_isPermissionDenied(e)) return null;
      rethrow;
    }
  }

  /// [multiple] が true のときは複数画像選択（長押し用）
  static Future<ImageTicketReadResult> pickAndParse({
    required bool multiple,
  }) async {
    if (kIsWeb) {
      return ImageTicketReadResult.failure(
        'Webでは画像からの読み取りに対応していません',
      );
    }

    List<XFile>? images;
    try {
      images = await pickImages(multiple: multiple);
    } on PlatformException {
      return ImageTicketReadResult.failure('画像を選択できませんでした');
    }

    if (images == null) {
      return ImageTicketReadResult.permissionDenied();
    }
    if (images.isEmpty) {
      return ImageTicketReadResult.cancelled();
    }

    return parseImages(images);
  }

  /// 既に選ばれた画像パスを解析する（テスト・再利用用）
  static Future<ImageTicketReadResult> parseImages(List<XFile> images) async {
    final qrs = await _extractQrValues(images);
    if (qrs.isEmpty) {
      return ImageTicketReadResult.failure('画像からQRコードを検出できませんでした');
    }
    if (qrs.length == 1) {
      return ImageTicketReadResult.failure(
        'QRコードが1枚分しか見つかりませんでした。'
        'もう1枚が写った画像を選ぶか、長押しで2枚まとめて選んでください。',
      );
    }

    final ticket = parseTicketFromTwoQrs(qrs[0], qrs[1]);
    if (ticket == null) {
      return ImageTicketReadResult.failure(
        '2枚のQRコードを読み取れませんでした。画像を確認して再度お試しください。',
      );
    }
    return ImageTicketReadResult.success(ticket);
  }

  static Future<List<String>> _extractQrValues(List<XFile> images) async {
    final controller = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
    );
    final found = <String>[];
    try {
      for (final image in images) {
        final capture = await controller.analyzeImage(
          image.path,
          formats: const [BarcodeFormat.qrCode],
        );
        if (capture == null) continue;
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw == null || raw.isEmpty) continue;
          if (found.contains(raw)) continue;
          found.add(raw);
          if (found.length >= 2) return found;
        }
      }
    } finally {
      await controller.dispose();
    }
    return found;
  }

  static bool _isPermissionDenied(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    return code.contains('permission') ||
        code.contains('access') ||
        message.contains('permission') ||
        message.contains('denied') ||
        message.contains('access');
  }
}
