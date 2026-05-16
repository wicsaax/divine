// 卢恩占卜引擎 (Elder Futhark, 长枝符文 24 个).
//
// 某些符文是"不可逆位"的 (画上去不会反过来的形状), 这类传统称为 nonreversible.

import 'dart:math';
import 'divination.dart';

class Rune {
  final String glyph; // ᚠ
  final String nameOldNorse; // Fehu
  final String nameZh;
  final String meaning; // 短描述
  final List<String> upright;
  final List<String> reversed; // 空 list 表示不可逆位
  const Rune({
    required this.glyph,
    required this.nameOldNorse,
    required this.nameZh,
    required this.meaning,
    required this.upright,
    this.reversed = const [],
  });

  bool get reversible => reversed.isNotEmpty;
}

const List<Rune> elderFuthark = [
  Rune(glyph: 'ᚠ', nameOldNorse: 'Fehu',     nameZh: '菲胡', meaning: '财富、牲畜', upright: ['富足','资源','回报','流动'], reversed: ['损失','贪婪','停滞']),
  Rune(glyph: 'ᚢ', nameOldNorse: 'Uruz',     nameZh: '乌鲁兹', meaning: '原牛、原始力', upright: ['力量','意志','活力','野性'], reversed: ['软弱','失控','病弱']),
  Rune(glyph: 'ᚦ', nameOldNorse: 'Thurisaz', nameZh: '索里萨兹', meaning: '巨人、刺', upright: ['防御','警示','突破阻碍'], reversed: ['冲突','危险','被针对']),
  Rune(glyph: 'ᚨ', nameOldNorse: 'Ansuz',    nameZh: '安苏兹', meaning: '神之口、讯息', upright: ['沟通','启示','智慧','讯息到来'], reversed: ['误解','谎言','沟通阻塞']),
  Rune(glyph: 'ᚱ', nameOldNorse: 'Raidho',   nameZh: '莱多', meaning: '骑乘、旅途', upright: ['旅程','节奏','秩序','正确方向'], reversed: ['偏离','延误','节奏混乱']),
  Rune(glyph: 'ᚲ', nameOldNorse: 'Kenaz',    nameZh: '肯纳兹', meaning: '火炬、光', upright: ['启发','洞见','创造的火','学习'], reversed: ['幻觉','误判','灵感熄灭']),
  Rune(glyph: 'ᚷ', nameOldNorse: 'Gebo',     nameZh: '盖博', meaning: '礼物、馈赠', upright: ['给予','伙伴关系','平衡的交换'], reversed: []),
  Rune(glyph: 'ᚹ', nameOldNorse: 'Wunjo',    nameZh: '温佑', meaning: '喜悦、安乐', upright: ['喜悦','和谐','满足','归属'], reversed: ['哀伤','失谐','延迟的喜悦']),
  Rune(glyph: 'ᚺ', nameOldNorse: 'Hagalaz',  nameZh: '哈格拉兹', meaning: '冰雹、破坏', upright: ['打断','清洗','不可控的变化'], reversed: []),
  Rune(glyph: 'ᚾ', nameOldNorse: 'Nauthiz',  nameZh: '瑙提兹', meaning: '需要、匮乏', upright: ['需要','约束','耐心','逆境中的学习'], reversed: ['强求','受困','缺乏']),
  Rune(glyph: 'ᛁ', nameOldNorse: 'Isa',      nameZh: '伊萨', meaning: '冰、停滞', upright: ['停滞','内观','冷静','等待'], reversed: []),
  Rune(glyph: 'ᛃ', nameOldNorse: 'Jera',     nameZh: '耶拉', meaning: '年、丰收', upright: ['循环','回报','应时','收获'], reversed: []),
  Rune(glyph: 'ᛇ', nameOldNorse: 'Eihwaz',   nameZh: '艾瓦兹', meaning: '紫杉、转化', upright: ['转化','韧性','贯通生死的视角'], reversed: []),
  Rune(glyph: 'ᛈ', nameOldNorse: 'Perthro',  nameZh: '佩斯罗', meaning: '骰盅、命运', upright: ['未知的命运','秘密','机会'], reversed: ['失望','秘密暴露','命运转折']),
  Rune(glyph: 'ᛉ', nameOldNorse: 'Algiz',    nameZh: '埃尔哈兹', meaning: '麋鹿、护盾', upright: ['保护','神圣边界','直觉的警示'], reversed: ['脆弱','边界被破','轻信']),
  Rune(glyph: 'ᛊ', nameOldNorse: 'Sowilo',   nameZh: '索维洛', meaning: '太阳', upright: ['胜利','光','生命力','清明'], reversed: []),
  Rune(glyph: 'ᛏ', nameOldNorse: 'Tiwaz',    nameZh: '提瓦兹', meaning: '提尔神、正义', upright: ['正义','勇气','信念','为道义而战'], reversed: ['不公','失去信念','失败']),
  Rune(glyph: 'ᛒ', nameOldNorse: 'Berkano',  nameZh: '贝卡诺', meaning: '桦树、生长', upright: ['生长','新生','滋养','女性力量'], reversed: ['停滞','家庭问题','创意阻塞']),
  Rune(glyph: 'ᛖ', nameOldNorse: 'Ehwaz',    nameZh: '埃瓦兹', meaning: '马、伙伴', upright: ['伙伴关系','信任','协同前进'], reversed: ['失和','信任破裂','分道']),
  Rune(glyph: 'ᛗ', nameOldNorse: 'Mannaz',   nameZh: '玛纳兹', meaning: '人', upright: ['自我','人性','群体','智识'], reversed: ['孤立','自欺','人际隔阂']),
  Rune(glyph: 'ᛚ', nameOldNorse: 'Laguz',    nameZh: '拉古兹', meaning: '水、流动', upright: ['直觉','流动','潜意识','治愈'], reversed: ['困惑','失向','被情绪淹没']),
  Rune(glyph: 'ᛜ', nameOldNorse: 'Ingwaz',   nameZh: '英瓦兹', meaning: '英格神、孕育', upright: ['内在积蓄','即将释放的能量','圆满'], reversed: []),
  Rune(glyph: 'ᛟ', nameOldNorse: 'Othala',   nameZh: '奥撒拉', meaning: '故土、传承', upright: ['传承','根基','所属','家族遗产'], reversed: ['失根','与传统冲突','无法立足']),
  Rune(glyph: 'ᛞ', nameOldNorse: 'Dagaz',    nameZh: '达加兹', meaning: '昼、突破', upright: ['突破','转捩点','光明乍现'], reversed: []),
];

