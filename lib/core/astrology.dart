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
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final planets = (ex['planets'] as List).cast<Map>();
    final houses = (ex['houses'] as List).cast<Map>();
    final aspects = (ex['aspects'] as List).cast<Map>();
    final buf = StringBuffer();
    buf.writeln('请基于以下由 Swiss Ephemeris 精确算出的本命盘给我做解读.');
    buf.writeln();
    buf.writeln('阳历: ${ex["birthdate"]} ${ex["birthtime"]}');
    buf.writeln('出生地: ${ex["birthplace"]}');
    buf.writeln();
    buf.writeln('上升 (ASC): ${ex["ascendant"]}');
    buf.writeln('中天 (MC):  ${ex["mc"]}');
    buf.writeln();
    buf.writeln('十大行星 (黄经度数 · 星座 · 宫位):');
    for (final p in planets) {
      final retro = (p['retrograde'] as bool) ? ' ☋' : '';
      buf.writeln('  ${p["name"]}: ${p["signFormatted"]} · 第${p["house"]}宫$retro');
    }
    buf.writeln();
    buf.writeln('主要相位 (容许 orb 内):');
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
    buf.writeln('关注方向: ${ex["focus"]}');
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
    }
    buf.writeln();
    buf.writeln('请按现代心理占星 + 传统占星综合解读: '
        '\n1. 太阳/月亮/上升三柱组合的人格底色, '
        '\n2. 关键行星所落星座 + 宫位的实际意义, '
        '\n3. 主要相位 (尤其紧张相位 — 对分/四分) 反映的内在张力, '
        '\n4. 若关注方向是事业/感情/家庭, 重点回应对应宫位 (10/5,7/4 宫), '
        '\n5. 不预测命定吉凶, 给原型理解 + 可行动建议.');
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
