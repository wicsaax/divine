# divine —— 多体系占卜 app

Flutter 写的占卜 app，跨平台（iOS / Android / Web / macOS）。算法层（抽牌、起卦、抽符文）完全本地、纯函数；解读层接 OpenAI 兼容的任意 LLM（DeepSeek / OpenAI / Kimi / 智谱 / Ollama / …），用户自带 key。

## 首版包含的占卜法

| 体系 | 实现 | 说明 |
|------|------|------|
| 塔罗 🃏 | 韦特 78 张 + 4 种牌阵 (单张 / 时间线 / 情境-行动-结果 / 凯尔特十字) | 算法本地, 含正逆位 |
| 周易六爻 ☯ | 三钱法 + 64 卦 (王弼序) + 动爻变卦 | 卦辞、象辞简译已内置 |
| 卢恩符文 ᚱ | Elder Futhark 24 符 + 3 种阵 (单符 / 奥丁三符 / 诺恩五符) | 区分可逆/不可逆符文 |
| 通用 AI 占卜 🔮 | 无固定算法, 让 AI 直接对答 | 4 种模式: 神谕回响 / 每日一签 / 决策辅助 / 关系洞察 |

## 怎么扩展（加更多占卜法）

每个占卜法是一个独立的 Dart 文件，实现 `DivinationEngine` 接口，然后在 `lib/main.dart` 里 `register` 一行就行。UI 自动识别。

例如要加八字 / 紫微 / 奇门遁甲：

```dart
// lib/core/bazi.dart
class BaziEngine extends DivinationEngine {
  @override String get id => 'bazi';
  @override String get nameZh => '八字';
  @override String get emoji => '🐲';
  // ... 实现 perform / buildUserPrompt / systemPrompt
}

// lib/main.dart 加一行
DivinationRegistry.register(BaziEngine());
```

不需要改任何 UI 代码。

## 怎么跑

```bash
cd divine_app

# 跑在 macOS 桌面 (最快, 不需要 Xcode/Android Studio)
flutter run -d macos

# 跑在 Chrome (Web)
flutter run -d chrome

# 跑在 iOS 模拟器 (需要 Xcode)
open -a Simulator
flutter run

# 跑在 Android 模拟器 (需要 Android Studio)
flutter run
```

第一次进入 app 后，点右上角齿轮进入设置，填 endpoint + API key + model（顶部有快捷预设，DeepSeek / OpenAI / Kimi / 智谱 / Ollama 一键填）。

## 文件结构

```
lib/
├── main.dart                    # 入口, 注册引擎
├── core/
│   ├── divination.dart          # 抽象层 (DivinationEngine + DivinationRegistry)
│   ├── tarot.dart               # 塔罗 78 张 + 4 种牌阵
│   ├── runes.dart               # 卢恩 24 符 + 3 种阵
│   ├── iching.dart              # 周易 64 卦 + 三钱法
│   └── generic.dart             # 通用 AI 占卜
├── llm/
│   ├── config.dart              # LLM 配置 + 预设
│   └── client.dart              # OpenAI 兼容 SSE 流式客户端
├── storage/
│   └── history.dart             # 历史记录 (shared_preferences)
└── ui/
    └── screens/
        ├── home_screen.dart     # 首页, 选占卜方式
        ├── reading_screen.dart  # 占卜 + 聊天解读
        ├── settings_screen.dart # LLM 设置
        └── history_screen.dart  # 历史记录
```

## API key 安全

通过 `flutter_secure_storage` 保存到：
- iOS: Keychain
- Android: EncryptedSharedPreferences (基于 Keystore)
- macOS: Keychain
- Web: 仅当前 session（浏览器限制）

非敏感配置（endpoint / model / temperature）走 `shared_preferences`。

## 后续路线

- [ ] 八字 / 紫微（需要农历 + 节气库，推荐 `lunar_dart`）
- [ ] 占星本命盘（需要瑞士星历表，有 Dart 绑定 `sweph`）
- [ ] 抽牌动画
- [ ] 真实塔罗牌面（开源韦特变公版）
- [ ] 历史搜索 / 标签 / 导出
- [ ] 多人档案（问出生年月的占卜法）
- [ ] 把 prompt 模板暴露给用户编辑
