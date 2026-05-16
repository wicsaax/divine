// 八字四柱视觉化: 4 根竖直柱 (年/月/日/时), 天干在上, 地支在下,
// 按五行配色, 日柱高亮金边, 逐柱"立起"动画.

import 'package:flutter/material.dart';
import 'animated_reveal.dart';

// 天干 → 五行
const Map<String, String> _ganElement = {
  '甲': '木', '乙': '木',
  '丙': '火', '丁': '火',
  '戊': '土', '己': '土',
  '庚': '金', '辛': '金',
  '壬': '水', '癸': '水',
};

// 地支 → 五行 (本气)
const Map<String, String> _zhiElement = {
  '寅': '木', '卯': '木',
  '巳': '火', '午': '火',
  '辰': '土', '丑': '土', '戌': '土', '未': '土',
  '申': '金', '酉': '金',
  '亥': '水', '子': '水',
};

// 五行配色 (主+亮色)
const Map<String, (Color, Color)> _elementColors = {
  '金': (Color(0xFFD4A24C), Color(0xFFFFE4A1)),
  '木': (Color(0xFF4F7942), Color(0xFFA9D49B)),
  '水': (Color(0xFF2E5C8E), Color(0xFF8FBFDE)),
  '火': (Color(0xFFC0392B), Color(0xFFF1A89E)),
  '土': (Color(0xFF8B6F47), Color(0xFFD4B58D)),
};

class BaziPillars extends StatelessWidget {
  final String year, month, day, hour;
  final String dayMaster;
  final bool hourKnown;

  const BaziPillars({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.dayMaster,
    required this.hourKnown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['年柱', '月柱', '日柱', '时柱'];
    final gz = [year, month, day, hour];
    final isMaster = [false, false, true, false];
    final known = [true, true, true, hourKnown];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++)
                AnimatedReveal(
                  delayMs: 150 + i * 200,
                  slideFrom: const Offset(0, 0.3),
                  durationMs: 600,
                  child: _Pillar(
                    label: labels[i],
                    ganZhi: gz[i],
                    isMaster: isMaster[i],
                    known: known[i],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedReveal(
            delayMs: 1000,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.center_focus_strong,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(text: '日主: ',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                          TextSpan(
                            text: dayMaster,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          TextSpan(
                            text: ' · 五行属${_ganElement[dayMaster] ?? "?"}',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
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

class _Pillar extends StatelessWidget {
  final String label;
  final String ganZhi;
  final bool isMaster;
  final bool known;
  const _Pillar({
    required this.label,
    required this.ganZhi,
    required this.isMaster,
    required this.known,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!known || ganZhi.isEmpty || ganZhi == '—') {
      return SizedBox(
        width: 64,
        child: Column(
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Container(
              width: 56, height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
              ),
              child: Text(
                '未\n知',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final gan = ganZhi[0];
    final zhi = ganZhi.length > 1 ? ganZhi[1] : '';
    final ganElement = _ganElement[gan];
    final zhiElement = _zhiElement[zhi];
    final ganColors = _elementColors[ganElement] ?? _elementColors['土']!;
    final zhiColors = _elementColors[zhiElement] ?? _elementColors['土']!;

    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isMaster ? FontWeight.w700 : FontWeight.w500,
                color: isMaster ? const Color(0xFFD4AF37) : null,
              )),
          const SizedBox(height: 4),
          Container(
            width: 56, height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMaster ? const Color(0xFFD4AF37) : theme.colorScheme.outlineVariant,
                width: isMaster ? 2.5 : 1,
              ),
              boxShadow: isMaster
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: [
                  // 天干
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: ganColors.$1,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gan,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                            ),
                          ),
                          Text(
                            ganElement ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 地支
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: zhiColors.$1.withValues(alpha: 0.7),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            zhi,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                            ),
                          ),
                          Text(
                            zhiElement ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
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
