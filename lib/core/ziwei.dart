// 紫微斗数 (ZiWei DouShu) - 基础排盘.
//
// 实现:
//   1. 阴历年月日 + 真太阳时(简化为本地时) → 12 宫位
//   2. 命宫 / 身宫定位 (寅起正月顺数月, 落点起子时逆/顺数时)
//   3. 五虎遁: 年干 → 寅月天干 → 命宫天干
//   4. 60 甲子纳音五行 → 五行局 (水二/木三/金四/土五/火六)
//   5. 紫微星定位 (五行局 + 阴历日 算法)
//   6. 紫微系 6 主星 + 天府系 8 主星 = 14 主星定位
//   7. 12 宫名 (命/兄/妻/子/财/疾/迁/仆/官/田/福/父, 逆时针)
//
// 未做:
//   - 六吉星 (左辅右弼天魁天钺文昌文曲)
//   - 六煞星 (擎羊陀罗火星铃星地空地劫)
//   - 四化 (禄权科忌)
//   - 大限 (10 年一宫)
//   - 小限 / 流年
//   交给 LLM 基于结构化盘面做后续推断.

import 'package:lunar/lunar.dart';
import 'divination.dart';

// 天干: 0=甲 1=乙 2=丙 3=丁 4=戊 5=己 6=庚 7=辛 8=壬 9=癸
const _ganNames = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
// 地支: 0=子 1=丑 2=寅 3=卯 4=辰 5=巳 6=午 7=未 8=申 9=酉 10=戌 11=亥
const _zhiNames = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

// 60 甲子的纳音五行 (index 0=甲子, 1=乙丑, ..., 59=癸亥)
// 对应五行局数: 水=2 木=3 金=4 土=5 火=6
const Map<int, int> _ganZhiToBureau = {
  // 索引区间 → 局数. 每 2 个干支共享一种纳音.
  0: 4, 1: 4,       // 甲子乙丑 海中金
  2: 6, 3: 6,       // 丙寅丁卯 炉中火
  4: 3, 5: 3,       // 戊辰己巳 大林木
  6: 5, 7: 5,       // 庚午辛未 路旁土
  8: 4, 9: 4,       // 壬申癸酉 剑锋金
  10: 6, 11: 6,     // 甲戌乙亥 山头火
  12: 2, 13: 2,     // 丙子丁丑 涧下水
  14: 5, 15: 5,     // 戊寅己卯 城头土
  16: 4, 17: 4,     // 庚辰辛巳 白蜡金
  18: 3, 19: 3,     // 壬午癸未 杨柳木
  20: 2, 21: 2,     // 甲申乙酉 泉中水
  22: 5, 23: 5,     // 丙戌丁亥 屋上土
  24: 6, 25: 6,     // 戊子己丑 霹雳火
  26: 3, 27: 3,     // 庚寅辛卯 松柏木
  28: 2, 29: 2,     // 壬辰癸巳 长流水
  30: 4, 31: 4,     // 甲午乙未 沙中金
  32: 6, 33: 6,     // 丙申丁酉 山下火
  34: 3, 35: 3,     // 戊戌己亥 平地木
  36: 5, 37: 5,     // 庚子辛丑 壁上土
  38: 4, 39: 4,     // 壬寅癸卯 金箔金
  40: 6, 41: 6,     // 甲辰乙巳 覆灯火
  42: 2, 43: 2,     // 丙午丁未 天河水
  44: 5, 45: 5,     // 戊申己酉 大驿土
  46: 4, 47: 4,     // 庚戌辛亥 钗钏金
  48: 3, 49: 3,     // 壬子癸丑 桑柘木
  50: 2, 51: 2,     // 甲寅乙卯 大溪水
  52: 5, 53: 5,     // 丙辰丁巳 沙中土
  54: 6, 55: 6,     // 戊午己未 天上火
  56: 3, 57: 3,     // 庚申辛酉 石榴木
  58: 2, 59: 2,     // 壬戌癸亥 大海水
};

const _bureauName = {
  2: '水二局',
  3: '木三局',
  4: '金四局',
  5: '土五局',
  6: '火六局',
};

const _bureauNayin = {
  2: '水',
  3: '木',
  4: '金',
  5: '土',
  6: '火',
};

/// 12 宫名 (从命宫开始, 逆时针).
const _palaceNames = [
  '命宫', '兄弟', '夫妻', '子女', '财帛', '疾厄',
  '迁移', '仆役', '官禄', '田宅', '福德', '父母',
];

// 五虎遁: 年干 → 寅月天干起
const _wuhudun = {
  0: 2, 5: 2,  // 甲己起丙 (寅月天干 = 丙)
  1: 4, 6: 4,  // 乙庚起戊
  2: 6, 7: 6,  // 丙辛起庚
  3: 8, 8: 8,  // 丁壬起壬
  4: 0, 9: 0,  // 戊癸起甲
};

