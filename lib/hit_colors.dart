import 'package:flutter/material.dart';

/// 的中表示など、テーマに追従する強調色
class HitColors {
  const HitColors._();

  static Color foreground(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static Color background(BuildContext context) {
    return Theme.of(context).colorScheme.errorContainer;
  }

  static Color onBackground(BuildContext context) {
    return Theme.of(context).colorScheme.onErrorContainer;
  }
}
