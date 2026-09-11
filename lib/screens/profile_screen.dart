import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../helper/api_helper.dart';
import '../providers/session_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'help_center_screen.dart';

// ─────────────────────────────────────────────────────────────
//  ProfileScreen
// ─────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  bool _privacy = true;
  bool _memoryEnabled = true;
  List<dynamic> _memories = [];
  bool _loadingMemory = false;

  @override
  void initState() {
    super.initState();
    _fetchMemorySettings();
  }

  Future<void> _fetchMemorySettings() async {
    if (ApiHelper.token == null) return;
    if (mounted) setState(() => _loadingMemory = true);
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/memory');
      final res = await http.get(url, headers: ApiHelper.headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _memoryEnabled = data['enabled'] ?? true;
            _memories = data['memories'] ?? [];
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMemory = false);
  }

  Future<void> _toggleMemory(bool enabled) async {
    if (mounted) setState(() => _memoryEnabled = enabled);
    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/memory/toggle');
      final body = jsonEncode({'enabled': enabled});
      await http.post(url, headers: ApiHelper.headers(), body: body);
    } catch (_) {}
  }

  Future<void> _deleteMemoryItem(int id) async {
    if (mounted) {
      setState(() {
        _memories.removeWhere((m) => m['id'] == id);
      });
    }
    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/memory/$id');
      await http.delete(url, headers: ApiHelper.headers());
    } catch (_) {}
  }

  Future<void> _clearAllMemories() async {
    if (mounted) {
      setState(() {
        _memories.clear();
      });
    }
    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/user/memory');
      await http.delete(url, headers: ApiHelper.headers());
    } catch (_) {}
  }

  // ── Logout ──
  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius)),
        title: const Text('Keluar'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService().signOut();
              await ApiHelper.clearToken();
              if (mounted) {
                context.read<ProfileProvider>().clearProfile();
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 350),
                    pageBuilder: (_, __, ___) => const LoginScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Keluar',
                style: TextStyle(
                    color: AppColors.destructive, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _snackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.foreground,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header profil ──
            _buildHeader(textTheme),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Akun ──
                  _sectionLabel('Akun'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profil',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                    _MenuItem(
                      icon: Icons.lock_outline_rounded,
                      label: 'Ubah Kata Sandi',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── Pengaturan ──
                  _sectionLabel('Pengaturan'),
                  const SizedBox(height: 8),
                  _settingsCard(textTheme),

                  const SizedBox(height: 24),

                  // ── Data & Privasi ──
                  _sectionLabel('Data & Privasi'),
                  const SizedBox(height: 8),
                  _dataPrivacyCard(textTheme),

                  const SizedBox(height: 24),

                  // ── Dukungan ──
                  _sectionLabel('Dukungan'),
                  const SizedBox(height: 8),
                  _menuCard([
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Pusat Bantuan',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const HelpCenterScreen()),
                      ),
                    ),
                    _MenuItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Hubungi Kami',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const HelpCenterScreen(showContact: true)),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ── Tombol Keluar ──
                  _logoutButton(),

                  const SizedBox(height: 8),

                  // Versi app
                  const Center(
                    child: Text(
                      'SoulTalk AI · v1.0.0',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.mutedForeground),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Header — foto, nama, email, badge, stats
  // ─────────────────────────────────────────────
  Widget _buildHeader(TextTheme textTheme) {
    final profileProvider = context.watch<ProfileProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Foto + nama + email
          Row(
            children: [
              // Foto
              Stack(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.50),
                          width: 2.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        profileProvider.avatarPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.20),
                          child: Center(
                            child: Text(
                                profileProvider.name.isNotEmpty
                                    ? profileProvider.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tombol edit foto
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Nama + email + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileProvider.name,
                      style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profileProvider.email,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.white, size: 11),
                          SizedBox(width: 4),
                          Text('Premium',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Label section
  // ─────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        letterSpacing: 1.1,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Kartu menu generik (item dengan chevron)
  // ─────────────────────────────────────────────
  Widget _menuCard(List<_MenuItem> items) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: SoftShadow.soft,
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: e.key == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: isLast ? const Radius.circular(18) : Radius.zero,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(item.icon, color: theme.colorScheme.primary, size: 19),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.label,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                fontSize: 14)),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: theme.colorScheme.outline),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Kartu pengaturan (dengan toggle)
  // ─────────────────────────────────────────────
  Widget _settingsCard(TextTheme textTheme) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: SoftShadow.soft,
      ),
      child: Column(
        children: [
          // Notifikasi
          _toggleRow(
            icon: Icons.notifications_none_rounded,
            label: 'Notifikasi',
            desc: 'Pengingat & pemeriksaan rutin',
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
            isFirst: true,
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Privasi
          _toggleRow(
            icon: Icons.shield_outlined,
            label: 'Privasi',
            desc: 'Data kamu aman & terenkripsi di perjalanan',
            value: _privacy,
            onChanged: (v) => setState(() => _privacy = v),
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Mode gelap — tersambung ke ThemeProvider
          _toggleRow(
            icon: Icons.dark_mode_outlined,
            label: 'Mode Gelap',
            desc: 'Ubah tampilan aplikasi ke tema gelap',
            value: context.watch<ThemeProvider>().isDark,
            onChanged: (v) {
              context.read<ThemeProvider>().set(v);
            },
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Bahasa
          InkWell(
            onTap: () => _showLanguageSheet(),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.language_rounded,
                        color: theme.colorScheme.primary, size: 19),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bahasa',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                fontSize: 14)),
                        Text('Indonesia',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataPrivacyCard(TextTheme textTheme) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: SoftShadow.soft,
      ),
      child: Column(
        children: [
          // Memory toggle
          _toggleRow(
            icon: Icons.psychology_outlined,
            label: 'Memori SoulTalk',
            desc: 'AI mengingat info penting ceritamu',
            value: _memoryEnabled,
            onChanged: (v) => _toggleMemory(v),
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Kelola Memori
          _menuItemRow(
            icon: Icons.settings_suggest_outlined,
            label: 'Kelola Memori',
            desc: 'Lihat dan hapus catatan ingatan AI',
            onTap: () {
              _fetchMemorySettings();
              _showManageMemoryDialog();
            },
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Hapus Riwayat Sesi
          _menuItemRow(
            icon: Icons.delete_sweep_outlined,
            label: 'Hapus Riwayat Sesi',
            desc: 'Hapus permanen semua riwayat obrolan',
            onTap: () => _confirmClearSessions(),
          ),
          Divider(
              height: 1, indent: 68, endIndent: 16, color: theme.colorScheme.outline),

          // Hapus Akun
          _menuItemRow(
            icon: Icons.no_accounts_outlined,
            label: 'Hapus Akun Anda',
            desc: 'Tutup akun dan hapus seluruh data',
            onTap: () => _confirmDeleteAccount(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _menuItemRow({
    required IconData icon,
    required String label,
    required String desc,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive 
                    ? theme.colorScheme.error.withValues(alpha: 0.09) 
                    : theme.colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon, 
                color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary, 
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6), 
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4), 
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showManageMemoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ingatan SoulTalk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_memories.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(ctx);
                    await _clearAllMemories();
                    setDialogState(() {});
                    if (mounted) setState(() {});
                    navigator.pop();
                    _snackbar('Semua ingatan berhasil dihapus');
                  },
                  child: const Text('Hapus Semua', style: TextStyle(color: AppColors.destructive, fontSize: 12)),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 250,
            child: _loadingMemory
                ? const Center(child: CircularProgressIndicator())
                : _memories.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada ingatan tersimpan.\nSoulTalk akan mengingat konteks penting saat bercerita.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final item = _memories[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item['content'] ?? '',
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.destructive, size: 20),
                              onPressed: () async {
                                await _deleteMemoryItem(item['id']);
                                setDialogState(() {});
                                if (mounted) setState(() {});
                              },
                            ),
                          );
                        },
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearSessions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius)),
        title: const Text('Hapus Riwayat Sesi'),
        content: const Text('Apakah kamu yakin ingin menghapus semua riwayat sesi obrolan secara permanen? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.read<SessionProvider>().clearSessions();
              if (success) {
                _snackbar('Semua riwayat sesi berhasil dihapus');
              } else {
                _snackbar('Gagal menghapus riwayat sesi');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius)),
        title: const Text('Hapus Akun'),
        content: const Text('Tindakan ini sangat sensitif. Semua data Anda akan dihapus permanen dari server kami. Apakah Anda yakin ingin melanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (ApiHelper.token != null) {
                try {
                  final url = Uri.parse('${ApiHelper.baseUrl}/api/user/account');
                  final res = await http.delete(url, headers: ApiHelper.headers());
                  if (res.statusCode == 200) {
                    await ApiHelper.clearToken();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                    _snackbar('Akun Anda berhasil dihapus');
                    return;
                  }
                } catch (_) {}
              }
              _snackbar('Gagal menghapus akun');
            },
            child: const Text('Hapus Akun', style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isFirst = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontSize: 14)),
                Text(desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
              ],
            ),
          ),
          _Toggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Tombol keluar
  // ─────────────────────────────────────────────
  Widget _logoutButton() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _logout,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: theme.colorScheme.error.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: theme.colorScheme.error, size: 18),
            const SizedBox(width: 8),
            Text('Keluar dari Akun',
                style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Bottom sheet pemilih bahasa
  // ─────────────────────────────────────────────
  void _showLanguageSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Pilih Bahasa',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            _langOption('🇮🇩', 'Indonesia', true),
            _langOption('🇬🇧', 'English', false),
            _langOption('🇸🇦', 'العربية', false),
          ],
        ),
      ),
    );
  }

  Widget _langOption(String flag, String name, bool selected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        if (!selected) _snackbar('Bahasa $name segera hadir');
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface)),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Model helper
// ─────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});
}

// ─────────────────────────────────────────────────────────────
//  Toggle pill
// ─────────────────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.28),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 4,
                    offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
