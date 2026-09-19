import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/secure_store.dart';
import 'api_client.dart';

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;
  AuthApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
}

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  static const String _accessTokenKey = 'auth_jwt_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _cachedUserKey = 'auth_cached_user';

  /// Currently stored access token (used by session restore on app launch).
  Future<String?> getStoredToken() => SecureStore.readEncrypted(_accessTokenKey);

  /// Currently stored refresh token.
  Future<String?> getStoredRefreshToken() =>
      SecureStore.readEncrypted(_refreshTokenKey);

  /// Whether a token was persisted on this device.
  Future<bool> hasSession() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  /// Persist the user profile alongside the token it belongs to, so the app
  /// can restore the session offline on the next launch. The cache is keyed
  /// by the token itself: `cachedUserForToken` only returns the user when the
  /// stored token matches, which means each login gets its own cached entry
  /// (the newest token overwrites older ones).
  Future<void> cacheUser(String token, AuthUser user) {
    return SecureStore.writeJson(_cachedUserKey, {
      'token': token,
      'user': {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        if (user.phone != null) 'phone': user.phone,
        if (user.createdAt != null)
          'createdAt': user.createdAt!.toIso8601String(),
      },
    });
  }

  /// Load the cached user only if it belongs to [token].
  Future<AuthUser?> cachedUserForToken(String token) async {
    final data = await SecureStore.readJson(_cachedUserKey);
    if (data == null || data['token'] != token) return null;
    final raw = data['user'];
    if (raw is! Map) return null;
    return AuthUser.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Forget the cached user (called on logout).
  Future<void> clearUserCache() => SecureStore.delete(_cachedUserKey);

  Future<({String token, AuthUser user})> register({
    required String name,
    required String email,
    String? phone,
    required String password,
  }) async {
    final payload = {
      'name': name,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
    };
    final http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/signup',
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on ApiHostUnreachableException catch (e) {
      throw AuthApiException(
        'Could not reach the server. Check that the backend is running and '
        'your device is on the same network. (${e.cause})',
      );
    }
    final body = _decode(res);
    if (res.statusCode != 201 || body['success'] != true) {
      throw AuthApiException(
        body['message']?.toString() ?? 'Registration failed',
        statusCode: res.statusCode,
      );
    }
    final token = _tokenFromBody(body);
    final refreshToken = _refreshTokenFromBody(body);
    if (token.isEmpty) {
      throw AuthApiException('Server did not return an access token');
    }
    final user = AuthUser.fromJson(_userFromBody(body));
    await SecureStore.writeEncrypted(_accessTokenKey, token);
    if (refreshToken != null) {
      await SecureStore.writeEncrypted(_refreshTokenKey, refreshToken);
    }
    await cacheUser(token, user);
    return (token: token, user: user);
  }

  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email,
      'password': password,
    };
    final http.Response res;
    try {
      res = await ApiClient.instance.post(
        '/auth/login',
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } on ApiHostUnreachableException catch (e) {
      throw AuthApiException(
        'Could not reach the server. Check that the backend is running and '
        'your device is on the same network. (${e.cause})',
      );
    }
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw AuthApiException(
        body['message']?.toString() ?? 'Login failed',
        statusCode: res.statusCode,
      );
    }
    final token = _tokenFromBody(body);
    final refreshToken = _refreshTokenFromBody(body);
    if (token.isEmpty) {
      throw AuthApiException('Server did not return an access token');
    }
    final user = AuthUser.fromJson(
      _userFromBody(body),
    );
    await SecureStore.writeEncrypted(_accessTokenKey, token);
    if (refreshToken != null) {
      await SecureStore.writeEncrypted(_refreshTokenKey, refreshToken);
    }
    await cacheUser(token, user);
    // ignore: avoid_print
    print('[AUTH-LOGIN] token persisted len=${token.length}, refresh=${refreshToken != null}');
    return (token: token, user: user);
  }

  Future<void> logout() async {
    await SecureStore.delete(_accessTokenKey);
    await SecureStore.delete(_refreshTokenKey);
    await clearUserCache();
  }

  String _tokenFromBody(Map<String, dynamic> body) {
    final direct = body['accessToken']?.toString() ?? body['token']?.toString() ?? '';
    return direct.trim();
  }

  String? _refreshTokenFromBody(Map<String, dynamic> body) {
    final direct = body['refreshToken']?.toString() ?? body['token']?.toString();
    final trimmed = direct?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  Map<String, dynamic> _userFromBody(Map<String, dynamic> body) {
    final rawUser = body['user'];
    if (rawUser is Map) {
      return Map<String, dynamic>.from(rawUser);
    }
    final nested = body['data'];
    if (nested is Map && nested['user'] is Map) {
      return Map<String, dynamic>.from(nested['user'] as Map);
    }
    return const {};
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'message': 'Unexpected server response'};
    } catch (_) {
      return <String, dynamic>{'message': 'Unexpected server response'};
    }
  }
}
