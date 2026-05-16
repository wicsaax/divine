import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../llm/client.dart';
import '../../llm/config.dart';
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
        _testResultOk = '✓ 连接成功. 模型回复: $reply';
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
      const SnackBar(content: Text('已保存')),
    );
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = allPresets();
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM 设置'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 申请教程入口 (一键打开教程页, 含跳转 + 步骤)
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
                          Text('不会申请 key？看教程',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: theme.colorScheme.onPrimaryContainer,
                              )),
                          const SizedBox(height: 2),
                          Text('每家 provider 的注册 / 充值 / 创建 key 步骤',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              )),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('一键预设', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map((p) => _PresetChip(
                      preset: p,
                      selected: _endpointCtl.text == p.endpoint &&
                          _modelCtl.text == p.model,
                      onTap: () => _applyPreset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),

          Text('Endpoint', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _endpointCtl,
            decoration: const InputDecoration(hintText: 'https://api.deepseek.com/v1'),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          Text('Model', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _modelCtl,
            decoration: const InputDecoration(hintText: 'deepseek-v4-flash'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Text('API key',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: '粘贴',
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
            child: Text(
              'API key 加密保存在系统钥匙串 (iOS Keychain / Android Keystore).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? '测试中…' : '测试连接'),
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
          const SizedBox(height: 24),

          Text('高级', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temperature', style: theme.textTheme.bodySmall),
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
                    Text('Max tokens', style: theme.textTheme.bodySmall),
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
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
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
