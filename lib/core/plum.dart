// 梅花易数 (Plum Blossom Numerology).
//
// 经典宋代占法, 由邵雍创立. 与六爻共享 64 卦数据, 但起卦方式更简洁:
//   先天八卦数: 乾1 兑2 离3 震4 巽5 坎6 艮7 坤8
//   取三组随机数:
//     上卦 = (n1) mod 8 (0 视为 8)
//     下卦 = (n1+n2) mod 8 (0 视为 8)
//     动爻 = (n1+n2+n3) mod 6 (0 视为 6, 自下而上)
//   动爻位置的爻阴变阳/阳变阴, 得变卦.

import 'dart:math';

import 'divination.dart';
import 'iching.dart';

// 先天八卦数 → trigram binary (bottom-up, 1=yang/0=yin)
const Map<int, String> _trigramByNumber = {
  1: '111', // 乾
  2: '110', // 兑
  3: '101', // 离
  4: '100', // 震
  5: '011', // 巽
  6: '010', // 坎
  7: '001', // 艮
  8: '000', // 坤
};

const Map<int, String> _trigramName = {
  1: '乾☰', 2: '兑☱', 3: '离☲', 4: '震☳',
  5: '巽☴', 6: '坎☵', 7: '艮☶', 8: '坤☷',
};

class PlumBlossomEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'plum';
  @override String get nameZh => '梅花易数';
  @override String get nameEn => 'Plum Blossom';
  @override String get emoji => '🌸';
  @override String get tagline => '邵雍传 · 数起卦';
  @override String get description =>
      '宋代邵雍所创的占法, 以数字起卦, 不需要工具. 取三组数 (如随机数、报数、'
      '看到的物件数), 由先天八卦数推出本卦, 再以动爻得变卦. 与六爻共享 64 卦数据.';

  @override int? get accentColorHex => 0xFFBE4C7C; // 梅红

  @override
  String get systemPrompt =>
      '你是一位精通梅花易数的占筮者, 师承邵雍《观物外篇》《梅花诗》一系, '
      '擅长以体用、互卦、变卦综合判断.\n'
      '\n阅读规则:\n'
      '1. 严格依据用户给出的本卦、动爻位、变卦.\n'
      '2. 解读上卦 (用) 与下卦 (体) 的生克关系, 并参考互卦.\n'
      '3. 结合动爻所在位置 (初/二/三/四/五/上) 给出过程性指引.\n'
      '4. 联系用户问题, 落到可执行的判断或行动方向, 而非堆砌经文.\n'
      '5. 语气克制有底蕴, 不使用 emoji. 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(
          key: 'random',
          name: '随机起卦',
          description: '由系统取三组真随机数自动起卦, 适合无明确数字时.',
        ),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final n1 = _rng.nextInt(999) + 1;
    final n2 = _rng.nextInt(999) + 1;
    final n3 = _rng.nextInt(999) + 1;
    return _build(n1, n2, n3);
  }

  DivinationResult _build(int n1, int n2, int n3) {
    int upper = n1 % 8;
    if (upper == 0) upper = 8;
    int lower = (n1 + n2) % 8;
    if (lower == 0) lower = 8;
    int changingYao = (n1 + n2 + n3) % 6;
    if (changingYao == 0) changingYao = 6;

    // hexagram binary 自下而上 = lower trigram + upper trigram
    final lowerBin = _trigramByNumber[lower]!;
    final upperBin = _trigramByNumber[upper]!;
    final origBin = lowerBin + upperBin;
    final origHex = hexagrams.firstWhere((h) => h.binary == origBin);

    // 变卦: 翻转 changingYao 位 (1-indexed, 自下而上)
    final derived = StringBuffer();
    for (var i = 0; i < 6; i++) {
      if (i + 1 == changingYao) {
        derived.write(origBin[i] == '1' ? '0' : '1');
      } else {
        derived.write(origBin[i]);
      }
    }
    final derivedHex = hexagrams.firstWhere((h) => h.binary == derived.toString());

    final items = <DivinationItem>[
      DivinationItem(
        position: '上卦 (用)',
        positionHint: '外卦, 代表客观环境与他人',
        name: _trigramName[upper]!,
        subtitle: '数 $upper',
        keywords: [],
        extra: {'binary': upperBin, 'number': upper},
      ),
      DivinationItem(
        position: '下卦 (体)',
        positionHint: '内卦, 代表自身与本体',
        name: _trigramName[lower]!,
        subtitle: '数 $lower',
        keywords: [],
        extra: {'binary': lowerBin, 'number': lower},
      ),
      DivinationItem(
        position: '动爻',
        positionHint: '变化所在的关键位置',
        name: '第 $changingYao 爻',
        subtitle: '自下而上',
        keywords: [],
        extra: {'position': changingYao},
      ),
    ];

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: 'random',
      variantName: '梅花易数',
      items: items,
      extras: {
        'numbers': [n1, n2, n3],
        'upperTrigram': _trigramName[upper],
        'lowerTrigram': _trigramName[lower],
        'changingYao': changingYao,
        'originalBinary': origBin,
        'originalNumber': origHex.number,
        'originalName': origHex.nameZh,
        'originalPinyin': origHex.pinyin,
        'originalJudgment': origHex.judgment,
        'originalUnicode': origHex.unicode,
        'derivedBinary': derivedHex.binary,
        'derivedNumber': derivedHex.number,
        'derivedName': derivedHex.nameZh,
        'derivedPinyin': derivedHex.pinyin,
        'derivedJudgment': derivedHex.judgment,
        'derivedUnicode': derivedHex.unicode,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请就当前能量给出判断)" : question.trim()}');
    buf.writeln();
    buf.writeln('起卦方式: 梅花易数, 取三组数 ${ex["numbers"]}.');
    buf.writeln('上卦 (用): ${ex["upperTrigram"]}');
    buf.writeln('下卦 (体): ${ex["lowerTrigram"]}');
    buf.writeln('动爻: 第 ${ex["changingYao"]} 爻');
    buf.writeln();
    buf.writeln('本卦: ${ex["originalUnicode"]} 第${ex["originalNumber"]}卦 ${ex["originalName"]} (${ex["originalPinyin"]})');
    buf.writeln('  卦辞: ${ex["originalJudgment"]}');
    buf.writeln('变卦: ${ex["derivedUnicode"]} 第${ex["derivedNumber"]}卦 ${ex["derivedName"]} (${ex["derivedPinyin"]})');
    buf.writeln('  卦辞: ${ex["derivedJudgment"]}');
    buf.writeln();
    buf.writeln('请按梅花易数的体用生克之法解读, 联系问题给出可落地的判断.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '${ex["originalUnicode"]} ${ex["originalName"]} → ${ex["derivedUnicode"]} ${ex["derivedName"]} (动 ${ex["changingYao"]})';
  }
}
