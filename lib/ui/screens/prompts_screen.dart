// 提示词管理:
//   - PromptsScreen: 列出所有引擎 + 当前激活的 prompt 是哪个
//   - EnginePromptsScreen: 单个引擎的 prompt 列表 (内置 + 自定义)
//   - PromptEditorScreen: 编辑某个自定义 prompt (modal bottom sheet)

import 'package:flutter/material.dart';

import '../../core/divination.dart';
import '../../i18n/strings.dart';
import '../../storage/prompt_store.dart';

class PromptsScreen extends StatelessWidget {
  const PromptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engines = DivinationRegistry.all();
    return Scaffold(
      appBar: AppBar(title: const Text('提示词')),
      body: AnimatedBuilder(
        animation: PromptStore.instance,
        builder: (ctx, _) {
          return ListView.separated(
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: engines.length,
            itemBuilder: (_, i) {
              final e = engines[i];
              final accent = e.accentColorHex != null ? Color(e.accentColorHex!) : theme.colorScheme.primary;
              final active = PromptStore.instance.activeFor(e.id);
              final custom = PromptStore.instance.forEngine(e.id);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(e.emoji, style: const TextStyle(fontSize: 20)),
                ),
                title: Text(e.nameZh, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  active != null
                      ? '已激活: ${active.name}  (${custom.length} 个自定义)'
                      : '使用默认  (${custom.length} 个自定义)',
                  style: TextStyle(
                    color: active != null ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EnginePromptsScreen(engine: e)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EnginePromptsScreen extends StatelessWidget {
  const EnginePromptsScreen({super.key, required this.engine});
  final DivinationEngine engine;

  Future<void> _edit(BuildContext context, {CustomPrompt? existing}) async {
    final initialBody = existing?.body ?? engine.systemPrompt;
    final initialName = existing?.name ?? '新提示词 ${PromptStore.instance.forEngine(engine.id).length + 1}';
    final result = await showModalBottomSheet<CustomPrompt>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PromptEditor(
        engine: engine,
        existingId: existing?.id,
        initialName: initialName,
        initialBody: initialBody,
      ),
    );
    if (result != null) {
      await PromptStore.instance.save(result);
    }
  }

  Future<void> _delete(BuildContext context, CustomPrompt p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${p.name}」?'),
        content: const Text('删除后, 若它是激活提示词, 会回退到默认.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('btn.cancel'))),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.t('btn.delete')),
          ),
        ],
      ),
    );
    if (ok == true) await PromptStore.instance.delete(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = engine.accentColorHex != null ? Color(engine.accentColorHex!) : theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(engine.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(engine.nameZh),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '新建',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: PromptStore.instance,
        builder: (ctx, _) {
          final activeId = PromptStore.instance.activeFor(engine.id)?.id;
          final custom = PromptStore.instance.forEngine(engine.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 默认 (内置)
              _PromptCard(
                title: '默认 (内置)',
                preview: engine.systemPrompt,
                isActive: activeId == null,
                accent: accent,
                onTapActivate: activeId == null
                    ? null
                    : () => PromptStore.instance.setActive(engine.id, null),
                onTapView: () => _showPreview(context, '默认 (只读)', engine.systemPrompt),
                builtin: true,
              ),
              const SizedBox(height: 12),
              if (custom.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.text_snippet_outlined,
                            size: 40, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('暂无自定义提示词',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 4),
                        Text('右上角 + 新建; 默认 prompt 会作为起点',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            )),
                      ],
                    ),
                  ),
                ),
              for (final p in custom) ...[
                _PromptCard(
                  title: p.name,
                  preview: p.body,
                  isActive: activeId == p.id,
                  accent: accent,
                  onTapActivate: activeId == p.id
                      ? null
                      : () => PromptStore.instance.setActive(engine.id, p.id),
                  onTapEdit: () => _edit(context, existing: p),
                  onTapDelete: () => _delete(context, p),
                  builtin: false,
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showPreview(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(child: SelectableText(body)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.title,
    required this.preview,
    required this.isActive,
    required this.accent,
    required this.builtin,
    this.onTapActivate,
    this.onTapEdit,
    this.onTapDelete,
    this.onTapView,
  });

  final String title;
  final String preview;
  final bool isActive;
  final Color accent;
  final bool builtin;
  final VoidCallback? onTapActivate;
  final VoidCallback? onTapEdit;
  final VoidCallback? onTapDelete;
  final VoidCallback? onTapView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? accent : theme.dividerColor,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isActive)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle, size: 18, color: accent),
                ),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive ? accent : null,
                  ),
                ),
              ),
              if (builtin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('内置', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            preview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (onTapActivate != null)
                FilledButton.tonalIcon(
                  onPressed: onTapActivate,
                  icon: const Icon(Icons.radio_button_unchecked, size: 16),
                  label: const Text('设为激活'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '正在使用',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              const Spacer(),
              if (onTapView != null)
                TextButton(onPressed: onTapView, child: const Text('查看全文')),
              if (onTapEdit != null)
                IconButton(
                  onPressed: onTapEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: '编辑',
                ),
              if (onTapDelete != null)
                IconButton(
                  onPressed: onTapDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: '删除',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptEditor extends StatefulWidget {
  const _PromptEditor({
    required this.engine,
    this.existingId,
    required this.initialName,
    required this.initialBody,
  });
  final DivinationEngine engine;
  final String? existingId;
  final String initialName;
  final String initialBody;

  @override
  State<_PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<_PromptEditor> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _bodyCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName);
    _bodyCtl = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _bodyCtl.text = widget.engine.systemPrompt;
    });
  }

  void _save() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名字')),
      );
      return;
    }
    final id = widget.existingId ?? PromptStore.newId();
    final p = CustomPrompt(
      id: id,
      engineId: widget.engine.id,
      name: name,
      body: _bodyCtl.text,
    );
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: inset.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.existingId == null ? '新建提示词' : '编辑提示词',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('恢复默认'),
                  ),
                  TextButton(onPressed: _save, child: Text(S.t('btn.save'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  labelText: '名字',
                  hintText: '例: 严肃风格 / 偏直接 / 给朋友看的',
                ),
              ),
              const SizedBox(height: 12),
              Text('系统提示词 (LLM 收到的 system role 文本)',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                  minHeight: 200,
                ),
                child: TextField(
                  controller: _bodyCtl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '提示: 写"你是一位 …"打头, 列出"阅读规则", 控制 LLM 风格. '
                '保存后回上一级点"设为激活"才会生效.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
