// 西洋占星 (Western Astrology) - AI 近似版.
//
// 注意: 这不是精确的本命盘计算. 精确的本命盘需要瑞士星历表 (Swiss Ephemeris),
// 给出某时某地各行星的精确位置 (黄经、宫位、相位). 目前 Dart 生态的 sweph 绑定
// 还不够成熟可靠. 当前版本由 LLM 凭训练数据中的占星知识做近似排盘.

import 'divination.dart';

class AstrologyEngine extends DivinationEngine {
  @override String get id => 'astrology';
  @override String get nameZh => '西洋占星 (AI 近似)';
  @override String get nameEn => 'Astrology (AI-approx)';
  @override String get emoji => '🪐';
  @override String get tagline => '本命盘 · AI 排算';
  @override String get description =>
      '西方占星学以出生时刻的天空作为生命的"快照", 12 星座 × 12 宫位 × 行星位置 '
      '+ 相位构成本命盘. 当前版本由 LLM 近似排盘, 不保证黄经分秒级的精度. '
      '严肃的本命盘建议配合专业排盘软件 (如 astro.com 免费版).';

  @override int? get accentColorHex => 0xFF2E3A6E; // 深夜蓝

  @override
  bool get hasStandaloneResult => false; // 没有本地排盘, 完全靠 LLM

  @override
  String get systemPrompt =>
      '你是一位资深的西洋占星师, 既懂传统占星 (Hellenistic/Medieval), 也熟悉现代心理占星 '
      '(Jung/Greene/Hand). 风格深刻但克制.\n'
      '\n阅读规则:\n'
      '1. 用户会提供出生年月日时与出生城市. 请按现代西洋占星 (回归黄道, Placidus 宫位制) 近似排盘.\n'
      '2. 重点给出: 太阳/月亮/上升三大要素, 显著的行星宫位, 主要相位 (合相/对分/三分/四分).\n'
      '3. 若用户问的是具体方向 (事业 10 宫、感情 5/7 宫、家庭 4 宫等), 围绕该宫位与相关行星展开.\n'
      '4. 区分"本命"与"行运" (transits): 本命是底色, 行运是当下的天空压力. 用户如果问"最近", 简短提一下当下的关键行运.\n'
      '5. 如果出生时间精度不够 (没有到分钟), 主动说明上升与宫位可能偏移, 不要硬给.\n'
      '6. 不预测命定式的吉凶事件, 强调原型与选择.\n'
      '7. 必要时坦言: 你不是专业排盘软件, 行星具体度数仅供参考.\n'
      '8. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'natal_overview', name: '本命盘整体', description: '太阳/月亮/上升 + 主要行星宫位与相位概览.'),
        DivinationVariant(key: 'career',         name: '事业 (10 宫)', description: '聚焦 MC、10 宫、6 宫与工作相关行星.'),
        DivinationVariant(key: 'love',           name: '感情 (5/7 宫)', description: '聚焦金星、火星、5 宫与 7 宫相位.'),
        DivinationVariant(key: 'transit',        name: '近期行运', description: '本命底色 + 当下的关键行运压力.'),
      ];

  @override
  List<InputField> get inputs => const [
        InputField(
          key: 'birthdate',
          label: '公历出生日期',
          hint: 'YYYY-MM-DD',
          type: InputFieldType.date,
          required: true,
        ),
        InputField(
          key: 'birthtime',
          label: '出生时间',
          hint: 'HH:MM (越精确越好; 不知道时上升与宫位不可靠)',
          type: InputFieldType.text,
        ),
        InputField(
          key: 'birthplace',
          label: '出生城市',
          hint: '例: 上海, 中国 / Berlin, Germany',
          type: InputFieldType.location,
          required: true,
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
      items: const [],
      extras: {
        'birthdate': inputs['birthdate'] ?? '',
        'birthtime': inputs['birthtime'] ?? '',
        'birthplace': inputs['birthplace'] ?? '',
        'focus': variantName,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('请用西洋占星 (回归黄道, Placidus 宫位制) 给我做一次近似排盘.');
    buf.writeln();
    buf.writeln('出生日期: ${ex["birthdate"]}');
    if ((ex['birthtime'] as String).isNotEmpty) {
      buf.writeln('出生时间: ${ex["birthtime"]}');
    } else {
      buf.writeln('出生时间: 未知 (上升与宫位偏移可能较大)');
    }
    buf.writeln('出生城市: ${ex["birthplace"]}');
    buf.writeln('关注方向: ${ex["focus"]}');
    buf.writeln();
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
      buf.writeln();
    }
    buf.writeln('请按规则给出近似排盘与解读, 必要时坦言精度限制.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '本命 ${ex["birthdate"]} ${ex["birthtime"]} @ ${ex["birthplace"]} · ${ex["focus"]}';
  }
}
