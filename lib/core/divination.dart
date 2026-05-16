// 占卜引擎抽象层. 每种占卜法 (塔罗/卢恩/六爻/...) 实现这个接口,
// 然后在 main.dart 里 register 一次, UI 自动识别.

import 'dart:convert';

/// 单次占卜结果中的一个条目 (一张牌, 一个符文, 一个爻, 等).
class DivinationItem {
  final String position; // 牌阵中的位置名, 或卦中的爻位编号
  final String positionHint; // 位置的含义
  final String name; // 名字: 牌名/符文名/卦名
  final String? subtitle; // 副标题: 英文名/拼音等
  final String orientation; // 正位/逆位, 阳/阴, etc. 没有则填空串
  final List<String> keywords;
  final Map<String, dynamic> extra; // 引擎自定义字段

  const DivinationItem({
    required this.position,
    required this.positionHint,
    required this.name,
    this.subtitle,
    this.orientation = '',
    this.keywords = const [],
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'position': position,
        'positionHint': positionHint,
        'name': name,
        'subtitle': subtitle,
        'orientation': orientation,
        'keywords': keywords,
        'extra': extra,
      };

  factory DivinationItem.fromJson(Map<String, dynamic> j) => DivinationItem(
        position: j['position'] as String,
        positionHint: j['positionHint'] as String,
        name: j['name'] as String,
        subtitle: j['subtitle'] as String?,
        orientation: (j['orientation'] as String?) ?? '',
        keywords: ((j['keywords'] as List?) ?? const []).cast<String>(),
        extra: ((j['extra'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

/// 占卜法的"变体". 例如塔罗的不同牌阵, 六爻的不同起卦方式.
class DivinationVariant {
  final String key;
  final String name;
  final String description;
  const DivinationVariant({
    required this.key,
    required this.name,
    required this.description,
  });
}

/// 输入字段类型.
enum InputFieldType { text, date, datetime, location, number }

/// 某些占卜法需要的结构化输入 (例如八字需要生辰).
class InputField {
  final String key;
  final String label;
  final String? hint;
  final InputFieldType type;
  final bool required;
  const InputField({
    required this.key,
    required this.label,
    this.hint,
    this.type = InputFieldType.text,
    this.required = false,
  });
}

/// 一次完整占卜的结构化结果. 不含 LLM 解读.
class DivinationResult {
  final String engineId;
  final String engineName;
  final String variantKey;
  final String variantName;
  final List<DivinationItem> items;
  final Map<String, dynamic> extras;
  final DateTime drawnAt;

  DivinationResult({
    required this.engineId,
    required this.engineName,
    required this.variantKey,
    required this.variantName,
    required this.items,
    this.extras = const {},
    DateTime? drawnAt,
  }) : drawnAt = drawnAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'engineId': engineId,
        'engineName': engineName,
        'variantKey': variantKey,
        'variantName': variantName,
        'items': items.map((e) => e.toJson()).toList(),
        'extras': extras,
        'drawnAt': drawnAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory DivinationResult.fromJson(Map<String, dynamic> j) => DivinationResult(
        engineId: j['engineId'] as String,
        engineName: j['engineName'] as String,
        variantKey: j['variantKey'] as String,
        variantName: j['variantName'] as String,
        items: (j['items'] as List)
            .map((e) => DivinationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        extras: ((j['extras'] as Map?) ?? const {}).cast<String, dynamic>(),
        drawnAt: DateTime.parse(j['drawnAt'] as String),
      );
}

/// 占卜引擎抽象类.
abstract class DivinationEngine {
  String get id;
  String get nameZh;
  String get nameEn;
  String get emoji; // 入口卡片上的图标
  String get tagline; // 卡片副标题, 一行话
  String get description; // 详细介绍, 用于"开始前"页面
  String get systemPrompt; // 该占卜法专用的 LLM 系统提示

  /// 该占卜法用于渲染卡片配色的强调色 (16 进制).
  /// 比如塔罗用紫, 六爻用青, 占星用深蓝. 默认 null = 走主题色.
  int? get accentColorHex => null;

  /// 该占卜法的所有变体. 至少要有一个.
  List<DivinationVariant> get variants;

  /// 默认变体的 key, 一般是第一个.
  String get defaultVariantKey => variants.first.key;

  /// 该占卜法在执行前需要用户提供的结构化字段 (例如八字需要出生年月日时).
  /// 默认空, 表示无需结构化输入.
  List<InputField> get inputs => const [];

  /// 执行一次占卜.
  /// [variantKey] 是变体 key, [inputs] 是结构化字段值 (字符串).
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  });

  /// 把结果渲染成给 LLM 的 user message.
  String buildUserPrompt({
    required String question,
    required DivinationResult result,
  });

  /// 把结果渲染成给人看的简短摘要 (UI 列表/历史用).
  String summarize(DivinationResult result) {
    if (result.items.isEmpty) return result.variantName;
    return result.items.map((e) {
      final ori = e.orientation.isNotEmpty ? ' (${e.orientation})' : '';
      return '${e.position}: ${e.name}$ori';
    }).join('  ·  ');
  }
}

/// 引擎注册表. 全局单例式注册, 简单够用.
class DivinationRegistry {
  static final Map<String, DivinationEngine> _engines = {};
  static final List<DivinationEngine> _ordered = [];

  static void register(DivinationEngine engine) {
    if (_engines.containsKey(engine.id)) return;
    _engines[engine.id] = engine;
    _ordered.add(engine);
  }

  static DivinationEngine? get(String id) => _engines[id];

  static List<DivinationEngine> all() => List.unmodifiable(_ordered);
}
