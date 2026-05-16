# divine —— 多体系占卜 app

跨平台占卜 app（Android / Windows / Web / macOS），算法层本地纯函数，解读层接 OpenAI 兼容的任意 LLM（DeepSeek / OpenAI / Kimi / 智谱 / Ollama / …），用户自带 key。

## 已实现的占卜法

| 体系 | 实现 |
|---|---|
| 塔罗 🃏 | 韦特 78 张 + 4 种牌阵, 含正逆位 |
| 雷诺曼 🎴 | 36 张 + 三牌线 / 九宫格 |
| 周易六爻 ☯ | 三钱法 + 64 卦 + 动爻变卦, 内置卦辞象传 |
| 梅花易数 🌸 | 邵雍数字起卦, 体用变互 |
| 八字 🐉 | **真排盘 (lunar 库)**: 公历→农历→节气→年/月/日/时四柱干支, 日主 |
| 西洋占星 🪐 | **AI 近似**: 上升/太阳/月亮 + 行星宫位 (LLM 凭训练知识近似排盘) |
| 数字命理 🔢 | 毕达哥拉斯生命数 + 大师数 |
| 卢恩符文 ᚱ | Elder Futhark 24 符 + 3 阵 |
| Ogham 🌳 | 凯尔特树文字 20 + 5 forfeda |
| 经典占卜 📖 | 圣经 / 道德经 / 论语 / 诗经 / 庄子 随机引段 |
| 是否占卜 ⚖️ | 塔罗 / 三硬币 / 魔法八号球 |
| 通用 AI 占卜 🔮 | 神谕 / 每日一签 / 决策辅助 / 关系洞察 |

## 体验要点

- **离线占卜**: 9 种占卜法没配 LLM 也能用, 先看抽到的牌/卦, 想看 AI 解读再点
- **结果先于解读**: 用户主动点「让 AI 解读这次占卜」才走 LLM, 不浪费 token
- **多人档案**: 出生信息建一次, 八字/占星/数字命理一键复用
- **流式 + 推理可见**: 支持 DeepSeek R1 等推理模型, 思考过程可折叠展开
- **断流可续**: 切到别的 app 网络断了, 会保留已生成部分, 点「继续」让 LLM 接着写
- **历史**: 自动保存, 标签 + 关键词搜索 + 引擎筛选 + Markdown 导出
- **懒人配置**: 一键预设 + 一键打开 provider 注册页 + 测试连接

## 后续路线 (Roadmap)

按复杂度排, 不一定全做:

- [ ] **紫微斗数** — 14 主星安星法 + 12 宫 + 三方四正. 至少 1-2 天工程
- [ ] **占星本命盘真算** — Swiss Ephemeris (sweph) Dart 绑定, 行星精确黄经 + Placidus 宫位 + 相位. 涉及 FFI 和星历数据文件, 跨平台调试 1-2 天
- [ ] **真实韦特塔罗牌面** — 78 张公版图片 + 翻牌动画. 资源准备 + UI 重做 2-3 小时
- [ ] **抽牌动画** — 牌从牌堆翻出 + 摆位置 + 翻面. 1-2 小时
- [ ] **八字深入** — 十神映射 + 大运排盘 + 流年提示 + 旺衰用神. 半天
- [ ] **多模态** — 手相 / 面相, 调多模态 LLM 看图. 1.5-2 小时
- [ ] **Android 前台服务保活网络** — 治本解决后台被 OEM 杀进程导致流断. 1-2 小时
- [ ] **iOS 签名 + TestFlight 上传** — 需要 Apple Developer 账号 (¥688/年). CI 路径已留口子

## 怎么跑

```bash
cd divine_app
flutter pub get

flutter run -d chrome     # 浏览器, 最快
flutter run -d macos       # Mac 桌面
flutter run                # 真机/模拟器 (需要 Xcode / Android Studio)
```

第一次进入 → 右上角齿轮 → 「不会申请 key？看教程」→ 选 DeepSeek → 跳浏览器申请 → 粘贴 → 测试连接 → 保存。

## 文件结构

```
lib/
├── main.dart                          # 入口 + 引擎注册
├── core/                              # 占卜引擎 (每种占卜法一个文件)
│   ├── divination.dart                # 抽象层 + 注册表 + InputField/Variant 定义
│   ├── tarot.dart  lenormand.dart
│   ├── iching.dart  plum.dart
│   ├── bazi.dart  astrology.dart
│   ├── numerology.dart  runes.dart  ogham.dart
│   ├── biblio.dart  yesno.dart  generic.dart
├── llm/
│   ├── config.dart                    # LLM 配置 + 预设
│   └── client.dart                    # OpenAI 兼容 SSE 流式 (支持 reasoning_content)
├── storage/
│   ├── history.dart                   # 历史 (含 tags)
│   └── profile.dart                   # 出生档案
└── ui/screens/
    ├── home_screen.dart
    ├── reading_screen.dart             # 占卜 + 聊天 + 标签编辑
    ├── settings_screen.dart            # LLM 设置
    ├── provider_guide_screen.dart      # 申请 key 教程 + 跳转
    ├── profiles_screen.dart            # 档案管理
    └── history_screen.dart             # 历史搜索 + 标签筛选 + 导出
```

## 怎么加新占卜法

```dart
// lib/core/your_method.dart
class YourEngine extends DivinationEngine {
  @override String get id => 'your_id';
  @override String get nameZh => '你的占卜法';
  @override String get emoji => '✨';
  // ... 实现 systemPrompt / variants / perform / buildUserPrompt
}

// lib/main.dart 加一行
DivinationRegistry.register(YourEngine());
```

UI 自动识别, 不用改任何其他文件。

## CI / 发布

`.github/workflows/build.yml`:
- push 任何分支 → 跑 test + analyze + 双平台 build, 产物上传为 artifacts (30 天)
- push tag `v*` → 自动建一个 GitHub Release, 挂 APK + Windows zip

```bash
git tag v0.x.y
git push origin v0.x.y
```

## 数据存储

- LLM API key: 系统钥匙串 (iOS Keychain / Android Keystore via flutter_secure_storage)
- 占卜历史 / 档案 / 其它配置: `SharedPreferences` (本地, 不上云)
- 历史可导出为 Markdown (在历史页右上角分享图标)

## License

MIT.
