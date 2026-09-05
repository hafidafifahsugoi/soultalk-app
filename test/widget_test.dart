import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk_ai/main.dart';
import 'package:soultalk_ai/screens/splash_screen.dart';
import 'package:soultalk_ai/screens/login_screen.dart';
import 'package:soultalk_ai/screens/register_screen.dart';

void main() {
  testWidgets('SplashScreen menampilkan teks Indonesia dengan benar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoulTalkApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('SoulTalk AI'), findsOneWidget);
    expect(find.text('Mulai Sekarang'), findsOneWidget);

    // Selesaikan timer splash (2.8 detik)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('LoginScreen menampilkan elemen Indonesia dengan benar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('Selamat Datang'), findsOneWidget);
    // Tombol masuk — cari di ElevatedButton
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    // "Daftar sekarang" ada di dalam Text.rich
    expect(find.textContaining('Daftar sekarang'), findsOneWidget);
  });

  testWidgets('RegisterScreen menampilkan form pendaftaran dengan benar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen()),
    );

    expect(find.text('Buat Akun Baru'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Daftar Sekarang'), findsOneWidget);
    expect(find.text('Daftar dengan Google'), findsOneWidget);
    // "Masuk" ada di dalam Text.rich
    expect(find.textContaining('Masuk'), findsOneWidget);
  });

  testWidgets('Navigasi dari LoginScreen ke RegisterScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    // Scroll ke bawah agar tombol "Daftar sekarang" terlihat
    await tester.dragUntilVisible(
      find.textContaining('Daftar sekarang'),
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.tap(find.textContaining('Daftar sekarang'),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}
