import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/a11y_widgets.dart';
import 'package:horceracing_ticket_qr_reader/main.dart';

void main() {
  testWidgets('home screen shows scan prompt', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('馬券QRリーダー'), findsOneWidget);
    expect(find.text('QRコード読み取り'), findsOneWidget);
    expect(find.text('画像から読み取り'), findsOneWidget);
    expect(
      find.textContaining('馬券のQRコードは2枚あります'),
      findsOneWidget,
    );
  });

  testWidgets('home scan buttons use the same elevated style', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(ElevatedButton), findsNWidgets(2));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('A11yLabeledRow exposes combined semantics label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: A11yLabeledRow(label: '式別', value: '単勝'),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(A11yLabeledRow)),
      matchesSemantics(label: '式別、単勝'),
    );
  });

  testWidgets('A11yLabeledRow uses semanticValue for widget rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: A11yLabeledRow(
            label: '馬番',
            semanticValue: '馬番1、馬番2',
            valueWidget: Text('1-2'),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(A11yLabeledRow)),
      matchesSemantics(label: '馬番、馬番1、馬番2'),
    );
  });
}
