import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'parse_local.dart' show jyoCdDict;

/// 地方競馬の開催日を keiba.go.jp 月次CSV + netkeiba から特定し、
/// `https://db.netkeiba.com/race/{id}` 形式の URL を組み立てる。
class LocalRaceUrlResolver {
  static const _userAgent =
      'Mozilla/5.0 (compatible; HorseRacingTicketQrReader/1.0)';
  static const _channel = MethodChannel('horceracing_ticket_qr_reader/storage');

  /// EUC-JP: 回=0xB2F3 / 日目=0xC6FCCCDC
  static final _roundDayPattern = RegExp(
    '(\\d+)\xB2\xF3[\\x00-\\xFF]{0,60}?(\\d+)\xC6\xFC\xCC\xDC',
  );

  /// 地方馬券の「年」は令和の年度として扱う（1〜40）。それ以外は西暦下2桁。
  static bool isReiwaFiscalYear(int year) => year >= 1 && year <= 40;

  static Future<String?> resolve({
    required String racecourseCode,
    required String venueName,
    required int year,
    required int round,
    required int day,
    required int race,
  }) async {
    final jyoCd = jyoCdDict[racecourseCode];
    if (jyoCd == null) return null;
    if (round <= 0 || day <= 0 || race <= 0) return null;

    final months = _candidateMonths(year);
    final dateSets = await Future.wait(
      months.map((ym) => _venueDatesForMonth(ym.$1, ym.$2, venueName)),
    );
    final dates = <String>{};
    for (final set in dateSets) {
      dates.addAll(set);
    }
    if (dates.isEmpty) return null;

    final ordered = dates.toList()..sort();
    final startIndex = _estimatedStartIndex(ordered.length, round);

    // 推定位置から左右に探索
    for (final index in _searchOrder(ordered.length, startIndex)) {
      final date = ordered[index];
      final info = await _roundDayFor(date, jyoCd);
      if (info == null) continue;
      if (info.$1 == round && info.$2 == day) {
        return buildUrl(
          westernYear: int.parse(date.substring(0, 4)),
          jyoCd: jyoCd,
          monthDay: date.substring(4, 8),
          race: race,
        );
      }
    }
    return null;
  }

  static String buildUrl({
    required int westernYear,
    required String jyoCd,
    required String monthDay,
    required int race,
  }) {
    final id =
        '$westernYear$jyoCd$monthDay${race.toString().padLeft(2, '0')}';
    return 'https://db.netkeiba.com/race/$id';
  }

  /// 令和N年度 → 西暦 (N+2018)年4月 〜 (N+2019)年3月。
  /// 西暦下2桁の場合はその年の1〜12月。
  static List<(int, int)> _candidateMonths(int year) {
    if (isReiwaFiscalYear(year)) {
      final startYear = year + 2018;
      return [
        for (var m = 4; m <= 12; m++) (startYear, m),
        for (var m = 1; m <= 3; m++) (startYear + 1, m),
      ];
    }
    final western = year < 100 ? 2000 + year : year;
    return [for (var m = 1; m <= 12; m++) (western, m)];
  }

  static int _estimatedStartIndex(int count, int round) {
    if (count <= 0) return 0;
    // 回が進むほど年度後半の日付になる想定
    final ratio = ((round - 1).clamp(0, 40)) / 25.0;
    return (count * ratio).floor().clamp(0, count - 1);
  }

  static Iterable<int> _searchOrder(int length, int start) sync* {
    if (length <= 0) return;
    yield start;
    for (var d = 1; d < length; d++) {
      final right = start + d;
      final left = start - d;
      if (right < length) yield right;
      if (left >= 0) yield left;
    }
  }

  static Future<Set<String>> _venueDatesForMonth(
    int year,
    int month,
    String venueName,
  ) async {
    final cacheFile = await _monthCacheFile(year, month);
    List<int> bytes;
    if (await cacheFile.exists()) {
      bytes = await cacheFile.readAsBytes();
    } else {
      final uri = Uri.https(
        'www.keiba.go.jp',
        '/KeibaWeb/DataDownload/RaceDataDownload',
        {
          'type': 'monthly',
          'k_year': '$year',
          'k_month': '$month',
        },
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return {};
      }
      bytes = response.bodyBytes;
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(bytes, flush: true);
    }

    return _parseVenueDatesFromZip(bytes, venueName);
  }

