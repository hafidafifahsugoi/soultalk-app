import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'video_call_screen.dart';
import 'main_shell.dart';
import 'summary_screen.dart';
import 'mood_calendar_screen.dart';
import '../widgets/mood_bunny_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedMoodIndex;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static const _moods = [
    {
      'emoji': '😢',
      'label': 'Sedih',
      'message': 'Terima kasih sudah menyadari perasaanmu. Aku di sini untuk mendengarkan jika kamu ingin bercerita.',
    },
    {
      'emoji': '😟',
      'label': 'Cemas',
      'message': 'Merasa cemas itu wajar. Mari ambil napas perlahan bersama-sama.',
    },
    {
      'emoji': '😐',
      'label': 'Biasa',
      'message': 'Hari yang tenang. Semoga sisa harimu berjalan dengan lancar.',
    },
    {
      'emoji': '🙂',
      'label': 'Baik',
      'message': 'Senang mendengarnya. Semoga hal-hal baik terus menyertaimu hari ini.',
    },
    {
      'emoji': '😊',
      'label': 'Hebat',
      'message': 'Luar biasa! Simpan energi positif ini dan bagikan ke sekitarmu.',
    },
  ];


  void _startCall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VideoCallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final shellState = context.findAncestorStateOfType<MainShellState>();
    final profileProvider = context.watch<ProfileProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final recentSessions = sessionProvider.sessions.take(3).toList();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_selectedMoodIndex != null) {
          setState(() {
            _selectedMoodIndex = null;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat pagi,',
                      style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                  Text(
                      profileProvider.name.isNotEmpty
                          ? profileProvider.name.split(' ').first
                          : 'Pengguna',
                      style: textTheme.titleLarge?.copyWith(fontSize: 26)),
                ],
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(Icons.notifications_none_rounded,
                            color: theme.colorScheme.onSurface, size: 22),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        profileProvider.avatarPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                          child: Center(
                            child: Text(
                                profileProvider.name.isNotEmpty
                                    ? profileProvider.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Mood selection section
          Text(
            'Bagaimana perasaanmu hari ini?',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_moods.length, (index) {
              final isSelected = _selectedMoodIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedMoodIndex == index) {
                      _selectedMoodIndex = null;
                    } else {
                      _selectedMoodIndex = index;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.14)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: MoodBunnyIcon(
                    moodIndex: index,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          if (_selectedMoodIndex != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                final hasSavedToday = sessionProvider.moodHistoryList.any((m) => m['date'] == todayStr);
                
                return GestureDetector(
                  onTap: () {}, // Absorb taps inside the card to prevent closing
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _moods[_selectedMoodIndex!]['message']!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!hasSavedToday) ...[
                          TextField(
                            controller: _noteController,
                            style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Tulis catatan singkat tentang perasaanmu (opsional)...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.8)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: theme.colorScheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final mood = _moods[_selectedMoodIndex!];
                              await sessionProvider.saveMoodCheckIn(
                                _selectedMoodIndex!,
                                mood['emoji']!,
                                mood['label']!,
                                note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
                              );
                              _noteController.clear();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Suasana hati hari ini berhasil disimpan!'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: theme.colorScheme.primary,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Simpan Perasaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Catatan suasana hati hari ini sudah disimpan. Terima kasih!',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
          ],
          const SizedBox(height: 20),

          // Tombol mulai sesi video AI
          ElevatedButton.icon(
            onPressed: () => _startCall(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text('Berbicara dengan SoulTalk AI'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 28),

          // Riwayat Suasana Hati
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Suasana Hati',
                  style: textTheme.titleLarge?.copyWith(fontSize: 18)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MoodCalendarScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Detail',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sessionProvider.moodHistoryList.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Text(
                'Belum ada cukup data untuk melihat polanya.\nCoba check-in beberapa hari dulu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: sessionProvider.moodHistoryList.map((m) {
                  final dateStr = m['date'] as String;
                  final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
                  final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                  final dayLabel = days[parsedDate.weekday - 1];
                  
                  final moodIndex = m['moodIndex'] as int;
                  final level = 30.0 + (moodIndex * 17.5);
                  
                  return _buildDynamicMoodBar(context, dayLabel, moodIndex, level);
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Sesi Cerita Terakhir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sesi Cerita Terakhir',
                  style: textTheme.titleLarge?.copyWith(fontSize: 18)),
              TextButton(
                onPressed: () => shellState?.setIndex(1),
                child: Text('Lihat semua',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...recentSessions.map((c) => _buildConvTile(context, c)),
        ],
      ),
    ),
  );
}



  Widget _buildDynamicMoodBar(BuildContext context, String day, int moodIndex, double level) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 96,
          width: 28,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: level / 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: MoodBunnyIcon(moodIndex: moodIndex, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(day,
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildConvTile(BuildContext context, SessionItem c) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SummaryScreen(fromCall: false, sessionItem: c),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildMoodIndicator(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${c.time} · ${c.duration}',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodIndicator(SessionItem c) {
    return MoodBunnyIcon(
      emoji: c.emoji.isNotEmpty ? c.emoji : c.moodAbbr,
      size: 42,
    );
  }
}
