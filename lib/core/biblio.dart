// 圣经占卜 (Bibliomancy).
//
// 古老的西方传统: 闭眼翻书, 指到哪句就是哪句, 视为天启的回应.
// 本应用支持多本"经典文本":
//   bible    : 基督教圣经新旧约
//   tao      : 道德经
//   lunyu    : 论语
//   shijing  : 诗经
//   zhuangzi : 庄子内篇
//
// 算法只产生一个章节/段号的引用 (例如"罗马书 8:28"), 由 LLM 补完原文与解读.
// 不把全文打包到 app 内, 减少体积.

import 'dart:math';
import 'divination.dart';

class _BookSpec {
  final String name;
  final int maxChapter;
  final int maxVerse;
  const _BookSpec(this.name, this.maxChapter, this.maxVerse);
}

// 圣经 66 卷的章节范围 (粗略, 章数为该书实际章数, verse 用一个安全上限)
const List<_BookSpec> _bibleBooks = [
  _BookSpec('创世记', 50, 50),
  _BookSpec('出埃及记', 40, 40),
  _BookSpec('利未记', 27, 35),
  _BookSpec('民数记', 36, 40),
  _BookSpec('申命记', 34, 35),
  _BookSpec('约书亚记', 24, 30),
  _BookSpec('士师记', 21, 30),
  _BookSpec('路得记', 4, 22),
  _BookSpec('撒母耳记上', 31, 30),
  _BookSpec('撒母耳记下', 24, 30),
  _BookSpec('列王纪上', 22, 30),
  _BookSpec('列王纪下', 25, 30),
  _BookSpec('约伯记', 42, 25),
  _BookSpec('诗篇', 150, 20),
  _BookSpec('箴言', 31, 25),
  _BookSpec('传道书', 12, 20),
  _BookSpec('雅歌', 8, 15),
  _BookSpec('以赛亚书', 66, 25),
  _BookSpec('耶利米书', 52, 25),
  _BookSpec('以西结书', 48, 25),
  _BookSpec('但以理书', 12, 25),
  _BookSpec('马太福音', 28, 25),
  _BookSpec('马可福音', 16, 25),
  _BookSpec('路加福音', 24, 25),
  _BookSpec('约翰福音', 21, 25),
  _BookSpec('使徒行传', 28, 25),
  _BookSpec('罗马书', 16, 25),
  _BookSpec('哥林多前书', 16, 25),
  _BookSpec('哥林多后书', 13, 25),
  _BookSpec('加拉太书', 6, 25),
  _BookSpec('以弗所书', 6, 25),
  _BookSpec('腓立比书', 4, 25),
  _BookSpec('歌罗西书', 4, 25),
  _BookSpec('帖撒罗尼迦前书', 5, 25),
  _BookSpec('希伯来书', 13, 25),
  _BookSpec('雅各书', 5, 25),
  _BookSpec('彼得前书', 5, 25),
  _BookSpec('约翰一书', 5, 25),
  _BookSpec('启示录', 22, 22),
];

// 道德经 81 章 (按 1-81 抽)
class _SingleBook {
  final String name;
  final int max;
  const _SingleBook(this.name, this.max);
}

const _SingleBook _tao = _SingleBook('道德经', 81);
const _SingleBook _lunyu = _SingleBook('论语', 20); // 20 篇
const _SingleBook _shijing = _SingleBook('诗经', 305); // 305 篇
const _SingleBook _zhuangzi = _SingleBook('庄子', 33); // 内 7 + 外 15 + 杂 11

class BiblioEngine extends DivinationEngine {
  static final Random _rng = Random.secure();

  @override String get id => 'biblio';
  @override String get nameZh => '经典占卜';
  @override String get nameEn => 'Bibliomancy';
  @override String get emoji => '📖';
  @override String get tagline => '随机翻书 · 经文回应';
  @override String get description =>
      '源自古地中海与犹太-基督教传统的占卜方式: 心中默想问题, 随机翻开一本经典, '
      '指到的段落就是天启给你的回应. 本应用支持基督教圣经、道德经、论语、诗经、庄子.';

