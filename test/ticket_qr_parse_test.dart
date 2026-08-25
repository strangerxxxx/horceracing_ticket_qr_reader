import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/ticket_qr_parse.dart';

void main() {
  const localCombined =
      '1611000110000511017789641007740083364970613732211260811000010000123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345612345678901234560701';

  const jraCombined =
      '3090001704021220098511194685090900151611246100010000000000000000000000000000000000001000000001000000005456789012345678901234567890123456789012345678901234567890123456789012345678901234560517';

  test('combined local payload parses from paste', () {
    final result = parseTicketFromPastedText(localCombined);
    expect(result, isNotNull);
    expect(result!.containsKey('エラー'), isFalse);
    expect(result['開催場'], '大井');
    final purchase = (result['購入内容'] as List).first as Map;
    expect(purchase['式別'], '馬番連単');
  });

  test('combined JRA payload parses from paste', () {
    final result = parseTicketFromPastedText(jraCombined);
    expect(result, isNotNull);
    expect(result!.containsKey('エラー'), isFalse);
    expect(result['券種'], 'ながし');
  });

  test('two halves joined by newline parse', () {
    final mid = localCombined.length ~/ 2;
    final pasted =
        '${localCombined.substring(0, mid)}\n${localCombined.substring(mid)}';
    final result = parseTicketFromPastedText(pasted);
    expect(result, isNotNull);
    expect(result!.containsKey('エラー'), isFalse);
    expect(result['開催場'], '大井');
  });

  test('whitespace around payload is ignored', () {
    final result = parseTicketFromPastedText('\n  $jraCombined  \n');
    expect(result, isNotNull);
    expect(result!['券種'], 'ながし');
  });

  test('empty and garbage return null', () {
    expect(parseTicketFromPastedText(''), isNull);
    expect(parseTicketFromPastedText('   '), isNull);
    expect(parseTicketFromPastedText('hello world'), isNull);
  });
}
