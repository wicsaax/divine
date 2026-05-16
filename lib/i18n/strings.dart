// 极简的 i18n: 一个 Map + ValueNotifier 监听语言切换.
//
// 用法:
//   Text(S.t('settings'))                // 当前语言
//   ValueListenableBuilder(valueListenable: S.locale, builder: (...))
//   S.setLocale('en')                    // 切换, 所有听 locale 的 widget 会刷新
//
// 内容部分 (78 张塔罗牌名/64 卦/14 主星等) 不在这里处理, 留在各 engine 的 data 里.

import 'package:flutter/foundation.dart';

class S {
  static final ValueNotifier<String> locale = ValueNotifier<String>('zh');

  static void setLocale(String l) {
    if (l == locale.value) return;
    if (!_strings.containsKey(l)) return;
    locale.value = l;
  }

  /// 翻译查表; 找不到 key 时回退到中文, 再找不到返回 key 本身.
  static String t(String key) {
    final m = _strings[locale.value] ?? _strings['zh']!;
    return m[key] ?? _strings['zh']![key] ?? key;
  }

  /// 当前 locale 是否英文.
  static bool get isEn => locale.value == 'en';
}

const Map<String, Map<String, String>> _strings = {
  'zh': _zh,
  'en': _en,
};

const Map<String, String> _zh = {
  // App + 顶级菜单
  'app.title': 'divine',
  'app.tagline': '今天想问点什么',
  'app.subtagline': '选一种方式, 抽完牌可以接着追问',
  'home.method_section': '占卜方式',
  'home.method_count': '共 {n} 种',

  // 顶部按钮 tooltip
  'tip.profiles': '档案',
  'tip.history': '历史',
  'tip.settings': '设置',

  // 通用按钮
  'btn.cancel': '取消',
  'btn.confirm': '确认',
  'btn.save': '保存',
  'btn.delete': '删除',
  'btn.export': '导出',
  'btn.clear': '清空',
  'btn.start': '开始',
  'btn.interpret': '让 AI 解读这次占卜',
  'btn.copy': '复制',
  'btn.continue': '继续未完成的部分',
  'btn.retry': '重试',
  'btn.new': '新建',
  'btn.edit': '编辑',
  'btn.use_this': '用这个',
  'btn.test_conn': '测试连接',
  'btn.testing': '测试中…',
  'btn.go_settings': '去设置',

  // 设置页
  'settings.title': 'LLM 设置',
  'settings.guide_title': '不会申请 key？看教程',
  'settings.guide_sub': '每家 provider 的注册 / 充值 / 创建 key 步骤',
  'settings.preset': '一键预设',
  'settings.endpoint': 'Endpoint',
  'settings.model': 'Model',
  'settings.api_key': 'API key',
  'settings.api_key_hint': 'API key 加密保存在系统钥匙串 (iOS Keychain / Android Keystore).',
  'settings.advanced': '高级',
  'settings.temperature': 'Temperature',
  'settings.max_tokens': 'Max tokens',
  'settings.paste': '粘贴',
  'settings.section_app': 'App 偏好',
  'settings.language': '语言',
  'settings.theme': '主题',
  'settings.theme_system': '跟随系统',
  'settings.theme_light': '浅色',
  'settings.theme_dark': '深色',
  'settings.font_size': '字号',
  'settings.font_small': '小',
  'settings.font_medium': '中',
  'settings.font_large': '大',
  'settings.notif_fg': '解读时显示通知栏',
  'settings.notif_fg_sub': '关掉后, Android 上切走再回来流容易被打断',
  'settings.streaming': '流式输出',
  'settings.streaming_sub': '关掉后等 LLM 全部生成完才一次性显示',
  'settings.save_history': '自动保存历史',
  'settings.save_history_sub': '关掉后所有占卜不留痕',
  'settings.section_data': '数据',
  'settings.export_config': '导出配置 + 历史 (JSON)',
  'settings.import_config': '从 JSON 导入',
  'settings.clear_data': '清空所有数据',
  'settings.clear_data_sub': '历史 / 档案 / 配置一并删除, 不可恢复',
  'settings.section_about': '关于',
  'settings.about_version': '版本',
  'settings.about_github': '源代码 (GitHub)',
  'settings.about_license': '开源协议',

  // 主屏
  'home.unconfigured_title': '先去配 LLM, 否则没法解读',
  'home.unconfigured_sub': '推荐 DeepSeek, 几块钱能玩很久',

  // 解读页
  'reading.you_question': '你的问题 (可选)',
  'reading.question_hint': '例如: 我接下来三个月的工作发展方向?',
  'reading.method': '方式',
  'reading.info': '信息',
  'reading.from_profile': '从档案填',
  'reading.thinking': '正在汲取讯息…',
  'reading.reasoning': '推理中',
  'reading.thought': '思考过程',
  'reading.follow_hint': '基于结果继续追问…',
  'reading.cta_configured': '想看 AI 解读? 点下面.',
  'reading.cta_unconfigured': '想看 AI 解读, 需要先配 LLM (回首页右上角设置).',
  'reading.cta_back': '不想看解读? 直接返回, 结果已自动保存到历史.',
  'reading.saved': '已保存到历史',
  'reading.copied': '已复制',
  'reading.interrupted': '上面这段被打断了',
  'reading.continue_msg': '(刚才网络中断了, 请接着上面没说完的部分继续, 不要重复已经写过的内容.)',

  // 历史
  'history.title': '历史',
  'history.empty_title': '还没有历史记录',
  'history.empty_sub': '完成一次占卜后会自动保存到这里, 方便日后回看.',
  'history.search_hint': '搜索问题 / 关键词 / 解读内容',
  'history.all': '全部',
  'history.results': '{n} 条结果',
  'history.no_match': '没有匹配的历史',
  'history.no_question': '(无具体问题)',
  'history.confirm_clear': '清空全部历史?',
  'history.confirm_clear_sub': '此操作不可恢复.',
  'history.confirm_delete': '删除这条记录?',
  'history.tag_section': '标签',

  // 档案
  'profile.title': '出生档案',
  'profile.pick_title': '选择档案',
  'profile.empty_title': '还没有档案',
  'profile.empty_sub': '为自己 / 家人 / 朋友建一个出生档案,\n做八字、占星、数字命理时一键复用.',
  'profile.new_first': '新建第一个档案',
  'profile.new': '新建档案',
  'profile.edit': '编辑档案',
  'profile.name': '称呼 *',
  'profile.name_hint': '例: 自己 / 妈妈 / 李四',
  'profile.date': '公历出生日期',
  'profile.time': '出生时间',
  'profile.time_hint': 'HH:MM (不知道可留空)',
  'profile.place': '出生地',
  'profile.place_hint': '例: 浙江杭州',
  'profile.gender': '性别',
  'profile.gender_male': '男',
  'profile.gender_female': '女',
  'profile.notes': '备注',
  'profile.no_birth': '(无生辰信息)',
  'profile.filled': '已填入「{name}」的档案',
  'profile.confirm_delete': '删除「{name}」?',
  'profile.confirm_delete_sub': '档案被引用过的占卜记录不受影响.',
};

