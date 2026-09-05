import 'package:flutter/material.dart';

/// Mengontrol mode terang/gelap di seluruh app.
/// Di-provide dari main.dart dan dikonsumsi oleh ProfileScreen.
class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void set(bool dark) {
    if (_isDark == dark) return;
    _isDark = dark;
    notifyListeners();
  }
}
