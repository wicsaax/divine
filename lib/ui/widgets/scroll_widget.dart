// 经典占卜 (Bibliomancy): 羊皮卷展开动画 + 中央引用.

import 'package:flutter/material.dart';

class ScrollReveal extends StatefulWidget {
  final String reference;
  final String book;
  const ScrollReveal({super.key, required this.reference, required this.book});

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctl, curve: Curves.easeInOutCubic);
    Future.delayed(const Duration(milliseconds: 200), () {
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
        // 0..1, 卷轴宽度从 30% 展开到 100%
        final widthFraction = 0.3 + 0.7 * t;
        return Center(
          child: FractionallySizedBox(
            widthFactor: widthFraction,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8D9A8),
                    Color(0xFFF5E9C2),
                    Color(0xFFE8D9A8),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border(
                  left: BorderSide(color: const Color(0xFF8B6F2F).withValues(alpha: 0.5), width: 4),
                  right: BorderSide(color: const Color(0xFF8B6F2F).withValues(alpha: 0.5), width: 4),
                ),
              ),
              child: Opacity(
                opacity: t < 0.7 ? 0 : (t - 0.7) / 0.3,
                child: Column(
                  children: [
                    Text(
                      widget.book,
                      style: const TextStyle(
                        color: Color(0xFF6E4A20),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.reference,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF3E2814),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
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