/// 求 (gan, zhi) 在 60 甲子中的索引 0-59.
int _ganZhiIdx(int gan, int zhi) {
  for (var i = 0; i < 60; i++) {
    if (i % 10 == gan && i % 12 == zhi) return i;
  }
  return -1;
}

/// 时辰编号: 23:00-0:59 = 子(0), 1:00-2:59 = 丑(1), ..., 21:00-22:59 = 亥(11).
int _hourToZhi(int hour) {
  if (hour == 23 || hour == 0) return 0;
  return ((hour + 1) ~/ 2);
}

/// 命宫地支号 = (寅 + month - 1) - hourIdx, 调正 mod 12.
/// 月落点 = (1 + month) mod 12 = 寅(2) 起正月 顺数 (month-1) 位.
/// 命宫 = 月落点 起子时 逆数 hourIdx 位.
int _mingPalaceZhi(int lunarMonth, int hourIdx) {
  final monthAnchor = (1 + lunarMonth) % 12;
  return ((monthAnchor - hourIdx) % 12 + 12) % 12;
}

/// 身宫 = 月落点 顺数 hourIdx 位.
int _shenPalaceZhi(int lunarMonth, int hourIdx) {
  final monthAnchor = (1 + lunarMonth) % 12;
  return (monthAnchor + hourIdx) % 12;
}

/// 命宫天干: 由年干 + 五虎遁 推出寅月天干, 然后顺数到命宫地支.
int _mingPalaceGan(int yearGan, int mingZhi) {
  final yinGan = _wuhudun[yearGan]!;
  // 寅 (zhi 2) 起寅月, 顺数到 mingZhi 共多少位
  final offset = (mingZhi - 2 + 12) % 12;
  return (yinGan + offset) % 10;
}

/// 紫微地支号. 算法:
///   q = ceil(lunarDay / bureau)
///   r = q * bureau - lunarDay
///   若 r 偶数: 顺数 r 位 = (寅 + q - 1 + r) mod 12
///   若 r 奇数: 逆数 r 位 = (寅 + q - 1 - r) mod 12
int _ziWeiZhi(int bureau, int lunarDay) {
  final q = (lunarDay + bureau - 1) ~/ bureau; // ceil
  final r = q * bureau - lunarDay;
  const base = 2; // 寅
  if (r % 2 == 0) {
    return (base + q - 1 + r) % 12;
  } else {
    return ((base + q - 1 - r) % 12 + 12) % 12;
  }
}

class _StarPlacement {
  final String name;
  final int zhi;
  const _StarPlacement(this.name, this.zhi);
}

/// 紫微系 6 主星: 紫微, 天机, 太阳, 武曲, 天同, 廉贞.
/// 相对紫微位置 offset:  0   -1   -3   -4   -5   -8
List<_StarPlacement> _ziWeiSystem(int z) {
  int mod(int x) => ((x % 12) + 12) % 12;
  return [
    _StarPlacement('紫微', z),
    _StarPlacement('天机', mod(z - 1)),
    _StarPlacement('太阳', mod(z - 3)),
    _StarPlacement('武曲', mod(z - 4)),
    _StarPlacement('天同', mod(z - 5)),
    _StarPlacement('廉贞', mod(z - 8)),
  ];
}

/// 天府 = (12 - 紫微) mod 12.
/// 天府系 8 主星: 天府, 太阴, 贪狼, 巨门, 天相, 天梁, 七杀, 破军.
/// 相对天府 offset: 0  +1  +2  +3  +4  +5  +6  +10
List<_StarPlacement> _tianFuSystem(int z) {
  final t = ((12 - z) % 12 + 12) % 12;
  int mod(int x) => ((x % 12) + 12) % 12;
  return [
    _StarPlacement('天府', t),
    _StarPlacement('太阴', mod(t + 1)),
    _StarPlacement('贪狼', mod(t + 2)),
    _StarPlacement('巨门', mod(t + 3)),
    _StarPlacement('天相', mod(t + 4)),
    _StarPlacement('天梁', mod(t + 5)),
    _StarPlacement('七杀', mod(t + 6)),
    _StarPlacement('破军', mod(t + 10)),
  ];
}

class ZiWeiEngine extends DivinationEngine {
  @override String get id => 'ziwei';
  @override String get nameZh => '紫微斗数';
  @override String get nameEn => 'ZiWei DouShu';
  @override String get emoji => '✶';
  @override String get tagline => '14 主星 · 12 宫';
  @override String get description =>
      '中国紫微斗数, 由出生时辰落 12 宫, 14 颗主星按五行局与阴历日定位. '
      '本应用使用 lunar 库做阴历换算 + 经典安星法定主星位置, 出基础盘 '
      '(命/身宫, 五行局, 紫微星, 14 主星, 12 宫名). 六吉六煞与四化、大限 '
      '由 LLM 基于盘面继续推断.';

