// 前台服务桥接 (仅 Android).
//
// LLM 流式开始前调 start(), 让 Android 启动前台服务 + 通知, 防止 OEM 在切 app 时
// 杀进程导致流断. 流结束后 (无论成功失败) 调 stop().
//
// 其他平台 (iOS / Windows / web) 调用为空操作, 不影响功能.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/app_settings.dart';

class LlmStreamService {
  static const _channel = MethodChannel('com.divine.divine/llm_stream_service');

  static Future<void> start() async {
    if (!_supported) return;
    // 用户在设置里关了通知, 就不启前台服务 (Android 切走风险自负)
    if (!AppSettings.instance.fgNotification) return;
    try {
      await _channel.invokeMethod<bool>('start');
    } catch (_) {
      // 服务启动失败 (例如老设备 / 权限拒绝) 不影响流式继续, 只是没保活.
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  static bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }
}
