// 自定义系统提示词存储.
//
// 每个引擎可以有任意多个自定义 prompt (CustomPrompt), 用户选一个作为"激活".
// 激活的 prompt 在 ReadingScreen interpret 时替代 engine.systemPrompt.
//
// 内置 prompt (来自 engine.systemPrompt) 不存储, 始终作为"默认"项显示;
// 激活 = null 表示用内置.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPromptsKey = 'custom_prompts_v1';     // List<CustomPrompt> json
const _kActiveKeyPrefix = 'custom_prompt_active_'; // + engineId → promptId

class CustomPrompt {
  final String id;
  final String engineId;
  String name;
  String body;
  final DateTime createdAt;

  CustomPrompt({
    required this.id,
    required this.engineId,
    required this.name,
    required this.body,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'engineId': engineId,
        'name': name,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomPrompt.fromJson(Map<String, dynamic> j) => CustomPrompt(
        id: j['id'] as String,
        engineId: j['engineId'] as String,
        name: j['name'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class PromptStore extends ChangeNotifier {
  static final PromptStore instance = PromptStore._();
  PromptStore._();

  final List<CustomPrompt> _all = [];
  final Map<String, String?> _activeByEngine = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPromptsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _all
          ..clear()
          ..addAll(list.map((e) => CustomPrompt.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    // 加载所有 active.
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_kActiveKeyPrefix)) {
        final engineId = k.substring(_kActiveKeyPrefix.length);
        final promptId = prefs.getString(k);
        if (promptId != null && promptId.isNotEmpty) {
          _activeByEngine[engineId] = promptId;
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<CustomPrompt> forEngine(String engineId) =>
      _all.where((p) => p.engineId == engineId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  CustomPrompt? activeFor(String engineId) {
    final id = _activeByEngine[engineId];
    if (id == null) return null;
    return _all.where((p) => p.id == id).firstOrNull;
  }

  /// 优先级: active custom > builtin (engine.systemPrompt).
  /// 返回应当用作 system message 的字符串.
  String resolveSystemPrompt(String engineId, String builtin) {
    final p = activeFor(engineId);
    return p?.body ?? builtin;
  }

  Future<void> save(CustomPrompt p) async {
    final idx = _all.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      _all[idx] = p;
    } else {
      _all.add(p);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _all.removeWhere((p) => p.id == id);
    // 若此 prompt 是某引擎的 active, 顺带清掉
    final orphans = <String>[];
    _activeByEngine.forEach((engineId, promptId) {
      if (promptId == id) orphans.add(engineId);
    });
    for (final engineId in orphans) {
      _activeByEngine.remove(engineId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kActiveKeyPrefix$engineId');
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActive(String engineId, String? promptId) async {
    if (promptId == null) {
      _activeByEngine.remove(engineId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kActiveKeyPrefix$engineId');
    } else {
      _activeByEngine[engineId] = promptId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_kActiveKeyPrefix$engineId', promptId);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPromptsKey,
        jsonEncode(_all.map((e) => e.toJson()).toList()));
  }

  /// 生成稳定 id.
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
