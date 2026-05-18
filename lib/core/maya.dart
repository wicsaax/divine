// 玛雅卓尔金 (Tzolkin) 占卜.
//
// 玛雅 260 日历 (Sacred Calendar) 由 20 个日签 (Day Signs) × 13 个音 (Tones)
// 组合而成. 任何阳历日期都能转换成"今天是第几号 + 哪个签 + 哪个音".
//
// 算法:
//   - 相关日: GMT correlation (Goodman-Martinez-Thompson) 584283
//     公历 1970-01-01 = Long Count 12.17.16.7.5, Tzolkin = 13 Chicchan
//     对应 day_index = 0 时为 1970-01-01.
//   - 给定阳历日, 计算它距 1970-01-01 的天数 N.
//   - 日签 = (signOffset0 + N) mod 20
//   - 音 = (toneOffset0 + N) mod 13
//   - 1970-01-01 Tzolkin: 13 Chicchan
//     Chicchan 是 20 个日签里的第 5 (从 Imix=0 算)
//     所以 signOffset0 = 4 (要让 N=0 出 Chicchan=4)
//     Tone 13 = 13, 我们用 1-13 表示, 0 对应 13, signOffset 应该让 N=0 → tone 13.
//     用 0-indexed: tone idx = 12 (因为 13 是 13th tone)
//     公式: tone (1-13) = ((N + toneOffset) mod 13) + 1 — 调整 toneOffset

import 'divination.dart';

class _DaySign {
  final int idx; // 0-19
  final String nameMaya;
  final String nameZh;
  final String emoji;
  final List<String> keywords;
  const _DaySign(this.idx, this.nameMaya, this.nameZh, this.emoji, this.keywords);
}

const List<_DaySign> _daySigns = [
  _DaySign(0,  'Imix',     '鳄鱼',  '🐊', ['本源', '滋养', '原始能量']),
  _DaySign(1,  'Ik',       '风',    '🌬', ['呼吸', '沟通', '灵感']),
  _DaySign(2,  'Akbal',    '夜',    '🌙', ['梦境', '潜意识', '深度']),
  _DaySign(3,  'Kan',      '种子',  '🌱', ['潜能', '智慧', '播种']),
  _DaySign(4,  'Chicchan', '蛇',    '🐍', ['本能', '生命力', '蜕变']),
  _DaySign(5,  'Cimi',     '死神',  '💀', ['转化', '放手', '过渡']),
  _DaySign(6,  'Manik',    '鹿',    '🦌', ['行动', '完成', '助人']),
  _DaySign(7,  'Lamat',    '星',    '⭐', ['美', '艺术', '丰盛']),
  _DaySign(8,  'Muluc',    '水',    '💧', ['情感', '感觉', '净化']),
  _DaySign(9,  'Oc',       '狗',    '🐕', ['忠诚', '心', '陪伴']),
  _DaySign(10, 'Chuen',    '猴',    '🐒', ['玩耍', '创造', '艺术家']),
  _DaySign(11, 'Eb',       '草',    '🌾', ['旅行', '道路', '人间']),
  _DaySign(12, 'Ben',      '芦苇',  '🎋', ['坚韧', '权威', '家庭']),
  _DaySign(13, 'Ix',       '美洲豹','🐆', ['萨满', '魔法', '神秘']),
  _DaySign(14, 'Men',      '鹰',    '🦅', ['远见', '愿景', '高度']),
  _DaySign(15, 'Cib',      '猫头鹰','🦉', ['祖先', '智慧', '宽恕']),
  _DaySign(16, 'Caban',    '地',    '🌍', ['同步', '运动', '思考']),
  _DaySign(17, 'Etznab',   '镜',    '🪞', ['真相', '反映', '清晰']),
  _DaySign(18, 'Cauac',    '风暴',  '⛈', ['净化', '激活', '更新']),
  _DaySign(19, 'Ahau',     '太阳',  '☀️', ['启蒙', '光明', '神性']),
];

const Map<int, String> _toneNames = {
  1: '磁性 (统合)', 2: '月亮 (挑战)', 3: '电力 (服务)',
  4: '自存 (形式)', 5: '超频 (光芒)', 6: '韵律 (平等)',
  7: '共振 (引导)', 8: '银河 (和谐)', 9: '太阳 (意愿)',
  10: '行星 (显化)', 11: '光谱 (释放)', 12: '水晶 (合作)',
  13: '宇宙 (回归)',
};

class MayaTzolkinEngine extends DivinationEngine {
  @override String get id => 'maya';
  @override String get nameZh => '玛雅卓尔金';
  @override String get nameEn => 'Maya Tzolkin';
  @override String get emoji => '🐆';
  @override String get tagline => '260 日神圣历 · 20 签 + 13 音';
  @override String get description =>
      '玛雅文明的神圣历法 (Tzolkin), 260 日为周期. 由 20 个日签 (Day Sign) '
      '与 13 个音 (Tone / Galactic Tone) 组合, 每个组合都有独特的能量原型. '
      '出生日的卓尔金能量塑造你的"波符"和"印记". 也可看任意日期的"今日讯息".';

