// 档案列表 + 增删改. 弹窗式编辑.

import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../storage/profile.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key, this.pickMode = false});

  /// pickMode=true 时, 点击档案返回; false 时进入编辑.
  final bool pickMode;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late Future<List<BirthProfile>> _future = ProfileStore.loadAll();

  Future<void> _refresh() async {
    setState(() => _future = ProfileStore.loadAll());
    await _future;
  }

  Future<void> _edit([BirthProfile? p]) async {
    final updated = await showModalBottomSheet<BirthProfile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileEditor(profile: p),
    );
    if (updated != null) {
      await ProfileStore.save(updated);
      _refresh();
    }
  }

  Future<void> _delete(BirthProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${p.name}」?'),
        content: const Text('档案被引用过的占卜记录不受影响.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ProfileStore.delete(p.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? S.t('profile.pick_title') : S.t('profile.title')),
        actions: [
          IconButton(
            tooltip: S.t('btn.new'),
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<BirthProfile>>(
        future: _future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🪪', style: TextStyle(
                    fontSize: 56,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
                  const SizedBox(height: 12),
                  Text('还没有档案',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '为自己 / 家人 / 朋友建一个出生档案,\n做八字、占星、数字命理时一键复用.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('新建第一个档案'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      p.name.isNotEmpty ? p.name.substring(0, 1) : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(p.summary().isNotEmpty ? p.summary() : '(无生辰信息)'),
                  trailing: widget.pickMode
                      ? const Icon(Icons.chevron_right)
                      : Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              onPressed: () => _edit(p),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: '编辑',
                            ),
                            IconButton(
                              onPressed: () => _delete(p),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                  onTap: widget.pickMode
                      ? () => Navigator.of(context).pop<BirthProfile>(p)
                      : () => _edit(p),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({this.profile});
  final BirthProfile? profile;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _nameCtl = TextEditingController(text: widget.profile?.name ?? '');
  late final _dateCtl = TextEditingController(text: widget.profile?.birthDate ?? '');
  late final _timeCtl = TextEditingController(text: widget.profile?.birthTime ?? '');
  late final _placeCtl = TextEditingController(text: widget.profile?.birthPlace ?? '');
  late final _notesCtl = TextEditingController(text: widget.profile?.notes ?? '');
  String? _gender;

  @override
  void initState() {
    super.initState();
    _gender = widget.profile?.gender;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _dateCtl.dispose();
    _timeCtl.dispose();
    _placeCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写称呼')),
      );
      return;
    }
    final base = widget.profile;
    final updated = (base ?? BirthProfile(id: ProfileStore.newId(), name: name)).copyWith(
      name: name,
      gender: _gender,
      birthDate: _dateCtl.text.trim().isEmpty ? null : _dateCtl.text.trim(),
      birthTime: _timeCtl.text.trim().isEmpty ? null : _timeCtl.text.trim(),
      birthPlace: _placeCtl.text.trim().isEmpty ? null : _placeCtl.text.trim(),
      notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.profile == null ? '新建档案' : '编辑档案',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  labelText: '称呼 *',
                  hintText: '例: 自己 / 妈妈 / 李四',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dateCtl,
                decoration: const InputDecoration(
                  labelText: '公历出生日期',
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _timeCtl,
                decoration: const InputDecoration(
                  labelText: '出生时间',
                  hintText: 'HH:MM (不知道可留空)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _placeCtl,
                decoration: const InputDecoration(
                  labelText: '出生地',
                  hintText: '例: 浙江杭州',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('性别', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('男'),
                    selected: _gender == '男',
                    onSelected: (v) => setState(() => _gender = v ? '男' : null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('女'),
                    selected: _gender == '女',
                    onSelected: (v) => setState(() => _gender = v ? '女' : null),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '可选, 例: 阴历 / 真太阳时偏差等',
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
