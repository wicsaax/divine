// 西洋占星 - 用 Swiss Ephemeris (sweph package) 算真本命盘.
//
// 已实现:
//   - 十大行星 (日月水金火木土天海冥) 黄经
//   - 12 星座定位 (热带黄道)
//   - Placidus 宫位制 (12 cusps + ASC + MC)
//   - 主要相位 (合相 / 对分 / 三分 / 四分 / 六合) 含 orb
//
// 未实现 (列入 roadmap):
//   - 凯龙、北交点、宿命点等次要星体
//   - 中点 (midpoint) 分析
//   - 配宫制其他选择 (整宫制 / 等宫制)
//   - 推运 / 太阳弧 / 行运

import 'package:sweph/sweph.dart';

import 'astrology_cities.dart';
import 'divination.dart';

const _zodiacSigns = [
  '白羊', '金牛', '双子', '巨蟹', '狮子', '处女',
  '天秤', '天蝎', '射手', '摩羯', '水瓶', '双鱼',
];

const _planets = [
  (HeavenlyBody.SE_SUN,     '太阳'),
  (HeavenlyBody.SE_MOON,    '月亮'),
  (HeavenlyBody.SE_MERCURY, '水星'),
  (HeavenlyBody.SE_VENUS,   '金星'),
  (HeavenlyBody.SE_MARS,    '火星'),
  (HeavenlyBody.SE_JUPITER, '木星'),
  (HeavenlyBody.SE_SATURN,  '土星'),
  (HeavenlyBody.SE_URANUS,  '天王星'),
  (HeavenlyBody.SE_NEPTUNE, '海王星'),
  (HeavenlyBody.SE_PLUTO,   '冥王星'),
];

/// 主要相位定义: (名称, 角度, 容许 orb).
const List<(String, double, double)> _aspects = [
  ('合相', 0.0,   8.0),
  ('对分', 180.0, 8.0),
  ('三分', 120.0, 7.0),
  ('四分', 90.0,  7.0),
  ('六合', 60.0,  5.0),
];

bool _swephInited = false;

Future<void> _ensureSwephInit() async {
  if (_swephInited) return;
  await Sweph.init();
  _swephInited = true;
}

String _formatSign(double longitude) {
  final l = ((longitude % 360) + 360) % 360;
  final signIdx = (l / 30).floor();
  final deg = l - signIdx * 30;
  final degInt = deg.floor();
  final minInt = ((deg - degInt) * 60).floor();
  return '${_zodiacSigns[signIdx]} $degInt°${minInt.toString().padLeft(2, "0")}\'';
}

int _signIndex(double longitude) {
  final l = ((longitude % 360) + 360) % 360;
  return (l / 30).floor();
}

/// 行星 P 在第几宫? cusps[1..12] 是 12 宫起点黄经.
int _houseOf(double planetLon, List<double> cusps) {
  final l = ((planetLon % 360) + 360) % 360;
  for (var i = 1; i <= 12; i++) {
    final a = ((cusps[i] % 360) + 360) % 360;
    final b = ((cusps[i == 12 ? 1 : i + 1] % 360) + 360) % 360;
    if (a <= b) {
      if (l >= a && l < b) return i;
    } else {
      // 跨 0 度
      if (l >= a || l < b) return i;
    }
  }
  return 1;
}

class AstrologyEngine extends DivinationEngine {
  @override String get id => 'astrology';
  @override String get nameZh => '西洋占星';
  @override String get nameEn => 'Astrology';
  @override String get emoji => '🪐';
  @override String get tagline => '本命盘 · 真黄经';
  @override String get description =>
      '西方占星学本命盘. 本应用使用 Swiss Ephemeris (瑞士星历表) 计算十大行星'
      '在出生时刻的精确黄经, 用 Placidus 宫位制划 12 宫, 并自动识别主要相位. '
      '需要准确的出生时间 (到分钟) 和出生城市.';

  @override int? get accentColorHex => 0xFF2E3A6E;

  @override bool get hasStandaloneResult => true;

