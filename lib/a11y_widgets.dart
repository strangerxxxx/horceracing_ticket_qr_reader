import 'package:flutter/material.dart';

/// セクション見出し（スクリーンリーダーで見出しとして認識）
class A11ySectionTitle extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const A11ySectionTitle(this.title, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: style),
    );
  }
}

/// ローディング表示（状態を読み上げ可能）
class A11yLoadingIndicator extends StatelessWidget {
  final String message;

  const A11yLoadingIndicator({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const ExcludeSemantics(child: Center(child: CircularProgressIndicator())),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// 状態メッセージ（エラー・案内など）
class A11yStatusMessage extends StatelessWidget {
  final String message;
  final TextStyle? style;
  final bool liveRegion;

  const A11yStatusMessage(
    this.message, {
    super.key,
    this.style,
    this.liveRegion = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      liveRegion: liveRegion,
      child: Text(message, style: style),
    );
  }
}

/// 装飾用の区切り文字（読み上げから除外）
class A11ySeparatorText extends StatelessWidget {
  final String separator;

  const A11ySeparatorText(this.separator, {super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        separator,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 外部リンク行
class A11yLinkText extends StatelessWidget {
  final String label;
  final String url;
  final VoidCallback onTap;

  const A11yLinkText({
    super.key,
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: label,
      hint: url,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            url,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// ラベル付き情報行
class A11yLabeledRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final double labelWidth;

  const A11yLabeledRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelWidth = 80,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final valueStyle = const TextStyle(fontWeight: FontWeight.w500);

    if (valueWidget != null) {
      return Semantics(
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: labelWidth, child: Text(label, style: labelStyle)),
              Expanded(child: valueWidget!),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: '$label、$value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: ExcludeSemantics(child: Text(label, style: labelStyle)),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: Text(value ?? '', style: valueStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
