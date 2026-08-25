import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/app_storage.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('app_storage_');
    AppStorage.debugDirectory = tempDir;
  });

  tearDown(() async {
    AppStorage.debugDirectory = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('debugDirectory overrides platform storage', () async {
    final dir = await AppStorage.directory();
    expect(dir.path, tempDir.path);
  });
}
