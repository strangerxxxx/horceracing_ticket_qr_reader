import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'app_storage.dart';
import 'http_fetch.dart';
import 'parse_local.dart' show jyoCdDict;

/// 地方競馬 URL 解決の結果
class LocalRaceResolveResult {
  final String? url;
  final String? failureReason;

  const LocalRaceResolveResult._({this.url, this.failureReason});

  const LocalRaceResolveResult.success(String url) : this._(url: url);

  const LocalRaceResolveResult.failure(String reason)
      : this._(failureReason: reason);

  bool get isSuccess => url != null;
}

/// 地方競馬の開催日を keiba.go.jp 月次CSV + netkeiba から特定し、
/// `https://db.netkeiba.com/race/{id}` 形式の URL を組み立てる。
class LocalRaceUrlResolver {
  static const _monthFetchConcurrency = 3;

  /// EUC-JP: 回=0xB2F3 / 日目=0xC6FCCCDC
  static final _roundDayPattern = RegExp(
    '(\\d+)\xB2\xF3[\\x00-\\xFF]{0,60}?(\\d+)\xC6\xFC\xCC\xDC',
  );

  /// 地方馬券の「年」が令和の年度か（1〜18。19以降は平成と衝突するため除外）。
  static bool isReiwaFiscalYear(int year) => year >= 1 && year <= 18;

  /// 地方馬券の「年」が平成か（19〜31）。
  static bool isHeiseiYear(int year) => year >= 19 && year <= 31;

  /// 券面の年コードを西暦年に変換する（令和年度・平成・西暦下2桁）。
  static int toWesternYear(int year) {
    if (isReiwaFiscalYear(year)) return year + 2018;
    if (isHeiseiYear(year)) return year + 1988;
    if (year < 100) return 2000 + year;
    return year;
  }

  /// 券面の年コードの表示用ラベル（地方: 令和7年度 / 平成28年度、それ以外: 2028年）。
  static String formatTicketYearLabel(int year) {
    if (isReiwaFiscalYear(year)) return '令和$year年度';
    if (isHeiseiYear(year)) return '平成$year年度';
    if (year < 100) return '${2000 + year}年';
    return '$year年';
  }

  /// JRA（中央）券面の年コード表示。西暦下2桁 → `2026年`。
  static String formatJraTicketYearLabel(int year) {
    if (year < 100) return '${2000 + year}年';
    return '$year年';
  }

  /// パース結果に応じた年ラベル（地方フォーマットは元号、JRAは西暦4桁）。
  static String formatYearLabelForTicket(Map data, int year) {
    // 地方パーサのみ「場コード」を付ける
    if (data.containsKey('場コード')) {
      return formatTicketYearLabel(year);
    }
    return formatJraTicketYearLabel(year);
  }

  static Future<String?> resolve({
    required String racecourseCode,
    required String venueName,
    required int year,
    required int round,
    required int day,
    required int race,
  }) async {
    final result = await resolveDetailed(
      racecourseCode: racecourseCode,
      venueName: venueName,
      year: year,
      round: round,
      day: day,
      race: race,
    );
    return result.url;
  }

  static Future<LocalRaceResolveResult> resolveDetailed({
    required String racecourseCode,
    required String venueName,
    required int year,
    required int round,
    required int day,
    required int race,
  }) async {
    final jyoCd = jyoCdDict[racecourseCode];
    if (jyoCd == null) {
      return const LocalRaceResolveResult.failure('未対応の競馬場コードです');
    }
    if (round <= 0 || day <= 0 || race <= 0) {
      return const LocalRaceResolveResult.failure('開催情報（回・日・レース）が不正です');
    }

    final months = _candidateMonths(year);
    var networkFailures = 0;
    var monthsWithData = 0;

    final dateSets = await _mapLimited(
      months,
      _monthFetchConcurrency,
      (ym) async {
        try {
          final set = await _venueDatesForMonth(ym.$1, ym.$2, venueName);
          if (set.isNotEmpty) monthsWithData++;
          return set;
        } on HttpFetchException {
          networkFailures++;
          return <String>{};
        }
      },
    );

    final dates = <String>{};
    for (final set in dateSets) {
      dates.addAll(set);
    }
    if (dates.isEmpty) {
      if (networkFailures > 0 && monthsWithData == 0) {
        return const LocalRaceResolveResult.failure(
          '開催カレンダーの取得に失敗しました（通信エラー）。通信環境を確認して再取得してください',
        );
      }
      return LocalRaceResolveResult.failure(
        '「$venueName」の開催日がカレンダーに見つかりませんでした',
      );
    }

    final ordered = dates.toList()..sort();
    final startIndex = _estimatedStartIndex(ordered.length, round);

    var checked = 0;
    var probeFailures = 0;
    for (final index in _searchOrder(ordered.length, startIndex)) {
      final date = ordered[index];
      checked++;
      try {
        final info = await _roundDayFor(date, jyoCd);
        if (info == null) continue;
        if (info.$1 == round && info.$2 == day) {
          return LocalRaceResolveResult.success(
            buildUrl(
              westernYear: int.parse(date.substring(0, 4)),
              jyoCd: jyoCd,
              monthDay: date.substring(4, 8),
              race: race,
            ),
          );
        }
      } on HttpFetchException {
        probeFailures++;
      }
    }

    if (probeFailures > 0 && probeFailures == checked) {
      return const LocalRaceResolveResult.failure(
        '開催日の照会に失敗しました（通信エラー）。通信環境を確認して再取得してください',
      );
    }

    return LocalRaceResolveResult.failure(
      '第$round回・第$day日に一致する開催を特定できませんでした'
      '（候補日 $checked 件を確認）',
    );
  }

  static Future<List<T>> _mapLimited<T, A>(
    List<A> items,
    int concurrency,
    Future<T> Function(A item) mapper,
  ) async {
    if (items.isEmpty) return [];
    final results = List<T?>.filled(items.length, null);
    var cursor = 0;

    Future<void> worker() async {
      while (true) {
        final i = cursor++;
        if (i >= items.length) return;
        results[i] = await mapper(items[i]);
      }
    }

    final workers = concurrency < items.length ? concurrency : items.length;
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    return results.cast<T>();
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
  /// 平成N年 → 西暦 (N+1988)年の1〜12月。
  /// それ以外の2桁は西暦下2桁。
  static List<(int, int)> _candidateMonths(int year) {
    if (isReiwaFiscalYear(year)) {
      final startYear = year + 2018;
      return [
        for (var m = 4; m <= 12; m++) (startYear, m),
        for (var m = 1; m <= 3; m++) (startYear + 1, m),
      ];
    }
    if (isHeiseiYear(year)) {
      final western = year + 1988;
      return [for (var m = 1; m <= 12; m++) (western, m)];
    }
    final western = year < 100 ? 2000 + year : year;
    return [for (var m = 1; m <= 12; m++) (western, m)];
  }

  static int _estimatedStartIndex(int count, int round) {
    if (count <= 0) return 0;
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
      final response = await HttpFetch.get(uri);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw HttpFetchException(
          '開催カレンダーの取得に失敗しました（HTTP ${response.statusCode}）',
        );
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
    final response = await HttpFetch.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw HttpFetchException(
        '開催日の照会に失敗しました（HTTP ${response.statusCode}）',
      );
    }

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

  static Future<Directory> _storageDirectory() => AppStorage.directory();
}
