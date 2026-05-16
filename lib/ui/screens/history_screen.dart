import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/divination.dart';
import '../../i18n/strings.dart';
import '../../llm/config.dart';
import '../../storage/history.dart';
import 'reading_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ReadingRecord>> _future = HistoryStore.loadAll();
  final _dateFmt = DateFormat('MM-dd HH:mm');
  final _searchCtl = TextEditingController();
  String _searchQuery = '';
  String? _engineFilter; // null = 全部
  final Set<String> _tagFilter = {}; // 空 = 不按标签过滤; 非空 = 命中任一即匹配

  Future<void> _refresh() async {
    setState(() => _future = HistoryStore.loadAll());
    await _future;
  }

  Future<void> _openDetail(ReadingRecord rec) async {
    final engine = DivinationRegistry.get(rec.engineId);
    if (engine == null) return;
    final cfg = await LLMConfigStore.load();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(engine: engine, config: cfg, replay: rec),
      ),
    );
    _refresh();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部历史?'),
        content: const Text('此操作不可恢复.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryStore.clear();
      _refresh();
    }
  }

  /// 匹配关键词: 问题, 引擎名, 占卜方式, 助手回复全文, 标签.
  bool _matches(ReadingRecord r, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    if (r.question.toLowerCase().contains(lower)) return true;
    if (r.engineName.toLowerCase().contains(lower)) return true;
    if (r.result.variantName.toLowerCase().contains(lower)) return true;
    for (final t in r.tags) {
      if (t.toLowerCase().contains(lower)) return true;
    }
    for (final m in r.messages) {
      if (m.role == 'assistant' && m.content.toLowerCase().contains(lower)) return true;
    }
    return false;
  }

  List<ReadingRecord> _filter(List<ReadingRecord> all) {
    return all.where((r) {
      if (_engineFilter != null && r.engineId != _engineFilter) return false;
      if (_tagFilter.isNotEmpty && !r.tags.any(_tagFilter.contains)) return false;
      return _matches(r, _searchQuery);
    }).toList();
  }

  Future<void> _exportFiltered(List<ReadingRecord> records) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的记录')),
      );
      return;
    }
    final buf = StringBuffer();
    buf.writeln('# divine 占卜记录');
    buf.writeln();
    buf.writeln('导出时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buf.writeln('记录数: ${records.length}');
    buf.writeln();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    for (final r in records) {
      buf.writeln('---');
      buf.writeln();
      buf.writeln('## ${fmt.format(r.ts)} · ${r.engineName} · ${r.result.variantName}');
      buf.writeln();
      if (r.question.isNotEmpty) {
        buf.writeln('**问题**: ${r.question}');
        buf.writeln();
      }
      if (r.tags.isNotEmpty) {
        buf.writeln('**标签**: ${r.tags.join(" · ")}');
        buf.writeln();
      }
      if (r.result.items.isNotEmpty) {
        buf.writeln('### 抽到的结果');
        buf.writeln();
        for (final it in r.result.items) {
          final ori = it.orientation.isNotEmpty ? ' (${it.orientation})' : '';
          final kw = it.keywords.isNotEmpty ? ' — ${it.keywords.join(" / ")}' : '';
          buf.writeln('- **${it.position}**: ${it.name}$ori$kw');
        }
        buf.writeln();
      }
      final assistantMsgs = r.messages.where((m) => m.role == 'assistant');
      if (assistantMsgs.isNotEmpty) {
        buf.writeln('### AI 解读');
        buf.writeln();
        for (final m in assistantMsgs) {
          if (m.reasoning.isNotEmpty) {
            buf.writeln('> [思考过程]');
            for (final line in m.reasoning.split('\n')) {
              buf.writeln('> $line');
            }
            buf.writeln('>');
          }
          buf.writeln(m.content);
          buf.writeln();
        }
      }
      final followUps = r.messages.where((m) => m.role == 'user').skip(1).toList();
      if (followUps.isNotEmpty) {
        buf.writeln('### 追问');
        buf.writeln();
        for (final u in followUps) {
          buf.writeln('- ${u.content}');
        }
        buf.writeln();
      }
    }
    final text = buf.toString();
    try {
      await Share.share(text, subject: 'divine 占卜记录 (${records.length} 条)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('history.title')),
        actions: [
          FutureBuilder<List<ReadingRecord>>(
            future: _future,
            builder: (_, snap) {
              return IconButton(
                tooltip: S.t('btn.export'),
                onPressed: snap.hasData
                    ? () => _exportFiltered(_filter(snap.data!.reversed.toList()))
                    : null,
                icon: const Icon(Icons.ios_share),
              );
            },
          ),
          IconButton(
            tooltip: S.t('btn.clear'),
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<ReadingRecord>>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.reversed.toList();
          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🌙', style: TextStyle(
                    fontSize: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
                  const SizedBox(height: 12),
                  Text(S.t('history.empty_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      S.t('history.empty_sub'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // 出现过的引擎 ids (按使用次数排序)
          final engineCount = <String, int>{};
          for (final r in all) {
            engineCount[r.engineId] = (engineCount[r.engineId] ?? 0) + 1;
          }
          final usedEngines = engineCount.keys
              .map((id) => DivinationRegistry.get(id))
              .whereType<DivinationEngine>()
              .toList()
            ..sort((a, b) => (engineCount[b.id] ?? 0)
                .compareTo(engineCount[a.id] ?? 0));

          // 全部用过的标签 (按次数排)
          final tagCount = <String, int>{};
          for (final r in all) {
            for (final t in r.tags) {
              tagCount[t] = (tagCount[t] ?? 0) + 1;
            }
          }
          final usedTags = tagCount.keys.toList()
            ..sort((a, b) => (tagCount[b] ?? 0).compareTo(tagCount[a] ?? 0));

          final filtered = _filter(all);

          return Column(
            children: [
              // 搜索框
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: S.t('history.search_hint'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              // 引擎过滤芯片
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _filterChip(S.t('history.all'), _engineFilter == null,
                        () => setState(() => _engineFilter = null),
                        count: all.length),
                    ...usedEngines.map((e) => _filterChip(
                          '${e.emoji} ${e.nameZh}',
                          _engineFilter == e.id,
                          () => setState(() =>
                              _engineFilter = _engineFilter == e.id ? null : e.id),
                          count: engineCount[e.id] ?? 0,
                        )),
                  ],
                ),
              ),
              // 标签过滤
              if (usedTags.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6, top: 8),
                        child: Icon(Icons.local_offer_outlined,
                            size: 16, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      ...usedTags.map((t) => _filterChip(
                            t,
                            _tagFilter.contains(t),
                            () => setState(() {
                              if (_tagFilter.contains(t)) {
                                _tagFilter.remove(t);
                              } else {
                                _tagFilter.add(t);
                              }
                            }),
                            count: tagCount[t] ?? 0,
                          )),
                    ],
                  ),
                ),
              const Divider(height: 1),
              // 结果计数
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  S.t('history.results').replaceAll('{n}', '${filtered.length}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(S.t('history.no_match'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _buildItem(filtered[i], theme),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap,
      {required int count}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(ReadingRecord rec, ThemeData theme) {
    final engine = DivinationRegistry.get(rec.engineId);
    final emoji = engine?.emoji ?? '🔮';
    final summary = engine?.summarize(rec.result) ?? '';
    final accent = engine?.accentColorHex != null
        ? Color(engine!.accentColorHex!)
        : theme.colorScheme.primary;
    return Dismissible(
      key: ValueKey(rec.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline,
            color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除这条记录?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        await HistoryStore.deleteById(rec.id);
        _refresh();
      },
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          rec.question.isEmpty ? '(无具体问题)' : rec.question,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: rec.question.isEmpty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${rec.engineName}  ·  ${_dateFmt.format(rec.ts)}\n$summary',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
            if (rec.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: rec.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(t,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface,
                                )),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _openDetail(rec),
      ),
    );
  }
}
