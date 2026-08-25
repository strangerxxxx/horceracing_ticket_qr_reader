import 'dart:io';

/// Copies Built-in Kotlin compatible Android build files into pub cache plugins.
///
/// Run after `flutter pub get`:
///   dart run tool/patch_built_in_kotlin_plugins.dart
Future<void> main() async {
  final projectRoot = Directory.current;
  final pubCache = _pubCacheDirectory();
  final patched = <String>[];

  final mobileScannerVersion = _lockedVersion(projectRoot, 'mobile_scanner');
  if (mobileScannerVersion == null) {
    stderr.writeln('mobile_scanner is not listed in pubspec.lock.');
    exitCode = 1;
    return;
  }

  final mobileScannerPatch = File(
    '${projectRoot.path}${Platform.pathSeparator}tool${Platform.pathSeparator}patches${Platform.pathSeparator}mobile_scanner_android_build.gradle',
  );
  if (!mobileScannerPatch.existsSync()) {
    stderr.writeln('Missing patch file: ${mobileScannerPatch.path}');
    exitCode = 1;
    return;
  }
  final patchContent = mobileScannerPatch.readAsStringSync();

  final pluginDir = Directory('${pubCache.path}${Platform.pathSeparator}mobile_scanner-$mobileScannerVersion');
  final buildGradle = File('${pluginDir.path}${Platform.pathSeparator}android${Platform.pathSeparator}build.gradle');
  if (!buildGradle.existsSync()) {
    stderr.writeln('mobile_scanner Android build file not found: ${buildGradle.path}');
    stderr.writeln('Run `flutter pub get` first.');
    exitCode = 1;
    return;
  }

  if (buildGradle.readAsStringSync() == patchContent) {
    stdout.writeln('mobile_scanner-$mobileScannerVersion is already patched.');
    return;
  }

  buildGradle.writeAsStringSync(patchContent);
  patched.add('mobile_scanner-$mobileScannerVersion');

  stdout.writeln('Patched Built-in Kotlin compatibility for: ${patched.join(', ')}');
}

String? _lockedVersion(Directory projectRoot, String packageName) {
  final lockFile = File('${projectRoot.path}${Platform.pathSeparator}pubspec.lock');
  if (!lockFile.existsSync()) return null;

  final lines = lockFile.readAsLinesSync();
  var inPackage = false;
  for (final line in lines) {
    if (line.trim() == '$packageName:') {
      inPackage = true;
      continue;
    }
    if (inPackage) {
      final match = RegExp(r'^\s+version:\s+"([^"]+)"').firstMatch(line);
      if (match != null) {
        return match.group(1);
      }
      if (line.trim().endsWith(':') && !line.startsWith('    ')) {
        return null;
      }
    }
  }
  return null;
}

Directory _pubCacheDirectory() {
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) {
    return Directory(env);
  }
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return Directory('$localAppData${Platform.pathSeparator}Pub${Platform.pathSeparator}Cache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev');
    }
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return Directory('$home${Platform.pathSeparator}.pub-cache${Platform.pathSeparator}hosted${Platform.pathSeparator}pub.dev');
  }
  throw StateError('Could not locate pub cache directory.');
}
