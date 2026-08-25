import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'scan_history_entry.dart';
import 'scan_history_query.dart';
import 'ticket_payout_checker.dart';

/// 読み取り履歴の永続化
class ScanHistoryService {
  static const _fileName = 'scan_history.json';
  static const _maxEntries = 100;
  static const _channel = MethodChannel('horceracing_ticket_qr_reader/storage');

  /// 同時書き込みを直列化する
  static Future<void> _lock = Future.value();

  /// テスト用に保存先を差し替える
  static Directory? debugDirectory;

  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final previous = _lock;
    final gate = Completer<void>();
    _lock = gate.future;
    return previous.then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  static Future<List<ScanHistoryEntry>> load() {
    return _synchronized(_loadUnlocked);
  }

  static Future<List<ScanHistoryEntry>> _loadUnlocked() async {
    final file = await _historyFile();
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _quarantineCorrupt(file);
        return [];
      }

      final entries = <ScanHistoryEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          entries.add(
            ScanHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // 壊れた1件はスキップ
        }
      }

      entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return ScanHistoryQuery.dedupeLatest(entries);
    } catch (_) {
      await _quarantineCorrupt(file);
      return [];
    }
  }

  static Future<void> _quarantineCorrupt(File file) async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.corrupt.$stamp');
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  static Future<String> add(Map<String, dynamic> data) {
    return _synchronized(() async {
      final entries = await _loadUnlocked();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final enriched = Map<String, dynamic>.from(data);
      if (!enriched.containsKey('エラー') && !enriched.containsKey('購入合計')) {
        enriched['購入合計'] =
            TicketPayoutChecker.summarizeTicket(enriched).totalAmountYen;
      }
      final key = ScanHistoryQuery.fingerprint(enriched);

      // 同一馬券は最新のみ残す
      entries.removeWhere(
        (e) => ScanHistoryQuery.fingerprint(e.data) == key,
      );

      entries.insert(
        0,
        ScanHistoryEntry(
          id: id,
          scannedAt: DateTime.now(),
          data: enriched,
        ),
      );

      if (entries.length > _maxEntries) {
        entries.removeRange(_maxEntries, entries.length);
      }

      await _writeEntriesUnlocked(entries);
      return id;
    });
  }

  static Future<void> updateData(
    String id,
    Map<String, dynamic> patch, {
    List<String> removeKeys = const [],
  }) {
    if (patch.isEmpty && removeKeys.isEmpty) return Future.value();

    return _synchronized(() async {
      final entries = await _loadUnlocked();
      final index = entries.indexWhere((e) => e.id == id);
      if (index < 0) return;

      final current = entries[index];
      final merged = {...current.data, ...patch};
      for (final key in removeKeys) {
        merged.remove(key);
      }
      entries[index] = ScanHistoryEntry(
        id: current.id,
        scannedAt: current.scannedAt,
        data: merged,
      );
      await _writeEntriesUnlocked(entries);
    });
  }

  static Future<void> delete(String id) {
    return _synchronized(() async {
      final entries = await _loadUnlocked()
        ..removeWhere((e) => e.id == id);
      await _writeEntriesUnlocked(entries);
    });
  }

  /// スワイプ削除の Undo 用。同一 id があれば置換、なければ先頭に戻す。
  static Future<void> restore(ScanHistoryEntry entry) {
    return _synchronized(() async {
      final entries = await _loadUnlocked();
      entries.removeWhere((e) => e.id == entry.id);
      entries.insert(0, entry);
      entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      if (entries.length > _maxEntries) {
        entries.removeRange(_maxEntries, entries.length);
      }
      await _writeEntriesUnlocked(entries);
    });
  }

  static Future<void> clear() {
    return _synchronized(() async {
      final file = await _historyFile();
      if (await file.exists()) {
        await file.delete();
      }
    });
  }

  static Future<void> _writeEntriesUnlocked(List<ScanHistoryEntry> entries) async {
    final file = await _historyFile();
    final tmp = File('${file.path}.tmp');
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    await tmp.writeAsString(payload, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  static Future<File> _historyFile() async {
    final directory = await _storageDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<Directory> _storageDirectory() async {
    if (debugDirectory != null) return debugDirectory!;

    if (Platform.isAndroid) {
      final path = await _channel.invokeMethod<String>('getStorageDirectory');
      if (path == null || path.isEmpty) {
        throw StateError('Android storage directory is unavailable.');
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

    return Directory('$home${Platform.pathSeparator}.horceracing_ticket_qr_reader');
  }
}
