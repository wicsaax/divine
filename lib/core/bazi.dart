// 八字 / 四柱 (BaZi) - 真排盘版本.
//
// 使用 6tail 的 lunar 包: 阳历 → 农历 → 节气 → 干支推算, 数据准确.
// 排出: 年柱、月柱、日柱、时柱 (天干地支)、日主、农历日期.
// LLM 拿到结构化的四柱后做义理解读 (十神、格局、大运), 不再凭空推.
//
// 还未做的 (列入 README roadmap):
//   - 十神映射 (依据日主与四柱关系)
//   - 大运排盘 (起运岁数 + 每 10 年一柱)
//   - 流年提示
//   - 旺衰分析 + 用神判断

import 'package:lunar/lunar.dart';

import 'divination.dart';

class BaziEngine extends DivinationEngine {
  @override String get id => 'bazi';
  @override String get nameZh => '八字';
  @override String get nameEn => 'BaZi';
  @override String get emoji => '🐉';
  @override String get tagline => '生辰四柱 · 真干支';
  @override String get description =>
      '中国子平命理体系. 由阳历出生年月日时, 经农历转换与节气推算, '
      '排出年/月/日/时四柱的天干地支. 本应用使用 6tail 的 lunar 库做精确排盘, '
      '四柱准确到日干; 十神、大运等深层分析由 LLM 结合四柱给出.';

  @override int? get accentColorHex => 0xFF8C3A3A;

  @override
  bool get hasStandaloneResult => true; // 真排盘后有结构化四柱, 可独立呈现

