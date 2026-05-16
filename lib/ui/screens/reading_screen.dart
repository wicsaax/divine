import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/divination.dart';
import '../../llm/client.dart';
import '../../llm/config.dart';
import '../../storage/history.dart';

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
    HistoryStore.append(ReadingRecord(
      engineId: widget.engine.id,
      engineName: widget.engine.nameZh,
      question: _questionCtl.text.trim(),
      result: _result!,
      messages: _messages,
    ));
    _saved = true;
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
    final inputs = {
      for (final e in _inputCtls.entries) e.key: e.value.text.trim(),
    };

    DivinationResult result;
    try {
      result = widget.engine.perform(variantKey: _variantKey, inputs: inputs);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    setState(() {
      _result = result;
      _messages.clear();
      _error = null;
      _saved = false;
    });

    // 没有结构化输出的引擎 (通用 AI / 八字 / 占星), 抽完直接走 LLM, 否则等用户点解读.
    if (!widget.engine.hasStandaloneResult) {
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
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(role: 'system', content: widget.engine.systemPrompt))
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
        _messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      );
      await for (final chunk in stream) {
        if (chunk.type == LLMChunkType.reasoning) {
          reasoningBuf.write(chunk.text);
          setState(() => _streamingReasoning = reasoningBuf.toString());
        } else {
          contentBuf.write(chunk.text);
          setState(() => _streamingText = contentBuf.toString());
        }
        _scrollToBottom();
      }
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: contentBuf.toString()));
        _streaming = false;
        _streamingText = '';
        _streamingReasoning = '';
        _saved = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _streaming = false;
        _error = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
              tooltip: '保存',
              onPressed: _saved
                  ? null
                  : () {
                      _autoSaveIfNeeded();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已保存到历史')),
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
            child: ListView(
              controller: _scrollCtl,
              padding: const EdgeInsets.all(16),
              children: _buildContent(theme),
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
      widgets.add(const SizedBox(height: 16));

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
        widgets.add(_ChatBubble(message: m, accent: _accent));
      }
      // 推理过程 (R1 等模型): 流式但用浅色字, 可视化思考链.
      if (_streaming && _streamingReasoning.isNotEmpty && _streamingText.isEmpty) {
        widgets.add(_ReasoningPanel(
          text: _streamingReasoning,
          accent: _accent,
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
                Text('正在汲取讯息…',
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
        Text('方式', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _variantKey,
          onChanged: (val) {
            if (val != null) setState(() => _variantKey = val);
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
      if (inputs.isNotEmpty) ...[
        Text('信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
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
      Text('你的问题 (可选)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: _questionCtl,
        maxLines: 4,
        minLines: 2,
        decoration: const InputDecoration(
          hintText: '例如: 我接下来三个月的工作发展方向?',
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _streaming ? null : _startReading,
          style: FilledButton.styleFrom(backgroundColor: _accent),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('开始'),
        ),
      ),
      const SizedBox(height: 16),
    ];
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
                decoration: const InputDecoration(
                  hintText: '基于结果继续追问…',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            if (engine.id == 'iching') ..._buildIChing(context, accent),
            if (result.items.isNotEmpty)
              ..._buildItems(context, accent),
            if (engine.id == 'bazi' || engine.id == 'astrology' || engine.id == 'oracle')
              _buildExtrasOnly(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIChing(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final ex = result.extras;
    final hasDerived = ex.containsKey('derivedNumber');
    return [
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
      const SizedBox(height: 10),
      ...result.items.reversed.map((it) => _itemRow(context, it, accent)),
    ];
  }

  List<Widget> _buildItems(BuildContext context, Color accent) {
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
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
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
/// 默认展开, 内容用浅色字呈现, 视觉上区分于正文.
class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  bool _expanded = true;

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
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: widget.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('推理中',
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
            Text(widget.text,
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
