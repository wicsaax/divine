// 周易卦象可视化 widget.
//
// 把六爻按传统从下到上画出来:
//   阳爻 (⚊): 实心粗横条
//   阴爻 (⚋): 两段, 中间空白
//   变爻 标记 (◯ 老阴 / × 老阳) 在右侧
//
// 支持本卦 + 变卦并排 + 中间箭头.

import 'package:flutter/material.dart';

class HexagramView extends StatelessWidget {
  /// 6 字符 0/1 字符串, 自下而上 (line1, line2, ..., line6).
  final String binary;
  final String? title;
  final String? subtitle;
  final List<int> changingLines; // 1-6
  final Color accent;
  final double width;

  const HexagramView({
    super.key,
    required this.binary,
    required this.accent,
    this.title,
    this.subtitle,
    this.changingLines = const [],
    this.width = 96,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineH = width * 0.12;
    final gapH = lineH * 0.55;
    final totalH = lineH * 6 + gapH * 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
          ),
        Container(
          width: width,
          height: totalH,
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: width * 0.08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 5; i >= 0; i--) ...[
                _Yao(
                  isYang: binary[i] == '1',
                  isChanging: changingLines.contains(i + 1),
                  height: lineH,
                  accent: accent,
                ),
                if (i > 0) SizedBox(height: gapH),
              ],
            ],
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
      ],
    );
  }
}

class _Yao extends StatelessWidget {
  final bool isYang;
  final bool isChanging;
  final double height;
  final Color accent;
  const _Yao({
    required this.isYang,
    required this.isChanging,
    required this.height,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isChanging
        ? Colors.red.shade400
        : accent;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: isYang
                ? _bar(color)
                : Row(
                    children: [
                      Expanded(child: _bar(color)),
                      SizedBox(width: height * 1.0), // 阴爻中间断开
                      Expanded(child: _bar(color)),
                    ],
                  ),
          ),
          if (isChanging)
            Padding(
              padding: EdgeInsets.only(left: height * 0.4),
              child: SizedBox(
                width: height * 1.1,
                child: Center(
                  child: Text(
                    isYang ? '×' : '◯',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: height * 0.9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height * 0.18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// 本卦 → 变卦 并列视图.
class HexagramTransition extends StatelessWidget {
  final String originalBinary;
  final String? derivedBinary;
  final List<int> changingLines;
  final String originalLabel;
  final String? derivedLabel;
  final Color accent;
  final double width;

  const HexagramTransition({
    super.key,
    required this.originalBinary,
    this.derivedBinary,
    required this.accent,
    this.changingLines = const [],
    required this.originalLabel,
    this.derivedLabel,
    this.width = 88,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HexagramView(
          binary: originalBinary,
          accent: accent,
          changingLines: changingLines,
          subtitle: originalLabel,
          width: width,
        ),
        if (derivedBinary != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward,
                color: theme.colorScheme.onSurfaceVariant, size: 20),
          ),
          HexagramView(
            binary: derivedBinary!,
            accent: accent.withValues(alpha: 0.7),
            subtitle: derivedLabel,
            width: width,
          ),
        ],
      ],
    );
  }
}
