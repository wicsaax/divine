// 各 LLM provider 的申请教程 + 跳转 + 一键应用预设到设置.
//
// 设计原则: 让"完全不会"的用户也能 3 分钟内跑通 - 看教程, 点链接, 复制 key.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../llm/config.dart';

class _ProviderGuide {
  final String name;
  final String tagline; // 一句话定位
  final String? badge; // "推荐" 等小标签
  final String endpoint;
  final String defaultModel;
  final String signupUrl;
  final String keysUrl;
  final List<String> steps;
  final String pricing;
  const _ProviderGuide({
    required this.name,
    required this.tagline,
    this.badge,
    required this.endpoint,
    required this.defaultModel,
    required this.signupUrl,
    required this.keysUrl,
    required this.steps,
    required this.pricing,
  });
}

const List<_ProviderGuide> _guides = [
  _ProviderGuide(
    name: 'DeepSeek',
    tagline: '国产, 便宜稳定, 起步首选',
    badge: '推荐',
    endpoint: 'https://api.deepseek.com/v1',
    defaultModel: 'deepseek-v4-flash',
    signupUrl: 'https://platform.deepseek.com/sign_up',
    keysUrl: 'https://platform.deepseek.com/api_keys',
    pricing: '便宜, 一次完整占卜成本极低 · 具体价格以官网为准',
    steps: [
      '点"去注册" → 用手机号注册并实名认证 (建议绑微信支付方便充值)',
      '充值 ¥5-10 (够玩很久, 几百次占卜)',
      '点"创建 API key" → 起个名字 → 生成 key',
      '点 key 旁边的复制按钮, 然后回到 LLM 设置粘贴',
      '日常用 deepseek-v4-flash 就行; 想要更深的推理换 deepseek-v4-pro',
    ],
  ),
  _ProviderGuide(
    name: 'Kimi (月之暗面)',
    tagline: '国产, 长上下文 (128k 起), 中文体验佳',
    endpoint: 'https://api.moonshot.cn/v1',
    defaultModel: 'moonshot-v1-8k',
    signupUrl: 'https://platform.moonshot.cn/',
    keysUrl: 'https://platform.moonshot.cn/console/api-keys',
    pricing: '约 ¥12 / 百万输入 tokens · 新账号有免费额度',
    steps: [
      '点"去注册" → 手机号或微信注册',
      '完成实名认证 (国内服务都要)',
      '点"创建 API key" → 复制',
      '回到 LLM 设置粘贴 key',
      '模型可选 moonshot-v1-8k / 32k / 128k, 上下文越大越贵',
    ],
  ),
  _ProviderGuide(
    name: '智谱 GLM',
    tagline: '国产, GLM 系列, 兼容 OpenAI 协议',
    endpoint: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-4-flash',
    signupUrl: 'https://www.bigmodel.cn/',
    keysUrl: 'https://open.bigmodel.cn/usercenter/apikeys',
    pricing: 'glm-4-flash 完全免费 · glm-4 约 ¥1 / 千输出 tokens',
    steps: [
      '点"去注册" → 手机号或微信注册',
      '点"创建 API key" → 复制',
      '回到 LLM 设置粘贴',
      '想免费玩选 glm-4-flash, 效果一般; 要效果好选 glm-4-plus',
    ],
  ),
  _ProviderGuide(
    name: 'OpenAI',
    tagline: '国外, 需要国际信用卡 + 网络环境',
    endpoint: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    signupUrl: 'https://platform.openai.com/signup',
    keysUrl: 'https://platform.openai.com/api-keys',
    pricing: 'gpt-4o-mini 约 \$0.15 / 百万输入 tokens · 需绑国际卡',
    steps: [
      '需要国际网络环境 + 一张国际信用卡 (国内卡几乎都不行)',
      '注册 OpenAI 账号, 国内手机号会被拒, 用海外手机号或 SMS 服务',
      '创建 API key, 充值',
      '回到 LLM 设置粘贴; 模型 gpt-4o-mini 性价比最高',
      '如果在国内访问慢, 可以用兼容的代理服务 (endpoint 改成代理地址)',
    ],
  ),
  _ProviderGuide(
    name: 'Ollama 本地',
    tagline: '本地跑, 无需 key, 完全私密免费',
    endpoint: 'http://localhost:11434/v1',
    defaultModel: 'qwen2.5:7b',
    signupUrl: 'https://ollama.com/download',
    keysUrl: '',
    pricing: '完全免费 · 但只能在装了 ollama 的电脑上用; 手机连同 WiFi 也行',
    steps: [
      '在电脑上下载并安装 Ollama',
      '电脑终端运行: ollama pull qwen2.5:7b (或别的模型)',
      '终端运行: ollama serve (默认 11434 端口)',
      '手机和电脑在同一 WiFi, 把 endpoint 改成 http://<电脑IP>:11434/v1',
      'API key 随便填 (例: ollama), 模型填刚拉的模型名',
    ],
  ),
];

class ProviderGuideScreen extends StatelessWidget {
  const ProviderGuideScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      // 退路: 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        SnackBar(content: Text('无法直接打开, 已复制到剪贴板: $url')),
      );
    }
  }

  void _applyPreset(BuildContext context, _ProviderGuide g) {
    Navigator.of(context).pop<LLMPreset>(
      LLMPreset(g.name, g.endpoint, g.defaultModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('申请 API key 教程'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _guides.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _GuideCard(
          guide: _guides[i],
          theme: theme,
          onOpen: (url) => _openUrl(context, url),
          onUsePreset: () => _applyPreset(context, _guides[i]),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.guide,
    required this.theme,
    required this.onOpen,
    required this.onUsePreset,
  });

  final _ProviderGuide guide;
  final ThemeData theme;
  final void Function(String url) onOpen;
  final VoidCallback onUsePreset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(guide.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (guide.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(guide.badge!,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(guide.tagline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(guide.pricing,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (guide.signupUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onOpen(guide.signupUrl),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('去注册 / 下载'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (guide.keysUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => onOpen(guide.keysUrl),
                    icon: const Icon(Icons.vpn_key_outlined, size: 16),
                    label: const Text('创建 API key'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: onUsePreset,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('用这个'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('操作步骤',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (var i = 0; i < guide.steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20, height: 20,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(guide.steps[i],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
