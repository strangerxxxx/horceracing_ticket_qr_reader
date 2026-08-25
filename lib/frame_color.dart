import 'package:flutter/material.dart';

/// 競馬の枠色（1〜8枠）
class FrameStyle {
  final int frameNumber;
  final Color color;
  final Color textColor;
  final String label;

  const FrameStyle({
    required this.frameNumber,
    required this.color,
    required this.textColor,
    required this.label,
  });
}

/// 枠番未確定時（出走頭数・結果が分かる前）
const undeterminedFrameStyle = FrameStyle(
  frameNumber: 0,
  color: Color(0xFF9E9E9E),
  textColor: Color(0xFFFFFFFF),
  label: '未確定',
);

const frameStyles = <FrameStyle>[
  FrameStyle(
    frameNumber: 1,
    color: Color(0xFFFFFFFF),
    textColor: Color(0xFF333333),
    label: '白',
  ),
  FrameStyle(
    frameNumber: 2,
    color: Color(0xFF222222),
    textColor: Color(0xFFFFFFFF),
    label: '黒',
  ),
  FrameStyle(
    frameNumber: 3,
    color: Color(0xFFC62927),
    textColor: Color(0xFFFFFFFF),
    label: '赤',
  ),
  FrameStyle(
    frameNumber: 4,
    color: Color(0xFF1973CD),
    textColor: Color(0xFFFFFFFF),
    label: '青',
  ),
  FrameStyle(
    frameNumber: 5,
    color: Color(0xFFFFEB3B),
    textColor: Color(0xFF333333),
    label: '黄',
  ),
  FrameStyle(
    frameNumber: 6,
    color: Color(0xFF2F7D32),
    textColor: Color(0xFFFFFFFF),
    label: '緑',
  ),
  FrameStyle(
    frameNumber: 7,
    color: Color(0xFFFFA727),
    textColor: Color(0xFF333333),
    label: '橙',
  ),
  FrameStyle(
    frameNumber: 8,
    color: Color(0xFFF8BBD0),
    textColor: Color(0xFF333333),
    label: '桃',
  ),
];

FrameStyle frameStyleFor(int? frameNumber) {
  if (frameNumber == null || frameNumber < 1 || frameNumber > 8) {
    return undeterminedFrameStyle;
  }
  return frameStyles[frameNumber - 1];
}

/// 出走頭数から馬番→枠番を求める（JRA/地方の一般的な割当）。
int horseNumberToFrame(int horseNumber, int fieldSize) {
  if (horseNumber < 1) return 1;
  if (fieldSize <= 8) {
    return horseNumber.clamp(1, 8);
  }
  if (fieldSize <= 16) {
    final firstDouble = 17 - fieldSize;
    if (horseNumber < firstDouble) return horseNumber;
    return firstDouble + (horseNumber - firstDouble) ~/ 2;
  }
  if (fieldSize == 17) {
    if (horseNumber <= 14) return (horseNumber + 1) ~/ 2;
    return 8;
  }
  // 18頭以上（実質18）
  if (horseNumber <= 12) return (horseNumber + 1) ~/ 2;
  if (horseNumber <= 15) return 7;
  return 8;
}

/// 表示用の枠番を決める。未確定のときは null。
///
/// [numberIsFrame] が true（枠連・枠単）なら [number] 自体が枠番。
/// レース結果の枠番マップや出走頭数があればそれに従う。
int? resolveFrameNumber({
  required int number,
  required bool numberIsFrame,
  Map<int, int>? frameByHorseNumber,
  int? fieldSize,
}) {
  if (numberIsFrame) {
    return number.clamp(1, 8);
  }
  final fromResult = frameByHorseNumber?[number];
  if (fromResult != null && fromResult >= 1 && fromResult <= 8) {
    return fromResult;
  }
  if (fieldSize != null && fieldSize > 0) {
    return horseNumberToFrame(number, fieldSize);
  }
  return null;
}

/// スクリーンリーダー向けの馬番・枠番ラベル
String numberBadgeSemanticLabel({
  required int number,
  required int? frameNumber,
  required bool numberIsFrame,
}) {
  final kind = numberIsFrame ? '枠番' : '馬番';
  if (frameNumber == null) {
    return '$kind$number、枠番未確定';
  }
  final style = frameStyleFor(frameNumber);
  return '$kind$number、$frameNumber枠${style.label}';
}

/// 馬番・枠番を枠色の四角で表示する。
class NumberBadge extends StatelessWidget {
  final int number;
  final int? frameNumber;
  final bool numberIsFrame;
  final double size;

  const NumberBadge({
    super.key,
    required this.number,
    required this.frameNumber,
    this.numberIsFrame = false,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final style = frameStyleFor(frameNumber);
    final needsBorder =
        style.frameNumber == 1 || style.color.computeLuminance() > 0.85;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final badgeSize = (size * textScale).clamp(size, size * 2);

    return Semantics(
      label: numberBadgeSemanticLabel(
        number: number,
        frameNumber: frameNumber,
        numberIsFrame: numberIsFrame,
      ),
      excludeSemantics: true,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.color,
          border: Border.all(
            color: needsBorder ? const Color(0xFF333333) : style.color,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: style.textColor,
            fontSize: badgeSize * 0.55,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
