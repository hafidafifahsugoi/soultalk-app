import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../helper/api_helper.dart';
import '../services/firestore_service.dart';

/// Mengelola data profil pengguna di seluruh app.
/// Menyediakan state nama, email, nomor telepon, bio, dan path avatar.
class ProfileProvider extends ChangeNotifier {
  String _name = 'Aria Bennett';
  String _email = 'aria@soultalk.ai';
  String _phone = '+62 812-3456-7890';
  String _bio = 'Mencari ketenangan pikiran dan pertumbuhan pribadi melalui meditasi dan jurnal harian.';
  final String _avatarPath = 'assets/images/user-avatar.png';

  final FirestoreService _firestoreService = FirestoreService();

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

    await fetchProfileFromFirestore();
    await fetchProfileFromBackend();
  }

  /// Mengambil profil langsung dari Cloud Firestore
  Future<void> fetchProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final data = await _firestoreService.getUserProfile(user.uid);
      if (data != null) {
        _name = data['name'] ?? user.displayName ?? _name;
        _email = data['email'] ?? user.email ?? _email;
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

    // Sinkronisasi ke Cloud Firestore jika pengguna sedang login
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.updateUserProfile(user.uid, {
          'name': name,
          'email': email,
          'phone': phone,
          'bio': bio,
        });
        if (name.isNotEmpty) {
          await user.updateDisplayName(name);
        }
      } catch (_) {}
    }

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

  /// Mereset profil saat pengguna keluar (logout).
  void clearProfile() {
    _name = 'Tamu';
    _email = '';
    _phone = '';
    _bio = '';
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('profile_name');
      prefs.remove('profile_email');
      prefs.remove('profile_phone');
      prefs.remove('profile_bio');
    }).catchError((_) {});
  }
}
