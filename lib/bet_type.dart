/// 馬券の式別名を netkeiba 払戻テーブルの名称に揃える。
///
/// 地方競馬の券面表記と netkeiba の対応:
/// - 枠連複 → 枠連
/// - 枠連単 → 枠単
/// - 普通馬複 → 馬連
/// - 馬番連単 → 馬単
/// - 馬3連複 → 三連複
/// - 馬3連単 → 三連単
String normalizeBetType(String betType) {
  switch (betType) {
    case '枠連複':
      return '枠連';
    case '枠連単':
      return '枠単';
    case '普通馬複':
      return '馬連';
    case '馬番連単':
      return '馬単';
    case '馬3連複':
    case '3連複':
      return '三連複';
    case '馬3連単':
    case '3連単':
      return '三連単';
    default:
      return betType;
  }
}

/// 着順どおりの式別か（馬単・枠単・三連単）
bool isOrderedBetType(String betType) {
  final normalized = normalizeBetType(betType);
  return normalized == '馬単' ||
      normalized == '枠単' ||
      normalized == '三連単';
}
