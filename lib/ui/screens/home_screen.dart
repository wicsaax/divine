import 'package:flutter/material.dart';

import '../../core/divination.dart';
import '../../llm/config.dart';
import 'history_screen.dart';
import 'profiles_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.config});
  final LLMConfig config;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late LLMConfig _config = widget.config;

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<LLMConfig>(
      MaterialPageRoute(builder: (_) => SettingsScreen(initial: _config)),
    );
    if (updated != null) setState(() => _config = updated);
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  Future<void> _openProfiles() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilesScreen()),
    );
  }

  Future<void> _openReading(DivinationEngine engine) async {
    // 只有"必须 LLM"的引擎才在 LLM 未配置时拦截 (因为它们没结构化输出).
    // 其它引擎可以离线占卜, 只是看不到 AI 解读.
    if (!_config.isReady && !engine.hasStandaloneResult) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('这种占卜必须配 LLM'),
          content: Text('${engine.nameZh} 没有可独立呈现的结果, 需要 AI 解读. 现在去设置 LLM 吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去设置')),
          ],
        ),
      );
      if (go == true) await _openSettings();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingScreen(engine: engine, config: _config),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engines = DivinationRegistry.all();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Text('🔮', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('divine',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                )),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '档案',
            onPressed: _openProfiles,
            icon: const Icon(Icons.contacts_outlined),
          ),
          IconButton(
            tooltip: '历史',
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (!_config.isReady)
              _UnconfiguredBanner(onTap: _openSettings)
            else
              _ReadyHero(theme: theme),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  Text(
                    '占卜方式',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${engines.length} 种',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 156,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: engines.length,
              itemBuilder: (ctx, i) => _MethodCard(
                engine: engines[i],
                onTap: () => _openReading(engines[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyHero extends StatelessWidget {
  const _ReadyHero({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            theme.colorScheme.tertiary.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text('✦', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今天想问点什么',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '选一种方式, 抽完牌可以接着追问',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnconfiguredBanner extends StatelessWidget {
  const _UnconfiguredBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.key_outlined, color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '先去配 LLM, 否则没法解读',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '推荐 DeepSeek, 几块钱能玩很久',
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.engine, required this.onTap});
  final DivinationEngine engine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = engine.accentColorHex != null
        ? Color(engine.accentColorHex!)
        : theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: isDark ? 0.32 : 0.18),
                accent.withValues(alpha: isDark ? 0.10 : 0.05),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.4 : 0.18),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(engine.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const Spacer(),
              Text(
                engine.nameZh,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                engine.tagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
