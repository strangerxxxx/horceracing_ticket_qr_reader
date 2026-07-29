import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'scan_history_entry.dart';

/// 読み取り履歴の永続化
class ScanHistoryService {
  static const _storageKey = 'scan_history';
  static const _maxEntries = 100;

  static Future<List<ScanHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ScanHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  static Future<void> add(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await load();

    entries.insert(
      0,
      ScanHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        scannedAt: DateTime.now(),
        data: data,
      ),
    );

    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await load()..removeWhere((e) => e.id == id);

    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
