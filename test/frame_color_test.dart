import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horceracing_ticket_qr_reader/frame_color.dart';

void main() {
  test('frameStyleFor returns configured colors', () {
    expect(frameStyleFor(1).color, const Color(0xFFFFFFFF));
    expect(frameStyleFor(1).textColor, const Color(0xFF333333));
    expect(frameStyleFor(3).label, '赤');
    expect(frameStyleFor(8).color, const Color(0xFFF8BBD0));
    expect(frameStyleFor(null).label, '未確定');
    expect(frameStyleFor(99).color, undeterminedFrameStyle.color);
  });

  test('horseNumberToFrame matches standard assignment', () {
    expect(horseNumberToFrame(5, 8), 5);
    expect(horseNumberToFrame(8, 9), 8);
    expect(horseNumberToFrame(9, 9), 8);
    expect(horseNumberToFrame(7, 10), 7);
    expect(horseNumberToFrame(8, 10), 7);
    expect(horseNumberToFrame(9, 10), 8);
    expect(horseNumberToFrame(10, 10), 8);
    expect(horseNumberToFrame(5, 12), 5);
    expect(horseNumberToFrame(6, 12), 5);
    expect(horseNumberToFrame(11, 12), 8);
    expect(horseNumberToFrame(12, 12), 8);
    expect(horseNumberToFrame(1, 16), 1);
    expect(horseNumberToFrame(2, 16), 1);
    expect(horseNumberToFrame(15, 16), 8);
    expect(horseNumberToFrame(16, 16), 8);
    expect(horseNumberToFrame(15, 17), 8);
    expect(horseNumberToFrame(17, 17), 8);
    expect(horseNumberToFrame(13, 18), 7);
    expect(horseNumberToFrame(16, 18), 8);
  });

  test('resolveFrameNumber returns null when undetermined', () {
    expect(
      resolveFrameNumber(number: 7, numberIsFrame: false),
      isNull,
    );
    expect(
      resolveFrameNumber(number: 7, numberIsFrame: true),
      7,
    );
    expect(
      resolveFrameNumber(number: 12, numberIsFrame: false, fieldSize: 12),
      8,
    );
    expect(
      resolveFrameNumber(
        number: 12,
        numberIsFrame: false,
        frameByHorseNumber: {12: 5},
      ),
      5,
    );
  });

  test('numberBadgeSemanticLabel describes frame color', () {
    expect(
      numberBadgeSemanticLabel(number: 7, frameNumber: null, numberIsFrame: false),
      '馬番7、枠番未確定',
    );
    expect(
      numberBadgeSemanticLabel(number: 3, frameNumber: 3, numberIsFrame: true),
      '枠番3、3枠赤',
    );
    expect(
      numberBadgeSemanticLabel(number: 12, frameNumber: 2, numberIsFrame: false),
      '馬番12、2枠黒',
    );
  });
}
