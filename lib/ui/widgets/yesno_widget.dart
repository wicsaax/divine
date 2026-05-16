// 是否占卜的戏剧化展示: 大字 + 颜色对应 + 呼吸动画.

import 'package:flutter/material.dart';
import 'animated_reveal.dart';

class YesNoBigReveal extends StatelessWidget {
  final String tendency;     // 倾向是 / 倾向否 / 难以判断 / 明确是 / 明确否
  final String? detail;      // 来源详情, 例如 "二正一反" / "塔罗-星星 (正位)"
  final String method;
  const YesNoBigReveal({
    super.key,
    required this.tendency,
    required this.method,
    this.detail,
  });

  Color _bg(BuildContext ctx) {
    final t = tendency;
    if (t.contains('明确是') || t == '倾向是') return const Color(0xFF388E3C);
    if (t.contains('明确否') || t == '倾向否') return const Color(0xFFC62828);
    return const Color(0xFF616161);
  }

  String _bigText() {
    if (tendency.contains('是')) return 'YES';
    if (tendency.contains('否')) return 'NO';
    return 'MAYBE';
  }

  @override
  Widget build(BuildContext context) {
    final color = _bg(context);
    return AnimatedReveal(
      delayMs: 200,
      startScale: 0.5,
      slideFrom: Offset.zero,
      durationMs: 800,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.65)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            BreathingPulse(
              child: Text(
                _bigText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  shadows: [
                    Shadow(color: Colors.black38, blurRadius: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tendency,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '$method · $detail',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(method,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
