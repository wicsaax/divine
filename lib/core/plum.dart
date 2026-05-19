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

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    final trigramOptions = [
      for (final entry in _trigramName.entries)
        ManualFieldOption(
          key: entry.key.toString(),
          label: entry.value,
          subtitle: '数 ${entry.key}',
        ),
    ];
    const yaoOptions = [
      ManualFieldOption(key: '1', label: '初爻 (第 1, 最下)'),
      ManualFieldOption(key: '2', label: '二爻 (第 2)'),
      ManualFieldOption(key: '3', label: '三爻 (第 3)'),
      ManualFieldOption(key: '4', label: '四爻 (第 4)'),
      ManualFieldOption(key: '5', label: '五爻 (第 5)'),
      ManualFieldOption(key: '6', label: '上爻 (第 6, 最上)'),
    ];
    return [
      ManualField(
        key: 'upper',
        label: '上卦 (外卦/用)',
        kind: ManualFieldKind.picker,
        options: trigramOptions,
        group: '上下卦',
      ),
      ManualField(
        key: 'lower',
        label: '下卦 (内卦/体)',
        kind: ManualFieldKind.picker,
        options: trigramOptions,
        group: '上下卦',
      ),
      const ManualField(
        key: 'changing',
        label: '动爻位置',
        hint: '自下而上数, 1 = 最下, 6 = 最上',
        kind: ManualFieldKind.picker,
        options: yaoOptions,
        group: '动爻',
      ),
    ];
  }

  @override
  DivinationResult performManual({
    required String variantKey,
    required Map<String, String> selections,
  }) {
    final upper = int.tryParse(selections['upper'] ?? '');
    final lower = int.tryParse(selections['lower'] ?? '');
    final changing = int.tryParse(selections['changing'] ?? '');
    if (upper == null || !_trigramByNumber.containsKey(upper)) {
      throw ArgumentError('请选上卦');
    }
    if (lower == null || !_trigramByNumber.containsKey(lower)) {
      throw ArgumentError('请选下卦');
    }
    if (changing == null || changing < 1 || changing > 6) {
      throw ArgumentError('请选动爻位置');
    }
    return _buildFromParts(upper, lower, changing);
  }

  DivinationResult _build(int n1, int n2, int n3) {
    int upper = n1 % 8; if (upper == 0) upper = 8;
    int lower = (n1 + n2) % 8; if (lower == 0) lower = 8;
    int changingYao = (n1 + n2 + n3) % 6; if (changingYao == 0) changingYao = 6;
    return _buildFromParts(upper, lower, changingYao, numbers: [n1, n2, n3]);
  }

  DivinationResult _buildFromParts(int upper, int lower, int changingYao,
      {List<int>? numbers}) {
    // hexagram binary 自下而上 = lower trigram + upper trigram
    final lowerBin = _trigramByNumber[lower]!;
    final upperBin = _trigramByNumber[upper]!;
    final origBin = lowerBin + upperBin;
    final origHex = hexagrams.firstWhere((h) => h.binary == origBin);

    final derived = StringBuffer();
    for (var i = 0; i < 6; i++) {
      if (i + 1 == changingYao) {
        derived.write(origBin[i] == '1' ? '0' : '1');
      } else {
        derived.write(origBin[i]);
      }
    }
    final derivedHex =
        hexagrams.firstWhere((h) => h.binary == derived.toString());

    final items = <DivinationItem>[
      DivinationItem(
        position: '上卦 (用)',
        positionHint: '外卦, 代表客观环境与他人',
        name: _trigramName[upper]!,
        subtitle: '数 $upper',
        keywords: const [],
        extra: {'binary': upperBin, 'number': upper},
      ),
      DivinationItem(
        position: '下卦 (体)',
        positionHint: '内卦, 代表自身与本体',
        name: _trigramName[lower]!,
        subtitle: '数 $lower',
        keywords: const [],
        extra: {'binary': lowerBin, 'number': lower},
      ),
      DivinationItem(
        position: '动爻',
        positionHint: '变化所在的关键位置',
        name: '第 $changingYao 爻',
        subtitle: '自下而上',
        keywords: const [],
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
        if (numbers != null) 'numbers': numbers,
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
    final numbers = ex['numbers'];
    if (numbers != null) {
      buf.writeln('起卦方式: 梅花易数, 取三组数 $numbers.');
    } else {
      buf.writeln('起卦方式: 梅花易数 (由用户手动指定上下卦与动爻).');
    }
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
