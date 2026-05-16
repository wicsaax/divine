// 数字命理 (Pythagorean Numerology).
//
// 主流的西方数字命理系统, 由出生日期推算生命数 (Life Path Number).
// 算法: 把生日所有数字加总, 反复降为单数 (1-9), 但 11/22/33 是"大师数",
// 保留不降.
//
// 例: 1990-06-15
//   1+9+9+0+0+6+1+5 = 31 → 3+1 = 4
//   生命数 = 4

import 'divination.dart';

const Map<int, _NumberMeaning> _meanings = {
  1: _NumberMeaning('开创者', ['独立', '领导', '主动', '原创'], '开拓与自立的能量, 适合做先行者.'),
  2: _NumberMeaning('协作者', ['敏感', '合作', '调和', '直觉'], '在关系中实现自我, 擅长平衡与陪伴.'),
  3: _NumberMeaning('表达者', ['创造', '艺术', '社交', '欢愉'], '以表达为生命主题, 容易吸引关注.'),
  4: _NumberMeaning('建造者', ['秩序', '务实', '勤勉', '可靠'], '通过结构与坚持累积成果, 慢工出细活.'),
  5: _NumberMeaning('自由探索者', ['变化', '冒险', '感官', '沟通'], '不安于现状, 命中带有大量经历与转折.'),
  6: _NumberMeaning('滋养者', ['责任', '家庭', '美感', '服务'], '以照顾他人和创造美感为路径.'),
  7: _NumberMeaning('追寻者', ['内省', '智慧', '神秘', '研究'], '走向内在与本质的道路, 偏孤独但深刻.'),
  8: _NumberMeaning('掌权者', ['权力', '物质', '执行', '业力'], '在世俗事业上有强大显化力, 也面对相应业力.'),
  9: _NumberMeaning('人道者', ['博爱', '理想', '完结', '智慧'], '一个周期的完成者, 心怀更大的群体.'),
  11: _NumberMeaning('灵感导师', ['启示', '直觉', '高频', '使命'], '大师数 11. 高度的灵性敏感与启发力.'),
  22: _NumberMeaning('世界建造师', ['宏大', '务实', '显化', '架构'], '大师数 22. 把理想落地为大型现实工程.'),
  33: _NumberMeaning('大爱导师', ['慈悲', '疗愈', '奉献', '榜样'], '大师数 33. 极少出现, 是无私的服务者.'),
};

class _NumberMeaning {
  final String archetype;
  final List<String> keywords;
  final String description;
  const _NumberMeaning(this.archetype, this.keywords, this.description);
}

int _digitSum(int n) {
  var s = 0;
  while (n > 0) {
    s += n % 10;
    n ~/= 10;
  }
  return s;
}

int _reduce(int n) {
  while (n > 9 && n != 11 && n != 22 && n != 33) {
    n = _digitSum(n);
  }
  return n;
}

class NumerologyEngine extends DivinationEngine {
  @override String get id => 'numerology';
  @override String get nameZh => '数字命理';
  @override String get nameEn => 'Numerology';
  @override String get emoji => '🔢';
  @override String get tagline => '毕达哥拉斯传 · 生命数';
  @override String get description =>
      '源自古希腊毕达哥拉斯学派的数字命理. 用出生日期反复降数, '
      '得到 1-9 的"生命数"或 11/22/33 的"大师数", 揭示一生的主导能量与功课.';

  @override int? get accentColorHex => 0xFF3B7A57; // 数字绿

  @override
  String get systemPrompt =>
      '你是一位精通毕达哥拉斯数字命理的解读师, 兼具占星师的隐喻能力与心理咨询师的同理.\n'
      '\n阅读规则:\n'
      '1. 严格依据用户给出的生日所推算出的生命数, 不自创计算.\n'
      '2. 解读生命数的原型、长处、潜在阴影、典型功课.\n'
      '3. 联系用户的具体问题给出可落地的建议, 而不只是泛泛的特质描述.\n'
      '4. 适度使用数字命理术语 (生命数 / 大师数 / 业力数), 不晦涩.\n'
      '5. 不预测命定结果, 强调可塑性与选择.\n'
      '6. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(
          key: 'life_path',
          name: '生命数',
          description: '由公历出生年月日推算, 揭示一生的主导能量.',
        ),
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
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final raw = (inputs['birthdate'] ?? '').trim();
    if (raw.isEmpty) {
      throw ArgumentError('生日不能为空');
    }
    final m = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(raw);
    if (m == null) {
      throw ArgumentError('生日格式不对, 请用 YYYY-MM-DD');
    }
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) {
      throw ArgumentError('生日不合法');
    }
    final total = _digitSum(y) + _digitSum(mo) + _digitSum(d);
    final lifePath = _reduce(total);
    final meaning = _meanings[lifePath]!;

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: '生命数',
      items: [
        DivinationItem(
          position: '生命数',
          positionHint: '一生的主导能量与功课',
          name: '$lifePath ${meaning.archetype}',
          subtitle: meaning.description,
          keywords: meaning.keywords,
          extra: {'value': lifePath, 'rawTotal': total},
        ),
      ],
      extras: {
        'birthdate': raw,
        'sum': total,
        'lifePath': lifePath,
        'archetype': meaning.archetype,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请就生命数给出整体解读)" : question.trim()}');
    buf.writeln();
    buf.writeln('生日: ${ex["birthdate"]}');
    buf.writeln('降数过程: 各位相加得 ${ex["sum"]} → 最终生命数 ${ex["lifePath"]}');
    buf.writeln('对应原型: ${ex["archetype"]}');
    buf.writeln();
    buf.writeln('请解读这个生命数的核心能量、长处、容易遇到的阴影或功课, 并结合问题给出可落地的建议.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '生命数 ${ex["lifePath"]} · ${ex["archetype"]}';
  }
}
