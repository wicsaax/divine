// 占星本命盘 wheel — CustomPainter 画的圆形 12 宫 + 黄道 + 行星 + 主相位.

import 'dart:math' as math;
import 'package:flutter/material.dart';

const List<String> _signGlyphs = [
  '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓',
];
const List<String> _planetGlyphs = [
  '☉', '☽', '☿', '♀', '♂', '♃', '♄', '♅', '♆', '♇',
];
const List<String> _planetNames = [
  '太阳', '月亮', '水星', '金星', '火星', '木星', '土星', '天王星', '海王星', '冥王星',
];

class NatalChartView extends StatelessWidget {
  /// 行星: [{name, longitude, retrograde}, ...]
  final List<Map<String, dynamic>> planets;
  /// 12 宫起点 (cusps[1..12] 黄经度数). 长度 13, 第 0 项不用.
  final List<double> houseCusps;
  /// 主要相位: [{a, b, aspect, angle, orb}, ...]
  final List<Map<String, dynamic>> aspects;
  /// 行运行星 (外圈, 可空)
  final List<Map<String, dynamic>>? transits;
  /// 推运行星 (内圈, 可空)
  final List<Map<String, dynamic>>? progressions;
  /// 行运 → 本命的紧密相位 (可空)
  final List<Map<String, dynamic>>? transitAspects;
  final double size;