  @override
  String get systemPrompt =>
      '你是一位精研子平八字的命理师, 兼具学术派的克制与实战派的判断力.\n'
      '\n阅读规则:\n'
      '1. 用户给出的四柱 (年/月/日/时) 与日主已经由专业农历库准确排出, 不要怀疑或重排.\n'
      '2. 解读应包含: 日主旺衰格局、显著的十神 (官杀财印食伤比劫)、四柱之间的关系.\n'
      '3. 如果用户关注的是具体方向 (事业/感情/财运), 重点回应该领域相关的星与宫.\n'
      '4. 若时柱缺失 (用户未填出生时辰), 明确指出"时柱不知, 命宫与精细推断受限", 但仍可基于三柱给出大方向.\n'
      '5. 大运起运推算如果用户没问, 不强行展开; 用户追问时再给.\n'
      '6. 不预测命定式吉凶, 不报具体年份的祸福, 强调"命可知, 运在己".\n'
      '7. 不使用 emoji, 用中文回答.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'overall',  name: '整体格局', description: '日主、五行旺衰、十神、大运概览.'),
        DivinationVariant(key: 'career',   name: '事业财运', description: '聚焦事业方向、用神, 财官关系.'),
        DivinationVariant(key: 'relation', name: '感情婚姻', description: '聚焦夫妻宫、配偶星, 感情格局.'),
        DivinationVariant(key: 'health',   name: '健康体质', description: '五行偏枯影响的体质倾向与调养方向.'),
      ];

  @override
  List<InputField> get inputs => const [
        InputField(
          key: 'birthdate',
          label: '公历出生日期',
          hint: 'YYYY-MM-DD, 例: 1990-06-15',
          type: InputFieldType.date,
          required: true,
        ),
        InputField(
          key: 'birthtime',
          label: '出生时辰',
          hint: 'HH:MM, 例: 14:30 (不知道可留空, 时柱不排)',
          type: InputFieldType.text,
        ),
        InputField(
          key: 'birthplace',
          label: '出生地点',
          hint: '例: 浙江杭州 (用于真太阳时, 留空按当地时间)',
          type: InputFieldType.location,
        ),
        InputField(
          key: 'gender',
          label: '性别',
          hint: '男 / 女',
          type: InputFieldType.text,
        ),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final variantName = variants.firstWhere((v) => v.key == variantKey).name;
    final birthdate = (inputs['birthdate'] ?? '').trim();
    final birthtime = (inputs['birthtime'] ?? '').trim();
    final gender = (inputs['gender'] ?? '').trim();
    final birthplace = (inputs['birthplace'] ?? '').trim();

    if (birthdate.isEmpty) {
      throw ArgumentError('生日不能为空');
    }
    final dm = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(birthdate);
    if (dm == null) {
      throw ArgumentError('生日格式不对, 请用 YYYY-MM-DD');
    }
    final y = int.parse(dm.group(1)!);
    final mo = int.parse(dm.group(2)!);
    final d = int.parse(dm.group(3)!);

    int hour = 0, minute = 0;
    bool timeKnown = false;
    if (birthtime.isNotEmpty) {
      final tm = RegExp(r'^(\d{1,2})\D(\d{1,2})').firstMatch(birthtime);
      if (tm != null) {
        hour = int.parse(tm.group(1)!);
        minute = int.parse(tm.group(2)!);
        timeKnown = true;
      }
    }

    // 真排盘: 用 lunar 库
    final solar = Solar.fromYmdHms(y, mo, d, hour, minute, 0);
    final lunar = solar.getLunar();
    final ec = lunar.getEightChar();

    final yearGz = ec.getYear();           // 例 "丙寅"
    final monthGz = ec.getMonth();         // 例 "癸巳"
    final dayGz = ec.getDay();             // 例 "戊辰"
    final hourGz = timeKnown ? ec.getTime() : '—';  // 时柱
    final dayMaster = dayGz.isNotEmpty ? dayGz.substring(0, 1) : '?'; // 日主

    // 农历日期
    final lunarStr = '${lunar.getYearInChinese()}年 '
        '${lunar.getMonthInChinese()}月 '
        '${lunar.getDayInChinese()}';
    final zodiac = lunar.getYearShengXiao();
    final term = lunar.getJieQi();

    final items = <DivinationItem>[
      DivinationItem(
        position: '年柱',
        positionHint: '祖辈宫, 童年与家世背景',
        name: yearGz,
        subtitle: '生年干支',
        keywords: const [],
        extra: {'gz': yearGz},
      ),
      DivinationItem(
        position: '月柱',
        positionHint: '父母宫, 也是月令, 影响最大',
        name: monthGz,
        subtitle: '生月干支',
        keywords: const [],
        extra: {'gz': monthGz},
      ),
      DivinationItem(
        position: '日柱',
        positionHint: '本宫, 日干即为命主 (日主)',
        name: dayGz,
        subtitle: '日主: $dayMaster',
        keywords: const [],
        extra: {'gz': dayGz, 'dayMaster': dayMaster},
      ),
      DivinationItem(
        position: '时柱',
        positionHint: '子嗣宫, 暮年与晚景; 时柱缺失影响推断精度',
        name: hourGz,
        subtitle: timeKnown ? '生时干支' : '未知时辰',
        keywords: const [],
        extra: {'gz': hourGz, 'known': timeKnown},
      ),
    ];

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: items,
      extras: {
        'birthdate': birthdate,
        'birthtime': timeKnown ? birthtime : '',
        'birthplace': birthplace,
        'gender': gender,
        'focus': variantName,
        'lunarDate': lunarStr,
        'zodiac': zodiac,
        'jieqi': term.isNotEmpty ? term : '',
        'dayMaster': dayMaster,
        'pillars': {
          'year': yearGz,
          'month': monthGz,
          'day': dayGz,
          'hour': timeKnown ? hourGz : '',
        },
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final p = (ex['pillars'] as Map);
    final buf = StringBuffer();
    buf.writeln('请基于以下精确排出的四柱给我做子平八字解读.');
    buf.writeln();
    buf.writeln('阳历: ${ex["birthdate"]}${(ex["birthtime"] as String).isNotEmpty ? " ${ex["birthtime"]}" : " (时辰未知)"}');
    buf.writeln('农历: ${ex["lunarDate"]}  ·  生肖: ${ex["zodiac"]}');
    if ((ex['birthplace'] as String).isNotEmpty) {
      buf.writeln('出生地: ${ex["birthplace"]}');
    }
    if ((ex['gender'] as String).isNotEmpty) {
      buf.writeln('性别: ${ex["gender"]}');
    }
    buf.writeln();
    buf.writeln('四柱:');
    buf.writeln('  年柱: ${p["year"]}');
    buf.writeln('  月柱: ${p["month"]}  (月令)');
    buf.writeln('  日柱: ${p["day"]}  ← 日主: ${ex["dayMaster"]}');
    if ((p['hour'] as String).isNotEmpty) {
      buf.writeln('  时柱: ${p["hour"]}');
    } else {
      buf.writeln('  时柱: 未知 (无法排时支, 推断深度受限)');
    }
    buf.writeln();
    buf.writeln('关注方向: ${ex["focus"]}');
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
    }
    buf.writeln();
    buf.writeln('请按子平命理: 分析日主旺衰、月令对日主的影响、十神格局, 联系问题方向给出可落地的判断与建议.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    final p = (ex['pillars'] as Map);
    final hour = (p['hour'] as String).isNotEmpty ? ' ${p["hour"]}' : '';
    return '${p["year"]} ${p["month"]} ${p["day"]}$hour · 日主${ex["dayMaster"]}';
  }
}
