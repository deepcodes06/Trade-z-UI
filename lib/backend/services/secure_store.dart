import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _spPrefix = 'ss_';
  static const _plainPrefix = 'sp_';

  // 32-byte key (in production: store in Keystore/Keychain via remote config)
  static final _key = enc.Key.fromUtf8(
    'TradeZSecretKeyTradeZSecretKey32'.substring(0, 32),
  );
  static final _iv = enc.IV.fromLength(16);

  static Future<SharedPreferences> _sp() => SharedPreferences.getInstance();

  static String _encrypt(String value) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    return encrypter.encrypt(value, iv: _iv).base64;
  }

  static String? _decrypt(String raw) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_key));
      return encrypter.decrypt64(raw, iv: _iv);
    } catch (_) {
      return null;
    }
  }

  /// Persist [value] redundantly:
  ///  1. plain SharedPreferences (most reliable, instant on Android)
  ///  2. encrypted SharedPreferences
  ///  3. secure storage (Keychain/Keystore)
  /// This guarantees the value survives an app restart even if any one of the
  /// storage backends misbehaves on a given device.
  static Future<void> writeEncrypted(String key, String value) async {
    final encrypted = _encrypt(value);
    final prefs = await _sp();
    await prefs.setString('$_plainPrefix$key', value); // plaintext fallback
    await prefs.setString('$_spPrefix$key', encrypted); // encrypted SP
    try {
      await _storage.write(key: key, value: encrypted); // hardened copy
    } catch (_) {}
  }

  /// Read [key] from whichever backend still holds it. Returns null only if
  /// no readable copy exists anywhere.
  static Future<String?> readEncrypted(String key) async {
    // 1. plain SharedPreferences
    try {
      final prefs = await _sp();
      final plain = prefs.getString('$_plainPrefix$key');
      if (plain != null && plain.isNotEmpty) return plain;
    } catch (_) {}
    // 2. encrypted SharedPreferences
    try {
      final prefs = await _sp();
      final raw = prefs.getString('$_spPrefix$key');
      if (raw != null) {
        final decrypted = _decrypt(raw);
        if (decrypted != null && decrypted.isNotEmpty) return decrypted;
      }
    } catch (_) {}
    // 3. secure storage
    try {
      final raw = await _storage.read(key: key);
      if (raw != null) {
        final decrypted = _decrypt(raw);
        if (decrypted != null && decrypted.isNotEmpty) return decrypted;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeJson(String key, Map<String, dynamic> json) =>
      writeEncrypted(key, jsonEncode(json));

  static Future<Map<String, dynamic>?> readJson(String key) async {
    final v = await readEncrypted(key);
    if (v == null) return null;
    try {
      return jsonDecode(v) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String key) async {
    try {
      final prefs = await _sp();
      await prefs.remove('$_plainPrefix$key');
      await prefs.remove('$_spPrefix$key');
    } catch (_) {}
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