class _RuneSpread {
  final String key;
  final String name;
  final String description;
  final List<List<String>> positions;
  const _RuneSpread(this.key, this.name, this.description, this.positions);
}

const List<_RuneSpread> _runeSpreads = [
  _RuneSpread('single', '单符指引', '抽 1 个符文, 适合每日抽签或简短问询.', [
    ['指引', '当下的核心讯息'],
  ]),
  _RuneSpread('odin', '奥丁三符', '3 个符文 (北欧古典).', [
    ['局面', '当下事件的本质'],
    ['挑战', '所面对的力量或考验'],
    ['指引', '神祇给出的方向'],
  ]),
  _RuneSpread('norn', '诺恩五符', '5 个符文, 命运三女神的视角.', [
    ['过去 (乌尔德)', '已成形的命运基础'],
    ['现在 (薇尔丹蒂)', '正在生成的此刻'],
    ['未来 (诗寇蒂)', '将到来的可能'],
    ['不可改变的', '需接受的固定因素'],
    ['可改变的', '你仍掌握的方向'],
  ]),
];

class RunesEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'runes';
  @override String get nameZh => '卢恩符文';
  @override String get nameEn => 'Runes';
  @override String get emoji => 'ᚱ';
  @override String get tagline => '北欧古传统 · 长枝 24 符';
  @override String get description =>
      '源自北欧日耳曼传统的 Elder Futhark 长枝符文, 共 24 个, 每个对应一种古老的能量原型. '
      '部分符文形状对称, 没有"逆位"; 另一些则有正逆两种含义.';

  @override
  String get systemPrompt =>
      '你是一位精通北欧古卢恩文 (Elder Futhark) 的占卜师, 兼具北欧神话学者的克制与同理.\n'
      '\n阅读规则:\n'
      '1. 严格依据用户给出的符文, 不要凭空增减.\n'
      '2. 区分"可逆位"和"不可逆位"符文; 不可逆位的符文不应有"逆位"解.\n'
      '3. 结合符文在牌阵中的位置含义解读, 给出可落地的洞察.\n'
      '4. 不要堆砌北欧术语吓唬人, 但可以恰当引述符文背后的意象.\n'
      '5. 不预测命定式的吉凶, 强调主体性和可行动方向.\n'
      '6. 不使用 emoji, 用中文回答.';

  @override
  List<DivinationVariant> get variants => _runeSpreads
      .map((s) => DivinationVariant(
            key: s.key,
            name: '${s.name}  (${s.positions.length} 符)',
            description: s.description,
          ))
      .toList();

  @override
  int? get accentColorHex => 0xFF8B6F47; // 古铜

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final spread = _runeSpreads.firstWhere((s) => s.key == variantKey,
        orElse: () => throw ArgumentError('unknown rune spread: $variantKey'));
    final n = spread.positions.length;
    final pool = List<Rune>.from(elderFuthark)..shuffle(_rng);
    final drawn = pool.take(n).toList();

    final items = <DivinationItem>[];
    for (var i = 0; i < n; i++) {
      final pos = spread.positions[i];
      final rune = drawn[i];
      final reversed = rune.reversible && _rng.nextBool();
      final orientation = !rune.reversible ? '不可逆' : (reversed ? '逆位' : '正位');
      final keywords = reversed ? rune.reversed : rune.upright;
      items.add(DivinationItem(
        position: pos[0],
        positionHint: pos[1],
        name: '${rune.glyph}  ${rune.nameZh}',
        subtitle: '${rune.nameOldNorse} · ${rune.meaning}',
        orientation: orientation,
        keywords: keywords,
        extra: {
          'glyph': rune.glyph,
          'old_norse': rune.nameOldNorse,
          'reversible': rune.reversible,
          'reversed': reversed,
        },
      ));
    }
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
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(未明说, 请基于符文给出整体讯息)" : question.trim()}');
    buf.writeln();
    buf.writeln('使用的阵列: ${result.variantName} —— ${result.extras["spreadDescription"]}');
    buf.writeln();
    buf.writeln('抽到的符文 (按位置顺序):');
    for (var i = 0; i < result.items.length; i++) {
      final it = result.items[i];
      buf.writeln('${i + 1}. 位置「${it.position}」(${it.positionHint})');
      buf.writeln('   符文: ${it.name}  ·  ${it.subtitle}  ·  ${it.orientation}');
      buf.writeln('   关键词: ${it.keywords.join(" / ")}');
    }
    buf.writeln();
    buf.writeln('请逐符解读, 再给出整体洞见与建议. 后续可能继续追问, 请记住这次的符文.');
    return buf.toString();
  }
}
