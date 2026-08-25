import 'dart:convert';
import 'dart:io';

import 'app_storage.dart';
import 'race_result.dart';

/// netkeiba レース結果のディスクキャッシュ
class RaceResultCache {
  /// 払戻未確定結果の再取得間隔
  static const incompleteTtl = Duration(minutes: 15);

  /// テスト用にキャッシュ先を差し替える
  static Directory? debugDirectory;

  static Future<RaceResult?> read(String url) async {
    try {
      final cached = await _readRaw(url);
      if (cached == null) return null;
      if (!_isFresh(cached.result, cached.cachedAt)) return null;
      return cached.result;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String url, RaceResult result) async {
    // 払戻確定済みを、一時的な未公開結果で上書きしない
    if (!(result.hasResults && result.layoutRecognized)) {
      final existing = await _readRaw(url);
      if (existing != null &&
          existing.result.hasResults &&
          existing.result.layoutRecognized) {
        return;
      }
    }

    final file = await _cacheFile(url);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'result': result.toJson(),
      }),
      flush: true,
    );
  }

  static Future<({RaceResult result, DateTime cachedAt})?> _readRaw(
    String url,
  ) async {
    final file = await _cacheFile(url);
    if (!await file.exists()) return null;

    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map) return null;

    final cachedAtRaw = raw['cachedAt'] as String?;
    final resultRaw = raw['result'];
    if (cachedAtRaw == null || resultRaw is! Map) return null;

    final cachedAt = DateTime.tryParse(cachedAtRaw);
    if (cachedAt == null) return null;

    final result = RaceResult.fromJson(Map<String, dynamic>.from(resultRaw));
    return (result: result, cachedAt: cachedAt);
  }

  static bool _isFresh(RaceResult result, DateTime cachedAt) {
    // 払戻確定済みのみ長期キャッシュ。未確定・レイアウト不明は短めに再取得。
    if (result.hasResults && result.layoutRecognized) return true;
    return DateTime.now().toUtc().difference(cachedAt.toUtc()) < incompleteTtl;
  }

  static Future<File> _cacheFile(String url) async {
    final dir = await _cacheDirectory();
    final key = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    return File('${dir.path}${Platform.pathSeparator}$key.json');
  }

  static Future<Directory> _cacheDirectory() async {
    if (debugDirectory != null) return debugDirectory!;

    final root = await _storageDirectory();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}race_result_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> _storageDirectory() async {
    if (debugDirectory != null) return debugDirectory!;
    return AppStorage.directory();
  }
}
