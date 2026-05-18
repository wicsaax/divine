// 星座运势 (Horoscope).
//
// 通俗款的"今日 / 本周 / 本月 / 本年"星座运势. 用户提供出生日期 (取太阳星座)
// 或者直接选择星座. 用 LLM 生成运势文本.

import 'divination.dart';

class _ZodiacSign {
  final int idx;            // 0-11
  final String nameZh;
  final String nameEn;
  final String glyph;
  final int startMonth, startDay;
  final int endMonth, endDay;
  final String element;
  final String quality;
  const _ZodiacSign(
    this.idx,
    this.nameZh,
    this.nameEn,
    this.glyph,
    this.startMonth, this.startDay,
    this.endMonth, this.endDay,
    this.element,
    this.quality,
  );
}

const List<_ZodiacSign> _signs = [
  _ZodiacSign(0,  '白羊座', 'Aries',       '♈', 3, 21, 4, 19,  '火', '基本'),
  _ZodiacSign(1,  '金牛座', 'Taurus',      '♉', 4, 20, 5, 20,  '土', '固定'),
  _ZodiacSign(2,  '双子座', 'Gemini',      '♊', 5, 21, 6, 20,  '风', '变动'),
  _ZodiacSign(3,  '巨蟹座', 'Cancer',      '♋', 6, 21, 7, 22,  '水', '基本'),
  _ZodiacSign(4,  '狮子座', 'Leo',         '♌', 7, 23, 8, 22,  '火', '固定'),
  _ZodiacSign(5,  '处女座', 'Virgo',       '♍', 8, 23, 9, 22,  '土', '变动'),
  _ZodiacSign(6,  '天秤座', 'Libra',       '♎', 9, 23, 10, 22, '风', '基本'),
  _ZodiacSign(7,  '天蝎座', 'Scorpio',     '♏', 10, 23, 11, 21,'水', '固定'),
  _ZodiacSign(8,  '射手座', 'Sagittarius', '♐', 11, 22, 12, 21,'火', '变动'),
  _ZodiacSign(9,  '摩羯座', 'Capricorn',   '♑', 12, 22, 1, 19, '土', '基本'),
  _ZodiacSign(10, '水瓶座', 'Aquarius',    '♒', 1, 20, 2, 18,  '风', '固定'),
  _ZodiacSign(11, '双鱼座', 'Pisces',      '♓', 2, 19, 3, 20,  '水', '变动'),
];

/// 由 月.日 推太阳星座.
_ZodiacSign? _signFromDate(int month, int day) {
  for (final s in _signs) {
    if (s.startMonth == s.endMonth) {
      if (month == s.startMonth && day >= s.startDay && day <= s.endDay) return s;
    } else {
      // 跨月 (例如 摩羯 12.22-1.19)
      if ((month == s.startMonth && day >= s.startDay) ||
          (month == s.endMonth && day <= s.endDay)) {
        return s;
      }
    }
  }
  return null;
}

/// 直接按名字找星座 (用户填"巨蟹" / "Cancer" / "♋" 都行).
_ZodiacSign? _signByName(String input) {
  final q = input.trim();
  if (q.isEmpty) return null;
  for (final s in _signs) {
    if (s.nameZh == q || s.nameEn.toLowerCase() == q.toLowerCase() || s.glyph == q) return s;
    if (q.contains(s.nameZh) || q.toLowerCase().contains(s.nameEn.toLowerCase())) return s;
  }
  return null;
}

class HoroscopeEngine extends DivinationEngine {
  @override String get id => 'horoscope';
  @override String get nameZh => '星座运势';
  @override String get nameEn => 'Horoscope';
  @override String get emoji => '⭐';
  @override String get tagline => '12 太阳星座 · 今日/本周/本月/本年';
  @override String get description =>
      '通俗的星座运势播报. 按出生日期推太阳星座, 或者直接选你的星座, '
      '看今天/本周/本月/全年的整体 / 爱情 / 事业 / 健康 / 幸运色与数字.';

  @override int? get accentColorHex => 0xFFD4AF37; // 金色

  @override bool get hasStandaloneResult => true;