  const NatalChartView({
    super.key,
    required this.planets,
    required this.houseCusps,
    required this.aspects,
    this.transits,
    this.progressions,
    this.transitAspects,
    this.size = 320,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChartPainter(
          planets: planets,
          houseCusps: houseCusps,
          aspects: aspects,
          transits: transits,
          progressions: progressions,
          transitAspects: transitAspects,
          colorScheme: theme.colorScheme,
          isDark: theme.brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> planets;
  final List<double> houseCusps;
  final List<Map<String, dynamic>> aspects;
  final List<Map<String, dynamic>>? transits;
  final List<Map<String, dynamic>>? progressions;
  final List<Map<String, dynamic>>? transitAspects;
  final ColorScheme colorScheme;
  final bool isDark;

  _ChartPainter({
    required this.planets,
    required this.houseCusps,
    required this.aspects,
    this.transits,
    this.progressions,
    this.transitAspects,
    required this.colorScheme,
    required this.isDark,
  });

  // 占星 wheel 中, 0° 白羊在西方 (左侧), 度数逆时针增加.
  // 数学坐标系: 0° 在右, 逆时针为正. 所以画图时 longitude→angle 是:
  //   screenAngle = π - longitudeRad (即把 0° 移到左, 反转方向)
  double _toAngle(double longitudeDeg) {
    final r = longitudeDeg * math.pi / 180;
    return math.pi - r;
  }

  Offset _onCircle(Offset center, double radius, double angle) {
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy - radius * math.sin(angle), // y 轴翻转
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;
    final zodiacInnerR = outerR - 28;
    final houseInnerR = outerR - 80;
    final planetR = outerR - 16;
    final aspectR = houseInnerR - 6;

    final stroke = colorScheme.onSurface.withValues(alpha: isDark ? 0.7 : 0.85);
    final faint = colorScheme.onSurface.withValues(alpha: 0.25);

    // 外圈
    canvas.drawCircle(center, outerR,
        Paint()..color = colorScheme.surfaceContainerLow);
    canvas.drawCircle(center, outerR,
        Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(center, zodiacInnerR,
        Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawCircle(center, houseInnerR,
        Paint()..color = faint..style = PaintingStyle.stroke..strokeWidth = 1);

    // 12 宫位线
    final housePaint = Paint()..color = faint..strokeWidth = 1;
    for (var i = 1; i <= 12; i++) {
      final a = _toAngle(houseCusps[i]);
      final outer = _onCircle(center, houseInnerR, a);
      final inner = _onCircle(center, aspectR, a);
      canvas.drawLine(outer, inner, housePaint);
      // 宫位号 (略小, 在 cusp 顺时针方向一点)
      final nextI = i == 12 ? 1 : i + 1;
      final midAng = (_toAngle(houseCusps[i]) + _toAngle(houseCusps[nextI])) / 2;
      // 处理跨 0 度
      double midA = midAng;
      // 用 cusp[i] 的下一刻度的均值, 简单近似
      _drawText(
        canvas,
        '$i',
        _onCircle(center, houseInnerR - 14, midA),
        color: colorScheme.onSurfaceVariant,
        fontSize: 10,
        bold: false,
      );
    }

    // 12 星座扇区 + glyph
    for (var i = 0; i < 12; i++) {
      final startDeg = i * 30.0;
      final endDeg = (i + 1) * 30.0;
      final startA = _toAngle(startDeg);
      final endA = _toAngle(endDeg);

      // 扇区分割线
      canvas.drawLine(
        _onCircle(center, zodiacInnerR, startA),
        _onCircle(center, outerR, startA),
        Paint()..color = stroke..strokeWidth = 0.8,
      );

      // glyph 在扇区中线
      final midA = (startA + endA) / 2;
      final glyphPos = _onCircle(center, (zodiacInnerR + outerR) / 2, midA);
      _drawText(
        canvas,
        _signGlyphs[i],
        glyphPos,
        color: stroke,
        fontSize: 18,
      );
    }

    // 行星点 — 防止重叠: 同象限内若两颗距离 < 8°, 沿径向错开
    final placed = <(double, double)>[]; // (angle, radius)
    for (var i = 0; i < planets.length && i < _planetGlyphs.length; i++) {
      final p = planets[i];
      final lon = p['longitude'] as double;
      final a = _toAngle(lon);
      var r = planetR.toDouble();
      // 防重叠: 若已有点在 < 0.12 弧度内, 推向内
      while (placed.any((p2) => (p2.$1 - a).abs() < 0.14 && (p2.$2 - r).abs() < 14)) {
        r -= 14;
      }
      placed.add((a, r));

      final pos = _onCircle(center, r, a);
      // 行星点
      canvas.drawCircle(
        pos, 12,
        Paint()..color = colorScheme.primary.withValues(alpha: 0.15),
      );
      _drawText(
        canvas,
        _planetGlyphs[i],
        pos,
        color: colorScheme.primary,
        fontSize: 16,
        bold: true,
      );

      // 逆行 ☋
      if (p['retrograde'] == true) {
        _drawText(
          canvas,
          '℞',
          Offset(pos.dx + 9, pos.dy + 8),
          color: Colors.red.shade400,
          fontSize: 9,
        );
      }
    }

    // 相位线 (中间)
    for (final asp in aspects) {
      final aName = asp['a'] as String;
      final bName = asp['b'] as String;
      final aspectType = asp['aspect'] as String;
      final a = planets.firstWhere((p) => p['name'] == aName, orElse: () => {});
      final b = planets.firstWhere((p) => p['name'] == bName, orElse: () => {});
      if (a.isEmpty || b.isEmpty) continue;
      final aA = _toAngle(a['longitude'] as double);
      final bA = _toAngle(b['longitude'] as double);
      final aP = _onCircle(center, aspectR, aA);
      final bP = _onCircle(center, aspectR, bA);
      final color = switch (aspectType) {
        '合相' => Colors.amber.shade600,
        '对分' => Colors.red.shade400,
        '三分' => Colors.green.shade500,
        '四分' => Colors.deepOrange.shade400,
        '六合' => Colors.blue.shade400,
        _ => faint,
      };
      canvas.drawLine(
        aP, bP,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = aspectType == '合相' || aspectType == '对分' ? 1.5 : 1,
      );
    }

    // 行运行星 (外圈, 略小, 蓝色调)
    if (transits != null && transits!.isNotEmpty) {
      final tRadius = outerR + 18; // 在黄道圈外
      // 给外圈空间
      canvas.drawCircle(center, tRadius,
          Paint()..color = Colors.blue.withValues(alpha: 0.04)..style = PaintingStyle.fill);
      canvas.drawCircle(center, tRadius,
          Paint()..color = Colors.blue.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.6);
      final tPlaced = <(double, double)>[];
      for (var i = 0; i < transits!.length && i < _planetGlyphs.length; i++) {
        final lon = transits![i]['longitude'] as double;
        final a = _toAngle(lon);
        var r = tRadius;
        while (tPlaced.any((p2) => (p2.$1 - a).abs() < 0.14 && (p2.$2 - r).abs() < 12)) {
          r += 12;
        }
        tPlaced.add((a, r));
        final pos = _onCircle(center, r, a);
        _drawText(
          canvas,
          _planetGlyphs[i],
          pos,
          color: Colors.blue.shade600,
          fontSize: 13,
          bold: true,
        );
      }
    }

    // 推运行星 (内圈, 紫色调)
    if (progressions != null && progressions!.isNotEmpty) {
      final pRadius = aspectR - 24;
      canvas.drawCircle(center, pRadius,
          Paint()..color = const Color(0xFF9580E0).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.6);
      final pPlaced = <(double, double)>[];
      for (var i = 0; i < progressions!.length && i < _planetGlyphs.length; i++) {
        final lon = progressions![i]['longitude'] as double;
        final a = _toAngle(lon);
        var r = pRadius;
        while (pPlaced.any((p2) => (p2.$1 - a).abs() < 0.14 && (p2.$2 - r).abs() < 12)) {
          r -= 12;
        }
        pPlaced.add((a, r));
        final pos = _onCircle(center, r, a);
        _drawText(
          canvas,
          _planetGlyphs[i],
          pos,
          color: const Color(0xFF9580E0),
          fontSize: 11,
          bold: false,
        );
      }
    }

    // 行运 → 本命的紧密相位虚线
    if (transitAspects != null && transitAspects!.isNotEmpty && transits != null) {
      final tRadius = outerR + 18;
      for (final asp in transitAspects!.take(10)) {
        final transitName = asp['transitPlanet'] as String;
        final natalName = asp['natalPlanet'] as String;
        final t = transits!.firstWhere((p) => p['name'] == transitName, orElse: () => {});
        final n = planets.firstWhere((p) => p['name'] == natalName, orElse: () => {});
        if (t.isEmpty || n.isEmpty) continue;
        final tA = _toAngle(t['longitude'] as double);
        final nA = _toAngle(n['longitude'] as double);
        final tP = _onCircle(center, tRadius, tA);
        final nP = _onCircle(center, aspectR + 4, nA);
        final aspectType = asp['aspect'] as String;
        final color = switch (aspectType) {
          '合相' => Colors.amber.shade600,
          '对分' => Colors.red.shade400,
          '三分' => Colors.green.shade500,
          '四分' => Colors.deepOrange.shade400,
          '六合' => Colors.blue.shade400,
          _ => Colors.grey,
        };
        // 画虚线
        _drawDashedLine(canvas, tP, nP, color.withValues(alpha: 0.55), 1.0);
      }
    }

    // ASC 指示 (cusp[1] 处一条粗线)
    final ascA = _toAngle(houseCusps[1]);
    canvas.drawLine(
      _onCircle(center, houseInnerR - 2, ascA),
      _onCircle(center, outerR + 4, ascA),
      Paint()..color = colorScheme.primary..strokeWidth = 2.5,
    );
    _drawText(
      canvas,
      'ASC',
      _onCircle(center, outerR + 16, ascA),
      color: colorScheme.primary,
      fontSize: 10,
      bold: true,
    );
    // MC (cusp[10])
    final mcA = _toAngle(houseCusps[10]);
    canvas.drawLine(
      _onCircle(center, houseInnerR - 2, mcA),
      _onCircle(center, outerR + 4, mcA),
      Paint()..color = colorScheme.secondary..strokeWidth = 2,
    );
    _drawText(
      canvas,
      'MC',
      _onCircle(center, outerR + 16, mcA),
      color: colorScheme.secondary,
      fontSize: 10,
      bold: true,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final total = (b - a).distance;
    const dashLen = 5.0;
    const gap = 3.0;
    const segLen = dashLen + gap;
    final segCount = (total / segLen).floor();
    final dx = (b.dx - a.dx) / total;
    final dy = (b.dy - a.dy) / total;
    for (var i = 0; i < segCount; i++) {
      final start = i * segLen;
      final p1 = Offset(a.dx + dx * start, a.dy + dy * start);
      final p2 = Offset(a.dx + dx * (start + dashLen), a.dy + dy * (start + dashLen));
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawText(Canvas canvas, String text, Offset pos,
      {required Color color, required double fontSize, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.planets != planets ||
      old.houseCusps != houseCusps ||
      old.aspects != aspects ||
      old.transits != transits ||
      old.progressions != progressions ||
      old.transitAspects != transitAspects;
}

// 简易图例 (用于盘下方说明).
class NatalChartLegend extends StatelessWidget {
  const NatalChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        for (var i = 0; i < _planetGlyphs.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_planetGlyphs[i],
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(width: 2),
              Text(_planetNames[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
      ],
    );
  }
}
