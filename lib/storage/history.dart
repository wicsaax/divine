// 占卜历史存储.
// 写到 shared_preferences 的单个 key (JSON 数组), 上限 100 条, 超出滚动删除.
// 数据量大了再换 sqflite/drift.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/divination.dart';

const String _kHistoryKey = 'divine_history_v1';
const int _kHistoryLimit = 100;

class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  /// 推理模型 (R1 等) 的思考链, 与 content 分开存. 仅 assistant 消息使用.
  final String reasoning;
  /// 这条消息是否被打断 (流式中途断网/后台被杀等).
  /// true 时 UI 渲染"继续"按钮.
  final bool interrupted;

  const ChatMessage({
    required this.role,
    required this.content,
    this.reasoning = '',
    this.interrupted = false,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (reasoning.isNotEmpty) 'reasoning': reasoning,
        if (interrupted) 'interrupted': true,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role'] as String,
        content: j['content'] as String,
        reasoning: (j['reasoning'] as String?) ?? '',
        interrupted: (j['interrupted'] as bool?) ?? false,
      );
}

class ReadingRecord {
  final String id;
  final DateTime ts;
  final String engineId;
  final String engineName;
  final String question;
  final DivinationResult result;
  final List<ChatMessage> messages;
  final List<String> tags;

  ReadingRecord({
    String? id,
    DateTime? ts,
    required this.engineId,
    required this.engineName,
    required this.question,
    required this.result,
    required this.messages,
    this.tags = const [],
  })  : ts = ts ?? DateTime.now(),
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  ReadingRecord copyWith({List<String>? tags, List<ChatMessage>? messages}) =>
      ReadingRecord(
        id: id,
        ts: ts,
        engineId: engineId,
        engineName: engineName,
        question: question,
        result: result,
        messages: messages ?? this.messages,
        tags: tags ?? this.tags,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts.toIso8601String(),
        'engineId': engineId,
        'engineName': engineName,
        'question': question,
        'result': result.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (tags.isNotEmpty) 'tags': tags,
      };

  factory ReadingRecord.fromJson(Map<String, dynamic> j) => ReadingRecord(
        id: (j['id'] as String?) ?? (j['ts'] as String), // 老数据用 ts 当 id
        ts: DateTime.parse(j['ts'] as String),
        engineId: j['engineId'] as String,
        engineName: j['engineName'] as String,
        question: j['question'] as String,
        result: DivinationResult.fromJson(j['result'] as Map<String, dynamic>),
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      );
}

class HistoryStore {
  static Future<List<ReadingRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ReadingRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 写入: 如果已有同 id 的记录则替换, 否则追加.
  static Future<void> append(ReadingRecord r) async {
    final all = await loadAll();
    final i = all.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      all[i] = r;
    } else {
      all.add(r);
    }
    if (all.length > _kHistoryLimit) {
      all.removeRange(0, all.length - _kHistoryLimit);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey,
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> deleteById(String id) async {
    final all = await loadAll();
    all.removeWhere((r) => r.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey,
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }
}
