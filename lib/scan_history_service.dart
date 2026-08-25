import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'scan_history_entry.dart';

/// 読み取り履歴の永続化
class ScanHistoryService {
  static const _fileName = 'scan_history.json';
  static const _maxEntries = 100;
  static const _channel = MethodChannel('horceracing_ticket_qr_reader/storage');

  static Future<List<ScanHistoryEntry>> load() async {
    final file = await _historyFile();
    if (!await file.exists()) return [];

    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ScanHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  static Future<String> add(Map<String, dynamic> data) async {
    final entries = await load();
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    entries.insert(
      0,
      ScanHistoryEntry(
        id: id,
        scannedAt: DateTime.now(),
        data: data,
      ),
    );

    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    await _writeEntries(entries);
    return id;
  }

  static Future<void> updateData(String id, Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;

    final entries = await load();
    final index = entries.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final current = entries[index];
    entries[index] = ScanHistoryEntry(
      id: current.id,
      scannedAt: current.scannedAt,
      data: {...current.data, ...patch},
    );
    await _writeEntries(entries);
  }

  static Future<void> delete(String id) async {
    final entries = await load()..removeWhere((e) => e.id == id);
    await _writeEntries(entries);
  }

  static Future<void> clear() async {
    final file = await _historyFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _writeEntries(List<ScanHistoryEntry> entries) async {
    final file = await _historyFile();
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<File> _historyFile() async {
    final directory = await _storageDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<Directory> _storageDirectory() async {
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
