// 塔罗占卜引擎. 韦特体系 78 张牌.
//
// 数据格式: List<TarotCard>, 全局 id 0-77.
// 算法: 用 dart:math 的 Random.secure() 洗牌 (操作系统 CSPRNG).

import 'dart:math';

import 'divination.dart';

class TarotCard {
  final String nameZh;
  final String nameEn;
  final String suit; // major | wands | cups | swords | pentacles
  final String number; // 0..XXI, A, 2..10, Page, Knight, Queen, King
  final String? element; // 火/水/风/土, major 为 null
  final List<String> upright;
  final List<String> reversed;
  const TarotCard({
    required this.nameZh,
    required this.nameEn,
    required this.suit,
    required this.number,
    this.element,
    required this.upright,
    required this.reversed,
  });
}

const List<TarotCard> _majorArcana = [
  TarotCard(nameZh: '愚者',     nameEn: 'The Fool',           suit: 'major', number: '0',    upright: ['新开始','冒险','纯真','自由'], reversed: ['鲁莽','犹豫','未做准备']),
  TarotCard(nameZh: '魔术师',   nameEn: 'The Magician',       suit: 'major', number: 'I',    upright: ['行动力','技能','意志','显化'], reversed: ['操纵','潜能未发挥','欺骗']),
  TarotCard(nameZh: '女祭司',   nameEn: 'The High Priestess', suit: 'major', number: 'II',   upright: ['直觉','潜意识','神秘','内在智慧'], reversed: ['秘密','压抑','忽视直觉']),
  TarotCard(nameZh: '皇后',     nameEn: 'The Empress',        suit: 'major', number: 'III',  upright: ['丰饶','母性','创造','滋养'], reversed: ['依赖','过度保护','创意阻塞']),
  TarotCard(nameZh: '皇帝',     nameEn: 'The Emperor',        suit: 'major', number: 'IV',   upright: ['权威','秩序','结构','父性'], reversed: ['专制','僵化','失控']),
  TarotCard(nameZh: '教皇',     nameEn: 'The Hierophant',     suit: 'major', number: 'V',    upright: ['传统','教导','信仰','体制'], reversed: ['反叛','自由思考','打破常规']),
  TarotCard(nameZh: '恋人',     nameEn: 'The Lovers',         suit: 'major', number: 'VI',   upright: ['关系','选择','和谐','价值观一致'], reversed: ['失衡','错位','错误选择']),
  TarotCard(nameZh: '战车',     nameEn: 'The Chariot',        suit: 'major', number: 'VII',  upright: ['胜利','意志','前进','掌控'], reversed: ['失控','方向不明','受阻']),
  TarotCard(nameZh: '力量',     nameEn: 'Strength',           suit: 'major', number: 'VIII', upright: ['勇气','内在力量','耐心','温柔的力量'], reversed: ['自我怀疑','软弱','失去信心']),
  TarotCard(nameZh: '隐士',     nameEn: 'The Hermit',         suit: 'major', number: 'IX',   upright: ['内省','孤独','智慧','向内寻求'], reversed: ['孤立','迷失','拒绝指引']),
  TarotCard(nameZh: '命运之轮', nameEn: 'Wheel of Fortune',   suit: 'major', number: 'X',    upright: ['变化','循环','机遇','命运转折'], reversed: ['厄运','抗拒变化','循环停滞']),
  TarotCard(nameZh: '正义',     nameEn: 'Justice',            suit: 'major', number: 'XI',   upright: ['公正','真理','因果','决断'], reversed: ['不公','逃避责任','偏见']),
  TarotCard(nameZh: '倒吊人',   nameEn: 'The Hanged Man',     suit: 'major', number: 'XII',  upright: ['暂停','牺牲','新视角','放手'], reversed: ['拖延','抗拒','无谓牺牲']),
  TarotCard(nameZh: '死神',     nameEn: 'Death',              suit: 'major', number: 'XIII', upright: ['结束','转变','重生','释放'], reversed: ['抗拒变化','停滞','无法放手']),
  TarotCard(nameZh: '节制',     nameEn: 'Temperance',         suit: 'major', number: 'XIV',  upright: ['平衡','调和','耐心','中道'], reversed: ['失衡','极端','不耐烦']),
  TarotCard(nameZh: '恶魔',     nameEn: 'The Devil',          suit: 'major', number: 'XV',   upright: ['束缚','欲望','依附','阴影'], reversed: ['解脱','觉醒','打破依附']),
  TarotCard(nameZh: '高塔',     nameEn: 'The Tower',          suit: 'major', number: 'XVI',  upright: ['突变','崩塌','启示','真相揭露'], reversed: ['避免灾难','抗拒变化','渐变']),
  TarotCard(nameZh: '星星',     nameEn: 'The Star',           suit: 'major', number: 'XVII', upright: ['希望','灵感','平静','信念'], reversed: ['绝望','失去信心','幻灭']),
  TarotCard(nameZh: '月亮',     nameEn: 'The Moon',           suit: 'major', number: 'XVIII',upright: ['幻觉','潜意识','恐惧','迷雾'], reversed: ['真相浮现','释放恐惧','清晰']),
  TarotCard(nameZh: '太阳',     nameEn: 'The Sun',            suit: 'major', number: 'XIX',  upright: ['喜悦','成功','活力','光明'], reversed: ['暂时阴影','缺乏自信','延迟']),
  TarotCard(nameZh: '审判',     nameEn: 'Judgement',          suit: 'major', number: 'XX',   upright: ['觉醒','召唤','重生','宽恕'], reversed: ['自我怀疑','拒绝召唤','未完成']),
  TarotCard(nameZh: '世界',     nameEn: 'The World',          suit: 'major', number: 'XXI',  upright: ['完成','圆满','成就','整合'], reversed: ['未完成','停滞','差最后一步']),
];

