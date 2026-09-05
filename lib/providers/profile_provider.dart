import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../helper/api_helper.dart';

/// Mengelola data profil pengguna di seluruh app.
/// Menyediakan state nama, email, nomor telepon, bio, dan path avatar.
class ProfileProvider extends ChangeNotifier {
  String _name = 'Aria Bennett';
  String _email = 'aria@soultalk.ai';
  String _phone = '+62 812-3456-7890';
  String _bio = 'Mencari ketenangan pikiran dan pertumbuhan pribadi melalui meditasi dan jurnal harian.';
  final String _avatarPath = 'assets/images/user-avatar.png';

  ProfileProvider() {
    _loadProfile();
  }

  // Getter
  String get name => _name;
  String get email => _email;
  String get phone => _phone;
  String get bio => _bio;
  String get avatarPath => _avatarPath;

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString('profile_name') ?? 'Aria Bennett';
      _email = prefs.getString('profile_email') ?? 'aria@soultalk.ai';
      _phone = prefs.getString('profile_phone') ?? '+62 812-3456-7890';
      _bio = prefs.getString('profile_bio') ?? 'Mencari ketenangan pikiran dan pertumbuhan pribadi melalui meditasi dan jurnal harian.';
      notifyListeners();
    } catch (_) {}

    await fetchProfileFromBackend();
  }

  Future<void> fetchProfileFromBackend() async {
    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/profile');
      final res = await http.get(url, headers: ApiHelper.headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _name = data['name'] ?? _name;
        _email = data['email'] ?? _email;
        _phone = data['phone'] ?? _phone;
        _bio = data['bio'] ?? _bio;
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_name', _name);
        await prefs.setString('profile_email', _email);
        await prefs.setString('profile_phone', _phone);
        await prefs.setString('profile_bio', _bio);
      }
    } catch (_) {}
  }

  void setProfile({
    required String name,
    required String email,
    required String phone,
    required String bio,
  }) {
    _name = name;
    _email = email;
    _phone = phone;
    _bio = bio;
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('profile_name', name);
      prefs.setString('profile_email', email);
      prefs.setString('profile_phone', phone);
      prefs.setString('profile_bio', bio);
    }).catchError((_) {});
  }

  /// Memperbarui data profil dan memberi tahu semua widget yang mendengarkan.
  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String bio,
  }) async {
    _name = name;
    _email = email;
    _phone = phone;
    _bio = bio;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', name);
      await prefs.setString('profile_email', email);
      await prefs.setString('profile_phone', phone);
      await prefs.setString('profile_bio', bio);
    } catch (_) {}

    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/profile');
      final body = jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'bio': bio,
      });
      await http.post(url, headers: ApiHelper.headers(), body: body);
    } catch (_) {}
  }
}
