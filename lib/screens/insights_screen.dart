import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'summary_screen.dart';
import '../widgets/mood_bunny_icon.dart';

/// Tab "Ringkasan" di bottom nav — menampilkan riwayat sesi,
/// bukan SummaryScreen langsung (agar tidak ada konflik navigasi).
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, this.standalone = false});

  /// true → halaman terpisah dengan back button (dibuka dari Profile)
  /// false → tab di dalam MainShell (tanpa AppBar)
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final sessionProvider = context.watch<SessionProvider>();
    final sessions = sessionProvider.sessions;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              if (standalone) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        color: theme.colorScheme.onSurface, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ruang Refleksi',
                            style: textTheme.titleLarge?.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rangkuman perjalanan tenangmu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge total sesi
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 13, color: theme.colorScheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            '${sessions.length} sesi',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Kartu statistik mingguan ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _WeeklyCard(),
        ),
        const SizedBox(height: 24),

        // ── Label riwayat ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Riwayat Sesi Cerita',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── List riwayat ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: sessions.length,
            itemBuilder: (ctx, i) => _SessionTile(
              session: sessions[i],
              onTap: () => Navigator.of(ctx).push(
                MaterialPageRoute(
                  builder: (_) => SummaryScreen(fromCall: false, sessionItem: sessions[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (standalone) {
      return Scaffold(
        body: SafeArea(child: content),
      );
    }
    return SafeArea(child: content);
  }
}

// ─────────────────────────────────────────────
//  Kartu statistik mingguan
// ─────────────────────────────────────────────
class _WeeklyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Perkembangan Mingguanmu',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Statistik empat kolom dengan gaya soft kaca (glassmorphism)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                _MiniStat('${sessionProvider.totalSessions}', 'Total Sesi'),
                _miniDivider(),
                _MiniStat('${sessionProvider.streakDays} hr', 'Hari Beruntun'),
                _miniDivider(),
                _MiniStat(sessionProvider.averageCalm, 'Indikator\nKetenangan'),
                _miniDivider(),
                _MiniStat(sessionProvider.totalDurationFormatted, 'Durasi Sesi'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Belakangan ini kamu terlihat lebih sering merasa tenang setelah bercerita. Ingat untuk terus meluangkan waktu bagi dirimu.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.28),
      );
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Tile riwayat sesi
// ─────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final SessionItem session;
  final VoidCallback onTap;
  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Bunny Mood Icon
            MoodBunnyIcon(
              emoji: session.emoji.isNotEmpty ? session.emoji : session.moodAbbr,
              size: 42,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        session.duration,
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_rounded,
                          size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        session.accuracy,
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tanggal + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.time,
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
