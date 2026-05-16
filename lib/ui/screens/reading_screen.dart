import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/divination.dart';
import '../../llm/client.dart';
import '../../llm/config.dart';
import '../../storage/history.dart';
import '../../storage/profile.dart';
import '../widgets/tarot_card_widget.dart';
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
    final inputs = {
      for (final e in _inputCtls.entries) e.key: e.value.text.trim(),
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
        _messages
            // 只把 user/assistant/system 的 content 喂给 LLM (reasoning 不用回灌)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
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
        Row(
          children: [
            Text('信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickProfile,
              icon: const Icon(Icons.contacts_outlined, size: 16),
              label: const Text('从档案填'),
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
