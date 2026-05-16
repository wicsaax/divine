// App 层面的偏好 (语言/主题/字号/通知/历史/...).
// 与 LLMConfig 分开, LLMConfig 只管模型连接.
//
// 全局通过 AppSettings.instance 拿, 改完调 save() 持久化 + notify().

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocale = 'app_locale';
const _kThemeMode = 'app_theme_mode';
const _kFontScale = 'app_font_scale';
const _kFgNotification = 'app_fg_notification';
const _kStreaming = 'app_streaming';
const _kSaveHistory = 'app_save_history';
const _kDefaultEngine = 'app_default_engine';

enum AppThemeMode { system, light, dark }

extension on AppThemeMode {
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  String _locale = 'zh';                   // 'zh' | 'en'
  AppThemeMode _themeMode = AppThemeMode.system;
  double _fontScale = 1.0;                 // 0.9 / 1.0 / 1.15
  bool _fgNotification = true;             // 解读时挂前台服务通知 (Android)
  bool _streaming = true;                  // 流式输出
  bool _saveHistory = true;                // 自动存历史
  String? _defaultEngine;                  // 启动时默认引擎 id

  String get locale => _locale;
  AppThemeMode get themeMode => _themeMode;
  ThemeMode get materialThemeMode => _themeMode.materialMode;
  double get fontScale => _fontScale;
  bool get fgNotification => _fgNotification;
  bool get streaming => _streaming;
  bool get saveHistory => _saveHistory;
  String? get defaultEngine => _defaultEngine;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_kLocale) ?? 'zh';
    _themeMode = AppThemeMode.values[
        (prefs.getInt(_kThemeMode) ?? AppThemeMode.system.index)
            .clamp(0, AppThemeMode.values.length - 1)];
    _fontScale = prefs.getDouble(_kFontScale) ?? 1.0;
    _fgNotification = prefs.getBool(_kFgNotification) ?? true;
    _streaming = prefs.getBool(_kStreaming) ?? true;
    _saveHistory = prefs.getBool(_kSaveHistory) ?? true;
    _defaultEngine = prefs.getString(_kDefaultEngine);
    notifyListeners();
  }

  Future<void> setLocale(String v) async {
    if (v == _locale) return;
    _locale = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, v);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode v) async {
    if (v == _themeMode) return;
    _themeMode = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, v.index);
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    if (v == _fontScale) return;
    _fontScale = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScale, v);
    notifyListeners();
  }

  Future<void> setFgNotification(bool v) async {
    if (v == _fgNotification) return;
    _fgNotification = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFgNotification, v);
    notifyListeners();
  }

  Future<void> setStreaming(bool v) async {
    if (v == _streaming) return;
    _streaming = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreaming, v);
    notifyListeners();
  }

  Future<void> setSaveHistory(bool v) async {
    if (v == _saveHistory) return;
    _saveHistory = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSaveHistory, v);
    notifyListeners();
  }

  Future<void> setDefaultEngine(String? v) async {
    if (v == _defaultEngine) return;
    _defaultEngine = v;
    final prefs = await SharedPreferences.getInstance();
    if (v == null) {
      await prefs.remove(_kDefaultEngine);
    } else {
      await prefs.setString(_kDefaultEngine, v);
    }
    notifyListeners();
  }

  /// 清空全部 App 偏好 + 占卜历史 + 档案 + LLM 配置.
  /// 谨慎调用, UI 上必须二次确认.
  Future<void> wipeAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _locale = 'zh';
    _themeMode = AppThemeMode.system;
    _fontScale = 1.0;
    _fgNotification = true;
    _streaming = true;
    _saveHistory = true;
    _defaultEngine = null;
    notifyListeners();
  }
}
