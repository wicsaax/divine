// 梦境解析 (Oneiromancy / Dream Interpretation).
// 全 AI 引擎. 用户描述梦境, LLM 从心理学 + 神秘学 + 文化语境多角度解读.

import 'divination.dart';

class _DreamMode {
  final String key;
  final String name;
  final String description;
  final String style;
  const _DreamMode(this.key, this.name, this.description, this.style);
}

const List<_DreamMode> _dreamModes = [
  _DreamMode(
    'jungian',
    '荣格视角',
    '从集体无意识 + 阴影/原型 + 个体化过程解读',
    '强调梦中出现的人物/动物/场景作为"原型" (阴影、阿尼玛/阿尼姆斯、智慧老人、童年自我 等). '
    '梦境是潜意识与意识对话, 不要按字典式 1:1 解释符号; 关注梦的情绪基调和未完成的心理任务.',
  ),
  _DreamMode(
    'freudian',
    '弗洛伊德视角',
    '从欲望/压抑/童年/潜意识冲突解读',
    '梦是"愿望的伪装满足". 关注移置 (displacement)、凝缩 (condensation)、'
    '象征 (symbolization). 不必过度强调性, 但承认本能驱力的存在.',
  ),
  _DreamMode(
    'eastern',
    '东方文化视角 (周公解梦风)',
    '从中国传统解梦 + 易经五行 + 民俗经验解读',
    '参考周公解梦传统的符号词典, 但避免迷信吉凶, 用现代视角重新框架. '
    '可联系五行 (金木水火土) / 阴阳 / 季节给出能量解读.',
  ),
  _DreamMode(
    'spiritual',
    '灵性 / 玄学视角',
    '从灵魂功课 / 通灵讯息 / 高我提醒视角解读',
    '把梦看作灵魂或高我传递的讯息, 引述塔罗/星象/水晶等符号语言, '
    '但保持克制 — 不要妄称"预知未来". 关注情绪、能量、关系动力.',
  ),
  _DreamMode(
    'recurring',
    '反复出现的梦',
    '专门处理反复出现 / 多年困扰的梦',
    '反复梦境往往指向未化解的情结. 引导用户识别现实生活中对应的卡点, '
    '提供小的实践 (写日记 / 冥想 / 对话) 帮助消化.',
  ),
  _DreamMode(
    'nightmare',
    '噩梦 / 焦虑梦',
    '专门处理让人不安 / 醒来心悸的梦',
    '先做情绪正常化 (做噩梦是健康的减压机制), 再尝试解读. '
    '若梦境频繁 + 影响睡眠, 建议结合现实压力源处理.',
  ),
];

class DreamEngine extends DivinationEngine {
  @override String get id => 'dream';
  @override String get nameZh => '解梦';
  @override String get nameEn => 'Dream Interpretation';
  @override String get emoji => '💤';
  @override String get tagline => '心理学 + 神秘学 视角';
  @override String get description =>
      '梦境解析. 多视角支持: 荣格 / 弗洛伊德 / 东方周公解梦 / 灵性 / 反复梦 / 噩梦. '
      '在输入框描述你的梦 (场景 / 人物 / 情绪 / 印象最深的细节), 越具体越准.';

  @override int? get accentColorHex => 0xFF3A3A6E; // 夜蓝紫

  @override bool get hasStandaloneResult => false; // 必须 LLM 才能解读

  @override
  String get systemPrompt =>
      '你是一位精通梦境解析的咨询师, 兼具临床心理学 + 神话学 + 文化研究背景, '
      '同时承认梦境的神秘层面. \n'
      '\n阅读规则:\n'
      '1. 用户会描述一个梦, 你按所选视角解读.\n'
      '2. 先复述/确认梦的关键意象 (告诉用户你"听到了"什么), 再展开分析.\n'
      '3. 不要给"字典式"的 1:1 符号映射 (X = Y), 永远把符号放回梦的整体情境 + 用户的现实处境.\n'
      '4. 给出 2-3 个可能的解读方向, 让用户挑共鸣的, 不要替用户做唯一裁决.\n'
      '5. 不预测命定式未来. 强调梦是内在的镜子, 不是外在的预言.\n'
      '6. 必要时给"梦境工作"实践建议: 梦日记、对话/写信、积极想象、艺术表达等.\n'
      '7. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => _dreamModes
      .map((m) => DivinationVariant(
            key: m.key,
            name: m.name,
            description: m.description,
          ))
      .toList();

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final mode = _dreamModes.firstWhere((m) => m.key == variantKey);
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: mode.name,
      items: const [],
      extras: {'modeDescription': mode.description, 'style': mode.style},
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('解梦视角: ${result.variantName} —— ${ex["modeDescription"]}');
    buf.writeln('风格要求: ${ex["style"]}');
    buf.writeln();
    if (question.trim().isEmpty) {
      buf.writeln('用户没具体描述梦境. 请先问用户: 梦的关键场景? 谁出现了? 醒来时是什么情绪?');
    } else {
      buf.writeln('我的梦:');
      buf.writeln(question.trim());
      buf.writeln();
      buf.writeln('请按视角与规则解读.');
    }
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) => '视角: ${result.variantName}';
}