  @override
  String get systemPrompt =>
      '你是一位资深的占星专栏作家, 写过国内外大量星座运势栏目, '
      '风格类似 Susan Miller / Astro Ya (亚里) 那种, 既有占星根基又通俗易读.\n'
      '\n阅读规则:\n'
      '1. 用户给的是 太阳星座 + 时间窗口 (今日/本周/本月/本年).\n'
      '2. 你要根据当下的真实天象 (主要行星的星座+相位) 推 — '
      '如果训练数据日期较远, 请基于一般占星规律推断 + 标注"参考性".\n'
      '3. 输出结构:\n'
      '   ✦ 整体能量 (2-3 句概括)\n'
      '   ❤️ 爱情运势\n'
      '   💼 事业 / 学业\n'
      '   💰 财运\n'
      '   🌿 健康 / 心情\n'
      '   🎯 幸运色 + 幸运数字 + 当期建议\n'
      '4. 风格亲切但不夸张, 不预测吉凶, 给具体可执行的小建议.\n'
      '5. emoji 仅在小标题前用一个 (上面已经规定了), 正文不用.\n'
      '6. 用中文回答.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'today',  name: '今日运势', description: '关注当下的星象重点.'),
        DivinationVariant(key: 'week',   name: '本周运势', description: '一周的能量主线 + 各天起伏.'),
        DivinationVariant(key: 'month',  name: '本月运势', description: '本月主要天象与该星座的对应.'),
        DivinationVariant(key: 'year',   name: '本年运势', description: '全年大趋势 + 月度提示要点.'),
      ];

  @override
  List<InputField> get inputs => const [
        InputField(
          key: 'sign',
          label: '你的星座',
          hint: '直接填"白羊座 / Aries / ♈"; 留空则用下面的生日推',
        ),
        InputField(
          key: 'birthdate',
          label: '公历出生日期 (替代方案)',
          hint: 'YYYY-MM-DD; 若上面已选星座则忽略',
          type: InputFieldType.date,
        ),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final variantName = variants.firstWhere((v) => v.key == variantKey).name;
    final signInput = (inputs['sign'] ?? '').trim();
    final birthdate = (inputs['birthdate'] ?? '').trim();

    _ZodiacSign? sign;
    if (signInput.isNotEmpty) {
      sign = _signByName(signInput);
      if (sign == null) {
        throw ArgumentError('没认出这个星座名: $signInput\n试试: 白羊座 / Aries / ♈ 等');
      }
    } else if (birthdate.isNotEmpty) {
      final m = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(birthdate);
      if (m == null) throw ArgumentError('生日格式不对, 用 YYYY-MM-DD');
      sign = _signFromDate(int.parse(m.group(2)!), int.parse(m.group(3)!));
      if (sign == null) {
        throw ArgumentError('从生日推不出星座 (?!), 直接填星座名吧');
      }
    } else {
      throw ArgumentError('请填星座或者出生日期 (二选一)');
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: [
        DivinationItem(
          position: '你的星座',
          positionHint: '',
          name: '${sign.glyph} ${sign.nameZh}',
          subtitle: '${sign.nameEn} · ${sign.element} · ${sign.quality}',
          keywords: const [],
          extra: {'signIdx': sign.idx, 'signNameZh': sign.nameZh},
        ),
        DivinationItem(
          position: '时段',
          positionHint: '',
          name: variantName,
          subtitle: dateStr,
          keywords: const [],
        ),
      ],
      extras: {
        'signIdx': sign.idx,
        'signZh': sign.nameZh,
        'signEn': sign.nameEn,
        'signGlyph': sign.glyph,
        'element': sign.element,
        'quality': sign.quality,
        'period': variantKey,
        'periodName': variantName,
        'date': dateStr,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('请给我写一篇"${ex["signZh"]} (${ex["signEn"]}) ${ex["periodName"]}".');
    buf.writeln();
    buf.writeln('参考时间: ${ex["date"]}');
    buf.writeln('星座属性: ${ex["element"]}相 · ${ex["quality"]}宫');
    if (question.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('用户额外关注: ${question.trim()}');
    }
    buf.writeln();
    buf.writeln('请按 system prompt 里的结构 (整体 / 爱情 / 事业 / 财 / 健康 / 幸运色+数字+建议) 输出.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '${ex["signGlyph"]} ${ex["signZh"]} · ${ex["periodName"]}';
  }
}
