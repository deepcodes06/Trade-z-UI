import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  /// Key under which a runtime-chosen API base URL is persisted (so the user
  /// can switch backend hosts without rebuilding the APK).
  static const String _overrideKey = 'api_base_url_override';
  static const String _lastGoodKey = 'api_base_url_last_good';

  /// Base URL of the TradeZ backend.
  ///
  /// The backend mounts everything under `/api` (see server/src/app.js).
  /// Override at run time:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000
  ///
  /// Defaults:
  ///   - Web              -> localhost
  ///   - Android emulator -> 10.0.2.2
  ///   - iOS simulator    -> 127.0.0.1
  ///   - Physical device  -> your LAN IP, e.g. http://192.168.1.20:5000
  static String get apiBaseUrl => defaultApiBaseUrls.first;

  /// The ordered list of backend hosts the app will try, in order. The first
  /// one that responds is used for the rest of the session (and remembered).
  static List<String> get defaultApiBaseUrls {
    const env = String.fromEnvironment('API_BASE_URL');
    final list = <String>[];
    if (env.isNotEmpty) list.add(env);
    if (kIsWeb) {
      list.add('http://127.0.0.1:5000');
      list.add('http://localhost:5000');
    } else {
      // Android emulator host alias + host machine loopbacks. A physical
      // device should provide the dev machine's LAN IP via
      // --dart-define=API_BASE_URL=... or set it in-app (persisted under
      // _overrideKey).
      list.add('http://10.0.2.2:5000');
      list.add('http://127.0.0.1:5000');
      list.add('http://localhost:5000');
    }
    return list.where((e) => e.isNotEmpty).toSet().toList();
  }

  /// Full candidate list: [runtime override] -> [persisted last-good host] ->
  /// [compile-time defaults]. Used by [ApiClient] to fall through hosts when
  /// the network is unreachable.
  static Future<List<String>> apiBaseUrlCandidates() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_overrideKey);
    final lastGood = prefs.getString(_lastGoodKey);
    final list = <String>[];
    if (override != null && override.isNotEmpty) list.add(override);
    if (lastGood != null && lastGood.isNotEmpty) list.add(lastGood);
    list.addAll(defaultApiBaseUrls);
    return list.where((e) => e.isNotEmpty).toSet().toList();
  }

  /// Persist a host chosen at runtime (e.g. from an in-app settings entry)
  /// so it survives restarts and is tried first on the next launch.
  ///
  /// [url] is normalized: a missing `http://` scheme is added, trailing
  /// slashes are stripped, and invalid values are rejected (returns false).
  /// This keeps users from failing silently because they typed
  /// `192.168.1.20:5000` without the scheme.
  static Future<bool> setRuntimeBaseUrl(String url) async {
    final normalized = normalizeBaseUrl(url);
    if (normalized == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overrideKey, normalized);
    return true;
  }

  /// Strip whitespace/trailing slashes, add a scheme if missing, and validate
  /// the result. Returns null when the value can't be a base URL.
  static String? normalizeBaseUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return null;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1).trim();
    }
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.host == 'null') return null;
    // Reject path-only or malformed entries (must be a host[:port]).
    if (uri.host.contains(' ')) return null;
    return value;
  }

  static Future<String?> getRuntimeBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_overrideKey);
  }

  static Future<void> clearRuntimeBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_overrideKey);
  }

  /// Remember the most recently reachable host so subsequent calls skip
  /// straight to it instead of re-probing every candidate.
  static Future<void> rememberLastGoodHost(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGoodKey, baseUrl);
  }

  /// Every backend endpoint is mounted under this prefix. Kept as a constant
  /// so we never accidentally call `/auth/login` against the bare host.
  static const String apiPrefix = '/api';
}
