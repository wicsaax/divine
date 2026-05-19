// 西方土占 (Geomancy).
//
// 中世纪欧洲发达的占卜系统, 由 16 个"地形" (Geomantic Figures) 构成.
// 每个 figure 是 4 行点阵, 每行 1 或 2 点. 1=主动/阳, 2=被动/阴.
//
// 占卜流程:
//   1. 随机生成 4 "Mothers" (母图)
//   2. "Daughters" (女图) = Mothers 的转置 (mother i 的第 j 行 = daughter j 的第 i 行)
//   3. "Nieces" (侄图) = 相邻 mothers/daughters XOR 行加和奇偶
//   4. "Witnesses" 右见证 + 左见证 = nieces XOR
//   5. "Judge" 判官 = witnesses XOR
//   6. (Reconciler 协调者 = Mother1 + Judge XOR, 用于和当事人状态比对)
//
// 标准盘 16 位 (House Chart): 12 位类似占星 12 宫, 4 位是 4 见证 + judge.

import 'dart:math';
import 'divination.dart';

class _GeoFigure {
  final String nameLatin;
  final String nameZh;
  final List<int> rows; // 4 行, 每个 1 或 2
  final String element; // 风/水/火/土
  final String meaning;
  const _GeoFigure(this.nameLatin, this.nameZh, this.rows, this.element, this.meaning);
}

// 16 figures (按二进制顺序排列, 1=单点, 2=双点)
const List<_GeoFigure> _figures = [
  _GeoFigure('Via',             '道路',   [1,1,1,1], '水', '变化, 旅行, 单身'),
  _GeoFigure('Cauda Draconis',  '龙尾',   [1,1,1,2], '火', '结束, 撤离, 凶'),
  _GeoFigure('Puer',            '少年',   [1,1,2,1], '火', '冲动, 战斗, 火爆'),
  _GeoFigure('Fortuna Minor',   '小福',   [1,1,2,2], '火', '小幸运, 短期成功'),
  _GeoFigure('Puella',          '少女',   [1,2,1,1], '水', '魅力, 和谐, 表面'),
  _GeoFigure('Amissio',         '失去',   [1,2,1,2], '土', '失物, 离去, 释放'),
  _GeoFigure('Carcer',          '牢狱',   [1,2,2,1], '土', '限制, 困境, 责任'),
  _GeoFigure('Laetitia',        '喜悦',   [1,2,2,2], '风', '快乐, 健康, 成功'),
  _GeoFigure('Caput Draconis',  '龙首',   [2,1,1,1], '土', '开始, 入门, 吉'),
  _GeoFigure('Conjunctio',      '相聚',   [2,1,1,2], '土', '会合, 关系, 协作'),
  _GeoFigure('Acquisitio',      '获得',   [2,1,2,1], '风', '获得, 财富, 成果'),
  _GeoFigure('Rubeus',          '赤红',   [2,1,2,2], '火', '激情, 暴力, 警告'),
  _GeoFigure('Fortuna Major',   '大福',   [2,2,1,1], '土', '大幸运, 稳定成功'),
  _GeoFigure('Albus',           '洁白',   [2,2,1,2], '风', '智慧, 清明, 平和'),
  _GeoFigure('Tristitia',       '悲伤',   [2,2,2,1], '土', '忧伤, 阻滞, 沉重'),
  _GeoFigure('Populus',         '人群',   [2,2,2,2], '水', '群众, 静止, 中性'),
];

/// 二进制 (rows) → 索引
int _figureIdx(List<int> rows) {
  // rows 是 [r1,r2,r3,r4], 各为 1 或 2. 我们映射 1→0, 2→1, 形成 4-bit.
  // 但定义顺序是 row1 高位.
  var v = 0;
  for (var i = 0; i < 4; i++) {
    v = (v << 1) | (rows[i] - 1);
  }
  return v;
}

List<int> _xorRows(List<int> a, List<int> b) {
  return [for (var i = 0; i < 4; i++) ((a[i] - 1) ^ (b[i] - 1)) + 1];
}

class GeomancyEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'geomancy';
  @override String get nameZh => '西方土占';
  @override String get nameEn => 'Geomancy';
  @override String get emoji => '⛰️';
  @override String get tagline => '16 形 · 中世纪欧洲传统';
  @override String get description =>
      '中世纪欧洲发达的占卜系统. 由四"母图" (Mothers) 随机生成, '
      '推出四"女图" (Daughters)、四"侄图" (Nieces)、两"见证" (Witnesses), '
      '最终汇成"判官" (Judge). 16 个 Geomantic Figures 各有元素属性和含义.';

  @override int? get accentColorHex => 0xFF8B6F47;

  @override bool get hasStandaloneResult => true;

  @override
  String get systemPrompt =>
      '你是一位精通中世纪西方土占 (Geomancy) 的占卜师, 知 16 figures 的元素属性、'
      '行星归属、传统含义, 以及标准 16 House Chart 解读法.\n'
      '\n阅读规则:\n'
      '1. 用户给出的 4 母图 → 女图 → 侄图 → 见证 → 判官 已由算法精确推出.\n'
      '2. 重点解读判官 (Judge, 整体结论) + 右见证 (主动力量) + 左见证 (响应/对方).\n'
      '3. 用户的问题决定看哪些"宫位" (House), 但本应用没排 16 宫盘, 只用 7 张核心. 引述传统含义即可.\n'
      '4. 不预测命定吉凶, 给方向 + 时机.\n'
      '5. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'standard', name: '标准盘', description: '4 母 + 4 女 + 4 侄 + 2 见证 + 1 判官.'),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    final mothers = <List<int>>[
      for (var i = 0; i < 4; i++)
        [for (var j = 0; j < 4; j++) _rng.nextInt(2) + 1],
    ];
    return _buildFromMothers(variantKey, mothers);
  }

  @override
  bool get supportsManualInput => true;

  @override
  List<ManualField> manualFields(String variantKey) {
    final figureOptions = _figures
        .map((f) => ManualFieldOption(
              key: f.nameLatin,
              label: f.nameZh,
              subtitle: '${f.nameLatin} · ${f.element} · ${f.meaning}',
            ))
        .toList();
    return [
      for (var i = 0; i < 4; i++)
        ManualField(
          key: 'mother_$i',
          label: '母图 ${['I', 'II', 'III', 'IV'][i]}',
          hint: '占卜流程: 由四母图推出其余 12 figures',
          kind: ManualFieldKind.picker,
          options: figureOptions,
          group: '四母图 (依次)',
        ),
    ];
  }

  @override
  DivinationResult performManual({
    required String variantKey,
    required Map<String, String> selections,
  }) {
    final byLatin = {for (final f in _figures) f.nameLatin: f};
    final mothers = <List<int>>[];
    for (var i = 0; i < 4; i++) {
      final name = selections['mother_$i'];
      final fig = name == null ? null : byLatin[name];
      if (fig == null) throw ArgumentError('母图 ${i + 1} 还没选');
      mothers.add(List<int>.from(fig.rows));
    }
    return _buildFromMothers(variantKey, mothers);
  }

  DivinationResult _buildFromMothers(
      String variantKey, List<List<int>> mothers) {
    // 4 女图: 母图的转置
    final daughters = <List<int>>[
      for (var i = 0; i < 4; i++) [for (var j = 0; j < 4; j++) mothers[j][i]],
    ];

    // 4 侄图: 相邻 XOR
    final nieces = <List<int>>[
      _xorRows(mothers[0], mothers[1]),
      _xorRows(mothers[2], mothers[3]),
      _xorRows(daughters[0], daughters[1]),
      _xorRows(daughters[2], daughters[3]),
    ];

    final rightWitness = _xorRows(nieces[0], nieces[1]);
    final leftWitness = _xorRows(nieces[2], nieces[3]);
    final judge = _xorRows(rightWitness, leftWitness);

    final all = <(_GeoFigure, String)>[
      (_figures[_figureIdx(mothers[0])], '母 I'),
      (_figures[_figureIdx(mothers[1])], '母 II'),
      (_figures[_figureIdx(mothers[2])], '母 III'),
      (_figures[_figureIdx(mothers[3])], '母 IV'),
      (_figures[_figureIdx(daughters[0])], '女 V'),
      (_figures[_figureIdx(daughters[1])], '女 VI'),
      (_figures[_figureIdx(daughters[2])], '女 VII'),
      (_figures[_figureIdx(daughters[3])], '女 VIII'),
      (_figures[_figureIdx(nieces[0])], '侄 IX'),
      (_figures[_figureIdx(nieces[1])], '侄 X'),
      (_figures[_figureIdx(nieces[2])], '侄 XI'),
      (_figures[_figureIdx(nieces[3])], '侄 XII'),
      (_figures[_figureIdx(rightWitness)], '右见证'),
      (_figures[_figureIdx(leftWitness)], '左见证'),
      (_figures[_figureIdx(judge)], '★ 判官'),
    ];

    final items = <DivinationItem>[];
    for (final (fig, pos) in all) {
      items.add(DivinationItem(
        position: pos,
        positionHint: pos.contains('判官') ? '整体结论' : '',
        name: fig.nameZh,
        subtitle: '${fig.nameLatin} · ${fig.element}',
        keywords: [fig.meaning],
        extra: {'rows': fig.rows, 'element': fig.element},
      ));
    }

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: '标准盘',
      items: items,
      extras: {
        'judge': all.last.$1.nameZh,
        'judgeMeaning': all.last.$1.meaning,
        'rightWitness': _figures[_figureIdx(rightWitness)].nameZh,
        'leftWitness': _figures[_figureIdx(leftWitness)].nameZh,
      },
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('请用西方土占 (Geomancy) 给我做解读.');
    buf.writeln();
    buf.writeln('完整盘面 (4母 4女 4侄 2见证 1判官):');
    for (final it in result.items) {
      buf.writeln('  ${it.position}: ${it.name} (${it.subtitle}) — ${it.keywords.first}');
    }
    buf.writeln();
    buf.writeln('整体结论 (Judge): ${ex["judge"]} — ${ex["judgeMeaning"]}');
    buf.writeln('右见证 (主动力量): ${ex["rightWitness"]}');
    buf.writeln('左见证 (响应/对方): ${ex["leftWitness"]}');
    buf.writeln();
    if (question.trim().isNotEmpty) {
      buf.writeln('我的问题: ${question.trim()}');
      buf.writeln();
    }
    buf.writeln('请按 Geomancy 传统解读: '
        '\n1. Judge 是这次占卜的核心答复 — 它的元素、行星归属、传统含义都要展开, '
        '\n2. 右/左见证给整体走势 (谁主动谁被动, 进退如何), '
        '\n3. 4 母图作为问题的根本环境, 4 女图作为对方/外界反应, 4 侄图作为过程动态, '
        '\n4. 给可执行建议, 强调时机.');
    return buf.toString();
  }

  @override
  String summarize(DivinationResult result) {
    final ex = result.extras;
    return '判官: ${ex["judge"]} (${ex["judgeMeaning"]})';
  }
}
