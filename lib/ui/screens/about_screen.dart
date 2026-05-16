import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '0.5.0';
  static const _repoUrl = 'https://github.com/wicsaax/divine';

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(SnackBar(content: Text('Copied: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.t('settings.section_about'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/app_icon.jpg',
                width: 96, height: 96,
                errorBuilder: (_, __, ___) => Container(
                  width: 96, height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('🔮', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('divine',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('${S.t("settings.about_version")} $_version',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(S.t('settings.about_github')),
                  subtitle: const Text(_repoUrl),
                  onTap: () => _openUrl(context, _repoUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(S.t('settings.about_license')),
                  subtitle: const Text('MIT'),
                ),
                const ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('Engines'),
                  subtitle: Text('14 占卜引擎 · 真八字 / 紫微 / 占星 / 塔罗 / 周易 / 雷诺曼 / 梅花 / 数字命理 / 卢恩 / Ogham / 经典 / 是否 / AI'),
                ),
                const ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Credits'),
                  subtitle: Text(
                    'Tarot images: Wikimedia Commons (Rider-Waite, 1909, public domain)\n'
                    'Astrology: Swiss Ephemeris\n'
                    'Lunar calendar: 6tail/lunar',
                  ),
                  isThreeLine: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
