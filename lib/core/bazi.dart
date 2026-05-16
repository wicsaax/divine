// 八字 / 四柱 (BaZi) - AI 近似版.
//
// 注意: 这不是真正的八字算法实现. 真正实现需要农历库 + 24 节气 + 干支推算,
// 是一个 2-3 天的专项工程. 当前版本收集结构化输入 (出生时间 + 地点 + 性别),
// 完全交给 LLM 凭借训练数据中的八字知识做"近似"解读.
//
// 优先级方向: 后续如果要严肃做八字, 引入 `lunar_dart` 或类似农历库,
// 在 Dart 侧完成排盘, 然后只把结构化结果传给 LLM.

import 'divination.dart';

class BaziEngine extends DivinationEngine {
  @override String get id => 'bazi';
  @override String get nameZh => '八字 (AI 近似)';
  @override String get nameEn => 'BaZi (AI-approx)';
  @override String get emoji => '🐉';
  @override String get tagline => '生辰四柱 · AI 排盘';
  @override String get description =>
      '中国命理体系, 以出生年月日时的天干地支组成四柱 (年柱·月柱·日柱·时柱), '
      '推演人生格局、十神、大运、用神. 当前版本由 LLM 凭训练知识近似排盘, '
      '不保证精确到节气与真太阳时.';

  @override int? get accentColorHex => 0xFF8C3A3A; // 朱砂红

  @override
  bool get hasStandaloneResult => false; // 没有本地排盘, 完全靠 LLM

  @override
  String get systemPrompt =>
      '你是一位精研子平八字的命理师, 兼具学术派的克制与实战派的判断力.\n'
      '\n阅读规则:\n'
      '1. 用户会提供出生年月日时与地点 (尽可能精确). 请按子平法近似排出四柱 (年柱、月柱、日柱、时柱).\n'
      '2. 标注出"日主", 简述五行旺衰格局, 列出明显的十神关系.\n'
      '3. 若用户问的是具体方向 (事业/感情/财运), 重点回应该领域的关键力量与潜在课题.\n'
      '4. 如果出生时间不够精确 (例如只到日, 没有时辰), 主动指出"时柱不可知"的限制, 不要硬编.\n'
      '5. 不预测命定式吉凶, 不报年份的具体祸福, 强调"命可知, 运在己".\n'
      '6. 必要时坦诚: 你不是专业排盘软件, 节气与真太阳时可能略有偏差.\n'
      '7. 不使用 emoji, 用中文.';

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
          hint: 'HH:MM, 例: 14:30 (不知道可留空)',
          type: InputFieldType.text,
        ),
        InputField(
          key: 'birthplace',
          label: '出生地点',
          hint: '例: 浙江杭州 (用于真太阳时, 留空则按当地时间)',
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
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: const [], // 没有结构化牌; 关键数据在 extras
      extras: {
        'birthdate': inputs['birthdate'] ?? '',
        'birthtime': inputs['birthtime'] ?? '',
        'birthplace': inputs['birthplace'] ?? '',
        'gender': inputs['gender'] ?? '',
        'focus': variantName,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('请用子平八字给我做一次解读. (近似排盘, 节气与真太阳时如有偏差请说明)');
    buf.writeln();
    buf.writeln('出生日期: ${ex["birthdate"]}');
    if ((ex['birthtime'] as String).isNotEmpty) {
      buf.writeln('出生时辰: ${ex["birthtime"]}');
    } else {
      buf.writeln('出生时辰: 未知 (时柱不排)');
    }
    if ((ex['birthplace'] as String).isNotEmpty) {
      buf.writeln('出生地点: ${ex["birthplace"]}');
    }
    if ((ex['gender'] as String).isNotEmpty) {
      buf.writeln('性别: ${ex["gender"]}');
    }
    buf.writeln('关注方向: ${ex["focus"]}');
    buf.writeln();
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
      buf.writeln();
    }
    buf.writeln('请按规则排盘并解读, 必要时坦言精度限制.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '生辰 ${ex["birthdate"]} ${ex["birthtime"]} · 关注${ex["focus"]}';
  }
}
