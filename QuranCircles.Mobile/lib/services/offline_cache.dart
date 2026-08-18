import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> save(String key, String jsonString) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString('albayan_cache_$key', jsonString);
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/albayan_cache_$key.json');
        await file.writeAsString(jsonString);
      } catch (_) {}
    }
  }

  static Future<String?> load(String key) async {
    try {
      final prefs = await _getPrefs();
      final val = prefs.getString('albayan_cache_$key');
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/albayan_cache_$key.json');
        if (await file.exists()) {
          return await file.readAsString();
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> remove(String key) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove('albayan_cache_$key');
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith('albayan_cache_')).toList();
      for (var k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
