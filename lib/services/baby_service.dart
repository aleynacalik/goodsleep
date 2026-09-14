import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/baby.dart';

class BabyService {
  static const _kBabies = 'babies_v1';
  static const _kActiveBabyId = 'active_baby_id';

  static Future<List<Baby>> getBabies() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBabies);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Baby.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _save(List<Baby> babies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kBabies, jsonEncode(babies.map((b) => b.toJson()).toList()));
  }

  static Future<Baby?> getActiveBaby() async {
    final babies = await getBabies();
    if (babies.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_kActiveBabyId);
    if (activeId == null) return babies.first;
    try {
      return babies.firstWhere((b) => b.id == activeId);
    } catch (_) {
      return babies.first;
    }
  }

  static Future<void> setActiveBaby(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveBabyId, id);
  }

  static Future<void> addBaby(Baby baby) async {
    final babies = await getBabies();
    babies.add(baby);
    await _save(babies);
    if (babies.length == 1) await setActiveBaby(baby.id);
  }

  static Future<void> updateBaby(Baby baby) async {
    final babies = await getBabies();
    final idx = babies.indexWhere((b) => b.id == baby.id);
    if (idx >= 0) babies[idx] = baby;
    await _save(babies);
  }

  static Future<void> deleteBaby(String id) async {
    final babies = await getBabies();
    babies.removeWhere((b) => b.id == id);
    await _save(babies);
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_kActiveBabyId);
    if (activeId == id && babies.isNotEmpty) {
      await setActiveBaby(babies.first.id);
    }
  }

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