class _MinorSpec {
  final String num;
  final String partZh;
  final String partEn;
  final List<String> up;
  final List<String> rv;
  const _MinorSpec(this.num, this.partZh, this.partEn, this.up, this.rv);
}

const List<_MinorSpec> _wandsSpec = [
  _MinorSpec('A',      '一',   'Ace',    ['灵感','新机会','创造的火花'],     ['延迟','缺乏方向','热情消退']),
  _MinorSpec('2',      '二',   'Two',    ['计划','前瞻','选择道路'],         ['恐惧未知','缺乏规划','犹豫']),
  _MinorSpec('3',      '三',   'Three',  ['扩展','远见','等待机会到来'],     ['障碍','延误','短视']),
  _MinorSpec('4',      '四',   'Four',   ['庆祝','和谐','家的归属'],         ['不稳定','归属感缺失','小冲突']),
  _MinorSpec('5',      '五',   'Five',   ['竞争','冲突','意见分歧'],         ['和解','避免冲突','内在矛盾']),
  _MinorSpec('6',      '六',   'Six',    ['胜利','认可','公开成就'],         ['失败','自负','认可未到']),
  _MinorSpec('7',      '七',   'Seven',  ['防卫','挑战','捍卫立场'],         ['妥协','被压倒','放弃']),
  _MinorSpec('8',      '八',   'Eight',  ['迅速行动','消息','进展加速'],     ['延迟','停滞','信息混乱']),
  _MinorSpec('9',      '九',   'Nine',   ['韧性','坚持','最后一关'],         ['偏执','疲惫','防御过度']),
  _MinorSpec('10',     '十',   'Ten',    ['负担','责任','压力'],             ['释放压力','卸下负担','委派']),
  _MinorSpec('Page',   '侍从', 'Page',   ['探索','热情','新鲜想法'],         ['缺乏方向','拖延','坏消息']),
  _MinorSpec('Knight', '骑士', 'Knight', ['冒险','行动','热血'],             ['鲁莽','冲动','延迟']),
  _MinorSpec('Queen',  '王后', 'Queen',  ['自信','热情','领导力'],           ['嫉妒','情绪化','依赖']),
  _MinorSpec('King',   '国王', 'King',   ['远见','领导','激情驱动'],         ['专制','冲动','缺乏耐心']),
];

