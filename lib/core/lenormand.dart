// 雷诺曼 (Lenormand) 36 张牌.
//
// 19 世纪德法占卜系统, 名字来自玛丽·雷诺曼 (Marie Anne Lenormand).
// 与塔罗不同: 没有正逆位, 牌意更具象, 重在"组合"——前后牌一起读.

import 'dart:math';
import 'divination.dart';

class _LenCard {
  final int number;
  final String nameZh;
  final String nameEn;
  final List<String> keywords;
  const _LenCard(this.number, this.nameZh, this.nameEn, this.keywords);
}

const List<_LenCard> _lenormandDeck = [
  _LenCard(1,  '骑士',      'Rider',     ['消息', '到来', '快讯']),
  _LenCard(2,  '三叶草',    'Clover',    ['小幸运', '短暂喜悦', '机会']),
  _LenCard(3,  '船',        'Ship',      ['旅行', '远行', '商业往来']),
  _LenCard(4,  '房子',      'House',     ['家庭', '稳定', '所属']),
  _LenCard(5,  '树',        'Tree',      ['健康', '生命力', '根基']),
  _LenCard(6,  '云',        'Clouds',    ['困惑', '阴霾', '不明朗']),
  _LenCard(7,  '蛇',        'Snake',     ['女性敌手', '复杂', '蜿蜒']),
  _LenCard(8,  '棺木',      'Coffin',    ['结束', '休止', '深度转变']),
  _LenCard(9,  '花束',      'Bouquet',   ['礼物', '欣赏', '美好邀约']),
  _LenCard(10, '镰刀',      'Scythe',    ['突然切断', '果断', '锋利之事']),
  _LenCard(11, '鞭子',      'Whip',      ['冲突', '反复', '争论']),
  _LenCard(12, '鸟',        'Birds',     ['闲谈', '焦虑', '小事繁多']),
  _LenCard(13, '小孩',      'Child',     ['新开始', '天真', '小型']),
  _LenCard(14, '狐狸',      'Fox',       ['狡黠', '工作', '提防']),
  _LenCard(15, '熊',        'Bear',      ['权威', '财富', '保护者']),
  _LenCard(16, '繁星',      'Stars',     ['希望', '愿景', '清明']),
  _LenCard(17, '鹳',        'Stork',     ['迁徙', '变化', '更替']),
  _LenCard(18, '狗',        'Dog',       ['朋友', '忠诚', '陪伴']),
  _LenCard(19, '高塔',      'Tower',     ['机构', '孤独', '权力结构']),
  _LenCard(20, '公园',      'Garden',    ['社群', '公开场合', '社交']),
  _LenCard(21, '山',        'Mountain',  ['阻碍', '延误', '难度']),
  _LenCard(22, '十字路口',  'Crossroad', ['选择', '分岔', '决定']),
  _LenCard(23, '鼠',        'Mice',      ['损耗', '焦虑', '蚕食']),
  _LenCard(24, '心',        'Heart',     ['爱', '情感', '同情']),
  _LenCard(25, '戒指',      'Ring',      ['承诺', '契约', '循环']),
  _LenCard(26, '书',        'Book',      ['秘密', '学习', '未公开之事']),
  _LenCard(27, '信',        'Letter',    ['书面消息', '通讯', '文件']),
  _LenCard(28, '男士',      'Gentleman', ['询问者本人(男)', '关键男性']),
  _LenCard(29, '女士',      'Lady',      ['询问者本人(女)', '关键女性']),
  _LenCard(30, '百合',      'Lily',      ['和谐', '成熟', '家族']),
  _LenCard(31, '太阳',      'Sun',       ['成功', '光明', '能量']),
  _LenCard(32, '月亮',      'Moon',      ['情绪', '声誉', '潜意识']),
  _LenCard(33, '钥匙',      'Key',       ['答案', '打开', '关键']),
  _LenCard(34, '鱼',        'Fish',      ['财富', '丰盛', '流动资金']),
  _LenCard(35, '锚',        'Anchor',    ['稳固', '长期', '工作']),
  _LenCard(36, '十字架',    'Cross',     ['承担', '信仰', '宿命']),
];

class _LenSpread {
  final String key;
  final String name;
  final String description;
  final List<List<String>> positions;
  const _LenSpread(this.key, this.name, this.description, this.positions);
}

