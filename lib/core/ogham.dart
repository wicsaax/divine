// Ogham (爱尔兰树文字) 占卜.
//
// 古爱尔兰凯尔特字母系统, 主要由 20 个字母 + 5 个 forfeda (后期增补) 构成.
// 每个字母对应一种树或植物, 在德鲁伊传统中被用作占卜符号.

import 'dart:math';
import 'divination.dart';

class _Ogham {
  final String glyph;
  final String nameOld;
  final String nameZh;
  final String tree;
  final List<String> meaning;
  const _Ogham(this.glyph, this.nameOld, this.nameZh, this.tree, this.meaning);
}

const List<_Ogham> _oghamStaves = [
  // 20 主要字母 (the four aicme)
  _Ogham('ᚁ', 'Beith',   '贝',     '桦树',   ['新开始', '净化', '初萌']),
  _Ogham('ᚂ', 'Luis',    '路斯',   '花楸',   ['保护', '直觉', '抵御负能']),
  _Ogham('ᚃ', 'Fearn',   '法恩',   '桤木',   ['指引', '基础', '坚实根基']),
  _Ogham('ᚄ', 'Sail',    '塞尔',   '柳树',   ['女性力量', '潜意识', '流动']),
  _Ogham('ᚅ', 'Nion',    '尼恩',   '梣树',   ['连接', '世界树', '内外整合']),
  _Ogham('ᚆ', 'Uath',    '乌阿斯', '山楂',   ['考验', '阈限', '边界']),
  _Ogham('ᚇ', 'Dair',    '达尔',   '橡树',   ['力量', '稳固', '王者之木']),
  _Ogham('ᚈ', 'Tinne',   '廷内',   '冬青',   ['平衡', '战士的火', '正义之争']),
  _Ogham('ᚉ', 'Coll',    '科尔',   '榛树',   ['智慧', '灵感', '诗意']),
  _Ogham('ᚊ', 'Ceirt',   '凯尔特', '苹果树', ['选择', '完美', '隐藏的果实']),
  _Ogham('ᚋ', 'Muin',    '穆因',   '葡萄藤', ['启示', '内观', '醉与醒']),
  _Ogham('ᚌ', 'Gort',    '高尔特', '常春藤', ['探索', '螺旋成长', '缠绕']),
  _Ogham('ᚍ', 'Ngetal',  '恩盖塔尔','芦苇',   ['疗愈', '直射如箭', '坚毅']),
  _Ogham('ᚎ', 'Straif',  '斯特赖夫','黑刺李', ['命运转折', '强制变化', '严峻']),
  _Ogham('ᚏ', 'Ruis',    '鲁伊斯', '接骨木', ['完结', '蜕变', '终末与新生']),
  _Ogham('ᚐ', 'Ailm',    '艾尔姆', '银冷杉', ['远见', '高处的视野', '开阔']),
  _Ogham('ᚑ', 'Onn',     '昂',     '荆豆',   ['内在的火', '集中能量', '热望']),
  _Ogham('ᚒ', 'Ur',      '乌尔',   '石南',   ['大地', '土壤滋养', '安住']),
  _Ogham('ᚓ', 'Eadhadh', '埃达',   '白杨',   ['震颤', '感知微妙', '恐惧的克服']),
  _Ogham('ᚔ', 'Iodhadh', '约达',   '紫杉',   ['传承', '死亡与永恒', '世代连接']),
  // 5 forfeda (后期增补, 部分版本不用)
  _Ogham('ᚕ', 'Eabhadh', '埃巴',   '白杨变体',['过渡', '两栖', '陆水之间']),
  _Ogham('ᚖ', 'Or',      '欧',     '金雀花', ['财富', '繁茂的能量', '光辉']),
  _Ogham('ᚗ', 'Uilleann','维兰',   '忍冬',   ['弯曲', '关节', '柔韧的力量']),
  _Ogham('ᚘ', 'Ifin',    '伊芬',   '醋栗',   ['酸甜共存', '复杂滋味', '矛盾的真']),
  _Ogham('ᚙ', 'Eamhancholl','埃班姆','双榛',   ['知识的双面', '深度学习', '回响']),
];

class _OghamSpread {
  final String key;
  final String name;
  final String description;
  final List<List<String>> positions;
  const _OghamSpread(this.key, this.name, this.description, this.positions);
}

const List<_OghamSpread> _oghamSpreads = [
  _OghamSpread('single', '单符指引', '抽 1 根 Ogham 木枝.', [
    ['指引', '当下的核心讯息'],
  ]),
  _OghamSpread('three', '三世三符', '过去-现在-未来 3 根.', [
    ['过去', '已成的力量'],
    ['现在', '当下的张力'],
    ['未来', '若沿此走的方向'],
  ]),
];

class OghamEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'ogham';
  @override String get nameZh => 'Ogham 树文';
  @override String get nameEn => 'Ogham';
  @override String get emoji => '🌳';
  @override String get tagline => '凯尔特德鲁伊 · 木枝占';
  @override String get description =>
      '古爱尔兰德鲁伊传统的占卜系统, 25 根 (20 主 + 5 增补) 刻有 Ogham 文字的木枝, '
      '每根对应一种树木. 抛掷或抽取以获取自然界的回应.';

  @override int? get accentColorHex => 0xFF4F7942; // 林木绿

  @override
  String get systemPrompt =>
      '你是一位精通凯尔特德鲁伊传统的占卜师, 熟悉 Ogham 字母对应的树木原型与神话.\n'
      '\n阅读规则:\n'
      '1. 严格依据用户给出的木枝, 不要凭空增减.\n'
      '2. 解读时可以引述对应树木的自然特性与凯尔特神话语义, 但不堆砌专有名词.\n'
      '3. 联系用户问题给出可落地的方向, 强调与自然节律的呼应.\n'
      '4. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => _oghamSpreads
      .map((s) => DivinationVariant(
            key: s.key,
            name: '${s.name}  (${s.positions.length} 根)',
            description: s.description,
          ))
      .toList();

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final spread = _spreadOrThrow(variantKey);
    final n = spread.positions.length;
    final pool = List<_Ogham>.from(_oghamStaves)..shuffle(_rng);
    return _buildResult(variantKey, spread,
        [for (var i = 0; i < n; i++) _buildItem(spread.positions[i], pool[i])]);
  }

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    final spread = _spreadOrThrow(variantKey);
    final staveOptions = _oghamStaves
        .map((o) => ManualFieldOption(
              key: o.nameOld,
              label: '${o.glyph}  ${o.nameZh}',
              subtitle: '${o.nameOld} · ${o.tree}',
            ))
        .toList();
    return [
      for (var i = 0; i < spread.positions.length; i++)
        ManualField(
          key: 'stave_$i',
          label: '木枝',
          hint: spread.positions[i][1],
          kind: ManualFieldKind.picker,
          options: staveOptions,
          group: '位置 ${i + 1}: ${spread.positions[i][0]}',
        ),
    ];
  }

  @override
  DivinationResult performManual({
    required String variantKey,
    required Map<String, String> selections,
  }) {
    final spread = _spreadOrThrow(variantKey);
    final byName = {for (final o in _oghamStaves) o.nameOld: o};
    final items = <DivinationItem>[];
    for (var i = 0; i < spread.positions.length; i++) {
      final name = selections['stave_$i'];
      final stave = name == null ? null : byName[name];
      if (stave == null) throw ArgumentError('位置 ${i + 1} 还没选木枝');
      items.add(_buildItem(spread.positions[i], stave));
    }
    return _buildResult(variantKey, spread, items);
  }

  _OghamSpread _spreadOrThrow(String variantKey) =>
      _oghamSpreads.firstWhere((s) => s.key == variantKey,
          orElse: () =>
              throw ArgumentError('unknown ogham spread: $variantKey'));

  DivinationItem _buildItem(List<String> pos, _Ogham o) {
    return DivinationItem(
      position: pos[0],
      positionHint: pos[1],
      name: '${o.glyph}  ${o.nameZh}',
      subtitle: '${o.nameOld} · ${o.tree}',
      keywords: o.meaning,
      extra: {'glyph': o.glyph, 'tree': o.tree, 'oldName': o.nameOld},
    );
  }

  DivinationResult _buildResult(
      String variantKey, _OghamSpread spread, List<DivinationItem> items) {
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: spread.name,
      items: items,
      extras: {'spreadDescription': spread.description},
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请基于木枝给出整体讯息)" : question.trim()}');
    buf.writeln();
    buf.writeln('使用的阵列: ${result.variantName} —— ${result.extras["spreadDescription"]}');
    buf.writeln();
    buf.writeln('抽到的木枝:');
    for (var i = 0; i < result.items.length; i++) {
      final it = result.items[i];
      buf.writeln('${i + 1}. 位置「${it.position}」(${it.positionHint})');
      buf.writeln('   ${it.name}  ·  ${it.subtitle}  ·  关键词: ${it.keywords.join(" / ")}');
    }
    buf.writeln();
    buf.writeln('请逐根解读, 再给出整体观察与建议.');
    return buf.toString();
  }
}
