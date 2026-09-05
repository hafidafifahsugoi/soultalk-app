import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiHelper {
  static String _resolvedBaseUrl = 'https://backend-pi-ten-58.vercel.app';

  static String get baseUrl => _resolvedBaseUrl;

  static Future<void> initialize() async {
    await loadToken();

    // Default to the online cloud server
    _resolvedBaseUrl = 'https://backend-pi-ten-58.vercel.app';

    // Check if user previously saved a custom server URL
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_server_url');
      if (savedUrl != null &&
          savedUrl.trim().isNotEmpty &&
          !savedUrl.contains('soultalk-app-sigma') &&
          !savedUrl.contains('soultalk-app.')) {
        _resolvedBaseUrl = savedUrl.trim();
        debugPrint('SoulTalk AI Server using saved custom URL: $_resolvedBaseUrl');
        return;
      } else {
        // Clear obsolete saved server URL from previous project
        await prefs.remove('custom_server_url');
      }
    } catch (_) {}

    if (kIsWeb) {
      return;
    }

    // Candidates to test for the server
    final candidates = [
      'https://backend-pi-ten-58.vercel.app', // New Vercel Cloud Server (Online 24/7)
      'http://192.168.1.9:8000',               // PC Wi-Fi IP
      'http://localhost:8000',                 // Works if using USB adb reverse
      'http://10.0.2.2:8000',                  // Android Emulator
    ];

    for (final candidate in candidates) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 1500);
        final uri = Uri.parse(candidate);
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 400) {
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
      return response.statusCode >= 200 && response.statusCode < 400;
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
