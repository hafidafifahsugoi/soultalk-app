import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../helper/api_helper.dart';
import '../providers/profile_provider.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'aria@soultalk.ai');
  final _passwordController = TextEditingController(text: 'password');
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showSnackbar('Email wajib diisi');
      return;
    }
    if (password.isEmpty) {
      _showSnackbar('Kata sandi wajib diisi');
      return;
    }

    setState(() => _loading = true);

    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/auth/login');
      final body = jsonEncode({
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
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            phone: data['phone'] ?? '',
            bio: data['bio'] ?? '',
          );

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (_, __, ___) => const MainShell(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      } else {
        final data = jsonDecode(res.body);
        final errorMsg = data['detail'] ?? 'Terjadi kesalahan saat masuk';
        _showSnackbar(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackbar('Gagal terhubung ke ${ApiHelper.baseUrl}. Periksa backend & Wi-Fi.');
      }
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiHelper.baseUrl);
    bool testing = false;
    String? testResult;
    bool? testSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_ethernet_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pengaturan Server Backend',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Agar HP bisa terhubung, sesuaikan IP laptop Anda atau gunakan kabel USB (adb reverse).',
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'URL Server Backend',
                      hintText: 'http://192.168.1.9:8000',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => controller.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.wifi, size: 14),
                        label: const Text('Wi-Fi PC (192.168.1.9:8000)'),
                        onPressed: () {
                          setModalState(() {
                            controller.text = 'http://192.168.1.9:8000';
                            testResult = null;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.usb, size: 14),
                        label: const Text('USB adb reverse (localhost:8000)'),
                        onPressed: () {
                          setModalState(() {
                            controller.text = 'http://localhost:8000';
                            testResult = null;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.phone_android, size: 14),
                        label: const Text('Emulator (10.0.2.2:8000)'),
                        onPressed: () {
                          setModalState(() {
                            controller.text = 'http://10.0.2.2:8000';
                            testResult = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (testSuccess ?? false)
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (testSuccess ?? false) ? Icons.check_circle : Icons.error_outline,
                            color: (testSuccess ?? false) ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testResult!,
                              style: TextStyle(
                                color: (testSuccess ?? false) ? Colors.green.shade800 : Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: testing
                              ? null
                              : () async {
                                  setModalState(() {
                                    testing = true;
                                    testResult = null;
                                  });
                                  final ok = await ApiHelper.testConnection(controller.text);
                                  setModalState(() {
                                    testing = false;
                                    testSuccess = ok;
                                    testResult = ok
                                        ? 'Berhasil terhubung ke server!'
                                        : 'Gagal terhubung. Pastikan backend jalan & 1 Wi-Fi.';
                                  });
                                },
                          child: testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Tes Koneksi'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await ApiHelper.setBaseUrl(controller.text);
                            if (mounted) setState(() {});
                            Navigator.of(ctx).pop();
                            _showSnackbar('Server disetel ke: ${ApiHelper.baseUrl}');
                          },
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              // Logo icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: const Center(child: AppLogo(size: 36)),
              ),
              const SizedBox(height: 24),
              Text('Selamat Datang',
                  style: textTheme.displaySmall?.copyWith(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                'Masuk untuk melanjutkan perjalanan kesehatan mentalmu.',
                style: textTheme.bodyLarge
                    ?.copyWith(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 36),
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
              _label('Kata Sandi'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.mutedForeground),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.mutedForeground,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Lupa kata sandi?',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
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
                    : const Text('Masuk'),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Belum punya akun? ',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.mutedForeground),
                      children: const [
                        TextSpan(
                          text: 'Daftar sekarang',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _showServerConfigDialog,
                  icon: const Icon(Icons.dns_outlined, size: 15, color: AppColors.mutedForeground),
                  label: Text(
                    'Server: ${ApiHelper.baseUrl}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
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
