import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens a URL in an external browser without depending on url_launcher.
///
/// Android / iOS use a MethodChannel so the app stays Built-in Kotlin compatible.
/// Desktop uses the platform's default URL opener.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return false;
  }

  if (kIsWeb) {
    return false;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    const channel = MethodChannel('horceracing_ticket_qr_reader/url');
    final opened = await channel.invokeMethod<bool>('launchUrl', {'url': url});
    return opened ?? false;
  }

  if (Platform.isWindows) {
    final result = await Process.run('cmd', ['/c', 'start', '', url]);
    return result.exitCode == 0;
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [url]);
    return result.exitCode == 0;
  }

  if (Platform.isLinux) {
    final result = await Process.run('xdg-open', [url]);
    return result.exitCode == 0;
  }

  return false;
}
