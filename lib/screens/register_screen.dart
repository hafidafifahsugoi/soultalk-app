import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../helper/api_helper.dart';
import '../providers/profile_provider.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreeTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      _showSnackbar('Nama lengkap wajib diisi');
      return;
    }
    if (email.isEmpty) {
      _showSnackbar('Email wajib diisi');
      return;
    }
    if (password.length < 6) {
      _showSnackbar('Kata sandi minimal 6 karakter');
      return;
    }
    if (password != _confirmPasswordController.text) {
      _showSnackbar('Konfirmasi kata sandi tidak cocok');
      return;
    }
    if (!_agreeTerms) {
      _showSnackbar('Harap setujui syarat & ketentuan');
      return;
    }

    setState(() => _loading = true);

    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/auth/register');
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      });

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 7));

      setState(() => _loading = false);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String;
        await ApiHelper.saveToken(token);

        if (mounted) {
          context.read<ProfileProvider>().setProfile(
            name: name,
            email: email,
            phone: '',
            bio: 'Mencari ketenangan pikiran dan pertumbuhan pribadi melalui meditasi dan jurnal harian.',
          );

          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (_, __, ___) => const MainShell(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
            (route) => false,
          );
        }
      } else {
        final data = jsonDecode(res.body);
        final errorMsg = data['detail'] ?? 'Terjadi kesalahan saat mendaftar';
        _showSnackbar(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackbar('Gagal terhubung ke server');
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.foreground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + logo
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.muted,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.foreground, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                    child: const Center(child: AppLogo(size: 22)),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Text('Buat Akun Baru',
                  style: textTheme.displaySmall?.copyWith(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                'Mulai perjalanan kesehatan mentalmu bersama SoulTalk AI.',
                style: textTheme.bodyLarge
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 32),

              // Nama lengkap
              _label('Nama Lengkap'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'contoh: Budi Santoso',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(height: 20),

              // Email
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'kamu@contoh.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded,
                      color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(height: 20),

              // Kata sandi
              _label('Kata Sandi'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'minimal 6 karakter',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.mutedForeground),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.mutedForeground,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Konfirmasi kata sandi
              _label('Konfirmasi Kata Sandi'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: 'ulangi kata sandi',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.mutedForeground),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.mutedForeground,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Setuju syarat & ketentuan
              GestureDetector(
                onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _agreeTerms
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _agreeTerms
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                          width: 1.6,
                        ),
                      ),
                      child: _agreeTerms
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Saya menyetujui ',
                          style: textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedForeground),
                          children: const [
                            TextSpan(
                              text: 'Syarat & Ketentuan',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' dan '),
                            TextSpan(
                              text: 'Kebijakan Privasi',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Tombol daftar
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Daftar Sekarang'),
              ),
              const SizedBox(height: 32),

              // Sudah punya akun
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Sudah punya akun? ',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.mutedForeground),
                      children: const [
                        TextSpan(
                          text: 'Masuk',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }



  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
            fontSize: 14),
      );
}
