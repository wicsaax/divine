// 梅花易数: 三个数字"落下"动画 → 形成上下两卦 + 动爻位.
// 卦象本身由 HexagramTransition 在外面展示, 这里只展示起卦过程.

import 'package:flutter/material.dart';
import 'animated_reveal.dart';

class PlumNumberDrop extends StatelessWidget {
  final int n1, n2, n3;
  final String upperTrigram;
  final String lowerTrigram;
  final int changingYao;
  final Color accent;

  const PlumNumberDrop({
    super.key,
    required this.n1,
    required this.n2,
    required this.n3,
    required this.upperTrigram,
    required this.lowerTrigram,
    required this.changingYao,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 3; i++)
                AnimatedReveal(
                  delayMs: 100 + i * 300,
                  slideFrom: const Offset(0, -0.6),
                  startScale: 0.5,
                  durationMs: 700,
                  child: _NumberBall(
                    value: [n1, n2, n3][i],
                    label: ['n₁', 'n₂', 'n₃'][i],
                    accent: accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delayMs: 1100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Text('上卦', style: theme.textTheme.labelSmall),
                      Text(upperTrigram,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          )),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('·', style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 24,
                    )),
                  ),
                  Column(
                    children: [
                      Text('下卦', style: theme.textTheme.labelSmall),
                      Text(lowerTrigram,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          )),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('·', style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 24,
                    )),
                  ),
                  Column(
                    children: [
                      Text('动爻', style: theme.textTheme.labelSmall),
                      Text('第 $changingYao 爻',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade400,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberBall extends StatelessWidget {
  final int value;
  final String label;
  final Color accent;
  const _NumberBall({required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.85),
                accent.withValues(alpha: 0.5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
