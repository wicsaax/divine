import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../../core/divination.dart';
import '../../i18n/strings.dart';
import '../../llm/client.dart';
import '../../llm/config.dart';
import '../../storage/app_settings.dart';
import '../../storage/history.dart';
import '../../storage/profile.dart';
import '../../storage/prompt_store.dart';
import '../widgets/bazi_widget.dart';
import '../widgets/crystal_ball_widget.dart';
import '../widgets/hexagram_widget.dart';
import '../widgets/lenormand_widget.dart';
import '../widgets/natal_chart_widget.dart';
import '../widgets/numerology_widget.dart';
import '../widgets/plum_widget.dart';
import '../widgets/rune_stone_widget.dart';
import '../widgets/scroll_widget.dart';
import '../widgets/tarot_card_widget.dart';
import '../widgets/yesno_widget.dart';
import '../widgets/ziwei_chart_widget.dart';
import 'profiles_screen.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.engine,
    required this.config,
    this.replay,
  });

  final DivinationEngine engine;
  final LLMConfig config;

  /// 若传入, 则进入"回看历史"模式, 不会再做 LLM 调用.
  final ReadingRecord? replay;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late String _variantKey = widget.engine.defaultVariantKey;
  final _questionCtl = TextEditingController();
  final _followupCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  late final Map<String, TextEditingController> _inputCtls = {
    for (final f in widget.engine.inputs) f.key: TextEditingController(),
  };

  DivinationResult? _result;
  final List<ChatMessage> _messages = [];
  bool _streaming = false;
  String _streamingText = '';
  String _streamingReasoning = '';
  String? _error;
  bool _saved = false;
  String? _recordId;        // 同一次 reading 反复保存用同一个 id (避免历史里重复)
  List<String> _tags = [];
  bool _autoScroll = true;  // 用户在底部时为 true; 手动上滑后为 false 直到回到底部
  /// 手抽模式 (用户自己抽牌/起卦) vs 随机模式. supportsManualInput=true 的引擎默认手抽.
  late bool _manualMode = widget.engine.supportsManualInput;
  /// 手抽模式下用户选/填的字段值, 由 manualFields(variantKey) 的 key 索引.
  final Map<String, String> _manualSelections = {};

  Color get _accent => widget.engine.accentColorHex != null
      ? Color(widget.engine.accentColorHex!)
      : Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    if (widget.replay != null) {
      _result = widget.replay!.result;
      _variantKey = _result!.variantKey;
      _questionCtl.text = widget.replay!.question;
      _messages.addAll(widget.replay!.messages);
      _saved = true;
      _recordId = widget.replay!.id;
      _tags = List.of(widget.replay!.tags);
    }
    _resetManualDefaults();
  }

  /// 把当前变体下手抽字段的默认值填进 _manualSelections.
  /// 在 initState / 切变体 / 切手抽模式时调用.
  void _resetManualDefaults() {
    _manualSelections.clear();
    if (!widget.engine.supportsManualInput) return;
    for (final f in widget.engine.manualFields(_variantKey)) {
      if (f.defaultValue != null) {
        _manualSelections[f.key] = f.defaultValue!;
      }
    }
  }

  @override
  void dispose() {
    _autoSaveIfNeeded();
    _questionCtl.dispose();
    _followupCtl.dispose();
    _scrollCtl.dispose();
    for (final c in _inputCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _autoSaveIfNeeded() {
    if (_saved) return;
    if (_result == null) return;
    if (!AppSettings.instance.saveHistory) return; // 用户关了历史保存
    _recordId ??= DateTime.now().microsecondsSinceEpoch.toString();
    HistoryStore.append(ReadingRecord(
      id: _recordId!,
      engineId: widget.engine.id,
      engineName: widget.engine.nameZh,
      question: _questionCtl.text.trim(),
      result: _result!,
      messages: _messages,
      tags: _tags,
    ));
    _saved = true;
  }

  Future<void> _pickProfile() async {
    final p = await Navigator.of(context).push<BirthProfile>(
      MaterialPageRoute(builder: (_) => const ProfilesScreen(pickMode: true)),
    );
    if (p == null) return;
    final mapped = p.toEngineInputs();
    setState(() {
      for (final e in mapped.entries) {
        if (_inputCtls.containsKey(e.key)) {
          _inputCtls[e.key]!.text = e.value;
        }
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已填入「${p.name}」的档案')),
      );
    }
  }

  String? _validateInputs() {
    for (final f in widget.engine.inputs) {
      if (f.required && (_inputCtls[f.key]?.text.trim().isEmpty ?? true)) {
        return '请先填写「${f.label}」';
      }
    }
    return null;
  }

  Future<void> _startReading() async {
    if (_streaming) return;
    final err = _validateInputs();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    HapticFeedback.mediumImpact();
    // 把用户的"问题"也作为 input 传给 engine, 引擎可选择性使用
    // (例如周公解梦字典模式需要拿到梦境描述来扫关键词).
    final inputs = {
      for (final e in _inputCtls.entries) e.key: e.value.text.trim(),
      'question': _questionCtl.text.trim(),
    };

    DivinationResult result;
    try {
      result = await Future.value(
        widget.engine.perform(variantKey: _variantKey, inputs: inputs),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;

    setState(() {
      _result = result;
      _messages.clear();
      _error = null;
      _saved = false;
    });

    // 该次结果若没有结构化条目, 抽完直接走 LLM (前提是 LLM 已配置).
    // 有结构化条目就停下来, 等用户点"解读"才调 LLM (允许零成本玩占卜).
    if (result.items.isEmpty && widget.config.isReady) {
      await _interpret();
    }
  }

  /// 手抽模式: 用户已经在本地抽完牌/起完卦, 填了字段, 直接组装 result 再走 LLM 解读.
  /// 与 _startReading 的区别: 用户的意图就是"让 AI 解读我抽到的", 所以 LLM 已配则自动调.
  Future<void> _startManualReading() async {
    if (_streaming) return;
    HapticFeedback.mediumImpact();
    DivinationResult result;
    try {
      result = await Future.value(
        widget.engine.performManual(
          variantKey: _variantKey,
          selections: Map.of(_manualSelections),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _messages.clear();
      _error = null;
      _saved = false;
    });
    if (widget.config.isReady) {
      await _interpret();
    }
  }

  /// 点"解读"或必须 LLM 引擎抽完后调用. 把 result + question 喂给 LLM 流式输出.
  Future<void> _interpret() async {
    if (_streaming || _result == null) return;
    final question = _questionCtl.text.trim();
    final userPrompt = widget.engine.buildUserPrompt(
      question: question,
      result: _result!,
    );
    // 优先用用户激活的自定义 prompt
    final systemPrompt = PromptStore.instance
        .resolveSystemPrompt(widget.engine.id, widget.engine.systemPrompt);
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(role: 'system', content: systemPrompt))
        ..add(ChatMessage(role: 'user', content: userPrompt));
    });
    await _runStream();
  }

  Future<void> _sendFollowup() async {
    if (_streaming) return;
    final text = _followupCtl.text.trim();
    if (text.isEmpty) return;
    _followupCtl.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _saved = false;
    });
    await _runStream();
  }

  Future<void> _runStream() async {
    final liveStreaming = AppSettings.instance.streaming;
    setState(() {
      _streaming = true;
      _streamingText = '';
      _streamingReasoning = '';
      _error = null;
    });
    _scrollToBottom();
    final contentBuf = StringBuffer();
    final reasoningBuf = StringBuffer();
    try {
      final stream = LLMClient.streamChat(
        widget.config,
        _messages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
      );
      await for (final chunk in stream) {
        if (chunk.type == LLMChunkType.reasoning) {
          reasoningBuf.write(chunk.text);
          // 用户关了流式 → 不实时刷新 UI, 等结束一次性显示
          if (liveStreaming) {
            setState(() => _streamingReasoning = reasoningBuf.toString());
          }
        } else {
          contentBuf.write(chunk.text);
          if (liveStreaming) {
            setState(() => _streamingText = contentBuf.toString());
          }
        }
        if (liveStreaming) _scrollToBottom();
      }
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: contentBuf.toString(),
          reasoning: reasoningBuf.toString(),
        ));
        _streaming = false;
        _streamingText = '';
        _streamingReasoning = '';
        _saved = false;
      });
      _scrollToBottom();
    } catch (e) {
      // 流被打断: 保留已经收到的部分, 标记 interrupted, 用户可以点"继续"
      final partial = contentBuf.toString();
      final partialReasoning = reasoningBuf.toString();
      setState(() {
        if (partial.isNotEmpty || partialReasoning.isNotEmpty) {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: partial,
            reasoning: partialReasoning,
            interrupted: true,
          ));
        }
        _streaming = false;
        _streamingText = '';
        _streamingReasoning = '';
        _error = e.toString();
        _saved = false;
      });
    }
  }

  /// 续传: 给 LLM 一条 user 指令"继续刚才的回答", 让它接着说.
  Future<void> _continueInterrupted() async {
    if (_streaming) return;
    // 已经在 _messages 末尾有一条 interrupted 的 assistant. 直接发"请继续".
    setState(() {
      _messages.add(const ChatMessage(
        role: 'user',
        content: '(刚才网络中断了, 请接着上面没说完的部分继续, 不要重复已经写过的内容.)',
      ));
      _error = null;
    });
    await _runStream();
  }

  /// 仅在 _autoScroll = true 时滚到底部. 用户上滑读历史时不强行拉回.
  void _scrollToBottom({bool force = false}) {
    if (!force && !_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 用户手动滚动时调; 据当前位置更新 _autoScroll.
  ///
  /// 只听两种通知:
  /// - UserScrollNotification: 仅用户手势触发, 程序 animateTo 不会发. 用户一动手指就关掉自动跟随.
  /// - ScrollEndNotification: 滚动停止时发. 如果停在底部 (含 fling 惯性结束), 恢复自动跟随.
  /// 这样程序性的 _scrollToBottom 动画不会反过来抖 _autoScroll, 跟用户手势抢方向.
  bool _onScroll(ScrollNotification n) {
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
      if (_autoScroll) setState(() => _autoScroll = false);
      return false;
    }
    if (n is ScrollEndNotification) {
      final pos = n.metrics;
      final atBottom = pos.maxScrollExtent - pos.pixels < 48;
      if (atBottom != _autoScroll) {
        setState(() => _autoScroll = atBottom);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.engine.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(widget.engine.nameZh),
          ],
        ),
        actions: [
          if (_result != null && !_streaming)
            IconButton(
              tooltip: S.t('btn.save'),
              onPressed: _saved
                  ? null
                  : () {
                      _autoSaveIfNeeded();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(S.t('reading.saved'))),
                      );
                      setState(() {});
                    },
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView(
                    controller: _scrollCtl,
                    padding: const EdgeInsets.all(16),
                    children: _buildContent(theme),
                  ),
                ),
                // 用户上滑且正在流式 → 显示一个回到底部的小浮标
                if (!_autoScroll && _streaming)
                  Positioned(
                    right: 16, bottom: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: _accent,
                      onPressed: () {
                        setState(() => _autoScroll = true);
                        _scrollToBottom(force: true);
                      },
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // 解读已经开始 (有 message) 后才出现追问栏
          if (_result != null && _messages.isNotEmpty) _buildFollowupBar(theme),
        ],
      ),
    );
  }

  List<Widget> _buildContent(ThemeData theme) {
    final widgets = <Widget>[];
    if (_result == null) {
      widgets.addAll(_buildSetupSection(theme));
    } else {
      widgets.add(_DivinationCard(engine: widget.engine, result: _result!));
      widgets.add(const SizedBox(height: 12));
      widgets.add(_TagEditor(
        tags: _tags,
        accent: _accent,
        onChanged: (newTags) {
          setState(() {
            _tags = newTags;
            _saved = false;
          });
        },
      ));
      widgets.add(const SizedBox(height: 12));

      // 还没开始解读 + 有可独立呈现的结果 → 显示"解读"按钮
      if (_messages.isEmpty && !_streaming) {
        widgets.add(_InterpretCTA(
          accent: _accent,
          configured: widget.config.isReady,
          onTap: widget.config.isReady ? _interpret : null,
        ));
        return widgets;
      }

      // 如果用户输入了问题, 显示为首个聊天气泡 (替代隐藏的结构化 prompt)
      final q = _questionCtl.text.trim();
      if (q.isNotEmpty) {
        widgets.add(_ChatBubble(
          message: ChatMessage(role: 'user', content: q),
          accent: _accent,
        ));
      }
      // 跳过 system + 首个 user 消息 (那是给 LLM 看的结构化 prompt)
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.role == 'system') continue;
        if (i == 1 && m.role == 'user') continue;
        // assistant 消息且带思考链 → 折叠面板 (默认折起, 用户可点开)
        if (m.role == 'assistant' && m.reasoning.isNotEmpty) {
          widgets.add(_ReasoningPanel(
            text: m.reasoning,
            accent: _accent,
            initialExpanded: false,
          ));
        }
        widgets.add(_ChatBubble(message: m, accent: _accent));
        // 被打断的助手消息 → 下面跟"继续"按钮 (仅最后一条 + 不在流式中)
        if (m.role == 'assistant' &&
            m.interrupted &&
            !_streaming &&
            i == _messages.length - 1) {
          widgets.add(_ContinueButton(accent: _accent, onTap: _continueInterrupted));
        }
      }
      // 推理过程 (R1 等模型): 流式中显示, 默认展开
      if (_streaming && _streamingReasoning.isNotEmpty) {
        widgets.add(_ReasoningPanel(
          text: _streamingReasoning,
          accent: _accent,
          live: true,
          initialExpanded: _streamingText.isEmpty, // 正文开始后自动折起
        ));
      }
      // 正文流式
      if (_streaming && _streamingText.isNotEmpty) {
        widgets.add(_ChatBubble(
          message: ChatMessage(role: 'assistant', content: _streamingText),
          accent: _accent,
          streaming: true,
        ));
      }
      // 等待中 (还没收到任何内容)
      if (_streaming && _streamingText.isEmpty && _streamingReasoning.isEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 26, height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(S.t('reading.thinking'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        ));
      }
      if (_error != null) {
        widgets.add(Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildSetupSection(ThemeData theme) {
    final engine = widget.engine;
    final variants = engine.variants;
    final inputs = engine.inputs;
    final isDark = theme.brightness == Brightness.dark;
    return [
      Card(
        color: _accent.withValues(alpha: isDark ? 0.25 : 0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: isDark ? 0.45 : 0.25),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(engine.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(engine.nameZh, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(engine.tagline,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(engine.description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (variants.length > 1) ...[
        Text(S.t('reading.method'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _variantKey,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _variantKey = val;
                _resetManualDefaults();
              });
            }
          },
          child: Column(
            children: [
              for (final v in variants)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _variantKey == v.key
                          ? _accent
                          : theme.colorScheme.outlineVariant,
                      width: _variantKey == v.key ? 1.5 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    value: v.key,
                    title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(v.description),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    activeColor: _accent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      // 手抽模式开关 + 字段. 只有 supportsManualInput 的引擎才显示.
      if (engine.supportsManualInput) ...[
        Text(S.t('reading.manual_section'),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(S.t('reading.manual_self')),
                icon: const Icon(Icons.back_hand_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text(S.t('reading.manual_random')),
                icon: const Icon(Icons.casino_outlined),
              ),
            ],
            selected: {_manualMode},
            onSelectionChanged: (s) {
              setState(() {
                _manualMode = s.first;
                if (_manualMode) _resetManualDefaults();
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _accent.withValues(alpha: 0.25)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _manualMode
              ? S.t('reading.manual_hint_self')
              : S.t('reading.manual_hint_random'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (_manualMode) ..._buildManualFieldsSection(theme),
      ],
      if (inputs.isNotEmpty) ...[
        Row(
          children: [
            Text(S.t('reading.info'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickProfile,
              icon: const Icon(Icons.contacts_outlined, size: 16),
              label: Text(S.t('reading.from_profile')),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final f in inputs) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _inputCtls[f.key],
              keyboardType: f.type == InputFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: '${f.label}${f.required ? " *" : ""}',
                hintText: f.hint,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
      ],
      Text(S.t('reading.you_question'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _questionCtl,
        maxLines: 4,
        minLines: 2,
        decoration: InputDecoration(hintText: S.t('reading.question_hint')),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _streaming
              ? null
              : (engine.supportsManualInput && _manualMode
                  ? _startManualReading
                  : _startReading),
          style: FilledButton.styleFrom(backgroundColor: _accent),
          icon: Icon(engine.supportsManualInput && _manualMode
              ? Icons.psychology_alt_outlined
              : Icons.auto_awesome),
          label: Text(engine.supportsManualInput && _manualMode
              ? S.t('reading.manual_interpret')
              : S.t('btn.start')),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// 渲染手抽字段 (按 group 分组, picker/toggle/numberInput 三种).
  List<Widget> _buildManualFieldsSection(ThemeData theme) {
    final fields = widget.engine.manualFields(_variantKey);
    if (fields.isEmpty) return const [];

    // 按 group 分组保序
    final groups = <String?, List<ManualField>>{};
    final groupOrder = <String?>[];
    for (final f in fields) {
      if (!groups.containsKey(f.group)) {
        groupOrder.add(f.group);
        groups[f.group] = [];
      }
      groups[f.group]!.add(f);
    }

    final widgets = <Widget>[];
    for (final g in groupOrder) {
      if (g != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
          child: Text(
            g,
            style: theme.textTheme.labelLarge?.copyWith(
              color: _accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      }
      for (final f in groups[g]!) {
        widgets.add(_buildManualField(theme, f));
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  Widget _buildManualField(ThemeData theme, ManualField f) {
    switch (f.kind) {
      case ManualFieldKind.picker:
        return _buildManualPicker(theme, f);
      case ManualFieldKind.toggle:
        return _buildManualToggle(theme, f);
      case ManualFieldKind.numberInput:
        return _buildManualNumber(theme, f);
    }
  }

  Widget _buildManualPicker(ThemeData theme, ManualField f) {
    final currentKey = _manualSelections[f.key];
    final current = currentKey == null
        ? null
        : f.options.firstWhere(
            (o) => o.key == currentKey,
            orElse: () => const ManualFieldOption(key: '', label: ''),
          );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await _openPickerSheet(f);
        if (picked != null && mounted) {
          setState(() => _manualSelections[f.key] = picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: f.label,
          helperText: f.hint,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: current == null || current.key.isEmpty
            ? Text(S.t('reading.manual_pick_prompt'),
                style: TextStyle(color: theme.hintColor))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(current.label,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (current.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        current.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildManualToggle(ThemeData theme, ManualField f) {
    final segs = f.options.take(2).toList();
    final current = _manualSelections[f.key] ?? f.defaultValue ?? segs.first.key;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.label, style: theme.textTheme.bodyMedium),
              if (f.hint != null)
                Text(f.hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<String>(
          segments: [
            for (final o in segs)
              ButtonSegment(value: o.key, label: Text(o.label)),
          ],
          selected: {current},
          onSelectionChanged: (s) =>
              setState(() => _manualSelections[f.key] = s.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }

  Widget _buildManualNumber(ThemeData theme, ManualField f) {
    // 用 ValueKey 包含变体, 切变体后控件 remount, 老值不会残留.
    return TextField(
      key: ValueKey('manual-num/${widget.engine.id}/$_variantKey/${f.key}'),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: f.label,
        helperText: f.hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => _manualSelections[f.key] = v.trim(),
    );
  }

  Future<String?> _openPickerSheet(ManualField f) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        var filter = '';
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final q = filter.trim().toLowerCase();
          final filtered = q.isEmpty
              ? f.options
              : f.options.where((o) {
                  return o.label.toLowerCase().contains(q) ||
                      (o.subtitle?.toLowerCase().contains(q) ?? false);
                }).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.label,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (f.options.length >= 8)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: S.t('reading.manual_search'),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setSheetState(() => filter = v),
                        ),
                      ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          return ListTile(
                            title: Text(o.label),
                            subtitle: o.subtitle == null
                                ? null
                                : Text(o.subtitle!),
                            onTap: () => Navigator.of(ctx).pop(o.key),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildFollowupBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _followupCtl,
                minLines: 1,
                maxLines: 4,
                enabled: !_streaming,
                decoration: InputDecoration(
                  hintText: S.t('reading.follow_hint'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _sendFollowup(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _streaming ? theme.disabledColor : _accent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _streaming ? null : _sendFollowup,
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DivinationCard extends StatelessWidget {
  const _DivinationCard({required this.engine, required this.result});
  final DivinationEngine engine;
  final DivinationResult result;

  Color _accent(BuildContext context) => engine.accentColorHex != null
      ? Color(engine.accentColorHex!)
      : Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.32 : 0.16),
            accent.withValues(alpha: isDark ? 0.10 : 0.04),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(engine.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.variantName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 引擎专属视觉 dispatch
            ..._buildEngineVisual(context, accent),
            if (engine.id == 'bazi' || engine.id == 'astrology' || engine.id == 'oracle')
              _buildExtrasOnly(context),
          ],
        ),
      ),
    );
  }

  /// 引擎专属视觉. 每种占卜法走自己的入场动画 + 视觉.
  List<Widget> _buildEngineVisual(BuildContext context, Color accent) {
    final id = engine.id;
    final ex = result.extras;
    if (id == 'tarot') {
      // 塔罗已经在 _buildItems 走真图 + 翻牌动画
      return _buildItems(context, accent);
    }
    if (id == 'lenormand') {
      return [_LenormandRow(result: result)];
    }
    if (id == 'iching') return _buildIChing(context, accent);
    if (id == 'plum') {
      return [
        PlumNumberDrop(
          n1: (ex['numbers'] as List)[0] as int,
          n2: (ex['numbers'] as List)[1] as int,
          n3: (ex['numbers'] as List)[2] as int,
          upperTrigram: ex['upperTrigram'] as String,
          lowerTrigram: ex['lowerTrigram'] as String,
          changingYao: ex['changingYao'] as int,
          accent: accent,
        ),
        const SizedBox(height: 4),
        ..._buildIChing(context, accent),
      ];
    }
    if (id == 'bazi') {
      final p = (ex['pillars'] as Map);
      return [
        BaziPillars(
          year: p['year'] as String,
          month: p['month'] as String,
          day: p['day'] as String,
          hour: (p['hour'] as String).isNotEmpty ? p['hour'] as String : '—',
          dayMaster: ex['dayMaster'] as String,
          hourKnown: (p['hour'] as String).isNotEmpty,
        ),
      ];
    }
    if (id == 'ziwei') return _buildZiWei(context, accent);
    if (id == 'astrology') {
      final planets = (ex['planets'] as List).cast<Map<String, dynamic>>();
      final houses = (ex['houses'] as List).cast<Map>();
      final cusps = <double>[0.0];
      for (var i = 1; i <= 12; i++) {
        cusps.add(houses[i - 1]['cuspLongitude'] as double);
      }
      final aspects = (ex['aspects'] as List).cast<Map<String, dynamic>>();
      final transits = (ex['transits'] as List?)?.cast<Map<String, dynamic>>();
      final progressions = (ex['progressions'] as List?)?.cast<Map<String, dynamic>>();
      final transitAspects = (ex['transitAspects'] as List?)?.cast<Map<String, dynamic>>();
      return [
        Center(
          child: NatalChartView(
            planets: planets,
            houseCusps: cusps,
            aspects: aspects,
            transits: transits,
            progressions: progressions,
            transitAspects: transitAspects,
            size: 360,
          ),
        ),
        const SizedBox(height: 10),
        const NatalChartLegend(),
        const SizedBox(height: 4),
        Text(
          '○ 中圈 = 本命   ○ 外圈蓝 = 行运   ○ 内圈紫 = 推运   ⇢ 虚线 = 行运对本命相位',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '上升 ${ex["ascendant"]}  ·  中天 ${ex["mc"]}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    if (id == 'numerology') {
      final it = result.items.first;
      return [
        LifePathReveal(
          lifePath: it.extra['value'] as int,
          archetype: ex['archetype'] as String,
          keywords: it.keywords,
          description: it.subtitle ?? '',
          accent: accent,
        ),
      ];
    }
    if (id == 'runes') {
      return [_RuneRow(result: result)];
    }
    if (id == 'ogham') {
      return [_OghamRow(result: result)];
    }
    if (id == 'yesno') {
      final it = result.items.first;
      return [
        YesNoBigReveal(
          tendency: ex['tendency'] as String,
          method: ex['method'] as String,
          detail: it.subtitle,
        ),
      ];
    }
    if (id == 'biblio') {
      return [
        ScrollReveal(
          reference: ex['reference'] as String,
          book: ex['book'] as String,
        ),
      ];
    }
    if (id == 'oracle') {
      return [
        CrystalBall(
          mode: result.variantName,
          description: (ex['modeDescription'] as String?) ?? '',
        ),
      ];
    }
    if (id == 'dream' && result.variantKey == 'zhou_classic') {
      if (result.items.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text('💤', style: TextStyle(fontSize: 48, color: accent)),
                const SizedBox(height: 8),
                Text(
                  '内置周公解梦词典没匹配到关键词',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '梦境描述里没找到经典符号 (蛇/水/牙/飞 等). 你可以补充更具体的细节, 或者切到 AI 视角让模型自由发挥.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ];
      }
      // 命中, 用默认 _buildItems 显示
      return _buildItems(context, accent);
    }
    // 兜底
    return _buildItems(context, accent);
  }

  List<Widget> _buildIChing(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final ex = result.extras;
    final hasDerived = ex.containsKey('derivedNumber');
    // 六爻是 changingLines list, 梅花是 changingYao int
    List<int> changing = const [];
    if (ex['changingLines'] is List) {
      changing = (ex['changingLines'] as List).cast<int>();
    } else if (ex['changingYao'] is int) {
      changing = [ex['changingYao'] as int];
    }
    return [
      // 视觉化卦象
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: HexagramTransition(
          accent: accent,
          originalBinary: ex['originalBinary'] as String,
          derivedBinary: hasDerived ? ex['derivedBinary'] as String : null,
          changingLines: changing,
          originalLabel: '本卦 · ${ex["originalName"]}',
          derivedLabel: hasDerived ? '变卦 · ${ex["derivedName"]}' : null,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ex["originalUnicode"]}  第${ex["originalNumber"]}卦  ${ex["originalName"]} (${ex["originalPinyin"]})',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(ex['originalJudgment'] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
            if (hasDerived) ...[
              const SizedBox(height: 8),
              Text('变卦 → ${ex["derivedUnicode"]}  第${ex["derivedNumber"]}卦  ${ex["derivedName"]} (${ex["derivedPinyin"]})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w500,
                  )),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('无变爻', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildZiWei(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final ex = result.extras;
    final palaces = (ex['palaces'] as List).cast<Map<String, dynamic>>();
    final center = '${ex["mingPalace"]}\n${ex["bureau"]}\n紫微在${ex["ziWeiZhi"]}\n'
        '${ex["yearGanZhi"]} · ${ex["gender"] ?? ""}';
    return [
      ZiWeiChartWidget(
        palaces: palaces,
        centerInfo: center,
        accent: accent,
      ),
      const SizedBox(height: 8),
      Text(
        '★ 命宫  ·  身 身宫  ·  限 当前大限  ·  年 流年命宫\n'
        '金=主星  ·  蓝=吉星  ·  红=煞星  ·  禄权科忌 = 四化标',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.6,
        ),
      ),
    ];
  }

  List<Widget> _buildItems(BuildContext context, Color accent) {
    // 塔罗专属: 用真实牌面 widget + 翻转动画
    if (engine.id == 'tarot') {
      return [_TarotCardRow(result: result)];
    }
    return [
      for (final it in result.items) _itemRow(context, it, accent),
    ];
  }

  Widget _itemRow(BuildContext context, DivinationItem it, Color accent) {
    final theme = Theme.of(context);
    final ori = it.orientation.isNotEmpty ? '  ·  ${it.orientation}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 4, height: 32,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.position,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text('${it.name}$ori',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                if (it.subtitle != null && it.subtitle!.isNotEmpty)
                  Text(it.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                if (it.keywords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(it.keywords.join(' · '),
                        style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasOnly(BuildContext context) {
    final theme = Theme.of(context);
    final ex = result.extras;
    final lines = <String>[];
    if (ex.containsKey('birthdate') && (ex['birthdate'] as String).isNotEmpty) {
      lines.add('生日: ${ex["birthdate"]}');
    }
    if (ex.containsKey('birthtime') && (ex['birthtime'] as String).isNotEmpty) {
      lines.add('时间: ${ex["birthtime"]}');
    }
    if (ex.containsKey('birthplace') && (ex['birthplace'] as String).isNotEmpty) {
      lines.add('地点: ${ex["birthplace"]}');
    }
    if (ex.containsKey('gender') && (ex['gender'] as String).isNotEmpty) {
      lines.add('性别: ${ex["gender"]}');
    }
    if (ex.containsKey('focus')) {
      lines.add('关注: ${ex["focus"]}');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(lines.join('  ·  '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          )),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.accent,
    this.streaming = false,
  });
  final ChatMessage message;
  final Color accent;
  final bool streaming;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.t('reading.copied')), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';
    if (isSystem) return const SizedBox.shrink();
    final isDark = theme.brightness == Brightness.dark;

    final bg = isUser
        ? accent.withValues(alpha: isDark ? 0.35 : 0.15)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onLongPress: () => _copy(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isUser ? 14 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 14),
                    ),
                    border: isUser
                        ? Border.all(color: accent.withValues(alpha: 0.4), width: 1)
                        : null,
                  ),
                  child: SelectableText(
                    message.content,
                    style: TextStyle(color: fg, height: 1.55, fontSize: 15),
                  ),
                ),
              ),
            ),
            // 助手消息附一个复制按钮 (流式中不显示)
            if (!isUser && !streaming && message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: TextButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.content_copy, size: 14),
                  label: const Text('复制'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 推理模型 (DeepSeek R1 等) 思考过程的折叠面板.
/// 流式过程中默认展开 (initialExpanded=true), 完成后存到 ChatMessage 里, 渲染时默认折起.
class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    required this.text,
    required this.accent,
    this.initialExpanded = true,
    this.live = false, // 是否在流式中 (影响图标动效与文案)
  });
  final String text;
  final Color accent;
  final bool initialExpanded;
  final bool live;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  late bool _expanded = widget.initialExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (widget.live)
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: widget.accent,
                      ),
                    )
                  else
                    Icon(Icons.psychology_outlined,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(widget.live ? '推理中' : '思考过程',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            SelectableText(widget.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  height: 1.55,
                )),
          ],
        ],
      ),
    );
  }
}

/// 流被打断时显示的"继续"按钮.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.accent, required this.onTap});
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 16,
                  color: theme.colorScheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text('上面这段被打断了',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('继续未完成的部分'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// 标签编辑器: 显示现有标签 chip (X 可删), 加一个 "+ 加标签" chip 弹输入框.
class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.accent,
    required this.onChanged,
  });
  final List<String> tags;
  final Color accent;
  final ValueChanged<List<String>> onChanged;

  Future<void> _addTag(BuildContext context) async {
    final ctl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例: 事业 / 感情 / 2026 / 自己',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty && !tags.contains(tag)) {
      onChanged([...tags, tag]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.local_offer_outlined, size: 16,
            color: theme.colorScheme.onSurfaceVariant),
        for (final t in tags)
          Chip(
            label: Text(t, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            backgroundColor: accent.withValues(alpha: 0.15),
            side: BorderSide(color: accent.withValues(alpha: 0.3)),
            onDeleted: () => onChanged(tags.where((x) => x != t).toList()),
            deleteIconColor: theme.colorScheme.onSurfaceVariant,
          ),
        ActionChip(
          label: const Text('+ 标签', style: TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          onPressed: () => _addTag(context),
        ),
      ],
    );
  }
}

class _LenormandRow extends StatelessWidget {
  const _LenormandRow({required this.result});
  final DivinationResult result;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = result.items;
    final isSingle = cards.length <= 1;
    final cardW = isSingle ? 140.0 : 92.0;
    final cardH = isSingle ? 220.0 : 145.0;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  LenormandCardWidget(
                    width: cardW,
                    height: cardH,
                    flipDelayMs: 250 + i * 350,
                    position: cards[i].position,
                    card: LenormandCardData(
                      number: (cards[i].extra['number'] as int?) ?? 0,
                      nameZh: cards[i].name.replaceAll(RegExp(r'^\d+\.\s*'), ''),
                      nameEn: cards[i].subtitle ?? '',
                      keywords: cards[i].keywords,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final c in cards)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(c.position,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
                Expanded(
                  child: Text('${c.name}\n${c.keywords.join(" · ")}',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RuneRow extends StatelessWidget {
  const _RuneRow({required this.result});
  final DivinationResult result;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = result.items;
    return Column(
      children: [
        Wrap(
          spacing: 10, runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              StoneCardWidget(
                glyph: (items[i].extra['glyph'] as String?) ?? items[i].name.split(' ').first,
                name: items[i].name.split('  ').last,
                subtitle: items[i].subtitle,
                position: items[i].position,
                reversed: items[i].orientation == '逆位',
                accentDark: const Color(0xFF5C534A),
                accentLight: const Color(0xFFA89B8C),
                revealDelayMs: 200 + i * 350,
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${c.position}: ${c.keywords.join(" · ")}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
      ],
    );
  }
}

class _OghamRow extends StatelessWidget {
  const _OghamRow({required this.result});
  final DivinationResult result;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = result.items;
    return Column(
      children: [
        Wrap(
          spacing: 10, runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              StoneCardWidget(
                glyph: (items[i].extra['glyph'] as String?) ?? items[i].name.split(' ').first,
                name: items[i].name.split('  ').last,
                subtitle: items[i].subtitle,
                position: items[i].position,
                accentDark: const Color(0xFF3E5538),
                accentLight: const Color(0xFF8FA887),
                wood: true,
                revealDelayMs: 200 + i * 350,
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${c.position}: ${c.keywords.join(" · ")}',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
      ],
    );
  }
}

/// 塔罗牌一行: 牌面 widget + 关键词. 每张卡有翻转入场动画.
class _TarotCardRow extends StatelessWidget {
  const _TarotCardRow({required this.result});
  final DivinationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = result.items;
    final isSingle = cards.length == 1;
    final cardWidth = isSingle ? 140.0 : 96.0;
    final cardHeight = isSingle ? 224.0 : 154.0;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  TarotCardWidget(
                    width: cardWidth,
                    height: cardHeight,
                    flipDelayMs: 250 + i * 380,
                    position: cards[i].position,
                    card: TarotCardData(
                      nameZh: cards[i].name,
                      nameEn: cards[i].subtitle ?? '',
                      suit: (cards[i].extra['suit'] as String?) ?? 'major',
                      number: (cards[i].extra['number'] as String?) ?? '',
                      reversed: (cards[i].extra['reversed'] as bool?) ?? false,
                      keywords: cards[i].keywords,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 关键词区, 每张牌一段
        Column(
          children: [
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        c.position,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${c.name}  ·  ${c.orientation}\n${c.keywords.join(" · ")}',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "解读"按钮: 在结果已出但还没调 LLM 时显示.
/// 用户可以先看结果, 不想花 token 就直接退出 (会自动存历史).
class _InterpretCTA extends StatelessWidget {
  const _InterpretCTA({
    required this.accent,
    required this.configured,
    required this.onTap,
  });
  final Color accent;
  final bool configured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          configured
              ? '想看 AI 解读? 点下面.'
              : '想看 AI 解读, 需要先配 LLM (回首页右上角设置).',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: accent),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('让 AI 解读这次占卜'),
        ),
        const SizedBox(height: 6),
        Text(
          '不想看解读? 直接返回, 结果已自动保存到历史.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
