import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import '../services/secure_store.dart';
import 'api_client.dart';

class ProfileApiException implements Exception {
  final String message;
  final int? statusCode;
  ProfileApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ProfileApi {
  ProfileApi._();
  static final ProfileApi instance = ProfileApi._();

  static const String _tokenKey = 'auth_jwt_token';

  Future<String> _getToken() async {
    final token = await SecureStore.readEncrypted(_tokenKey);
    if (token == null) throw ProfileApiException('Not authenticated');
    return token;
  }

  Future<http.Response> _get(String path, {Map<String, String>? headers}) async {
    try {
      return await ApiClient.instance.get(path, headers: headers);
    } on ApiHostUnreachableException catch (e) {
      throw ProfileApiException(
        'Could not reach the server. Check your connection. (${e.cause})',
      );
    }
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Fetches the logged-in user's profile.
  ///
  /// The backend's `GET /api/user/profile` returns
  /// `{ success, user: { id, name, email, phone } }` from
  /// user.controller.js.
  Future<UserProfile> fetchProfile() async {
    final token = await _getToken();
    final res = await _get('/user/profile', headers: _headers(token));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw ProfileApiException(
        body['message']?.toString() ?? 'Failed to fetch profile',
        statusCode: res.statusCode,
      );
    }
    final m = (body['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return UserProfile(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      phone: m['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': 'Unexpected server response'};
    } catch (_) {
      return {'message': 'Unexpected server response'};
    }
  }
}
