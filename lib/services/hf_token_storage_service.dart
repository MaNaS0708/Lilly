import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hf_token_data.dart';

class HfTokenStorageService {
  static const String _tokenKey = 'hf_token_data';

  Future<void> saveToken(HfTokenData token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, jsonEncode(token.toMap()));
  }

  Future<HfTokenData?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tokenKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    return HfTokenData.fromMap(Map<String, dynamic>.from(decoded));
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
