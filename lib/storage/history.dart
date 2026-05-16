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
  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(role: j['role'] as String, content: j['content'] as String);
}

class ReadingRecord {
  final DateTime ts;
  final String engineId;
  final String engineName;
  final String question;
  final DivinationResult result;
  final List<ChatMessage> messages;

  ReadingRecord({
    DateTime? ts,
    required this.engineId,
    required this.engineName,
    required this.question,
    required this.result,
    required this.messages,
  }) : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'engineId': engineId,
        'engineName': engineName,
        'question': question,
        'result': result.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ReadingRecord.fromJson(Map<String, dynamic> j) => ReadingRecord(
        ts: DateTime.parse(j['ts'] as String),
        engineId: j['engineId'] as String,
        engineName: j['engineName'] as String,
        question: j['question'] as String,
        result: DivinationResult.fromJson(j['result'] as Map<String, dynamic>),
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
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

  static Future<void> append(ReadingRecord r) async {
    final all = await loadAll();
    all.add(r);
    if (all.length > _kHistoryLimit) {
      all.removeRange(0, all.length - _kHistoryLimit);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey,
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }
}
