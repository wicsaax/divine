// Lenormand 程序化牌面 + 翻牌动画.
//
// 没有真正公版图, 用每张牌对应的 emoji 作为视觉符号
// (rider=🐎 ship=⛵ key=🔑 等等). 牌面布局: 编号 + emoji + 中文名 + 英文名.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 36 张牌的 emoji 映射 (按 1-36 编号).
const Map<int, String> _lenEmoji = {
  1: '🐎',   // Rider
  2: '🍀',   // Clover
  3: '⛵',   // Ship
  4: '🏠',   // House
  5: '🌳',   // Tree
  6: '☁️',   // Clouds
  7: '🐍',   // Snake
  8: '⚰️',   // Coffin
  9: '💐',   // Bouquet
  10: '🌾',  // Scythe (用麦穗暗示)
  11: '⚡',  // Whip
  12: '🐦',  // Birds
  13: '👶',  // Child
  14: '🦊',  // Fox
  15: '🐻',  // Bear
  16: '⭐',  // Stars
  17: '🦩',  // Stork
  18: '🐕',  // Dog
  19: '🗼',  // Tower
  20: '🌷',  // Garden
  21: '⛰️',   // Mountain
  22: '🛤️',  // Crossroad
  23: '🐭',  // Mice
  24: '❤️',  // Heart
  25: '💍',  // Ring
  26: '📖',  // Book
  27: '✉️',  // Letter
  28: '👨',  // Gentleman
  29: '👩',  // Lady
  30: '🌸',  // Lily
  31: '☀️',  // Sun
  32: '🌙',  // Moon
  33: '🔑',  // Key
  34: '🐟',  // Fish
  35: '⚓',  // Anchor
  36: '✝️',  // Cross
};

class LenormandCardData {
  final int number;
  final String nameZh;
  final String nameEn;
  final List<String> keywords;
  const LenormandCardData({
    required this.number,
    required this.nameZh,
    required this.nameEn,
    required this.keywords,
  });
}

class LenormandCardWidget extends StatefulWidget {
  final LenormandCardData card;
  final String? position;
  final double width;
  final double height;
  final int flipDelayMs;

  const LenormandCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.position,
    this.flipDelayMs = 0,
  });

  @override
  State<LenormandCardWidget> createState() => _LenormandCardWidgetState();
}

class _LenormandCardWidgetState extends State<LenormandCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctl, curve: Curves.easeInOutCubic);
    Future.delayed(Duration(milliseconds: widget.flipDelayMs), () {
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
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final t = _anim.value;
        final angle = t * math.pi;
        final showFront = t > 0.5;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.position != null) ...[
              Text(widget.position!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
            ],
            Transform(
              alignment: Alignment.center,
              transform: transform,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _Face(card: widget.card, width: widget.width, height: widget.height),
                    )
                  : _Back(width: widget.width, height: widget.height),
            ),
          ],
        );
      },
    );
  }
}

class _Face extends StatelessWidget {
  final LenormandCardData card;
  final double width;
  final double height;
  const _Face({required this.card, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final emoji = _lenEmoji[card.number] ?? '🎴';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF4E0), Color(0xFFE5D4A6)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 编号
          Container(
            width: 26, height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB8860B),
            ),
            child: Text(
              '${card.number}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          // emoji 大字
          Text(emoji, style: const TextStyle(fontSize: 38)),
          // 名字
          Column(
            children: [
              Text(
                card.nameZh,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6E4A20),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                card.nameEn,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8B6F47),
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Back extends StatelessWidget {
  final double width, height;
  const _Back({required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF8B6F47)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: const Center(
        child: Text('❖',
            style: TextStyle(color: Color(0xFFD4AF37), fontSize: 32)),
      ),
    );
  }
}