  @override int? get accentColorHex => 0xFF7B3F00; // 玛雅赭红

  @override bool get hasStandaloneResult => true;

  @override
  String get systemPrompt =>
      '你是一位精通玛雅卓尔金占卜的解读师, 兼具神话学者的严谨与心理学家的同理.\n'
      '\n阅读规则:\n'
      '1. 用户给的日签 (20 个之一) + 音数 (1-13) 已由专业算法精确算出.\n'
      '2. 解读日签的原型能量 + 音数的频率, 二者结合的核心讯息.\n'
      '3. 关于"卓尔金波符" (Wavespell, 同一个日签开始的 13 日周期), 可适度提及.\n'
      '4. 不预测命定吉凶, 强调原型理解 + 节律感知.\n'
      '5. 不使用 emoji (除非已在用户输入里), 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'birth', name: '出生印记 (Galactic Signature)', description: '由出生日推算的核心日签 + 音, 终身印记.'),
        DivinationVariant(key: 'today', name: '今日讯息', description: '今天的日签 + 音, 当下能量.'),
      ];

  @override
  List<InputField> get inputs => const [
        InputField(
          key: 'birthdate',
          label: '公历日期',
          hint: 'YYYY-MM-DD (生日 / 想看的日期)',
          type: InputFieldType.date,
          required: true,
        ),
      ];

  /// 计算给定日期的 (sign idx 0-19, tone 1-13).
  /// 基准: 1970-01-01 = Chicchan (sign 4), Tone 13.
  (int, int) _tzolkin(DateTime date) {
    final base = DateTime.utc(1970, 1, 1);
    final days = date.toUtc().difference(base).inDays;
    final sign = ((4 + days) % 20 + 20) % 20;
    var toneIdx = ((12 + days) % 13 + 13) % 13;
    final tone = toneIdx + 1; // 1-13
    return (sign, tone);
  }

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    DateTime date;
    if (variantKey == 'today') {
      date = DateTime.now();
    } else {
      final raw = (inputs['birthdate'] ?? '').trim();
      if (raw.isEmpty) {
        throw ArgumentError('日期不能为空');
      }
      final m = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})$').firstMatch(raw);
      if (m == null) throw ArgumentError('日期格式不对');
      date = DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }

    final (signIdx, tone) = _tzolkin(date);
    final sign = _daySigns[signIdx];
    final variantName = variants.firstWhere((v) => v.key == variantKey).name;
    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: [
        DivinationItem(
          position: '日签 (Day Sign)',
          positionHint: '20 个日签中的一个, 代表原型能量',
          name: '${sign.emoji} ${sign.nameZh} ${sign.nameMaya}',
          subtitle: 'No.${sign.idx + 1}',
          keywords: sign.keywords,
          extra: {'signIdx': sign.idx, 'signNameMaya': sign.nameMaya},
        ),
        DivinationItem(
          position: '音 (Tone)',
          positionHint: '13 个银河音中的一个, 代表频率',
          name: '$tone — ${_toneNames[tone]}',
          subtitle: '银河音 $tone / 13',
          keywords: const [],
          extra: {'tone': tone},
        ),
      ],
      extras: {
        'date': '${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}',
        'signIdx': sign.idx,
        'signMaya': sign.nameMaya,
        'signZh': sign.nameZh,
        'tone': tone,
        'toneName': _toneNames[tone],
        'kin': signIdx * 13 + tone, // 大约的 Kin 编号 1-260
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('请用玛雅卓尔金占卜给我做解读.');
    buf.writeln();
    buf.writeln('日期: ${ex["date"]}');
    final signNo = (ex['signIdx'] as int) + 1;
    buf.writeln('日签 (Day Sign): ${ex["signZh"]} (${ex["signMaya"]}) - 20 签之 $signNo');
    buf.writeln('音 (Tone): ${ex["tone"]} - ${ex["toneName"]}');
    buf.writeln('Kin (大约编号 1-260): ${ex["kin"]}');
    buf.writeln('占卜模式: ${result.variantName}');
    buf.writeln();
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
      buf.writeln();
    }
    buf.writeln('请解读: '
        '\n1. 日签原型 (能量基底, 玛雅神话语境), '
        '\n2. 音数频率 (这个数字在 13 个音里位置, 主题), '
        '\n3. 日签 + 音 组合的核心讯息, '
        '\n4. 若是出生印记, 解读"终身波符"; 若是今日, 解读"今天怎么用这能量", '
        '\n5. 不预测命定式吉凶.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '${ex["signZh"]} (${ex["signMaya"]}) · 音 ${ex["tone"]}';
  }
}
