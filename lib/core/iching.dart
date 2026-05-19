// 周易/六爻占卜引擎.
//
// 起卦方式: 三枚铜钱法 (硬币法). 每爻投三枚硬币, 按"正面为3, 反面为2"计:
//   总和 = 6  -> 老阴 (变爻, ⚋ 变为 ⚊)
//   总和 = 7  -> 少阳 (本爻 ⚊, 不变)
//   总和 = 8  -> 少阴 (本爻 ⚋, 不变)
//   总和 = 9  -> 老阳 (变爻, ⚊ 变为 ⚋)
// 起卦顺序为自下而上, 共 6 次, 得到本卦 + 变爻位; 若有变爻则推出变卦.

import 'dart:math';
import 'divination.dart';

class Hexagram {
  final int number; // 1-64 (King Wen 序)
  final String nameZh; // 乾
  final String pinyin; // qián
  final String nameEn; // Heaven
  final String binary; // 自下而上 6 字符 0/1 (1=阳, 0=阴)
  final String judgment; // 卦辞简译
  final String image; // 象辞简译
  const Hexagram({
    required this.number,
    required this.nameZh,
    required this.pinyin,
    required this.nameEn,
    required this.binary,
    required this.judgment,
    required this.image,
  });

  /// Unicode 六爻字符. 王弼序 1-64 对应 U+4DC0-U+4DFF.
  String get unicode => String.fromCharCode(0x4DC0 + number - 1);
}

