// 出生档案 (BirthProfile): 把"出生年月日时 + 地点 + 性别"等结构化信息
// 抽出成可复用对象, 八字 / 占星 / 数字命理这些需要生辰的占卜法可以直接选档案,
// 不用每次手输.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _kProfilesKey = 'birth_profiles_v1';

class BirthProfile {
  final String id;
  final String name;
  final String? gender;     // "男" / "女" / null
  final String? birthDate;  // YYYY-MM-DD
  final String? birthTime;  // HH:MM or null
  final String? birthPlace;
  final String? notes;
  final DateTime createdAt;

  BirthProfile({
    required this.id,
    required this.name,
    this.gender,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birthDate': birthDate,
        if (birthTime != null) 'birthTime': birthTime,
        if (birthPlace != null) 'birthPlace': birthPlace,
        if (notes != null) 'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BirthProfile.fromJson(Map<String, dynamic> j) => BirthProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        gender: j['gender'] as String?,
        birthDate: j['birthDate'] as String?,
        birthTime: j['birthTime'] as String?,
        birthPlace: j['birthPlace'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  BirthProfile copyWith({
    String? name,
    String? gender,
    String? birthDate,
    String? birthTime,
    String? birthPlace,
    String? notes,
  }) =>
      BirthProfile(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthDate: birthDate ?? this.birthDate,
        birthTime: birthTime ?? this.birthTime,
        birthPlace: birthPlace ?? this.birthPlace,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  /// 把档案字段映射到 engine inputs (供 reading_screen 自动填充).
  Map<String, String> toEngineInputs() => {
        if (birthDate != null) 'birthdate': birthDate!,
        if (birthTime != null) 'birthtime': birthTime!,
        if (birthPlace != null) 'birthplace': birthPlace!,
        if (gender != null) 'gender': gender!,
      };

  /// 一行话摘要 (用于列表显示).
  String summary() {
    final parts = <String>[];
    if (birthDate != null) parts.add(birthDate!);
    if (birthTime != null) parts.add(birthTime!);
    if (gender != null) parts.add(gender!);
    if (birthPlace != null) parts.add(birthPlace!);
    return parts.join(' · ');
  }
}

class ProfileStore {
  static Future<List<BirthProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BirthProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(BirthProfile p) async {
    final all = await loadAll();
    final i = all.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      all[i] = p;
    } else {
      all.add(p);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfilesKey,
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfilesKey,
        jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// 生成简单 ID (时间戳, 够用).
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
