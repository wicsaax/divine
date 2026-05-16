// OpenAI 兼容协议的流式聊天客户端 (HTTP + Server-Sent Events).
//
// 同时支持普通模型 (deepseek-v4-flash / gpt-4o / ...) 和推理模型
// (deepseek-v4-pro / o1 系列). 推理模型会先输出 reasoning_content (思考链),
// 再输出 content (正文), 我们把两者作为不同 chunk type 传给上层 UI 区分展示.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'stream_service.dart';

enum LLMChunkType { content, reasoning }

class LLMChunk {
  final LLMChunkType type;
  final String text;
  const LLMChunk(this.type, this.text);
}

class LLMException implements Exception {
  final String message;
  LLMException(this.message);
  @override
  String toString() => 'LLMException: $message';
}

class LLMClient {
  /// 发一个最小请求验证 endpoint/key/model 三件套配的对.
  /// 推理模型 (deepseek-v4-pro / o1 等) 会先输出 reasoning_content 再 content,
  /// 所以 max_tokens 给足够大, 并把 reasoning_content 也视为"连通"的证据.
  static Future<String> testConnection(LLMConfig cfg) async {
    if (!cfg.isReady) {
      throw LLMException('endpoint/key/model 至少有一项未填.');
    }
    final url = Uri.parse('${cfg.endpoint.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
    final body = jsonEncode({
      'model': cfg.model,
      'messages': [
        {'role': 'user', 'content': '回 4 个字: 连接正常.'}
      ],
      'temperature': 0.0,
      'max_tokens': 1024, // 推理模型要留出思考空间, 1024 够推理完 + 给出答案
      'stream': false,
    });
    final client = http.Client();
    try {
      final resp = await client
          .post(url,
              headers: {
                'Authorization': 'Bearer ${cfg.apiKey}',
                'Content-Type': 'application/json',
              },
              body: body)
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        throw LLMException('HTTP ${resp.statusCode}: ${utf8.decode(resp.bodyBytes)}');
      }
      final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw LLMException('响应里没有 choices');
      }
      final first = choices.first as Map;
      final msg = first['message'] as Map?;
      final content = msg?['content'];
      final reasoning = msg?['reasoning_content'];
      final finishReason = first['finish_reason'];
      if (content is String && content.trim().isNotEmpty) {
        return '连接成功: ${content.trim()}';
      }
      // content 为空, 但推理模型若有 reasoning_content 也算连通
      if (reasoning is String && reasoning.trim().isNotEmpty) {
        return '连接成功 (推理模型还在思考中, 但通路正常). finish=$finishReason';
      }
      throw LLMException(
        '响应中没有 content (finish_reason=$finishReason). '
        '若是推理模型可能 max_tokens 不够, 已设 1024 应该够.',
      );
    } finally {
      client.close();
    }
  }

  /// 流式调用. 每个 chunk 标注类型, 推理模型的 chain-of-thought 与正文分开传出.
  static Stream<LLMChunk> streamChat(
    LLMConfig cfg,
    List<Map<String, String>> messages,
  ) async* {
    if (!cfg.isReady) {
      throw LLMException('LLM 还未配置, 请先到「设置」完成配置.');
    }

    final url = Uri.parse('${cfg.endpoint.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
    final body = jsonEncode({
      'model': cfg.model,
      'messages': messages,
      'temperature': cfg.temperature,
      'max_tokens': cfg.maxTokens,
      'stream': true,
    });

    final req = http.Request('POST', url);
    req.headers['Authorization'] = 'Bearer ${cfg.apiKey}';
    req.headers['Content-Type'] = 'application/json';
    req.headers['Accept'] = 'text/event-stream';
    req.body = body;

    final client = http.Client();
    await LlmStreamService.start();
    try {
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        final errBody = await resp.stream.bytesToString();
        throw LLMException('HTTP ${resp.statusCode}: $errBody');
      }

      final lines = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload == '[DONE]') return;
        Map<String, dynamic>? json;
        try {
          json = jsonDecode(payload) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'] as Map?;
        if (delta == null) continue;
        final reasoning = delta['reasoning_content'];
        if (reasoning is String && reasoning.isNotEmpty) {
          yield LLMChunk(LLMChunkType.reasoning, reasoning);
        }
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          yield LLMChunk(LLMChunkType.content, content);
        }
      }
    } finally {
      client.close();
      await LlmStreamService.stop();
    }
  }
}
