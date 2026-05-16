// 数字命理生命数大字展示: 中央巨型数字 + 光晕 + 原型副标题 + 关键词列.

import 'package:flutter/material.dart';
import 'animated_reveal.dart';

class LifePathReveal extends StatelessWidget {
  final int lifePath;
  final String archetype;
  final List<String> keywords;
  final String description;
  final Color accent;

  const LifePathReveal({
    super.key,
    required this.lifePath,
    required this.archetype,
    required this.keywords,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // 数字 + 光晕
          AnimatedReveal(
            delayMs: 200,
            startScale: 0.6,
            slideFrom: Offset.zero,
            durationMs: 800,
            child: Container(
              width: 180, height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.4 : 0.25),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: BreathingPulse(
                minScale: 0.96, maxScale: 1.04,
                child: Text(
                  '$lifePath',
                  style: TextStyle(
                    color: accent,
                    fontSize: 96,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedReveal(
            delayMs: 600,
            durationMs: 600,
            child: Text(
              archetype,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (keywords.isNotEmpty)
            AnimatedReveal(
              delayMs: 900,
              durationMs: 500,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8, runSpacing: 6,
                children: keywords
                    .map((k) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            k,
                            style: TextStyle(
                              fontSize: 13,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 14),
          AnimatedReveal(
            delayMs: 1100,
            durationMs: 500,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
