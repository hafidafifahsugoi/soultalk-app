import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import 'summary_screen.dart';

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
    final sessions = sessionProvider.sessions;
    final theme = Theme.of(context);

    // Calculate dynamic stats
    final totalSessions = sessions.length.toString();

    // Average calm: sum calm percentage
    double totalCalm = 0;
    for (final s in sessions) {
      if (s.moodAbbr == 'Te') {
        totalCalm += 90;
      } else if (s.moodAbbr == 'Cm') {
        totalCalm += 40;
      } else if (s.moodAbbr == 'Sd') {
        totalCalm += 50;
      } else {
        totalCalm += 72; // St / Sedikit Lelah
      }
    }
    final avgCalm = sessions.isEmpty ? '0%' : '${(totalCalm / sessions.length).toStringAsFixed(0)}%';

    // Total duration: sum minutes
    int totalMins = 0;
    for (final s in sessions) {
      final match = RegExp(r'(\d+)\s*mnt').firstMatch(s.duration);
      if (match != null) {
        totalMins += int.parse(match.group(1)!);
      } else {
        final secMatch = RegExp(r'(\d+)\s*dtk').firstMatch(s.duration);
        if (secMatch != null) {
          // count less than 60s as 1 min for statistics
          totalMins += 1;
        }
      }
    }

    String durationStr = '${totalMins}m';
    if (totalMins >= 60) {
      durationStr = '${totalMins ~/ 60}j ${totalMins % 60}m';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 14),
              const SizedBox(width: 7),
              Text(
                'Perkembangan Mingguanmu',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(totalSessions, 'Sesi'),
              _MiniStat(avgCalm, 'Indikator\nKetenangan'),
              _MiniStat(durationStr, 'Durasi\nSesi'),
            ],
          ),
          const Divider(height: 24, thickness: 0.8),
          Text(
            'Belakangan ini kamu terlihat lebih sering merasa tenang setelah bercerita. Ingat untuk terus meluangkan waktu bagi dirimu.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.3,
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
            // Emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child:
                    Text(session.emoji, style: const TextStyle(fontSize: 22)),
              ),
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
