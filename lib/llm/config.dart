// LLM 配置 model.
//
// API key 通过 flutter_secure_storage 存到系统 keychain (iOS) / keystore (Android).
// 其他非敏感字段走 shared_preferences (key/value, 写入 plist/SharedPreferences).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kEndpoint = 'llm_endpoint';
const String _kModel = 'llm_model';
const String _kTemperature = 'llm_temperature';
const String _kMaxTokens = 'llm_max_tokens';
const String _kApiKeySecure = 'llm_api_key';

class LLMConfig {
  String endpoint;
  String model;
  String apiKey;
  double temperature;
  int maxTokens;

  LLMConfig({
    this.endpoint = 'https://api.deepseek.com/v1',
    this.model = 'deepseek-v4-flash',
    this.apiKey = '',
    this.temperature = 0.8,
    this.maxTokens = 2048,
  });

  bool get isReady => apiKey.isNotEmpty && endpoint.isNotEmpty && model.isNotEmpty;

  String get maskedKey {
    if (apiKey.isEmpty) return '(未设置)';
    if (apiKey.length <= 8) return '*' * apiKey.length;
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }

  LLMConfig copy() => LLMConfig(
        endpoint: endpoint,
        model: model,
        apiKey: apiKey,
        temperature: temperature,
        maxTokens: maxTokens,
      );
}

class LLMConfigStore {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<LLMConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cfg = LLMConfig(
      endpoint: prefs.getString(_kEndpoint) ?? 'https://api.deepseek.com/v1',
      model: prefs.getString(_kModel) ?? 'deepseek-v4-flash',
      temperature: prefs.getDouble(_kTemperature) ?? 0.8,
      maxTokens: prefs.getInt(_kMaxTokens) ?? 2048,
    );
    try {
      cfg.apiKey = (await _secure.read(key: _kApiKeySecure)) ?? '';
    } catch (_) {
      // secure storage 在某些 desktop/web 平台不可用, 回退到不持久化的 key
      cfg.apiKey = '';
    }
    return cfg;
  }

  static Future<void> save(LLMConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEndpoint, cfg.endpoint);
    await prefs.setString(_kModel, cfg.model);
    await prefs.setDouble(_kTemperature, cfg.temperature);
    await prefs.setInt(_kMaxTokens, cfg.maxTokens);
    try {
      if (cfg.apiKey.isEmpty) {
        await _secure.delete(key: _kApiKeySecure);
      } else {
        await _secure.write(key: _kApiKeySecure, value: cfg.apiKey);
      }
    } catch (_) {
      // 写入 secure storage 失败 (例如 web 平台), 当前进程内的 key 仍有效.
    }
  }
}

class LLMPreset {
  final String label;
  final String endpoint;
  final String model;
  const LLMPreset(this.label, this.endpoint, this.model);
}

const List<LLMPreset> _commonPresets = [
  LLMPreset('DeepSeek V4 Flash',   'https://api.deepseek.com/v1',          'deepseek-v4-flash'),
  LLMPreset('DeepSeek V4 Pro',     'https://api.deepseek.com/v1',          'deepseek-v4-pro'),
  LLMPreset('OpenAI gpt-4o-mini',  'https://api.openai.com/v1',            'gpt-4o-mini'),
  LLMPreset('OpenAI gpt-4o',       'https://api.openai.com/v1',            'gpt-4o'),
  LLMPreset('Kimi 8k',             'https://api.moonshot.cn/v1',           'moonshot-v1-8k'),
  LLMPreset('智谱 GLM-4-Flash',     'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash'),
  LLMPreset('Ollama 本地',         'http://localhost:11434/v1',            'qwen2.5:7b'),
];

List<LLMPreset> allPresets() => _commonPresets;