const List<Hexagram> hexagrams = [
  Hexagram(number: 1,  nameZh: '乾',     pinyin: 'qián',     nameEn: 'The Creative',          binary: '111111', judgment: '元亨利贞, 自强不息.',                image: '天行健, 君子以自强不息.'),
  Hexagram(number: 2,  nameZh: '坤',     pinyin: 'kūn',      nameEn: 'The Receptive',         binary: '000000', judgment: '元亨, 利牝马之贞. 厚德载物.',         image: '地势坤, 君子以厚德载物.'),
  Hexagram(number: 3,  nameZh: '屯',     pinyin: 'zhūn',     nameEn: 'Difficulty at Beginning',binary: '100010', judgment: '草创艰难, 利建侯而不可妄进.',         image: '云雷屯, 君子以经纶.'),
  Hexagram(number: 4,  nameZh: '蒙',     pinyin: 'méng',     nameEn: 'Youthful Folly',        binary: '010001', judgment: '蒙昧待启, 求学问道.',                 image: '山下出泉, 君子以果行育德.'),
  Hexagram(number: 5,  nameZh: '需',     pinyin: 'xū',       nameEn: 'Waiting',               binary: '111010', judgment: '有孚, 光亨, 等待时机.',               image: '云上于天需, 君子以饮食宴乐.'),
  Hexagram(number: 6,  nameZh: '讼',     pinyin: 'sòng',     nameEn: 'Conflict',              binary: '010111', judgment: '有孚窒惕, 中吉终凶. 慎讼.',            image: '天与水违行讼, 君子以作事谋始.'),
  Hexagram(number: 7,  nameZh: '师',     pinyin: 'shī',      nameEn: 'The Army',              binary: '010000', judgment: '贞, 丈人吉. 统众有道.',                image: '地中有水师, 君子以容民畜众.'),
  Hexagram(number: 8,  nameZh: '比',     pinyin: 'bǐ',       nameEn: 'Holding Together',      binary: '000010', judgment: '吉, 原筮元永贞. 亲附之时.',           image: '地上有水比, 先王以建万国亲诸侯.'),
  Hexagram(number: 9,  nameZh: '小畜',   pinyin: 'xiǎo xù',  nameEn: 'Small Taming',          binary: '111011', judgment: '亨, 密云不雨, 自我西郊.',             image: '风行天上小畜, 君子以懿文德.'),
  Hexagram(number: 10, nameZh: '履',     pinyin: 'lǚ',       nameEn: 'Treading',              binary: '110111', judgment: '履虎尾, 不咥人, 亨.',                 image: '上天下泽履, 君子以辨上下定民志.'),
  Hexagram(number: 11, nameZh: '泰',     pinyin: 'tài',      nameEn: 'Peace',                 binary: '111000', judgment: '小往大来, 吉亨.',                     image: '天地交泰, 后以财成天地之道.'),
  Hexagram(number: 12, nameZh: '否',     pinyin: 'pǐ',       nameEn: 'Standstill',            binary: '000111', judgment: '否之匪人, 不利君子贞.',               image: '天地不交否, 君子以俭德辟难.'),
  Hexagram(number: 13, nameZh: '同人',   pinyin: 'tóng rén', nameEn: 'Fellowship',            binary: '101111', judgment: '同人于野, 亨. 利涉大川.',             image: '天与火同人, 君子以类族辨物.'),
  Hexagram(number: 14, nameZh: '大有',   pinyin: 'dà yǒu',   nameEn: 'Great Possession',      binary: '111101', judgment: '元亨. 物盛之时.',                     image: '火在天上大有, 君子以遏恶扬善.'),
  Hexagram(number: 15, nameZh: '谦',     pinyin: 'qiān',     nameEn: 'Modesty',               binary: '001000', judgment: '亨, 君子有终.',                       image: '地中有山谦, 君子以裒多益寡.'),
  Hexagram(number: 16, nameZh: '豫',     pinyin: 'yù',       nameEn: 'Enthusiasm',            binary: '000100', judgment: '利建侯行师.',                         image: '雷出地奋豫, 先王以作乐崇德.'),
  Hexagram(number: 17, nameZh: '随',     pinyin: 'suí',      nameEn: 'Following',             binary: '100110', judgment: '元亨利贞, 无咎.',                     image: '泽中有雷随, 君子以向晦入宴息.'),
  Hexagram(number: 18, nameZh: '蛊',     pinyin: 'gǔ',       nameEn: 'Work on the Decayed',   binary: '011001', judgment: '元亨, 利涉大川. 整治积弊.',           image: '山下有风蛊, 君子以振民育德.'),
  Hexagram(number: 19, nameZh: '临',     pinyin: 'lín',      nameEn: 'Approach',              binary: '110000', judgment: '元亨利贞, 至于八月有凶.',             image: '泽上有地临, 君子以教思无穷.'),
  Hexagram(number: 20, nameZh: '观',     pinyin: 'guān',     nameEn: 'Contemplation',         binary: '000011', judgment: '盥而不荐, 有孚顒若.',                  image: '风行地上观, 先王以省方观民设教.'),
  Hexagram(number: 21, nameZh: '噬嗑',   pinyin: 'shì kè',   nameEn: 'Biting Through',        binary: '100101', judgment: '亨. 利用狱.',                         image: '雷电噬嗑, 先王以明罚敕法.'),
  Hexagram(number: 22, nameZh: '贲',     pinyin: 'bì',       nameEn: 'Grace',                 binary: '101001', judgment: '亨, 小利有攸往.',                     image: '山下有火贲, 君子以明庶政.'),
  Hexagram(number: 23, nameZh: '剥',     pinyin: 'bō',       nameEn: 'Splitting Apart',       binary: '000001', judgment: '不利有攸往.',                         image: '山附于地剥, 上以厚下安宅.'),
  Hexagram(number: 24, nameZh: '复',     pinyin: 'fù',       nameEn: 'Return',                binary: '100000', judgment: '亨, 出入无疾, 朋来无咎.',             image: '雷在地中复, 先王以至日闭关.'),
  Hexagram(number: 25, nameZh: '无妄',   pinyin: 'wú wàng',  nameEn: 'Innocence',             binary: '100111', judgment: '元亨利贞, 其匪正有眚.',               image: '天下雷行物与无妄, 先王以茂对时育万物.'),
  Hexagram(number: 26, nameZh: '大畜',   pinyin: 'dà xù',    nameEn: 'Great Taming',          binary: '111001', judgment: '利贞, 不家食吉.',                     image: '天在山中大畜, 君子以多识前言往行.'),
  Hexagram(number: 27, nameZh: '颐',     pinyin: 'yí',       nameEn: 'Nourishment',           binary: '100001', judgment: '贞吉, 观颐, 自求口实.',               image: '山下有雷颐, 君子以慎言语节饮食.'),
  Hexagram(number: 28, nameZh: '大过',   pinyin: 'dà guò',   nameEn: 'Great Exceeding',       binary: '011110', judgment: '栋桡, 利有攸往.',                     image: '泽灭木大过, 君子以独立不惧.'),
  Hexagram(number: 29, nameZh: '坎',     pinyin: 'kǎn',      nameEn: 'The Abysmal Water',     binary: '010010', judgment: '习坎, 有孚, 维心亨.',                 image: '水洊至习坎, 君子以常德行习教事.'),
  Hexagram(number: 30, nameZh: '离',     pinyin: 'lí',       nameEn: 'The Clinging Fire',     binary: '101101', judgment: '利贞, 亨. 畜牝牛吉.',                 image: '明两作离, 大人以继明照于四方.'),
  Hexagram(number: 31, nameZh: '咸',     pinyin: 'xián',     nameEn: 'Influence',             binary: '001110', judgment: '亨利贞, 取女吉.',                     image: '山上有泽咸, 君子以虚受人.'),
  Hexagram(number: 32, nameZh: '恒',     pinyin: 'héng',     nameEn: 'Duration',              binary: '011100', judgment: '亨, 无咎, 利贞, 利有攸往.',           image: '雷风恒, 君子以立不易方.'),
  Hexagram(number: 33, nameZh: '遁',     pinyin: 'dùn',      nameEn: 'Retreat',               binary: '001111', judgment: '亨, 小利贞.',                         image: '天下有山遁, 君子以远小人.'),
  Hexagram(number: 34, nameZh: '大壮',   pinyin: 'dà zhuàng',nameEn: 'Great Power',           binary: '111100', judgment: '利贞.',                               image: '雷在天上大壮, 君子以非礼弗履.'),
  Hexagram(number: 35, nameZh: '晋',     pinyin: 'jìn',      nameEn: 'Progress',              binary: '000101', judgment: '康侯用锡马蕃庶, 昼日三接.',           image: '明出地上晋, 君子以自昭明德.'),
  Hexagram(number: 36, nameZh: '明夷',   pinyin: 'míng yí',  nameEn: 'Darkening of the Light',binary: '101000', judgment: '利艰贞.',                             image: '明入地中明夷, 君子以莅众用晦而明.'),
  Hexagram(number: 37, nameZh: '家人',   pinyin: 'jiā rén',  nameEn: 'The Family',            binary: '101011', judgment: '利女贞.',                             image: '风自火出家人, 君子以言有物而行有恒.'),
  Hexagram(number: 38, nameZh: '睽',     pinyin: 'kuí',      nameEn: 'Opposition',            binary: '110101', judgment: '小事吉.',                             image: '上火下泽睽, 君子以同而异.'),
  Hexagram(number: 39, nameZh: '蹇',     pinyin: 'jiǎn',     nameEn: 'Obstruction',           binary: '001010', judgment: '利西南, 不利东北. 利见大人.',         image: '山上有水蹇, 君子以反身修德.'),
  Hexagram(number: 40, nameZh: '解',     pinyin: 'xiè',      nameEn: 'Deliverance',           binary: '010100', judgment: '利西南, 无所往. 来复吉.',             image: '雷雨作解, 君子以赦过宥罪.'),
  Hexagram(number: 41, nameZh: '损',     pinyin: 'sǔn',      nameEn: 'Decrease',              binary: '110001', judgment: '有孚, 元吉无咎.',                     image: '山下有泽损, 君子以惩忿窒欲.'),
  Hexagram(number: 42, nameZh: '益',     pinyin: 'yì',       nameEn: 'Increase',              binary: '100011', judgment: '利有攸往, 利涉大川.',                 image: '风雷益, 君子以见善则迁有过则改.'),
  Hexagram(number: 43, nameZh: '夬',     pinyin: 'guài',     nameEn: 'Breakthrough',          binary: '111110', judgment: '扬于王庭, 孚号有厉.',                 image: '泽上于天夬, 君子以施禄及下.'),
  Hexagram(number: 44, nameZh: '姤',     pinyin: 'gòu',      nameEn: 'Coming to Meet',        binary: '011111', judgment: '女壮, 勿用取女.',                     image: '天下有风姤, 后以施命诰四方.'),
  Hexagram(number: 45, nameZh: '萃',     pinyin: 'cuì',      nameEn: 'Gathering Together',    binary: '000110', judgment: '亨, 王假有庙. 利见大人.',             image: '泽上于地萃, 君子以除戎器戒不虞.'),
  Hexagram(number: 46, nameZh: '升',     pinyin: 'shēng',    nameEn: 'Pushing Upward',        binary: '011000', judgment: '元亨, 用见大人勿恤.',                 image: '地中生木升, 君子以顺德积小以高大.'),
  Hexagram(number: 47, nameZh: '困',     pinyin: 'kùn',      nameEn: 'Oppression',            binary: '010110', judgment: '亨, 贞, 大人吉.',                     image: '泽无水困, 君子以致命遂志.'),
  Hexagram(number: 48, nameZh: '井',     pinyin: 'jǐng',     nameEn: 'The Well',              binary: '011010', judgment: '改邑不改井, 无丧无得.',               image: '木上有水井, 君子以劳民劝相.'),
  Hexagram(number: 49, nameZh: '革',     pinyin: 'gé',       nameEn: 'Revolution',            binary: '101110', judgment: '己日乃孚, 元亨利贞悔亡.',             image: '泽中有火革, 君子以治历明时.'),
  Hexagram(number: 50, nameZh: '鼎',     pinyin: 'dǐng',     nameEn: 'The Cauldron',          binary: '011101', judgment: '元吉亨.',                             image: '木上有火鼎, 君子以正位凝命.'),
  Hexagram(number: 51, nameZh: '震',     pinyin: 'zhèn',     nameEn: 'The Arousing Thunder',  binary: '100100', judgment: '亨, 震来虩虩, 笑言哑哑.',             image: '洊雷震, 君子以恐惧修省.'),
  Hexagram(number: 52, nameZh: '艮',     pinyin: 'gèn',      nameEn: 'Keeping Still Mountain',binary: '001001', judgment: '艮其背, 不获其身.',                   image: '兼山艮, 君子以思不出其位.'),
  Hexagram(number: 53, nameZh: '渐',     pinyin: 'jiàn',     nameEn: 'Gradual Progress',      binary: '001011', judgment: '女归吉, 利贞.',                       image: '山上有木渐, 君子以居贤德善俗.'),
  Hexagram(number: 54, nameZh: '归妹',   pinyin: 'guī mèi',  nameEn: 'The Marrying Maiden',   binary: '110100', judgment: '征凶, 无攸利.',                       image: '泽上有雷归妹, 君子以永终知敝.'),
  Hexagram(number: 55, nameZh: '丰',     pinyin: 'fēng',     nameEn: 'Abundance',             binary: '101100', judgment: '亨, 王假之, 勿忧宜日中.',             image: '雷电皆至丰, 君子以折狱致刑.'),
  Hexagram(number: 56, nameZh: '旅',     pinyin: 'lǚ',       nameEn: 'The Wanderer',          binary: '001101', judgment: '小亨, 旅贞吉.',                       image: '山上有火旅, 君子以明慎用刑.'),
  Hexagram(number: 57, nameZh: '巽',     pinyin: 'xùn',      nameEn: 'The Gentle Wind',       binary: '011011', judgment: '小亨, 利有攸往. 利见大人.',           image: '随风巽, 君子以申命行事.'),
  Hexagram(number: 58, nameZh: '兑',     pinyin: 'duì',      nameEn: 'The Joyous Lake',       binary: '110110', judgment: '亨利贞.',                             image: '丽泽兑, 君子以朋友讲习.'),
  Hexagram(number: 59, nameZh: '涣',     pinyin: 'huàn',     nameEn: 'Dispersion',            binary: '010011', judgment: '亨, 王假有庙. 利涉大川.',             image: '风行水上涣, 先王以享于帝立庙.'),
  Hexagram(number: 60, nameZh: '节',     pinyin: 'jié',      nameEn: 'Limitation',            binary: '110010', judgment: '亨, 苦节不可贞.',                     image: '泽上有水节, 君子以制数度议德行.'),
  Hexagram(number: 61, nameZh: '中孚',   pinyin: 'zhōng fú', nameEn: 'Inner Truth',           binary: '110011', judgment: '豚鱼吉, 利涉大川.',                   image: '泽上有风中孚, 君子以议狱缓死.'),
  Hexagram(number: 62, nameZh: '小过',   pinyin: 'xiǎo guò', nameEn: 'Small Exceeding',       binary: '001100', judgment: '亨利贞, 可小事不可大事.',             image: '山上有雷小过, 君子以行过乎恭.'),
  Hexagram(number: 63, nameZh: '既济',   pinyin: 'jì jì',    nameEn: 'After Completion',      binary: '101010', judgment: '亨, 小利贞, 初吉终乱.',               image: '水在火上既济, 君子以思患而豫防之.'),
  Hexagram(number: 64, nameZh: '未济',   pinyin: 'wèi jì',   nameEn: 'Before Completion',     binary: '010101', judgment: '亨, 小狐汔济, 濡其尾.',               image: '火在水上未济, 君子以慎辨物居方.'),
];

