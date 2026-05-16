// 通用 AI 占卜: 没有算法层, 完全交给 LLM 扮演占卜师.
//
// 用于覆盖一些"小众 / 未实现具体算法"的占卜法 (例如手相、面相、奇门遁甲、塔斯加图等),
// 以及那种"我就想问一下"的随手占.

import 'divination.dart';

class _GenericMode {
  final String key;
  final String name;
  final String description;
  final String systemPromptDelta; // 该模式专属的 system prompt 附加
  const _GenericMode(this.key, this.name, this.description, this.systemPromptDelta);
}

const List<_GenericMode> _modes = [
  _GenericMode(
    'oracle',
    '神谕回响',
    '不设具体方法, 让 AI 像一位经验丰富的占卜师那样直接回应你的问题.',
    '使用直觉式的整体回应, 不强行套用某种工具.',
  ),
  _GenericMode(
    'daily',
    '每日一签',
    '抽一段当日指引, 像签筒中抽出一签.',
    '风格如东方求签: 一首四句的偈语 + 一段白话解 + 一句行动建议. 偈语要押韵.',
  ),
  _GenericMode(
    'decision',
    '决策辅助',
    '帮你梳理一个待定决策, 给出多方视角与潜在盲点.',
    '从理性、情感、潜在风险、长期影响四个角度回应, 最后给一个综合建议. 不替用户做决定.',
  ),
  _GenericMode(
    'relation',
    '关系洞察',
    '看你与某人、某段关系的能量与下一步.',
    '聚焦关系动力: 你的视角、对方可能的视角、当下能量、可调整之处. 避免揣测具体事实.',
  ),
];

class GenericEngine extends DivinationEngine {
  @override String get id => 'oracle';
  @override String get nameZh => '通用 AI 占卜';
  @override String get nameEn => 'AI Oracle';
  @override String get emoji => '🔮';
  @override String get tagline => '无固定方法 · 直接对话';
  @override String get description =>
      '没有具体的算法或符号系统, 直接让 AI 作为占卜师与你对话. '
      '适合"随手一问"、不确定该用哪种方法、或想要一段当下的指引时使用.';

  @override
  String get systemPrompt =>
      '你是一位经验丰富、风格沉稳的占卜师, 兼具心理治疗师的同理与哲学家的克制.\n'
      '\n阅读规则:\n'
      '1. 直接回应用户的问题, 不强行套用某种工具或体系.\n'
      '2. 保持隐喻与诗意, 但不堆砌神秘词汇. 不使用 emoji.\n'
      '3. 不给命定式的吉凶, 不替用户做决定; 给方向、给视角、给可行动的选项.\n'
      '4. 如果用户问的是事实性问题 (例如"我考试能不能过"), 温和地把它转化为可探讨的层面.\n'
      '5. 用中文回答.';

  @override
  List<DivinationVariant> get variants => _modes
      .map((m) => DivinationVariant(
            key: m.key,
            name: m.name,
            description: m.description,
          ))
      .toList();

  @override
  int? get accentColorHex => 0xFF5E72A8; // 灰蓝

  @override
  bool get hasStandaloneResult => false; // 纯 AI 引擎, 没有结构化输出

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final mode = _modes.firstWhere((m) => m.key == variantKey,
        orElse: () => throw ArgumentError('unknown mode: $variantKey'));
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: mode.name,
      items: const [], // 没有结构化条目, 全部由 LLM 给出
      extras: {
        'modeDescription': mode.description,
        'systemPromptDelta': mode.systemPromptDelta,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final delta = ex['systemPromptDelta'] as String;
    final buf = StringBuffer();
    buf.writeln('占卜模式: ${result.variantName} —— ${ex["modeDescription"]}');
    buf.writeln('风格要求: $delta');
    buf.writeln();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(我没有特别想问的, 请给我当下的指引)" : question.trim()}');
    buf.writeln();
    buf.writeln('请按上述模式与风格给出回应, 之后我可能继续追问.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) => '模式: ${result.variantName}';
}