const List<_MinorSpec> _cupsSpec = [
  _MinorSpec('A',      '一',   'Ace',    ['新感情','爱','情感涌现'],         ['情感封闭','压抑','爱意未表达']),
  _MinorSpec('2',      '二',   'Two',    ['伙伴关系','和谐','互相吸引'],     ['失衡','分离','误解']),
  _MinorSpec('3',      '三',   'Three',  ['庆祝','友谊','社群'],             ['过度放纵','八卦','孤立']),
  _MinorSpec('4',      '四',   'Four',   ['冷漠','内省','倦怠'],             ['觉醒','新视角','重燃兴趣']),
  _MinorSpec('5',      '五',   'Five',   ['失望','悲伤','执着于失去'],       ['接受','前进','看到剩下的']),
  _MinorSpec('6',      '六',   'Six',    ['怀旧','童年','纯真'],             ['沉湎过去','无法前进','执念']),
  _MinorSpec('7',      '七',   'Seven',  ['幻想','选择','白日梦'],           ['清晰','决定','回到现实']),
  _MinorSpec('8',      '八',   'Eight',  ['离开','寻找意义','放下'],         ['停留','害怕改变','失而复返']),
  _MinorSpec('9',      '九',   'Nine',   ['满足','愿望成真','情感满足'],     ['不满','贪婪','表面快乐']),
  _MinorSpec('10',     '十',   'Ten',    ['幸福','家庭','情感圆满'],         ['不和','价值观冲突','破裂']),
  _MinorSpec('Page',   '侍从', 'Page',   ['创造灵感','新感情','童心'],       ['情绪化','过敏感','幻想脱离现实']),
  _MinorSpec('Knight', '骑士', 'Knight', ['浪漫','追求','情感行动'],         ['不切实际','情绪化','失约']),
  _MinorSpec('Queen',  '王后', 'Queen',  ['同理','直觉','关怀'],             ['情感依赖','不稳定','情绪溢出']),
  _MinorSpec('King',   '国王', 'King',   ['情感成熟','智慧','外稳内深'],     ['情绪失控','操纵','冷淡']),
];

const List<_MinorSpec> _swordsSpec = [
  _MinorSpec('A',      '一',   'Ace',    ['突破','清晰','新思想'],           ['混乱','错误信息','受阻']),
  _MinorSpec('2',      '二',   'Two',    ['抉择','僵局','蒙眼'],             ['犹豫','信息揭露','做出决定']),
  _MinorSpec('3',      '三',   'Three',  ['心碎','痛苦','悲伤'],             ['疗愈','宽恕','释怀']),
  _MinorSpec('4',      '四',   'Four',   ['休息','恢复','暂停'],             ['焦虑','不安','倦怠']),
  _MinorSpec('5',      '五',   'Five',   ['冲突','背叛','胜之不武'],         ['和解','宽恕','结束争执']),
  _MinorSpec('6',      '六',   'Six',    ['过渡','离开','走向平静'],         ['抗拒变化','无法离开','停留']),
  _MinorSpec('7',      '七',   'Seven',  ['欺骗','策略','暗中行动'],         ['坦白','被识破','良心不安']),
  _MinorSpec('8',      '八',   'Eight',  ['受限','自我设限','蒙蔽'],         ['解脱','觉察','走出限制']),
  _MinorSpec('9',      '九',   'Nine',   ['焦虑','失眠','深夜担忧'],         ['希望','释放','看见出路']),
  _MinorSpec('10',     '十',   'Ten',    ['结束','背叛','触底'],             ['复苏','释怀','最坏已过']),
  _MinorSpec('Page',   '侍从', 'Page',   ['求知','机敏','好奇'],             ['冲动','刻薄','缺乏深思']),
  _MinorSpec('Knight', '骑士', 'Knight', ['行动','决断','锋芒'],             ['鲁莽','冲动','急于求成']),
  _MinorSpec('Queen',  '王后', 'Queen',  ['独立','客观','理性'],             ['冷漠','刻薄','苦涩']),
  _MinorSpec('King',   '国王', 'King',   ['智慧','权威','清晰判断'],         ['专横','严苛','滥用权力']),
];

