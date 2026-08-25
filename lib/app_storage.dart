import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// アプリ専用の永続化ディレクトリ（履歴・キャッシュ共通）
class AppStorage {
  static const _channel = MethodChannel('horceracing_ticket_qr_reader/storage');

  /// テスト用に保存先を差し替える
  static Directory? debugDirectory;

  static Future<Directory> directory() async {
    if (debugDirectory != null) return debugDirectory!;

    if (kIsWeb) {
      return Directory.current;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final path = await _channel.invokeMethod<String>('getStorageDirectory');
      if (path == null || path.isEmpty) {
        throw StateError(
          '${Platform.operatingSystem} storage directory is unavailable.',
        );
      }
      return Directory(path);
    }

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) {
        return Directory.current;
      }
      return Directory(
        '$localAppData${Platform.pathSeparator}horceracing_ticket_qr_reader',
      );
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return Directory.current;
    }
    return Directory(
      '$home${Platform.pathSeparator}.horceracing_ticket_qr_reader',
    );
  }
}
