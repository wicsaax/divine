// 通用的"渐进显现"动画 widget. 用于占卜结果的入场.
//
// 用法:
//   AnimatedReveal(
//     delayMs: 200,
//     child: ...
//   )
// 或者批量 staggered:
//   for (var i = 0; i < items.length; i++)
//     AnimatedReveal(delayMs: 200 + i * 150, child: items[i])

import 'package:flutter/material.dart';

class AnimatedReveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final int durationMs;
  final Offset slideFrom;  // 起点偏移
  final double startScale; // 起始缩放
  final bool fade;

  const AnimatedReveal({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 600,
    this.slideFrom = const Offset(0, 0.2),
    this.startScale = 1.0,
    this.fade = true,
  });

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
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
      child: widget.child,
      builder: (ctx, child) {
        final t = _anim.value;
        Widget c = child!;
        if (widget.startScale != 1.0) {
          final scale = widget.startScale + (1.0 - widget.startScale) * t;
          c = Transform.scale(scale: scale, child: c);
        }
        if (widget.slideFrom != Offset.zero) {
          final dx = widget.slideFrom.dx * (1 - t);
          final dy = widget.slideFrom.dy * (1 - t);
          c = FractionalTranslation(translation: Offset(dx, dy), child: c);
        }
        if (widget.fade) {
          c = Opacity(opacity: t, child: c);
        }
        return c;
      },
    );
  }
}

/// 持续呼吸 (脉冲) 动画 — 给"YES/NO"那种戏剧化结果用.
class BreathingPulse extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  const BreathingPulse({
    super.key,
    required this.child,
    this.minScale = 0.97,
    this.maxScale = 1.03,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<BreathingPulse> createState() => _BreathingPulseState();
}

class _BreathingPulseState extends State<BreathingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      child: widget.child,
      builder: (ctx, child) {
        final t = Curves.easeInOut.transform(_ctl.value);
        final scale = widget.minScale + (widget.maxScale - widget.minScale) * t;
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
