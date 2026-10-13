import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Authentication credentials use platform secure storage, never a temp file.
class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static String _key(String server) =>
      'albayan_auth_${Uri.encodeComponent(server)}';
  static Future<String?> load(String server) =>
      _storage.read(key: _key(server));
  static Future<void> save(String server, String value) =>
      _storage.write(key: _key(server), value: value);
  static Future<void> remove(String server) =>
      _storage.delete(key: _key(server));
}