  @override int? get accentColorHex => 0xFF6E4A20; // 古书棕

  @override
  String get systemPrompt =>
      '你是一位兼通圣经神学、道家心法与儒家义理的解经者. '
      '\n阅读规则:\n'
      '1. 用户会给你一段经典的具体引用 (例如"罗马书 8:28"或"道德经 第二十五章").\n'
      '2. 准确补出该段落的原文或核心要义.\n'
      '3. 解读其本身的含义, 再回到用户的问题, 给出一段贴近其处境的回应.\n'
      '4. 不强行附会, 也不回避; 经文与问题之间的张力本身值得被点出.\n'
      '5. 不使用 emoji, 用中文.';

  @override
  List<DivinationVariant> get variants => const [
        DivinationVariant(key: 'bible',    name: '圣经',     description: '基督教新旧约 66 卷.'),
        DivinationVariant(key: 'tao',      name: '道德经',   description: '老子 81 章.'),
        DivinationVariant(key: 'lunyu',    name: '论语',     description: '孔子及门徒 20 篇.'),
        DivinationVariant(key: 'shijing',  name: '诗经',     description: '中国最早的诗歌总集 305 篇.'),
        DivinationVariant(key: 'zhuangzi', name: '庄子',     description: '庄子 33 篇 (内/外/杂).'),
      ];

  @override
  DivinationResult perform({
    required String variantKey,
    Map<String, String> inputs = const {},
  }) {
    String reference;
    String variantName;
    Map<String, dynamic> extras;
    switch (variantKey) {
      case 'bible':
        final b = _bibleBooks[_rng.nextInt(_bibleBooks.length)];
        final chap = _rng.nextInt(b.maxChapter) + 1;
        final verse = _rng.nextInt(b.maxVerse) + 1;
        reference = '${b.name} $chap:$verse';
        variantName = '圣经';
        extras = {'book': b.name, 'chapter': chap, 'verse': verse};
        break;
      case 'tao':
        final chap = _rng.nextInt(_tao.max) + 1;
        reference = '${_tao.name} 第 $chap 章';
        variantName = _tao.name;
        extras = {'book': _tao.name, 'chapter': chap};
        break;
      case 'lunyu':
        final chap = _rng.nextInt(_lunyu.max) + 1;
        reference = '${_lunyu.name} 第 $chap 篇';
        variantName = _lunyu.name;
        extras = {'book': _lunyu.name, 'chapter': chap};
        break;
      case 'shijing':
        final chap = _rng.nextInt(_shijing.max) + 1;
        reference = '${_shijing.name} 第 $chap 篇';
        variantName = _shijing.name;
        extras = {'book': _shijing.name, 'chapter': chap};
        break;
      case 'zhuangzi':
        final chap = _rng.nextInt(_zhuangzi.max) + 1;
        reference = '${_zhuangzi.name} 第 $chap 篇';
        variantName = _zhuangzi.name;
        extras = {'book': _zhuangzi.name, 'chapter': chap};
        break;
      default:
        throw ArgumentError('unknown variant: $variantKey');
    }

    return DivinationResult(
      engineId: id,
      engineName: nameZh,
      variantKey: variantKey,
      variantName: variantName,
      items: [
        DivinationItem(
          position: '所指段落',
          positionHint: '随机翻到的位置',
          name: reference,
          subtitle: variantName,
          keywords: const [],
          extra: extras,
        ),
      ],
      extras: {...extras, 'reference': reference},
    );
  }

  @override
  String buildUserPrompt({required String question, required DivinationResult result}) {
    final ex = result.extras;
    final buf = StringBuffer();
    buf.writeln('我的问题: ${question.trim().isEmpty ? "(请用所指段落回应我当下的境况)" : question.trim()}');
    buf.writeln();
    buf.writeln('随机翻开: ${ex["reference"]}');
    buf.writeln();
    buf.writeln('请先准确补出该段落的原文 (或核心要义), 再解读它本身, 最后联系我的问题给出回应.');
    return buf.toString();
  }
}
