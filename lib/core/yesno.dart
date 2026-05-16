// 是否占卜 (Yes / No / Maybe).
//
// 最简的占卜形式, 给一个二元问题一个倾向性回答. 用三种不同方法降低单点的随机感:
//   - tarot: 抽一张塔罗, 大阿尔卡纳正位偏 yes, 逆位偏 no, 小牌按花色与正逆位综合
//   - coins: 投 3 枚硬币, 三正=肯定 yes, 三反=肯定 no, 余者 maybe
//   - 8ball: 经典魔法八号球 20 句答案
//
// LLM 在收到结果后做"为什么"的解释, 让答案有依据.

import 'dart:math';
import 'divination.dart';
import 'tarot.dart';

const List<String> _eightBall = [
  '是的, 毫无疑问.',
  '是的, 现在就是时候.',
  '可以确定.',
  '是的, 大概率.',
  '观察显示是.',
  '迹象指向是.',
  '我的答案是是.',
  '是的.',
  '前景不错.',
  '是的, 但需耐心.',
  '现在不要轻易下结论.',
  '问题再问一次.',
  '请稍后再问.',
  '不能确定.',
  '现在告诉你不太合适.',
  '不要指望它.',
  '我的答案是否.',
  '迹象指向否.',
  '观察显示否.',
  '非常可疑.',
];

class YesNoEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'yesno';
  @override String get nameZh => '是否占卜';
  @override String get nameEn => 'Yes / No';
  @override String get emoji => '⚖️';
  @override String get tagline => '快速二元决断';
  @override String get description =>
      '当你需要一个简单的 yes/no/maybe 时使用. 提供三种法门: '
      '抽塔罗 (大阿尔卡纳正逆位决定倾向)、三枚硬币、经典魔法八号球.';

  @override int? get accentColorHex => 0xFF4A6FA5; // 海军蓝

  @override
  String get systemPrompt =>
      '你是一位简洁、直接的占卜师, 擅长把宇宙的回应翻译为"可执行的判断". '
      '\n阅读规则:\n'
      '1. 严格按用户给出的占卜方式和原始结果回答.\n'
      '2. 先给出一个明确的倾向 (倾向是 / 倾向否 / 难以判断), 不要含糊其辞.\n'
      '3. 用 1-2 段话说明"为什么这个答案", 结合所用方法的象征意义.\n'
      '4. 最后给出"当下行动建议", 把不确定性转化为可控的下一步.\n'
      '5. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(
          key: 'tarot',
          name: '塔罗一张',
          description: '抽一张, 正逆位决定倾向.',
        ),
        DivinationVariant(
          key: 'coins',
          name: '三枚硬币',
          description: '三正=明确肯定, 三反=明确否定, 余者偏中性.',
        ),
        DivinationVariant(
          key: '8ball',
          name: '魔法八号球',
          description: '抽一句魔法八号球的经典回答.',
        ),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    switch (variantKey) {
      case 'tarot':
        return _viaTarot();
      case 'coins':
        return _viaCoins();
      case '8ball':
        return _via8Ball();
      default:
        throw ArgumentError('unknown variant: $variantKey');
    }
  }

  DivinationResult _viaTarot() {
    final card = (List<TarotCard>.from(tarotDeck)..shuffle(_rng)).first;
    final reversed = _rng.nextBool();
    String tendency;
    if (card.suit == 'major') {
      tendency = reversed ? '倾向否' : '倾向是';
    } else if (card.suit == 'wands' || card.suit == 'cups') {
      tendency = reversed ? '难以判断' : '倾向是';
    } else {
      tendency = reversed ? '倾向否' : '难以判断';
    }
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: 'tarot',
      variantName: '塔罗一张',
      items: [
        DivinationItem(
          position: '答案',
          positionHint: '基于塔罗正逆位的倾向',
          name: card.nameZh,
          subtitle: '${reversed ? "逆位" : "正位"}  ·  $tendency',
          keywords: reversed ? card.reversed : card.upright,
          extra: {'suit': card.suit, 'reversed': reversed, 'tendency': tendency},
        ),
      ],
      extras: {'tendency': tendency, 'method': '塔罗'},
    );
  }

  DivinationResult _viaCoins() {
    var heads = 0;
    for (var i = 0; i < 3; i++) {
      if (_rng.nextBool()) heads++;
    }
    String tendency;
    String detail;
    switch (heads) {
      case 3: tendency = '明确是'; detail = '三正面'; break;
      case 2: tendency = '倾向是'; detail = '二正一反'; break;
      case 1: tendency = '倾向否'; detail = '一正二反'; break;
      default: tendency = '明确否'; detail = '三反面';
    }
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: 'coins',
      variantName: '三枚硬币',
      items: [
        DivinationItem(
          position: '答案',
          positionHint: '基于三硬币正反组合',
          name: tendency,
          subtitle: detail,
          keywords: const [],
          extra: {'heads': heads},
        ),
      ],
      extras: {'tendency': tendency, 'method': '三枚硬币', 'heads': heads},
    );
  }

  DivinationResult _via8Ball() {
    final phrase = _eightBall[_rng.nextInt(_eightBall.length)];
    final idx = _eightBall.indexOf(phrase);
    final tendency = idx < 10
        ? '倾向是'
        : (idx < 13 ? '难以判断' : '倾向否');
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: '8ball',
      variantName: '魔法八号球',
      items: [
        DivinationItem(
          position: '答案',
          positionHint: '魔法八号球的回应',
          name: phrase,
          subtitle: tendency,
          keywords: const [],
        ),
      ],
      extras: {'tendency': tendency, 'method': '八号球', 'phrase': phrase},
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请用本次答案回应我当下的境况)" : question.trim()}');
    buf.writeln();
    buf.writeln('占卜方式: ${ex["method"]}');
    final it = result.items.first;
    buf.writeln('结果: ${it.name}  ·  ${it.subtitle ?? ""}');
    buf.writeln('总体倾向: ${ex["tendency"]}');
    buf.writeln();
    buf.writeln('请按规则: 先明确给出倾向, 再解释为什么, 最后给一个当下行动建议.');
    return buf.toString();
  }
}
