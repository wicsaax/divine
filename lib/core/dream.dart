// 梦境解析 (Oneiromancy / Dream Interpretation).
//
// 两种模式:
//   1. 周公解梦 (传统查典) — 不需要 LLM, 内置 60+ 经典词条字典.
//      用户描述梦境, app 扫关键词, 列出"周公"传统释义.
//   2. AI 视角 (荣格 / 弗洛伊德 / 东方 / 灵性 / 反复 / 噩梦) — LLM 多角度解读.
//
// 两种可独立用. 字典模式即使没配 LLM 也有完整输出.

import 'divination.dart';
import 'dream_dict.dart';

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

  /// 周公字典模式有结构化输出, 其他 AI 模式无 — 用 result.items 是否为空区分.
  /// 这里返回 true 让主屏不拦截 (字典模式即使没 LLM 也能用).
  @override bool get hasStandaloneResult => true;

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
  List<DivinationVariant> get variants => [
        const DivinationVariant(
          key: 'zhou_classic',
          name: '周公解梦 (传统查典)',
          description: '查内置周公解梦词典, 无需 AI 也能用. 想叠加 AI 解读再点"让 AI 解读".',
        ),
        ..._dreamModes.map((m) => DivinationVariant(
              key: m.key,
              name: m.name,
              description: m.description,
            )),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    if (variantKey == 'zhou_classic') {
      // 字典模式: 扫用户的"问题" (即梦境描述), 命中的关键词作为 items.
      final dreamText = inputs['question'] ?? '';
      final items = scanZhouGongDict(dreamText);
      return DivinationResult(
        engineId: id,
        engineName: nameZh,
        variantKey: variantKey,
        variantName: '周公解梦 (传统查典)',
        items: items,
        extras: {
          'mode': 'zhou',
          'modeDescription': '查典',
          'hits': items.length,
          'dreamText': dreamText,
        },
      );
    }
    final mode = _dreamModes.firstWhere((m) => m.key == variantKey);
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: mode.name,
      items: const [],
      extras: {'mode': 'ai', 'modeDescription': mode.description, 'style': mode.style},
    );
  }

  /// 字典模式: 给定梦境描述, 扫词典, 返回 DivinationItems.
  /// 不在 perform 里, 是因为 perform 拿不到用户文本; 这个方法外部 (reading_screen)
  /// 拿到用户的"问题"(实际是梦境)后调用.
  static List<DivinationItem> scanZhouGongDict(String dreamText) {
    final entries = matchEntries(dreamText);
    return entries
        .map((e) => DivinationItem(
              position: e.symbol,
              positionHint: '周公解梦传统释义',
              name: e.symbol,
              subtitle: '《周公解梦》',
              keywords: [e.meaning],
            ))
        .toList();
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final mode = ex['mode'] as String;
    final buf = StringBuffer();
    if (mode == 'zhou') {
      // 字典模式也允许调 LLM 做"周公传统说法 + 现代心理"综合, 但默认不调.
      buf.writeln('用户用了"周公解梦"传统字典模式, 在我们的字典里命中了以下条目.');
      buf.writeln('请你结合这些传统释义 + 现代心理学视角综合解读, 不要简单复述字典.');
      buf.writeln();
      final hits = scanZhouGongDict(question);
      if (hits.isEmpty) {
        buf.writeln('(字典里没匹配到关键词, 请你自由发挥用周公解梦传统风格 + 现代视角解读)');
      } else {
        buf.writeln('字典命中:');
        for (final it in hits) {
          buf.writeln('  ${it.position}: ${it.keywords.first}');
        }
      }
      buf.writeln();
      buf.writeln('用户的梦:');
      buf.writeln(question.trim().isEmpty ? '(用户没描述)' : question.trim());
      return buf.toString();
    }
    // AI 视角模式
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
  String summarize(DivinationResult result) => '模式: ${result.variantName}';
}
