// 通用 AI 占卜: 水晶球 — 圆球 + 内部光晕 + 持续微浮动.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class CrystalBall extends StatefulWidget {
  final String mode;        // 模式名 (例如 "神谕回响")
  final String description;
  const CrystalBall({super.key, required this.mode, required this.description});

  @override
  State<CrystalBall> createState() => _CrystalBallState();
}

class _CrystalBallState extends State<CrystalBall>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtl;
  late final AnimationController _glowCtl;

  @override
  void initState() {
    super.initState();
    _floatCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtl.dispose();
    _glowCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_floatCtl, _glowCtl]),
            builder: (ctx, _) {
              final dy = math.sin(_floatCtl.value * math.pi * 2) * 6;
              final glow = 0.4 + 0.3 * Curves.easeInOut.transform(_glowCtl.value);
              return Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [
                        Color(0xFFE6DEFE),
                        Color(0xFF9580E0),
                        Color(0xFF4B2D89),
                        Color(0xFF1A0E33),
                      ],
                      stops: [0.0, 0.4, 0.75, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9580E0).withValues(alpha: glow),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // 高光
                      Positioned(
                        top: 22, left: 28,
                        child: Container(
                          width: 36, height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                      // 内部小高光
                      Positioned(
                        top: 30, left: 36,
                        child: Container(
                          width: 12, height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // 中央星星 (淡)
                      const Center(
                        child: Text(
                          '✦',
                          style: TextStyle(
                            color: Color(0xFFE6DEFE),
                            fontSize: 48,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // 底座
          Container(
            width: 140, height: 12,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4B3D7B), Color(0xFF1A0E33)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.mode,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