const List<_MinorSpec> _pentaclesSpec = [
  _MinorSpec('A',      '一',   'Ace',    ['新机会','财富种子','落地的开始'], ['错失机会','贪婪','落空']),
  _MinorSpec('2',      '二',   'Two',    ['平衡','适应','兼顾'],             ['失衡','混乱','顾此失彼']),
  _MinorSpec('3',      '三',   'Three',  ['合作','技艺','团队'],             ['缺乏团队','平庸','技艺不足']),
  _MinorSpec('4',      '四',   'Four',   ['保守','控制','积累'],             ['慷慨','放手','失去控制']),
  _MinorSpec('5',      '五',   'Five',   ['贫困','孤立','物质匮乏'],         ['复苏','援助到来','走出困境']),
  _MinorSpec('6',      '六',   'Six',    ['慷慨','施与受','公平分配'],       ['自私','债务','不公']),
  _MinorSpec('7',      '七',   'Seven',  ['评估','耐心等待收成','复盘'],     ['投入无回报','急于求成','放弃']),
  _MinorSpec('8',      '八',   'Eight',  ['勤奋','精进','学徒态度'],         ['缺乏专注','敷衍','技艺停滞']),
  _MinorSpec('9',      '九',   'Nine',   ['富足','独立','自我实现'],         ['物质依赖','孤独的富足','未独立']),
  _MinorSpec('10',     '十',   'Ten',    ['财富','传承','家族'],             ['财务损失','家族纠纷','传承断裂']),
  _MinorSpec('Page',   '侍从', 'Page',   ['学习','机会','踏实起步'],         ['缺乏目标','懒惰','学而不用']),
  _MinorSpec('Knight', '骑士', 'Knight', ['勤奋','可靠','稳步前进'],         ['顽固','单调','停滞不前']),
  _MinorSpec('Queen',  '王后', 'Queen',  ['务实','滋养','兼顾家与业'],       ['物质化','忽视家庭','失衡']),
  _MinorSpec('King',   '国王', 'King',   ['富足','成功','稳定的领导'],       ['顽固','贪婪','守财']),
];

List<TarotCard> _buildSuit(String suitZh, String suitEnFull, String suitId,
    String element, List<_MinorSpec> spec) {
  return spec
      .map((s) => TarotCard(
            nameZh: '$suitZh${s.partZh}',
            nameEn: '${s.partEn} of $suitEnFull',
            suit: suitId,
            number: s.num,
            element: element,
            upright: s.up,
            reversed: s.rv,
          ))
      .toList();
}

final List<TarotCard> tarotDeck = () {
  final deck = <TarotCard>[];
  deck.addAll(_majorArcana);
  deck.addAll(_buildSuit('权杖', 'Wands',     'wands',     '火', _wandsSpec));
  deck.addAll(_buildSuit('圣杯', 'Cups',      'cups',      '水', _cupsSpec));
  deck.addAll(_buildSuit('宝剑', 'Swords',    'swords',    '风', _swordsSpec));
  deck.addAll(_buildSuit('星币', 'Pentacles', 'pentacles', '土', _pentaclesSpec));
  assert(deck.length == 78);
  return deck;
}();