final Map<String, Hexagram> _binaryToHexagram = {
  for (final h in hexagrams) h.binary: h,
};

Hexagram _findByBinary(String binary) {
  final h = _binaryToHexagram[binary];
  if (h == null) {
    throw StateError('hexagram not found for binary: $binary');
  }
  return h;
}

/// 投三枚硬币: 正面 (heads) = 3, 反面 (tails) = 2.
/// 返回总和 6/7/8/9.
int _tossOnce(Random rng) {
  var sum = 0;
  for (var i = 0; i < 3; i++) {
    sum += rng.nextBool() ? 3 : 2;
  }
  return sum;
}

class IChingEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'iching';
  @override String get nameZh => '周易六爻';
  @override String get nameEn => 'I Ching';
  @override String get emoji => '☯';
  @override String get tagline => '三钱起卦 · 64 卦';
  @override String get description =>
      '中国上古占筮系统, 以阴 (⚋) 阳 (⚊) 两爻演化为 64 卦, 每卦六爻. '
      '本应用使用经典的三枚铜钱法: 每爻投三枚硬币, 由下而上, 共六次, 得本卦. '
      '出现"老阴"或"老阳"的爻为变爻, 阴变阳、阳变阴, 推出变卦.';

  @override
  String get systemPrompt =>
      '你是一位通读《周易》与历代易传的占筮者, 兼具传统义理派的稳重与象数派的灵敏.\n'
      '\n阅读规则:\n'
      '1. 严格依据用户给出的本卦与变爻位置 (以及由此推出的变卦), 不要凭空增减.\n'
      '2. 若有变爻: 重点解读变爻的爻辞与含义, 同时给出"由本卦走向变卦"的过程性观察.\n'
      '3. 若无变爻: 重点落在本卦的卦辞与时位.\n'
      '4. 回到用户的问题, 联系当下处境给出可落地的判断与建议, 而不仅是经文翻译.\n'
      '5. 适度使用易学术语 (世应、卦象、互卦等) 但不喧宾夺主.\n'
      '6. 不预测吉凶式的命定结果, 强调"占以决疑, 而非定命".\n'
      '7. 不使用 emoji, 用中文回答.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(
          key: 'coin',
          name: '三钱法',
          description: '投掷三枚硬币六次, 自下而上起卦; 出现老阴/老阳则变爻.',
        ),
      ];

  @override
  String get defaultVariantKey => 'coin';

  @override
  int? get accentColorHex => 0xFF2E5C6E; // 青墨

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final tosses = [for (var i = 0; i < 6; i++) _tossOnce(_rng)];
    return _buildResultFromTosses(variantKey, tosses);
  }

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    const lineNameZh = ['初', '二', '三', '四', '五', '上'];
    const lineOptions = [
      ManualFieldOption(key: '7', label: '少阳 ⚊', subtitle: '本爻为阳, 不变'),
      ManualFieldOption(key: '8', label: '少阴 ⚋', subtitle: '本爻为阴, 不变'),
      ManualFieldOption(key: '9', label: '老阳 ⚊ → ⚋', subtitle: '阳变阴 (变爻)'),
      ManualFieldOption(key: '6', label: '老阴 ⚋ → ⚊', subtitle: '阴变阳 (变爻)'),
    ];
    return [
      for (var i = 0; i < 6; i++)
        ManualField(
          key: 'line_$i',
          label: '${lineNameZh[i]}爻 (第 ${i + 1} 爻, 自下而上)',
          kind: ManualFieldKind.picker,
          options: lineOptions,
          group: '${lineNameZh[i]}爻',
        ),
    ];
  }

  @override
  DivinationResult performManual({
    required String variantKey,
    required Map<String, String> selections,
  }) {
    final tosses = <int>[];
    for (var i = 0; i < 6; i++) {
      final raw = selections['line_$i'];
      final t = int.tryParse(raw ?? '');
      if (t == null || t < 6 || t > 9) {
        throw ArgumentError('第 ${i + 1} 爻还没选');
      }
      tosses.add(t);
    }
    return _buildResultFromTosses(variantKey, tosses);
  }

  DivinationResult _buildResultFromTosses(
      String variantKey, List<int> tosses) {
    assert(tosses.length == 6);
    final lines = StringBuffer();         // 本卦 binary, 自下而上
    final changedLines = StringBuffer();  // 变卦 binary
    final changingPositions = <int>[];    // 1-6, 1 为最底
    for (var i = 0; i < 6; i++) {
      final t = tosses[i];
      switch (t) {
        case 6:
          lines.write('0'); changedLines.write('1');
          changingPositions.add(i + 1);
          break;
        case 7: lines.write('1'); changedLines.write('1'); break;
        case 8: lines.write('0'); changedLines.write('0'); break;
        case 9:
          lines.write('1'); changedLines.write('0');
          changingPositions.add(i + 1);
          break;
        default:
          throw ArgumentError('invalid toss sum: $t');
      }
    }
    final original = _findByBinary(lines.toString());
    final hasChange = changingPositions.isNotEmpty;
    final derived = hasChange ? _findByBinary(changedLines.toString()) : null;

    const lineNameZh = ['初', '二', '三', '四', '五', '上'];
    final items = <DivinationItem>[];
    for (var i = 0; i < 6; i++) {
      final t = tosses[i];
      final isYang = lines.toString()[i] == '1';
      final isChanging = changingPositions.contains(i + 1);
      String typeLabel;
      switch (t) {
        case 6: typeLabel = '老阴 (变)'; break;
        case 7: typeLabel = '少阳'; break;
        case 8: typeLabel = '少阴'; break;
        case 9: typeLabel = '老阳 (变)'; break;
        default: typeLabel = '?';
      }
      items.add(DivinationItem(
        position: '${lineNameZh[i]}爻',
        positionHint: isChanging ? '变爻, 重点关注' : '本爻',
        name: isYang ? '⚊ 阳' : '⚋ 阴',
        subtitle: typeLabel,
        orientation: isChanging ? '变' : '静',
        keywords: const [],
        extra: {'tossSum': t, 'yang': isYang, 'changing': isChanging},
      ));
    }

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: '三钱法',
      items: items,
      extras: {
        'originalBinary': lines.toString(),
        'originalNumber': original.number,
        'originalName': original.nameZh,
        'originalPinyin': original.pinyin,
        'originalNameEn': original.nameEn,
        'originalJudgment': original.judgment,
        'originalImage': original.image,
        'originalUnicode': original.unicode,
        'changingLines': changingPositions,
        if (derived != null) ...{
          'derivedBinary': derived.binary,
          'derivedNumber': derived.number,
          'derivedName': derived.nameZh,
          'derivedPinyin': derived.pinyin,
          'derivedNameEn': derived.nameEn,
          'derivedJudgment': derived.judgment,
          'derivedImage': derived.image,
          'derivedUnicode': derived.unicode,
        },
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final changing = (ex['changingLines'] as List).cast<int>();
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(未明说, 请就当前能量给出整体判断)" : question.trim()}');
    buf.writeln();
    buf.writeln('起卦方式: 三枚铜钱法 (自下而上, 共 6 爻).');
    buf.writeln();
    buf.writeln('本卦: ${ex["originalUnicode"]} 第 ${ex["originalNumber"]} 卦 · '
        '${ex["originalName"]} (${ex["originalPinyin"]}, ${ex["originalNameEn"]})');
    buf.writeln('  卦辞: ${ex["originalJudgment"]}');
    buf.writeln('  象传: ${ex["originalImage"]}');
    buf.writeln();
    buf.writeln('六爻 (自下而上):');
    for (var i = 0; i < result.items.length; i++) {
      final it = result.items[i];
      buf.writeln('  ${it.position}: ${it.name}  ·  ${it.subtitle}');
    }
    buf.writeln();
    if (changing.isEmpty) {
      buf.writeln('无变爻, 以本卦卦辞与卦象为主进行解读.');
    } else {
      buf.writeln('变爻位置: ${changing.join(", ")} (自下而上).');
      buf.writeln();
      buf.writeln('变卦: ${ex["derivedUnicode"]} 第 ${ex["derivedNumber"]} 卦 · '
          '${ex["derivedName"]} (${ex["derivedPinyin"]}, ${ex["derivedNameEn"]})');
      buf.writeln('  卦辞: ${ex["derivedJudgment"]}');
      buf.writeln('  象传: ${ex["derivedImage"]}');
      buf.writeln();
      buf.writeln('请重点解读变爻的爻辞含义, 并描述"本卦 → 变卦"的过程性指引.');
    }
    buf.writeln();
    buf.writeln('请结合问题给出可落地的判断与建议. 后续可能继续追问, 请记住此卦.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    final changing = (ex['changingLines'] as List).cast<int>();
    final base = '${ex["originalUnicode"]} ${ex["originalName"]}';
    if (changing.isEmpty) return base;
    return '$base → ${ex["derivedUnicode"]} ${ex["derivedName"]} (变爻 ${changing.join(",")})';
  }
}
