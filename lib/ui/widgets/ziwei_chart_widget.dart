// 紫微斗数 12 宫盘.
//
// 传统布局是 4x4 网格, 12 宫位在外圈, 中心 2x2 留作 "命主" 总结区.
// 12 地支顺时针: 巳午未申 / 辰  酉 / 卯  戌 / 寅丑子亥
//
// 但 dart 矩形布局比较麻烦, 我简化为 4x4 表格, 中间四格合并显示"命主信息".

import 'package:flutter/material.dart';

class ZiWeiChartWidget extends StatelessWidget {
  /// 12 宫数据, 每项含: name, zhi, ganZhi, stars (List<String>), isMing, isShen
  final List<Map<String, dynamic>> palaces;
  final String centerInfo;
  final Color accent;

  const ZiWeiChartWidget({
    super.key,
    required this.palaces,
    required this.centerInfo,
    required this.accent,
  });

  /// 12 地支在 4x4 网格中的位置 (row, col).
  /// 子=0 在底中右; 丑=1 底中左之右; 寅=2 在左下; 卯=3 左中下; 辰=4 左中上; 巳=5 左上;
  /// 午=6 顶中左; 未=7 顶中右; 申=8 右上; 酉=9 右中上; 戌=10 右中下; 亥=11 右下.
  static const Map<int, (int, int)> _zhiToCell = {
    5: (0, 0), 6: (0, 1), 7: (0, 2), 8: (0, 3),  // 巳午未申 顶部
    4: (1, 0),                       9: (1, 3),  // 辰      酉
    3: (2, 0),                       10: (2, 3), // 卯      戌
    2: (3, 0), 1: (3, 1), 0: (3, 2), 11: (3, 3), // 寅丑子亥 底部
  };

  static const _zhiOrder = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 把 palaces 按 zhi 名建索引
    final byZhi = <String, Map<String, dynamic>>{
      for (final p in palaces) p['zhi'] as String: p,
    };

    return LayoutBuilder(
      builder: (ctx, c) {
        final size = c.maxWidth;
        final cellSize = size / 4;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // 4x4 网格
              for (var i = 0; i < 12; i++)
                _placeCell(byZhi, i, cellSize, theme),
              // 中心 2x2 信息
              Positioned(
                left: cellSize,
                top: cellSize,
                width: cellSize * 2,
                height: cellSize * 2,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    centerInfo,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeCell(Map<String, Map<String, dynamic>> byZhi, int zhiIdx,
      double cellSize, ThemeData theme) {
    final pos = _zhiToCell[zhiIdx]!;
    final palace = byZhi[_zhiOrder[zhiIdx]];
    if (palace == null) return const SizedBox.shrink();

    final isMing = palace['isMing'] == true;
    final isShen = palace['isShen'] == true;
    final stars = (palace['stars'] as List).cast<String>();

    return Positioned(
      left: pos.$2 * cellSize,
      top: pos.$1 * cellSize,
      width: cellSize,
      height: cellSize,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMing
              ? accent.withValues(alpha: 0.18)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isMing ? accent : accent.withValues(alpha: 0.25),
            width: isMing ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    palace['name'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: cellSize * 0.10,
                      color: isMing ? accent : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isMing)
                  Text('★',
                      style: TextStyle(
                        color: accent,
                        fontSize: cellSize * 0.12,
                      )),
                if (isShen && !isMing)
                  Text('身',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                        fontSize: cellSize * 0.10,
                      )),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              palace['ganZhi'] as String,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: cellSize * 0.08,
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Wrap(
                spacing: 2,
                runSpacing: 1,
                children: stars
                    .map((s) => Text(
                          s,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: cellSize * 0.085,
                            color: _isPositiveStar(s)
                                ? Colors.amber.shade700
                                : theme.colorScheme.onSurface,
                            height: 1.1,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPositiveStar(String name) {
    // 主星里这几颗传统视为吉星 (作为色彩区分, 实际还要看组合)
    const positive = ['紫微', '天府', '太阳', '太阴', '天梁', '天同', '武曲', '天相'];
    return positive.contains(name);
  }
}