/// 牌阵定义.
class _Spread {
  final String key;
  final String name;
  final String description;
  final List<List<String>> positions; // [[name, hint], ...]
  const _Spread(this.key, this.name, this.description, this.positions);
}

const List<_Spread> _spreads = [
  _Spread('single', '单张指引', '抽 1 张, 适合每日指引或快速问询.', [
    ['指引', '当下最需要关注的能量或讯息'],
  ]),
  _Spread('ppf', '时间线 (过去-现在-未来)', '3 张, 看一件事在时间维度的展开.', [
    ['过去', '促成当前局面的根源, 已经发生的影响'],
    ['现在', '此刻的真实状态与正在发生的力量'],
    ['未来', '若延续当前能量, 可能的发展方向'],
  ]),
  _Spread('sao', '情境-行动-结果', '3 张, 适合面对一个具体决策.', [
    ['情境', '当下你所处的真实情境'],
    ['行动', '可以采取的方向或建议'],
    ['结果', '若按此方向发展可能出现的结果'],
  ]),
  _Spread('celtic', '凯尔特十字', '10 张, 经典深入的全景式牌阵.', [
    ['当前处境', '你此刻所处的核心状态'],
    ['挑战/阻碍', '横亘在面前的力量, 无论助力或阻力'],
    ['根基 (远因)', '事件的深层根源与潜意识基础'],
    ['近期过去', '刚刚发生、正在淡出的影响'],
    ['可能的未来', '若沿当前轨迹, 即将到来的局面'],
    ['不远的未来', '下一步即将展开的事件'],
    ['自我', '你对此事的态度与位置'],
    ['环境', '他人与外部环境的态度'],
    ['希望与恐惧', '你内心的期待, 也可能是隐藏的担忧'],
    ['最终结果', '若各力量整合, 最终走向'],
  ]),
];

class TarotEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'tarot';
  @override String get nameZh => '塔罗';
  @override String get nameEn => 'Tarot';
  @override String get emoji => '🃏';
  @override String get tagline => '韦特体系 · 78 张牌';
  @override String get description =>
      '源自西方神秘学传统的韦特塔罗, 22 张大阿尔卡纳代表人生原型与重大转折, '
      '56 张小阿尔卡纳分四花色 (权杖·圣杯·宝剑·星币), 对应火水风土四元素.';

  @override
  String get systemPrompt =>
      '你是一位精通韦特塔罗的占卜师, 风格沉稳、有同理心、不故弄玄虚.\n'
      '\n阅读规则:\n'
      '1. 严格遵守用户给出的牌阵结构, 不要凭空增减牌.\n'
      '2. 解读每张牌时, 必须结合它所处的位置含义, 以及正/逆位.\n'
      '3. 关键词只是锚点, 真正的解读要回到用户的问题, 给出可落地的洞察.\n'
      '4. 整体解读要回应"问题的整体能量", 不只是逐张翻译.\n'
      '5. 不预测吉凶式的命定结果; 给方向、给可行动建议, 让用户保有主体性.\n'
      '6. 语气自然, 不要堆砌神秘词汇, 不要使用 emoji.\n'
      '7. 用中文回答.';

  @override
  List<DivinationVariant> get variants => _spreads
      .map((s) => DivinationVariant(
            key: s.key,
            name: '${s.name}  (${s.positions.length} 张)',
            description: s.description,
          ))
      .toList();

  @override
  String get defaultVariantKey => 'ppf';

  @override
  int? get accentColorHex => 0xFF7B5DA8; // 深紫

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final spread = _spreadOrThrow(variantKey);
    final n = spread.positions.length;
    final deck = List<TarotCard>.from(tarotDeck)..shuffle(_rng);
    final drawn = deck.take(n).toList();

    final items = <DivinationItem>[];
    for (var i = 0; i < n; i++) {
      final reversed = _rng.nextBool();
      items.add(_buildItem(spread.positions[i], drawn[i], reversed));
    }
    return _buildResult(variantKey, spread, items);
  }

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    final spread = _spreadOrThrow(variantKey);
    final cardOptions = tarotDeck
        .map((c) => ManualFieldOption(
              key: c.nameZh,
              label: c.nameZh,
              subtitle: c.nameEn,
            ))
        .toList();
    const orientOptions = [
      ManualFieldOption(key: 'upright', label: '正位'),
      ManualFieldOption(key: 'reversed', label: '逆位'),
    ];
    final fields = <ManualField>[];
    for (var i = 0; i < spread.positions.length; i++) {
      final pos = spread.positions[i];
      final group = '位置 ${i + 1}: ${pos[0]}';
      fields.add(ManualField(
        key: 'card_$i',
        label: '牌',
        hint: pos[1],
        kind: ManualFieldKind.picker,
        options: cardOptions,
        group: group,
      ));
      fields.add(ManualField(
        key: 'orient_$i',
        label: '正/逆位',
        kind: ManualFieldKind.toggle,
        options: orientOptions,
        defaultValue: 'upright',
        group: group,
      ));
    }
    return fields;
  }

  @override
  DivinationResult performManual({
    required String variantKey,
    required Map<String, String> selections,
  }) {
    final spread = _spreadOrThrow(variantKey);
    final byName = {for (final c in tarotDeck) c.nameZh: c};
    final items = <DivinationItem>[];
    for (var i = 0; i < spread.positions.length; i++) {
      final cardName = selections['card_$i'];
      if (cardName == null || cardName.isEmpty) {
        throw ArgumentError('位置 ${i + 1} 还没选牌');
      }
      final card = byName[cardName];
      if (card == null) {
        throw ArgumentError('未识别的牌: $cardName');
      }
      final reversed = selections['orient_$i'] == 'reversed';
      items.add(_buildItem(spread.positions[i], card, reversed));
    }
    return _buildResult(variantKey, spread, items);
  }

  _Spread _spreadOrThrow(String variantKey) => _spreads.firstWhere(
        (s) => s.key == variantKey,
        orElse: () => throw ArgumentError('unknown spread: $variantKey'),
      );

  DivinationItem _buildItem(List<String> pos, TarotCard card, bool reversed) {
    return DivinationItem(
      position: pos[0],
      positionHint: pos[1],
      name: card.nameZh,
      subtitle: card.nameEn,
      orientation: reversed ? '逆位' : '正位',
      keywords: reversed ? card.reversed : card.upright,
      extra: {
        'suit': card.suit,
        'number': card.number,
        'element': card.element,
        'reversed': reversed,
      },
    );
  }

  DivinationResult _buildResult(
      String variantKey, _Spread spread, List<DivinationItem> items) {
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
  String buildUserPrompt({
    required String question,
    required DivinationResult result,
  }) {
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(未明说, 请给出当下的整体能量解读)" : question.trim()}');
    buf.writeln();
    buf.writeln('使用的牌阵: ${result.variantName} —— ${result.extras["spreadDescription"]}');
    buf.writeln();
    buf.writeln('抽到的牌 (按位置顺序):');
    for (var i = 0; i < result.items.length; i++) {
      final it = result.items[i];
      final suit = it.extra['suit'];
      final element = it.extra['element'];
      buf.writeln('${i + 1}. 位置「${it.position}」(${it.positionHint})');
      buf.writeln('   牌: ${it.name} / ${it.subtitle}  ·  ${it.orientation}');
      buf.writeln('   花色: $suit  ·  元素: ${element ?? "—"}  ·  关键词: ${it.keywords.join(" / ")}');
    }
    buf.writeln();
    buf.writeln('请先逐张解读 (结合位置含义与正/逆位), 然后给出整体观察与建议. 之后我可能会就这次抽牌继续追问, 请记住这次的牌.');
    return buf.toString();
  }
}
