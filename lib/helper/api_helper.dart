import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiHelper {
  static String _resolvedBaseUrl = 'http://192.168.1.9:8000';

  static String get baseUrl => _resolvedBaseUrl;

  static Future<void> initialize() async {
    await loadToken();

    if (kIsWeb) {
      _resolvedBaseUrl = 'http://localhost:8000';
      return;
    }

    // Check if user previously saved a custom server URL
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_server_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _resolvedBaseUrl = savedUrl.trim();
        debugPrint('SoulTalk AI Server using saved custom URL: $_resolvedBaseUrl');
        return;
      }
    } catch (_) {}

    // Candidates to test for the local server
    final candidates = [
      'http://192.168.1.9:8000', // PC Wi-Fi IP
      'http://localhost:8000',   // Works if using USB adb reverse
      'http://127.0.0.1:8000',
      'http://10.0.2.2:8000',    // Android Emulator
      'http://192.168.1.5:8000',
    ];

    for (final candidate in candidates) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1200);
        final uri = Uri.parse(candidate);
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode >= 200) {
          _resolvedBaseUrl = candidate;
          debugPrint('SoulTalk AI Server connected successfully to: $candidate');
          return;
        }
      } catch (_) {
        // Continue testing other candidates if connection fails
      }
    }

    // Default fallback based on platform if no candidates responded
    if (Platform.isAndroid) {
      // Prioritize PC Wi-Fi IP for real devices
      _resolvedBaseUrl = 'http://192.168.1.9:8000';
    } else {
      _resolvedBaseUrl = 'http://localhost:8000';
    }
    debugPrint('SoulTalk AI Server using fallback: $_resolvedBaseUrl');
  }

  static Future<void> setBaseUrl(String url) async {
    String formatted = url.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    _resolvedBaseUrl = formatted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_server_url', formatted);
    } catch (_) {}
  }

  static Future<bool> testConnection(String url) async {
    String formatted = url.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final uri = Uri.parse(formatted);
      final request = await client.getUrl(uri);
      final response = await request.close();
      return response.statusCode >= 200;
    } catch (_) {
      return false;
    }
  }

  static String? _token;

  static String? get token => _token;

  static Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
    } catch (_) {}
  }

  static Future<void> saveToken(String value) async {
    _token = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', value);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (_) {}
  }

  static Map<String, String> headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}
