import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/divination.dart';
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

  /// 匹配关键词: 问题, 引擎名, 占卜方式, 助手回复全文.
  bool _matches(ReadingRecord r, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    if (r.question.toLowerCase().contains(lower)) return true;
    if (r.engineName.toLowerCase().contains(lower)) return true;
    if (r.result.variantName.toLowerCase().contains(lower)) return true;
    for (final m in r.messages) {
      if (m.role == 'assistant' && m.content.toLowerCase().contains(lower)) return true;
    }
    return false;
  }

  List<ReadingRecord> _filter(List<ReadingRecord> all) {
    return all.where((r) {
      if (_engineFilter != null && r.engineId != _engineFilter) return false;
      return _matches(r, _searchQuery);
    }).toList();
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
        title: const Text('历史'),
        actions: [
          IconButton(
            tooltip: '清空',
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
                  Text('还没有历史记录',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '完成一次占卜后会自动保存到这里, 方便日后回看.',
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

          final filtered = _filter(all);

          return Column(
            children: [
              // 搜索框
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: '搜索问题 / 关键词 / 解读内容',
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
                    _filterChip('全部', _engineFilter == null,
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
              const Divider(height: 1),
              // 结果计数
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '${filtered.length} 条结果',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('没有匹配的历史',
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
    return ListTile(
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${rec.engineName}  ·  ${_dateFmt.format(rec.ts)}\n$summary',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ),
      isThreeLine: true,
      onTap: () => _openDetail(rec),
    );
  }
}