const List<_LenSpread> _lenSpreads = [
  _LenSpread('three', '三牌线', '3 张牌横排, 左中右递进, 形成一句"占辞".', [
    ['左 (因/前奏)', '事情的起因或背景'],
    ['中 (核心)', '当前主旨'],
    ['右 (果/方向)', '走向或结果'],
  ]),
  _LenSpread('nine', '九宫格', '3x3 共 9 张, 中央是核心, 周围八张提供上下文.', [
    ['左上', '过去能量'],
    ['上', '当下显化'],
    ['右上', '前方可能'],
    ['左', '内在动机'],
    ['核心', '关键议题'],
    ['右', '外在阻力'],
    ['左下', '潜在阴影'],
    ['下', '即将沉淀'],
    ['右下', '长期结果'],
  ]),
];

class LenormandEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'lenormand';
  @override String get nameZh => '雷诺曼';
  @override String get nameEn => 'Lenormand';
  @override String get emoji => '🎴';
  @override String get tagline => '19 世纪德法系 · 36 张';
  @override String get description =>
      '玛丽·雷诺曼传下的占卜系统, 36 张牌图案具象 (骑士、船、心、钥匙等), '
      '没有正逆位, 重点在"前后牌组合阅读". 适合具体生活议题的快速洞察.';

  @override int? get accentColorHex => 0xFFB8860B; // 暗金

  @override
  String get systemPrompt =>
      '你是一位精通雷诺曼系统的占卜师, 风格朴实、直接, 像 19 世纪德法占卜传统那样不空泛.\n'
      '\n阅读规则:\n'
      '1. 严格依照用户给出的牌. 雷诺曼牌没有正逆位.\n'
      '2. 解读"组合关系": 相邻牌的组合往往构成一句话或一个意象, 不要孤立逐张翻译.\n'
      '3. 三牌线读为一句话; 九宫格以中央牌为锚, 解读其周围的修饰.\n'
      '4. 联系具体问题, 给出可落地的判断或行动方向.\n'
      '5. 不预测命定结果, 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => _lenSpreads
      .map((s) => DivinationVariant(
            key: s.key,
            name: '${s.name}  (${s.positions.length} 张)',
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
    final deck = List<_LenCard>.from(_lenormandDeck)..shuffle(_rng);
    return _buildResult(variantKey, spread,
        [for (var i = 0; i < n; i++) _buildItem(spread.positions[i], deck[i])]);
  }

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    final spread = _spreadOrThrow(variantKey);
    final cardOptions = _lenormandDeck
        .map((c) => ManualFieldOption(
              key: c.number.toString(),
              label: '${c.number}. ${c.nameZh}',
              subtitle: c.nameEn,
            ))
        .toList();
    return [
      for (var i = 0; i < spread.positions.length; i++)
        ManualField(
          key: 'card_$i',
          label: '牌',
          hint: spread.positions[i][1],
          kind: ManualFieldKind.picker,
          options: cardOptions,
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
    final byNumber = {for (final c in _lenormandDeck) c.number: c};
    final items = <DivinationItem>[];
    for (var i = 0; i < spread.positions.length; i++) {
      final raw = selections['card_$i'];
      final num = int.tryParse(raw ?? '');
      final card = num == null ? null : byNumber[num];
      if (card == null) throw ArgumentError('位置 ${i + 1} 还没选牌');
      items.add(_buildItem(spread.positions[i], card));
    }
    return _buildResult(variantKey, spread, items);
  }

  _LenSpread _spreadOrThrow(String variantKey) =>
      _lenSpreads.firstWhere((s) => s.key == variantKey,
          orElse: () => throw ArgumentError('unknown spread: $variantKey'));

  DivinationItem _buildItem(List<String> pos, _LenCard card) {
    return DivinationItem(
      position: pos[0],
      positionHint: pos[1],
      name: '${card.number}. ${card.nameZh}',
      subtitle: card.nameEn,
      keywords: card.keywords,
      extra: {'number': card.number},
    );
  }

  DivinationResult _buildResult(
      String variantKey, _LenSpread spread, List<DivinationItem> items) {
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
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请就当前能量给出整体解读)" : question.trim()}');
    buf.writeln();
    buf.writeln('使用的阵列: ${result.variantName} —— ${result.extras["spreadDescription"]}');
    buf.writeln();
    buf.writeln('抽到的牌:');
    for (var i = 0; i < result.items.length; i++) {
      final it = result.items[i];
      buf.writeln('${i + 1}. 位置「${it.position}」(${it.positionHint})');
      buf.writeln('   ${it.name}  /  ${it.subtitle}  ·  关键词: ${it.keywords.join(" / ")}');
    }
    buf.writeln();
    buf.writeln('请按雷诺曼"组合阅读"的方式解读, 别孤立翻译每张牌.');
    return buf.toString();
  }
}