  @override int? get accentColorHex => 0xFF5C2E91; // 紫微紫

  @override bool get hasStandaloneResult => true;

  @override
  String get systemPrompt =>
      '你是一位精研紫微斗数的命理师. 用户给出的命盘 (12 宫 + 14 主星位置 + 五行局) '
      '已由专业算法准确排出, 不要怀疑或重排.\n'
      '\n阅读规则:\n'
      '1. 重点解读: 命宫主星格局 / 身宫主星 / 三方四正 (命宫 + 迁移 + 财帛 + 官禄 这四宫的星) / '
      '夫妻宫 + 财帛宫 + 官禄宫 + 福德宫 的主星.\n'
      '2. 如果某宫无主星, 说明该宫"借对宫" (取对宫的星看), 不要回避.\n'
      '3. 你可以补充常见的六吉六煞与四化推断 (基于年干), 但要标注"基于训练知识推断, 非本应用算出".\n'
      '4. 联系用户的具体方向 (事业/感情/财运) 给出可落地的判断与建议.\n'
      '5. 不预测命定式吉凶, 不报具体年份, 强调"命有方向, 运在己".\n'
      '6. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'overall',  name: '整体格局', description: '命宫主星 + 三方四正 + 主要宫位概览.'),
        DivinationVariant(key: 'career',   name: '事业财运', description: '聚焦官禄宫 + 财帛宫 + 田宅宫.'),
        DivinationVariant(key: 'relation', name: '感情婚姻', description: '聚焦夫妻宫 + 子女宫 + 福德宫.'),
        DivinationVariant(key: 'health',   name: '健康体质', description: '聚焦疾厄宫 + 命宫主星 + 五行局.'),
      ];

  @override
  List<InputField> get inputs => const [
        InputField(
          key: 'birthdate',
          label: '公历出生日期',
          hint: 'YYYY-MM-DD',
          type: InputFieldType.date,
          required: true,
        ),
        InputField(
          key: 'birthtime',
          label: '出生时辰',
          hint: 'HH:MM (紫微必须有时辰, 否则命/身宫不准)',
          type: InputFieldType.text,
          required: true,
        ),
        InputField(
          key: 'birthplace',
          label: '出生地点',
          hint: '例: 浙江杭州 (用于真太阳时, 可留空)',
          type: InputFieldType.location,
        ),
        InputField(
          key: 'gender',
          label: '性别',
          hint: '男 / 女',
          type: InputFieldType.text,
        ),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final variantName = variants.firstWhere((v) => v.key == variantKey).name;
    final birthdate = (inputs['birthdate'] ?? '').trim();
    final birthtime = (inputs['birthtime'] ?? '').trim();
    final gender = (inputs['gender'] ?? '').trim();
    final birthplace = (inputs['birthplace'] ?? '').trim();

    if (birthdate.isEmpty || birthtime.isEmpty) {
      throw ArgumentError('紫微必须提供准确的出生日期和时辰');
    }
    final dm = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(birthdate);
    final tm = RegExp(r'^(\d{1,2})\D(\d{1,2})').firstMatch(birthtime);
    if (dm == null || tm == null) {
      throw ArgumentError('日期或时辰格式不对');
    }
    final y = int.parse(dm.group(1)!);
    final mo = int.parse(dm.group(2)!);
    final d = int.parse(dm.group(3)!);
    final hour = int.parse(tm.group(1)!);
    final minute = int.parse(tm.group(2)!);

    // 阳历 → 阴历
    final solar = Solar.fromYmdHms(y, mo, d, hour, minute, 0);
    final lunar = solar.getLunar();
    final lunarMonth = lunar.getMonth().abs(); // 闰月用绝对值
    final lunarDay = lunar.getDay();
    final hourZhi = _hourToZhi(hour);

    // 年柱
    final yearGz = lunar.getEightChar().getYear();
    final yearGanCh = yearGz.substring(0, 1);
    final yearGan = _ganNames.indexOf(yearGanCh);

    // 命宫 / 身宫
    final mingZhi = _mingPalaceZhi(lunarMonth, hourZhi);
    final shenZhi = _shenPalaceZhi(lunarMonth, hourZhi);
    final mingGan = _mingPalaceGan(yearGan, mingZhi);
    final mingGanZhi = '${_ganNames[mingGan]}${_zhiNames[mingZhi]}';

    // 五行局
    final mingGzIdx = _ganZhiIdx(mingGan, mingZhi);
    final bureau = _ganZhiToBureau[mingGzIdx] ?? 4;
    final bureauName = _bureauName[bureau]!;

    // 紫微 + 14 主星
    final ziWei = _ziWeiZhi(bureau, lunarDay);
    final ziSys = _ziWeiSystem(ziWei);
    final tfSys = _tianFuSystem(ziWei);
    final allStars = [...ziSys, ...tfSys];

    // 12 宫 (从 命宫 逆时针)
    // 第 i 宫 (0=命, 1=兄, ...) 的地支 = (mingZhi - i + 12) mod 12
    final palaces = <Map<String, dynamic>>[];
    final items = <DivinationItem>[];
    for (var i = 0; i < 12; i++) {
      final palaceZhi = ((mingZhi - i) % 12 + 12) % 12;
      final palaceGan = _mingPalaceGan(yearGan, palaceZhi);
      final palaceName = _palaceNames[i];
      // 该宫的主星
      final stars = allStars.where((s) => s.zhi == palaceZhi).map((s) => s.name).toList();
      palaces.add({
        'name': palaceName,
        'zhi': _zhiNames[palaceZhi],
        'gan': _ganNames[palaceGan],
        'ganZhi': '${_ganNames[palaceGan]}${_zhiNames[palaceZhi]}',
        'stars': stars,
        'isMing': i == 0,
        'isShen': palaceZhi == shenZhi,
      });
      items.add(DivinationItem(
        position: palaceName,
        positionHint: i == 0 ? '本宫, 看整体性格与命主能量' : '',
        name: '${_ganNames[palaceGan]}${_zhiNames[palaceZhi]}',
        subtitle: stars.isEmpty ? '(无主星, 借对宫)' : stars.join(' · '),
        keywords: stars,
        extra: {'palace': palaceName, 'zhi': _zhiNames[palaceZhi]},
      ));
    }

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: items,
      extras: {
        'birthdate': birthdate,
        'birthtime': birthtime,
        'birthplace': birthplace,
        'gender': gender,
        'focus': variantName,
        'lunarDate': '${lunar.getYearInChinese()}年 ${lunar.getMonthInChinese()}月 ${lunar.getDayInChinese()}',
        'yearGanZhi': yearGz,
        'mingPalace': mingGanZhi,
        'shenPalaceZhi': _zhiNames[shenZhi],
        'bureau': bureauName,
        'bureauElement': _bureauNayin[bureau],
        'ziWeiZhi': _zhiNames[ziWei],
        'palaces': palaces,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final palaces = (ex['palaces'] as List).cast<Map>();
    final buf = StringBuffer();
    buf.writeln('请基于以下精确排出的紫微命盘给我做解读.');
    buf.writeln();
    buf.writeln('阳历: ${ex["birthdate"]} ${ex["birthtime"]}');
    buf.writeln('农历: ${ex["lunarDate"]}');
    buf.writeln('年柱: ${ex["yearGanZhi"]}');
    if ((ex['gender'] as String).isNotEmpty) buf.writeln('性别: ${ex["gender"]}');
    if ((ex['birthplace'] as String).isNotEmpty) buf.writeln('出生地: ${ex["birthplace"]}');
    buf.writeln();
    buf.writeln('命宫: ${ex["mingPalace"]}');
    buf.writeln('身宫地支: ${ex["shenPalaceZhi"]}');
    buf.writeln('五行局: ${ex["bureau"]}');
    buf.writeln('紫微星落: ${ex["ziWeiZhi"]}');
    buf.writeln();
    buf.writeln('12 宫排盘:');
    for (final p in palaces) {
      final markers = <String>[];
      if (p['isMing'] == true) markers.add('★命');
      if (p['isShen'] == true) markers.add('身');
      final stars = (p['stars'] as List).isEmpty
          ? '(无主星)'
          : (p['stars'] as List).join('·');
      buf.writeln('  ${p["name"]} (${p["ganZhi"]}) ${markers.join("")} : $stars');
    }
    buf.writeln();
    buf.writeln('关注方向: ${ex["focus"]}');
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
    }
    buf.writeln();
    buf.writeln('请按紫微斗数: '
        '\n1. 命宫主星 (或无主星情况) + 三方四正 (命/迁/财/官) 的格局, '
        '\n2. 身宫主星, 解读后半生重点, '
        '\n3. 关注方向对应的宫位 (事业看官禄+财帛, 感情看夫妻+福德, etc.), '
        '\n4. 若有训练知识可补充, 标注"基于训练知识, 非算出": 六吉六煞与四化推断, '
        '\n5. 不预测命定式吉凶, 给方向与可执行建议.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '命宫 ${ex["mingPalace"]} · ${ex["bureau"]} · 紫微在${ex["ziWeiZhi"]}';
  }
}