  @override
  String get systemPrompt =>
      '你是一位资深的西洋占星师, 既懂传统占星 (Hellenistic / Medieval) '
      '也熟悉现代心理占星 (Jung / Greene / Hand). 风格深刻但克制.\n'
      '\n阅读规则:\n'
      '1. 用户给的本命盘 (行星黄经、星座、宫位、相位) 已由 Swiss Ephemeris '
      '精确算出, 直接接受.\n'
      '2. 重点解读: 太阳/月亮/上升三大要素 (人格三柱); 显著行星宫位; 主要相位 '
      '(尤其合相、对分、三分、四分).\n'
      '3. 如果用户问的是具体方向 (事业 10 宫、感情 5/7 宫、家庭 4 宫等), 围绕该宫位与相关行星展开.\n'
      '4. 区分本命 (底色) 与行运 (当下天空的压力). 用户问"最近"时简短提一下当下行运.\n'
      '5. 不预测命定式吉凶, 强调原型与选择.\n'
      '6. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'natal_overview', name: '本命盘整体', description: '太阳/月亮/上升 + 行星宫位 + 主要相位.'),
        DivinationVariant(key: 'career',         name: '事业 (10 宫)', description: 'MC + 10 宫 + 6 宫 + 工作星.'),
        DivinationVariant(key: 'love',           name: '感情 (5/7 宫)', description: '金星 + 火星 + 5/7 宫相位.'),
        DivinationVariant(key: 'family',         name: '家庭 (4 宫)', description: 'IC + 4 宫 + 月亮.'),
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
          label: '出生时间',
          hint: 'HH:MM (越精确越好, 上升/宫位才准)',
          type: InputFieldType.text,
          required: true,
        ),
        InputField(
          key: 'birthplace',
          label: '出生城市',
          hint: '例: 上海 / Tokyo / 31.23,121.47 (lat,lon[,tz])',
          type: InputFieldType.location,
          required: true,
        ),
      ];

  @override
  Future<DivinationResult> perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) async {
    await _ensureSwephInit();
    final variantName = variants.firstWhere((v) => v.key == variantKey).name;
    final birthdate = (inputs['birthdate'] ?? '').trim();
    final birthtime = (inputs['birthtime'] ?? '').trim();
    final birthplace = (inputs['birthplace'] ?? '').trim();

    if (birthdate.isEmpty || birthtime.isEmpty || birthplace.isEmpty) {
      throw ArgumentError('日期、时间、城市三项都必填');
    }
    final dm = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(birthdate);
    final tm = RegExp(r'^(\d{1,2})\D(\d{1,2})').firstMatch(birthtime);
    if (dm == null || tm == null) {
      throw ArgumentError('日期或时间格式不对');
    }
    final y = int.parse(dm.group(1)!);
    final mo = int.parse(dm.group(2)!);
    final d = int.parse(dm.group(3)!);
    final h = int.parse(tm.group(1)!);
    final mi = int.parse(tm.group(2)!);

    final city = parseLatLon(birthplace) ?? findCity(birthplace);
    if (city == null) {
      throw ArgumentError(
        '城市未识别: $birthplace\n请使用城市名或直接填经纬度, 例: "31.23,121.47"',
      );
    }

    // 本地时间 → UT (减时区)
    final localHourDec = h + mi / 60.0;
    final utHourDec = localHourDec - city.tzHours;

    // Julian Day (UT)
    final jd = Sweph.swe_julday(y, mo, d, utHourDec, CalendarType.SE_GREG_CAL);

    final flags = SwephFlag.SEFLG_SPEED | SwephFlag.SEFLG_SWIEPH;

    // 计算各行星
    final planetData = <Map<String, dynamic>>[];
    for (final (body, name) in _planets) {
      final pos = Sweph.swe_calc_ut(jd, body, flags);
      planetData.add({
        'name': name,
        'longitude': pos.longitude,
        'speed': pos.speedInLongitude,
        'sign': _zodiacSigns[_signIndex(pos.longitude)],
        'signFormatted': _formatSign(pos.longitude),
        'retrograde': pos.speedInLongitude < 0,
      });
    }

    // Placidus 宫位
    final houseData = Sweph.swe_houses_ex(
      jd,
      flags,
      city.lat,
      city.lon,
      Hsys.P,
    );
    final cusps = houseData.cusps;       // [0..12] (index 1 is ASC, 10 is MC)
    final ascmc = houseData.ascmc;       // [0]=ASC [1]=MC

    // 给每个行星标注宫位
    for (final p in planetData) {
      p['house'] = _houseOf(p['longitude'] as double, cusps);
    }

    final ascLon = ascmc[0];
    final mcLon = ascmc[1];
    final natalSunLon = planetData.firstWhere((p) => p['name'] == '太阳')['longitude'] as double;

    // ====================== 深化计算 ======================
    // 现在的儒略日 (UT)
    final now = DateTime.now().toUtc();
    final jdNow = Sweph.swe_julday(
      now.year, now.month, now.day,
      now.hour + now.minute / 60.0,
      CalendarType.SE_GREG_CAL,
    );

    // 行运 (Transits): 当前各行星黄经
    final transits = <Map<String, dynamic>>[];
    for (final (body, name) in _planets) {
      final pos = Sweph.swe_calc_ut(jdNow, body, flags);
      transits.add({
        'name': name,
        'longitude': pos.longitude,
        'sign': _zodiacSigns[_signIndex(pos.longitude)],
        'signFormatted': _formatSign(pos.longitude),
        'retrograde': pos.speedInLongitude < 0,
      });
    }

    // 行运 → 本命相位 (发现当下天空怎样压本命)
    final transitAspects = <Map<String, dynamic>>[];
    for (var i = 0; i < transits.length; i++) {
      for (var j = 0; j < planetData.length; j++) {
        // 慢星 (木土天海冥) 的 transit 对本命快星更有意义
        // 这里全跑, LLM 自己取舍.
        final a = transits[i]['longitude'] as double;
        final b = planetData[j]['longitude'] as double;
        var diff = (a - b).abs() % 360;
        if (diff > 180) diff = 360 - diff;
        for (final (aspName, aspAngle, aspOrb) in _aspects) {
          // 行运相位用更紧的 orb (3-4°)
          final tightOrb = (aspOrb * 0.5).clamp(2.0, 5.0);
          if ((diff - aspAngle).abs() <= tightOrb) {
            transitAspects.add({
              'transitPlanet': transits[i]['name'],
              'natalPlanet': planetData[j]['name'],
              'aspect': aspName,
              'angle': aspAngle,
              'orb': (diff - aspAngle).abs(),
            });
            break;
          }
        }
      }
    }

    // 二次推运 (Secondary Progressions): 一日 = 一年
    // 出生后 N 天的天象 = 第 N 年的人生
    final ageYears = (now.toUtc().difference(DateTime.utc(y, mo, d, h, mi)).inDays) / 365.25;
    final ageInt = ageYears.floor();
    final jdProgressed = jd + ageInt.toDouble(); // jd + ageInt 日
    final progressions = <Map<String, dynamic>>[];
    for (final (body, name) in _planets) {
      final pos = Sweph.swe_calc_ut(jdProgressed, body, flags);
      progressions.add({
        'name': name,
        'longitude': pos.longitude,
        'signFormatted': _formatSign(pos.longitude),
      });
    }

    // 太阳弧 (Solar Arc Direction): 当前太阳 - 本命太阳 = 弧度. 所有本命行星 + 弧度 = 太阳弧推运.
    final solarArc = (() {
      var arc = (transits.first['longitude'] as double) - natalSunLon;
      arc = ((arc % 360) + 360) % 360;
      return arc;
    })();
    final solarArcPositions = <Map<String, dynamic>>[];
    for (final p in planetData) {
      final lon = ((p['longitude'] as double) + solarArc) % 360;
      solarArcPositions.add({
        'name': p['name'],
        'longitude': lon,
        'signFormatted': _formatSign(lon),
      });
    }

    // 中点 (Midpoints): 最常用的几个 (而非全部 45 对)
    double midpoint(double a, double b) {
      var diff = (b - a + 360) % 360;
      if (diff > 180) diff = diff - 360; // 取短弧
      return ((a + diff / 2) % 360 + 360) % 360;
    }
    double lonOf(String n) =>
        planetData.firstWhere((p) => p['name'] == n)['longitude'] as double;
    final midpointPairs = [
      ('太阳', '月亮', '心灵/伴侣轴'),
      ('金星', '火星', '爱欲/吸引轴'),
      ('太阳', '土星', '责任/老化轴'),
      ('月亮', '土星', '情感约束'),
      ('木星', '土星', '扩张-收缩'),
      ('水星', '金星', '思想-审美'),
    ];
    final midpoints = <Map<String, dynamic>>[];
    for (final (a, b, theme) in midpointPairs) {
      final lon = midpoint(lonOf(a), lonOf(b));
      midpoints.add({
        'pair': '$a / $b',
        'theme': theme,
        'longitude': lon,
        'signFormatted': _formatSign(lon),
      });
    }
    // ASC/MC 中点也常被关注
    midpoints.add({
      'pair': 'ASC / MC',
      'theme': '社会角色与个人形象的轴中点',
      'longitude': midpoint(ascLon, mcLon),
      'signFormatted': _formatSign(midpoint(ascLon, mcLon)),
    });

    // 相位 (planet × planet)
    final aspectList = <Map<String, dynamic>>[];
    for (var i = 0; i < planetData.length; i++) {
      for (var j = i + 1; j < planetData.length; j++) {
        final a = planetData[i]['longitude'] as double;
        final b = planetData[j]['longitude'] as double;
        var diff = (a - b).abs() % 360;
        if (diff > 180) diff = 360 - diff;
        for (final (aspName, aspAngle, aspOrb) in _aspects) {
          if ((diff - aspAngle).abs() <= aspOrb) {
            aspectList.add({
              'a': planetData[i]['name'],
              'b': planetData[j]['name'],
              'aspect': aspName,
              'angle': aspAngle,
              'orb': (diff - aspAngle).abs(),
            });
            break;
          }
        }
      }
    }

    // 构造 12 宫信息
    final houses = <Map<String, dynamic>>[];
    for (var i = 1; i <= 12; i++) {
      houses.add({
        'num': i,
        'cuspLongitude': cusps[i],
        'cuspFormatted': _formatSign(cusps[i]),
        'planets': planetData
            .where((p) => p['house'] == i)
            .map((p) => p['name'] as String)
            .toList(),
      });
    }

    final items = <DivinationItem>[];
    for (final p in planetData) {
      items.add(DivinationItem(
        position: p['name'] as String,
        positionHint: '',
        name: p['signFormatted'] as String,
        subtitle: '第 ${p["house"]} 宫${(p["retrograde"] as bool) ? "  ·  逆行" : ""}',
        keywords: const [],
        extra: {
          'longitude': p['longitude'],
          'house': p['house'],
          'retrograde': p['retrograde'],
        },
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
        'birthplace': '${city.name} (${city.lat.toStringAsFixed(2)}, ${city.lon.toStringAsFixed(2)}, tz +${city.tzHours})',
        'focus': variantName,
        'julianDay': jd,
        'ascendant': _formatSign(ascLon),
        'mc': _formatSign(mcLon),
        'planets': planetData,
        'houses': houses,
        'aspects': aspectList,
        // 深化计算
        'ageYears': ageYears,
        'transits': transits,
        'transitAspects': transitAspects,
        'progressions': progressions,
        'solarArc': solarArc,
        'solarArcPositions': solarArcPositions,
        'midpoints': midpoints,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final planets = (ex['planets'] as List).cast<Map>();
    final houses = (ex['houses'] as List).cast<Map>();
    final aspects = (ex['aspects'] as List).cast<Map>();
    final transits = (ex['transits'] as List?)?.cast<Map>() ?? const [];
    final transitAspects = (ex['transitAspects'] as List?)?.cast<Map>() ?? const [];
    final progressions = (ex['progressions'] as List?)?.cast<Map>() ?? const [];
    final solarArcPositions = (ex['solarArcPositions'] as List?)?.cast<Map>() ?? const [];
    final midpoints = (ex['midpoints'] as List?)?.cast<Map>() ?? const [];
    final ageYears = (ex['ageYears'] as double?) ?? 0;
    final variantKey = result.variantKey;

    final buf = StringBuffer();
    buf.writeln('请基于以下由 Swiss Ephemeris 精确算出的本命盘 + 深化推运给我做深度解读.');
    buf.writeln();
    buf.writeln('阳历: ${ex["birthdate"]} ${ex["birthtime"]}');
    buf.writeln('出生地: ${ex["birthplace"]}');
    buf.writeln('当前年龄: ${ageYears.toStringAsFixed(1)} 岁');
    buf.writeln();
    buf.writeln('=== 本命盘 ===');
    buf.writeln('上升 (ASC): ${ex["ascendant"]}');
    buf.writeln('中天 (MC):  ${ex["mc"]}');
    buf.writeln();
    buf.writeln('十大行星 (本命):');
    for (final p in planets) {
      final retro = (p['retrograde'] as bool) ? ' ☋' : '';
      buf.writeln('  ${p["name"]}: ${p["signFormatted"]} · 第${p["house"]}宫$retro');
    }
    buf.writeln();
    buf.writeln('本命主要相位:');
    if (aspects.isEmpty) {
      buf.writeln('  (无显著相位)');
    } else {
      for (final a in aspects) {
        final orb = (a['orb'] as double).toStringAsFixed(1);
        buf.writeln('  ${a["a"]} ${a["aspect"]} ${a["b"]}  (orb $orb°)');
      }
    }
    buf.writeln();
    buf.writeln('12 宫起点:');
    for (final h in houses) {
      final planetsHere = (h['planets'] as List).isEmpty
          ? ''
          : '  含星: ${(h["planets"] as List).join("·")}';
      buf.writeln('  第${h["num"]}宫 起 ${h["cuspFormatted"]}$planetsHere');
    }
    buf.writeln();
    buf.writeln('=== 深化推运 (Transit / Progression / Solar Arc / Midpoints) ===');

    // 行运 (transit_variant 时着重, 其他变体也展示但简短)
    if (transits.isNotEmpty) {
      buf.writeln('当下行运 (Transits, 此刻天空):');
      for (final t in transits) {
        final retro = (t['retrograde'] as bool? ?? false) ? ' ☋' : '';
        buf.writeln('  ${t["name"]}: ${t["signFormatted"]}$retro');
      }
    }
    if (transitAspects.isNotEmpty) {
      buf.writeln();
      buf.writeln('行运 → 本命的紧密相位 (orb < 5°):');
      for (final a in transitAspects.take(15)) {
        final orb = (a['orb'] as double).toStringAsFixed(1);
        buf.writeln('  行运${a["transitPlanet"]} ${a["aspect"]} 本命${a["natalPlanet"]} (orb $orb°)');
      }
      if (transitAspects.length > 15) {
        buf.writeln('  ... 还有 ${transitAspects.length - 15} 条 (略)');
      }
    }

    // 推运 (二次推运)
    if (progressions.isNotEmpty) {
      buf.writeln();
      buf.writeln('二次推运 (Secondary Progressions, "一日一年"法, 内在成熟):');
      for (final p in progressions) {
        buf.writeln('  推运${p["name"]}: ${p["signFormatted"]}');
      }
    }

    // 太阳弧
    final arc = ex['solarArc'] as double?;
    if (arc != null) {
      buf.writeln();
      buf.writeln('太阳弧 (Solar Arc Direction, 弧度 ${arc.toStringAsFixed(2)}°, 外在事件):');
      for (final p in solarArcPositions) {
        buf.writeln('  太阳弧${p["name"]}: ${p["signFormatted"]}');
      }
    }

    // 中点
    if (midpoints.isNotEmpty) {
      buf.writeln();
      buf.writeln('关键中点 (Midpoints):');
      for (final m in midpoints) {
        buf.writeln('  ${m["pair"]} 中点: ${m["signFormatted"]}  (${m["theme"]})');
      }
    }

    buf.writeln();
    buf.writeln('关注方向: ${ex["focus"]}');
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
    }
    buf.writeln();
    buf.writeln('请按现代心理占星 + 传统占星综合深度解读: '
        '\n1. **本命底色**: 太阳/月亮/上升三柱组合的人格底色 + 关键行星落宫的实际意义, '
        '\n2. **本命相位张力**: 紧张相位 (对分/四分) 是终生功课, 流畅相位 (三分/六合) 是天赋通道, '
        '\n3. **当下行运**: 行运 → 本命 的紧密相位反映现在天空对你的"敲门" — 哪些慢星 (土天海冥) 正在压本命哪颗, '
        '\n4. **内在成熟 (推运)**: 推运月亮 (~28年一轮) + 推运太阳的星座是当前阶段的内在主题, '
        '\n5. **外在事件 (太阳弧)**: 太阳弧推运的行星位置往往对应可见的人生事件节点, '
        '\n6. **中点**: 关键中点 (尤其太阳/月亮中点 + 金星/火星中点) 揭示一些核心议题, '
        '\n7. 若关注方向是 ${variantKey == "career" ? "事业 (10宫 + MC + 行运 → 10宫)" : variantKey == "love" ? "感情 (金星/火星 + 5/7宫 + 行运)" : variantKey == "family" ? "家庭 (4宫 + IC + 月亮)" : "整体"}, 重点回应, '
        '\n8. 不预测命定吉凶, 给原型理解 + 可行动建议.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    final planets = (ex['planets'] as List).cast<Map>();
    final sun = planets.firstWhere((p) => p['name'] == '太阳');
    final moon = planets.firstWhere((p) => p['name'] == '月亮');
    return '☉${sun["signFormatted"]} ☽${moon["signFormatted"]} ↑${ex["ascendant"]}';
  }
}
