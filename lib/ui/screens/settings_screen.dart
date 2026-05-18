import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/divination.dart';
import '../../i18n/strings.dart';
import '../../llm/client.dart';
import '../../llm/config.dart';
import '../../storage/app_settings.dart';
import 'about_screen.dart';
import 'prompts_screen.dart';
import 'provider_guide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initial});
  final LLMConfig initial;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _endpointCtl;
  late final TextEditingController _modelCtl;
  late final TextEditingController _keyCtl;
  late final TextEditingController _tempCtl;
  late final TextEditingController _maxTokCtl;
  bool _showKey = false;
  bool _testing = false;
  String? _testResultOk;
  String? _testResultErr;

  @override
  void initState() {
    super.initState();
    _endpointCtl = TextEditingController(text: widget.initial.endpoint);
    _modelCtl = TextEditingController(text: widget.initial.model);
    _keyCtl = TextEditingController(text: widget.initial.apiKey);
    _tempCtl = TextEditingController(text: widget.initial.temperature.toString());
    _maxTokCtl = TextEditingController(text: widget.initial.maxTokens.toString());
  }

  @override
  void dispose() {
    _endpointCtl.dispose();
    _modelCtl.dispose();
    _keyCtl.dispose();
    _tempCtl.dispose();
    _maxTokCtl.dispose();
    super.dispose();
  }

  void _applyPreset(LLMPreset p) {
    setState(() {
      _endpointCtl.text = p.endpoint;
      _modelCtl.text = p.model;
      _testResultOk = null;
      _testResultErr = null;
    });
  }

  Future<void> _openGuide() async {
    final preset = await Navigator.of(context).push<LLMPreset>(
      MaterialPageRoute(builder: (_) => const ProviderGuideScreen()),
    );
    if (preset != null) _applyPreset(preset);
  }

  LLMConfig _current() => LLMConfig(
        endpoint: _endpointCtl.text.trim(),
        model: _modelCtl.text.trim(),
        apiKey: _keyCtl.text.trim(),
        temperature: double.tryParse(_tempCtl.text.trim()) ?? widget.initial.temperature,
        maxTokens: int.tryParse(_maxTokCtl.text.trim()) ?? widget.initial.maxTokens,
      );

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResultOk = null;
      _testResultErr = null;
    });
    try {
      final reply = await LLMClient.testConnection(_current());
      setState(() {
        _testResultOk = '✓ $reply';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testResultErr = '✗ ${e.toString()}';
        _testing = false;
      });
    }
  }

  Future<void> _save() async {
    final cfg = _current();
    await LLMConfigStore.save(cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.t('reading.saved'))),
    );
    Navigator.of(context).pop(cfg);
  }

  Future<void> _exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final dump = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '0.5',
      'data': {
        for (final k in keys) k: prefs.get(k),
      },
    };
    final json = const JsonEncoder.withIndent('  ').convert(dump);
    try {
      await Share.share(json, subject: 'divine config + history backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    final ctl = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('settings.import_config')),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctl,
            maxLines: 8,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: '{\n  "version": "0.5",\n  "data": {...}\n}',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.t('btn.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: Text(S.t('btn.confirm')),
          ),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty) return;
    try {
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      final data = parsed['data'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      for (final e in data.entries) {
        final v = e.value;
        if (v is String) {
          await prefs.setString(e.key, v);
        } else if (v is int) {
          await prefs.setInt(e.key, v);
        } else if (v is double) {
          await prefs.setDouble(e.key, v);
        } else if (v is bool) {
          await prefs.setBool(e.key, v);
        } else if (v is List) {
          await prefs.setStringList(e.key, v.map((x) => x.toString()).toList());
        }
      }
      await AppSettings.instance.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imported. 重启 app 让所有变更生效.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失败: $e')),
        );
      }
    }
  }

  Future<void> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.t('settings.clear_data')),
        content: Text(S.t('settings.clear_data_sub')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.t('btn.cancel'))),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.t('btn.clear')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AppSettings.instance.wipeAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空. 重启 app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = allPresets();
    final settings = AppSettings.instance;
    final engines = DivinationRegistry.all();

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('settings.title')),
        actions: [
          TextButton(onPressed: _save, child: Text(S.t('btn.save'))),
        ],
      ),
      body: AnimatedBuilder(
        animation: settings,
        builder: (ctx, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- 申请教程入口 ----
            Card(
              color: theme.colorScheme.primaryContainer,
              child: InkWell(
                onTap: _openGuide,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.menu_book_outlined,
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(S.t('settings.guide_title'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: theme.colorScheme.onPrimaryContainer,
                                )),
                            const SizedBox(height: 2),
                            Text(S.t('settings.guide_sub'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                )),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- LLM 一键预设 ----
            _label(theme, S.t('settings.preset')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: presets
                  .map((p) => _PresetChip(
                        preset: p,
                        selected: _endpointCtl.text == p.endpoint && _modelCtl.text == p.model,
                        onTap: () => _applyPreset(p),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ---- Endpoint / Model / Key ----
            _label(theme, S.t('settings.endpoint')),
            const SizedBox(height: 6),
            TextField(
              controller: _endpointCtl,
              decoration: const InputDecoration(hintText: 'https://api.deepseek.com/v1'),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _label(theme, S.t('settings.model')),
            const SizedBox(height: 6),
            TextField(
              controller: _modelCtl,
              decoration: const InputDecoration(hintText: 'deepseek-v4-flash'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _label(theme, S.t('settings.api_key'))),
                IconButton(
                  tooltip: S.t('settings.paste'),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      setState(() => _keyCtl.text = data.text!.trim());
                    }
                  },
                  icon: const Icon(Icons.content_paste, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _keyCtl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(S.t('settings.api_key_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? S.t('btn.testing') : S.t('btn.test_conn')),
              ),
            ),
            if (_testResultOk != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_testResultOk!,
                      style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                ),
              ),
            if (_testResultErr != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_testResultErr!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ),
            const SizedBox(height: 20),

            // ---- Advanced (temperature/maxTokens) ----
            _label(theme, S.t('settings.advanced')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.t('settings.temperature'), style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _tempCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '0.8'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.t('settings.max_tokens'), style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _maxTokCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '2048'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ============= App 偏好 =============
            const Divider(),
            const SizedBox(height: 12),
            _label(theme, S.t('settings.section_app')),
            const SizedBox(height: 12),

            // 语言
            _row(theme, S.t('settings.language')),
            _choiceRow([
              ('中文', settings.locale == 'zh', () => settings.setLocale('zh')),
              ('English', settings.locale == 'en', () => settings.setLocale('en')),
            ]),
            const SizedBox(height: 14),

            // 主题
            _row(theme, S.t('settings.theme')),
            _choiceRow([
              (S.t('settings.theme_system'), settings.themeMode == AppThemeMode.system,
                  () => settings.setThemeMode(AppThemeMode.system)),
              (S.t('settings.theme_light'), settings.themeMode == AppThemeMode.light,
                  () => settings.setThemeMode(AppThemeMode.light)),
              (S.t('settings.theme_dark'), settings.themeMode == AppThemeMode.dark,
                  () => settings.setThemeMode(AppThemeMode.dark)),
            ]),
            const SizedBox(height: 14),

            // 字号
            _row(theme, S.t('settings.font_size')),
            _choiceRow([
              (S.t('settings.font_small'), settings.fontScale == 0.9, () => settings.setFontScale(0.9)),
              (S.t('settings.font_medium'), settings.fontScale == 1.0, () => settings.setFontScale(1.0)),
              (S.t('settings.font_large'), settings.fontScale == 1.15, () => settings.setFontScale(1.15)),
            ]),
            const SizedBox(height: 6),

            // 通知开关
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.t('settings.notif_fg')),
              subtitle: Text(S.t('settings.notif_fg_sub')),
              value: settings.fgNotification,
              onChanged: settings.setFgNotification,
            ),

            // 流式开关
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.t('settings.streaming')),
              subtitle: Text(S.t('settings.streaming_sub')),
              value: settings.streaming,
              onChanged: settings.setStreaming,
            ),

            // 历史保存
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.t('settings.save_history')),
              subtitle: Text(S.t('settings.save_history_sub')),
              value: settings.saveHistory,
              onChanged: settings.setSaveHistory,
            ),

            // 默认占卜方式
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: settings.defaultEngine,
              decoration: const InputDecoration(
                labelText: '默认占卜方式 (启动直接打开)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('(无, 显示首页)')),
                for (final e in engines)
                  DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text('${e.emoji} ${e.nameZh}'),
                  ),
              ],
              onChanged: settings.setDefaultEngine,
            ),

            // ============= 提示词 =============
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('提示词管理'),
              subtitle: const Text('为每种占卜法新建多个 LLM system prompt, 一键切换'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PromptsScreen()),
              ),
            ),

            // ============= 数据 =============
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _label(theme, S.t('settings.section_data')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share),
              title: Text(S.t('settings.export_config')),
              onTap: _exportData,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file),
              title: Text(S.t('settings.import_config')),
              onTap: _importData,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
              title: Text(S.t('settings.clear_data'),
                  style: TextStyle(color: theme.colorScheme.error)),
              subtitle: Text(S.t('settings.clear_data_sub')),
              onTap: _confirmWipe,
            ),

            // ============= 关于 =============
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(S.t('settings.section_about')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _row(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      );

  Widget _choiceRow(List<(String, bool, VoidCallback)> options) => Wrap(
        spacing: 8,
        children: options
            .map((o) => ChoiceChip(
                  label: Text(o.$1),
                  selected: o.$2,
                  onSelected: (_) => o.$3(),
                ))
            .toList(),
      );
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset, required this.selected, required this.onTap});
  final LLMPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            preset.label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
