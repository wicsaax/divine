// 卢恩 / Ogham 共用的"石头/木头"质感卡片.
// 中央大字 glyph, 下方名字, 可选逆位.

import 'package:flutter/material.dart';
import 'dart:math' as math;

class StoneCardWidget extends StatelessWidget {
  final String glyph;     // 大字符号 ᚠ / ᚁ 等
  final String name;
  final String? subtitle; // Old Norse / 树名
  final String? position;
  final bool reversed;
  final Color accentDark;  // 主体色
  final Color accentLight; // 高光
  final bool wood;         // true=木质纹理 (Ogham), false=石头 (Runes)
  final double width;
  final double height;
  final int revealDelayMs;

  const StoneCardWidget({
    super.key,
    required this.glyph,
    required this.name,
    this.subtitle,
    this.position,
    this.reversed = false,
    required this.accentDark,
    required this.accentLight,
    this.wood = false,
    this.width = 96,
    this.height = 130,
    this.revealDelayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (position != null) ...[
          Text(position!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
        ],
        _RevealedStone(
          glyph: glyph,
          name: name,
          subtitle: subtitle,
          reversed: reversed,
          accentDark: accentDark,
          accentLight: accentLight,
          wood: wood,
          width: width,
          height: height,
          delayMs: revealDelayMs,
        ),
      ],
    );
  }
}

class _RevealedStone extends StatefulWidget {
  final String glyph, name;
  final String? subtitle;
  final bool reversed, wood;
  final Color accentDark, accentLight;
  final double width, height;
  final int delayMs;
  const _RevealedStone({
    required this.glyph, required this.name, this.subtitle,
    required this.reversed, required this.wood,
    required this.accentDark, required this.accentLight,
    required this.width, required this.height,
    required this.delayMs,
  });
  @override
  State<_RevealedStone> createState() => _RevealedStoneState();
}

class _RevealedStoneState extends State<_RevealedStone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final t = _anim.value;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 1.2,
                  colors: [widget.accentLight, widget.accentDark],
                ),
                borderRadius: BorderRadius.circular(widget.wood ? 6 : 14),
                border: Border.all(
                  color: widget.accentDark.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                  // 内层柔光
                  BoxShadow(
                    color: widget.accentLight.withValues(alpha: 0.4),
                    blurRadius: 3,
                    spreadRadius: -3,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 6),
                    // glyph (中央, 凿刻效果)
                    Transform.rotate(
                      angle: widget.reversed ? math.pi : 0,
                      child: Text(
                        widget.glyph,
                        style: TextStyle(
                          fontSize: widget.width * 0.45,
                          color: Colors.white,
                          height: 1.0,
                          shadows: [
                            const Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(1, 2),
                            ),
                            Shadow(
                              color: widget.accentLight.withValues(alpha: 0.8),
                              blurRadius: 3,
                              offset: const Offset(-1, -1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (widget.reversed)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '逆位',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
