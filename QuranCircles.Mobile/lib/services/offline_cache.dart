import 'dart:io';
import 'package:flutter/foundation.dart';

class OfflineCache {
  static Future<void> save(String key, String jsonString) async {
    if (kIsWeb) return;
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/albayan_cache_$key.json');
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  static Future<String?> load(String key) async {
    if (kIsWeb) return null;
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/albayan_cache_$key.json');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }
}
