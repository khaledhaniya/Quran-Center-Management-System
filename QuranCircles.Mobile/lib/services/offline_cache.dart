import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCache {
  static String? _scope;
  @visibleForTesting
  static Directory? legacyDirectoryOverride;

  static void configure({required String server, required int userId}) {
    _scope = '${Uri.encodeComponent(server)}_$userId';
  }

  static void resetScope() => _scope = null;
  static String? _key(String key) =>
      _scope == null ? null : 'albayan_cache_${_scope}_$key';

  static Future<void> save(String key, String value) async {
    final storageKey = _key(key);
    if (storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }

  static Future<String?> load(String key) async {
    final storageKey = _key(key);
    if (storageKey == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _key(key);
    if (storageKey != null) await prefs.remove(storageKey);
    // Delete both copies written by older versions, especially user_login.
    await prefs.remove('albayan_cache_$key');
    if (!kIsWeb) {
      final oldFile = File(
          '${(legacyDirectoryOverride ?? Directory.systemTemp).path}/albayan_cache_$key.json');
      if (await oldFile.exists()) await oldFile.delete();
    }
  }

  static Future<void> clearAll() async {
    final scope = _scope;
    if (scope == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs
        .getKeys()
        .where((k) => k.startsWith('albayan_cache_${scope}_'))
        .toList()) {
      await prefs.remove(key);
    }
  }
}