const Map<String, String> _en = {
  // App + top
  'app.title': 'divine',
  'app.tagline': 'What do you want to ask?',
  'app.subtagline': 'Pick a method. You can keep asking after drawing.',
  'home.method_section': 'Methods',
  'home.method_count': '{n} total',

  'tip.profiles': 'Profiles',
  'tip.history': 'History',
  'tip.settings': 'Settings',

  'btn.cancel': 'Cancel',
  'btn.confirm': 'Confirm',
  'btn.save': 'Save',
  'btn.delete': 'Delete',
  'btn.export': 'Export',
  'btn.clear': 'Clear',
  'btn.start': 'Start',
  'btn.interpret': 'Have AI interpret this reading',
  'btn.copy': 'Copy',
  'btn.continue': 'Continue from where it stopped',
  'btn.retry': 'Retry',
  'btn.new': 'New',
  'btn.edit': 'Edit',
  'btn.use_this': 'Use this',
  'btn.test_conn': 'Test connection',
  'btn.testing': 'Testing…',
  'btn.go_settings': 'Open settings',

  'settings.title': 'LLM Settings',
  'settings.guide_title': 'Don\'t know how to get an API key?',
  'settings.guide_sub': 'Step-by-step for each provider',
  'settings.preset': 'Presets',
  'settings.endpoint': 'Endpoint',
  'settings.model': 'Model',
  'settings.api_key': 'API key',
  'settings.api_key_hint': 'API key is stored encrypted in system keychain (iOS Keychain / Android Keystore).',
  'settings.advanced': 'Advanced',
  'settings.temperature': 'Temperature',
  'settings.max_tokens': 'Max tokens',
  'settings.paste': 'Paste',
  'settings.section_app': 'App preferences',
  'settings.language': 'Language',
  'settings.theme': 'Theme',
  'settings.theme_system': 'System',
  'settings.theme_light': 'Light',
  'settings.theme_dark': 'Dark',
  'settings.font_size': 'Font size',
  'settings.font_small': 'Small',
  'settings.font_medium': 'Medium',
  'settings.font_large': 'Large',
  'settings.notif_fg': 'Notification during interpretation',
  'settings.notif_fg_sub': 'When off, switching apps on Android may interrupt the stream',
  'settings.streaming': 'Streaming output',
  'settings.streaming_sub': 'When off, wait for full response before showing',
  'settings.save_history': 'Auto-save history',
  'settings.save_history_sub': 'When off, readings leave no trace',
  'settings.section_data': 'Data',
  'settings.export_config': 'Export config + history (JSON)',
  'settings.import_config': 'Import from JSON',
  'settings.clear_data': 'Clear all data',
  'settings.clear_data_sub': 'Deletes history / profiles / config. Cannot be undone.',
  'settings.section_about': 'About',
  'settings.about_version': 'Version',
  'settings.about_github': 'Source (GitHub)',
  'settings.about_license': 'License',

  'home.unconfigured_title': 'Configure LLM first to enable interpretation',
  'home.unconfigured_sub': 'DeepSeek is recommended; cheap enough to play with',

  'reading.you_question': 'Your question (optional)',
  'reading.question_hint': 'e.g. Career direction for the next 3 months?',
  'reading.method': 'Method',
  'reading.info': 'Info',
  'reading.from_profile': 'Use a profile',
  'reading.thinking': 'Reaching out…',
  'reading.reasoning': 'Thinking',
  'reading.thought': 'Thought process',
  'reading.follow_hint': 'Follow up on the result…',
  'reading.cta_configured': 'Want AI interpretation? Tap below.',
  'reading.cta_unconfigured': 'AI interpretation requires LLM config (gear icon on Home).',
  'reading.cta_back': 'Don\'t want interpretation? Just go back; the result is saved.',
  'reading.saved': 'Saved to history',
  'reading.copied': 'Copied',
  'reading.interrupted': 'The above response was interrupted',
  'reading.continue_msg': '(The network was interrupted. Please continue from where you left off, without repeating what was already written.)',

  'history.title': 'History',
  'history.empty_title': 'No history yet',
  'history.empty_sub': 'Readings will auto-save here for later review.',
  'history.search_hint': 'Search questions / keywords / responses',
  'history.all': 'All',
  'history.results': '{n} results',
  'history.no_match': 'No matching history',
  'history.no_question': '(no specific question)',
  'history.confirm_clear': 'Clear all history?',
  'history.confirm_clear_sub': 'This cannot be undone.',
  'history.confirm_delete': 'Delete this record?',
  'history.tag_section': 'Tags',

  'profile.title': 'Birth Profiles',
  'profile.pick_title': 'Pick profile',
  'profile.empty_title': 'No profiles yet',
  'profile.empty_sub': 'Create a birth profile for yourself / family / friends.\nReuse it for BaZi, astrology, numerology.',
  'profile.new_first': 'Create first profile',
  'profile.new': 'New profile',
  'profile.edit': 'Edit profile',
  'profile.name': 'Name *',
  'profile.name_hint': 'e.g. Self / Mom / Jane',
  'profile.date': 'Birth date (Gregorian)',
  'profile.time': 'Birth time',
  'profile.time_hint': 'HH:MM (leave empty if unknown)',
  'profile.place': 'Birth place',
  'profile.place_hint': 'e.g. Hangzhou / Tokyo',
  'profile.gender': 'Gender',
  'profile.gender_male': 'M',
  'profile.gender_female': 'F',
  'profile.notes': 'Notes',
  'profile.no_birth': '(no birth info)',
  'profile.filled': 'Filled in from "{name}"',
  'profile.confirm_delete': 'Delete "{name}"?',
  'profile.confirm_delete_sub': 'Past readings that referenced this profile are not affected.',
};
