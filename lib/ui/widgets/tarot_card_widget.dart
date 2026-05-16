// 塔罗牌面卡片 + 翻牌动画.
//
// 当前实现: 程序化绘制的牌面 (花色色块 + 名字 + 编号 + 装饰). 不需要图片资源.
// 后续接公版韦特牌图: 把 _CardFace.build 里 Text/Container 换成 Image.asset(card.imagePath).

import 'dart:math' as math;

import 'package:flutter/material.dart';

class TarotCardData {
  final String nameZh;
  final String nameEn;
  final String suit;     // major | wands | cups | swords | pentacles
  final String number;
  final bool reversed;
  final List<String> keywords;
  const TarotCardData({
    required this.nameZh,
    required this.nameEn,
    required this.suit,
    required this.number,
    required this.reversed,
    this.keywords = const [],
  });
}

class TarotCardWidget extends StatefulWidget {
  const TarotCardWidget({
    super.key,
    required this.card,
    this.width = 100,
    this.height = 160,
    this.flipDelayMs = 0,
    this.position,
  });

  final TarotCardData card;
  final double width;
  final double height;
  final int flipDelayMs;
  final String? position; // 牌阵中位置名 (例如 "过去")

  @override
  State<TarotCardWidget> createState() => _TarotCardWidgetState();
}

class _TarotCardWidgetState extends State<TarotCardWidget>
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        // 0 → 1, 0.5 时翻到中线
        final t = _anim.value;
        final angle = t * math.pi;
        final showFront = t > 0.5;
        // 模拟透视
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.position != null) ...[
              Text(
                widget.position!,
                style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
            ],
            Transform(
              alignment: Alignment.center,
              transform: transform,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _CardFace(
                        card: widget.card,
                        width: widget.width,
                        height: widget.height,
                      ),
                    )
                  : _CardBack(width: widget.width, height: widget.height),
            ),
          ],
        );
      },
    );
  }
}

const Map<String, _SuitTheme> _suitThemes = {
  'major': _SuitTheme(Color(0xFF5E3A8E), Color(0xFF8B6CB8), '★'),
  'wands': _SuitTheme(Color(0xFFB54E3D), Color(0xFFDB8470), '🜂'),
  'cups': _SuitTheme(Color(0xFF3A6A8E), Color(0xFF6FA0C2), '🜄'),
  'swords': _SuitTheme(Color(0xFF424B5A), Color(0xFF74809A), '🜁'),
  'pentacles': _SuitTheme(Color(0xFF8B6F1E), Color(0xFFC7A958), '🜃'),
};

class _SuitTheme {
  final Color dark;
  final Color light;
  final String glyph;
  const _SuitTheme(this.dark, this.light, this.glyph);
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.width, required this.height});
  final TarotCardData card;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = _suitThemes[card.suit] ?? _suitThemes['major']!;
    return Transform(
      alignment: Alignment.center,
      transform: card.reversed
          ? (Matrix4.identity()..rotateZ(math.pi))
          : Matrix4.identity(),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.light, theme.dark],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              card.number,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
              ),
            ),
            Center(
              child: Text(
                theme.glyph,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 3)],
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  card.nameZh,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                ),
                Text(
                  card.nameEn,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B4E), Color(0xFF6B4D9C)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: width * 0.55,
              height: width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            const Text(
              '✦',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 36,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