  /// テスト用: ZIPバイト列から会場の開催日を抽出する。
  static Set<String> parseVenueDatesFromZipBytes(
    List<int> bytes,
    String venueName,
  ) =>
      _parseVenueDatesFromZip(bytes, venueName);

  static Set<String> _parseVenueDatesFromZip(
    List<int> bytes,
    String venueName,
  ) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? file;
    for (final f in archive.files) {
      if (f.name.endsWith('_racelist.csv')) {
        file = f;
        break;
      }
    }
    if (file == null) return {};

    final content = file.content as List<int>;
    final text = utf8.decode(content, allowMalformed: true);
    // BOM除去
    final normalized =
        text.startsWith('\uFEFF') ? text.substring(1) : text;

    final dates = <String>{};
    for (final line in normalized.split(RegExp(r'\r?\n'))) {
      if (line.isEmpty) continue;
      final cols = _parseCsvLine(line);
      if (cols.length < 3) continue;
      final venue = cols[0];
      final date = cols[1];
      if (!_venueMatches(venue, venueName)) continue;
      if (RegExp(r'^\d{8}$').hasMatch(date)) {
        dates.add(date);
      }
    }
    return dates;
  }

  static bool _venueMatches(String csvVenue, String ticketVenue) {
    if (csvVenue.isEmpty || ticketVenue.isEmpty) return false;
    if (csvVenue == ticketVenue) return true;
    // 帯広ば ⟷ 帯広
    if (csvVenue.startsWith(ticketVenue)) return true;
    if (ticketVenue.startsWith(csvVenue)) return true;
    final stripped = csvVenue.replaceAll(RegExp(r'[ばバ]$'), '');
    return stripped == ticketVenue || ticketVenue.startsWith(stripped);
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (c == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(c);
    }
    result.add(buffer.toString());
    return result;
  }

  static Future<(int, int)?> _roundDayFor(String yyyymmdd, String jyoCd) async {
    final cache = await _roundDayCacheFile(yyyymmdd, jyoCd);
    if (await cache.exists()) {
      final raw = await cache.readAsString();
      final parts = raw.trim().split(',');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]);
        final d = int.tryParse(parts[1]);
        if (r != null && d != null) return (r, d);
      }
    }

    final url = buildUrl(
      westernYear: int.parse(yyyymmdd.substring(0, 4)),
      jyoCd: jyoCd,
      monthDay: yyyymmdd.substring(4, 8),
      race: 1,
    );
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) return null;

    final latin1 = String.fromCharCodes(response.bodyBytes);
    final match = _roundDayPattern.firstMatch(latin1);
    if (match == null) return null;

    final round = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    if (round == null || day == null) return null;

    await cache.parent.create(recursive: true);
    await cache.writeAsString('$round,$day', flush: true);
    return (round, day);
  }

  /// テスト用: netkeiba HTML（EUC-JPバイト）から回・日目を読む。
  static (int, int)? parseRoundDayFromHtmlBytes(List<int> bodyBytes) {
    final latin1 = String.fromCharCodes(bodyBytes);
    final match = _roundDayPattern.firstMatch(latin1);
    if (match == null) return null;
    final round = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    if (round == null || day == null) return null;
    return (round, day);
  }

  static Future<File> _monthCacheFile(int year, int month) async {
    final dir = await _cacheDirectory();
    final name = 'racelist_${year}_${month.toString().padLeft(2, '0')}.zip';
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  static Future<File> _roundDayCacheFile(String yyyymmdd, String jyoCd) async {
    final dir = await _cacheDirectory();
    final sub = Directory(
      '${dir.path}${Platform.pathSeparator}round_day',
    );
    return File(
      '${sub.path}${Platform.pathSeparator}${yyyymmdd}_$jyoCd.txt',
    );
  }

  static Future<Directory> _cacheDirectory() async {
    final root = await _storageDirectory();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}local_race_cache',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
    return Directory(
      '$home${Platform.pathSeparator}.horceracing_ticket_qr_reader',
    );
  }
}
