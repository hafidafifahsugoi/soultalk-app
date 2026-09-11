import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_bunny_icon.dart';

class MoodCalendarScreen extends StatefulWidget {
  const MoodCalendarScreen({super.key});

  @override
  State<MoodCalendarScreen> createState() => _MoodCalendarScreenState();
}

class _MoodCalendarScreenState extends State<MoodCalendarScreen> {
  late DateTime _selectedMonth;
  Map<String, Map<String, dynamic>> _monthMoods = {};
  bool _isLoading = false;

  final List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final List<String> _weekDayLabels = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final provider = context.read<SessionProvider>();
    final records = await provider.getMoodRecordsForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final map = <String, Map<String, dynamic>>{};
    for (final r in records) {
      final date = r['date'] as String?;
      if (date != null) {
        map[date] = r;
      }
    }

    if (mounted) {
      setState(() {
        _monthMoods = map;
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    // Batasi agar tidak melampaui bulan depan jika data masa depan belum ada
    if (next.isBefore(DateTime(now.year, now.month + 2))) {
      setState(() {
        _selectedMonth = next;
      });
      _loadMonthData();
    }
  }

  int _daysInMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  void _showMoodDetail(BuildContext context, Map<String, dynamic> moodData) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final dateStr = moodData['date'] as String? ?? '';
    final moodIndex = moodData['moodIndex'] as int? ?? 3;
    final label = moodData['label'] as String? ?? MoodBunnyIcon.getLabel(moodIndex);
    final note = moodData['note'] as String?;

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(dateStr);
    } catch (_) {}

    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayName = parsedDate != null ? days[parsedDate.weekday - 1] : '';
    final formattedDate = parsedDate != null
        ? '$dayName, ${parsedDate.day} ${_monthNames[parsedDate.month - 1]} ${parsedDate.year}'
        : dateStr;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Big Cute Bunny
              MoodBunnyIcon(moodIndex: moodIndex, size: 84),
              const SizedBox(height: 12),

              // Mood Label Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Date
              Text(
                formattedDate,
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),

              // Note card
              if (note != null && note.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Catatan Hari Ini',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Warm comfort note
              Text(
                'Terima kasih sudah merawat dan mendengarkan perasaanmu hari ini ❤️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final daysCount = _daysInMonth(_selectedMonth);
    // Weekday: 1 (Monday) to 7 (Sunday). Convert to Sunday = 0, Monday = 1
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
    final startOffset = firstWeekday == 7 ? 0 : firstWeekday;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Mood counts for recap
    int checkInCount = _monthMoods.length;
    final moodFrequency = <int, int>{};
    for (final m in _monthMoods.values) {
      final idx = m['moodIndex'] as int? ?? 3;
      moodFrequency[idx] = (moodFrequency[idx] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.arrow_back_rounded,
                    color: theme.colorScheme.onSurface, size: 20),
              ),
            ),
          ),
        ),
        title: Text(
          'Kalender Suasana Hati',
          style: textTheme.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // ── Month Selector Card ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 28),
                          onPressed: _previousMonth,
                          color: theme.colorScheme.primary,
                        ),
                        Text(
                          '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 28),
                          onPressed: _nextMonth,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Calendar Grid Card ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Weekday labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _weekDayLabels.map((day) {
                            final isWeekend = day == 'Min' || day == 'Sab';
                            return SizedBox(
                              width: 38,
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isWeekend
                                      ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 0.6),
                        const SizedBox(height: 10),

                        // Grid of days
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 4,
                            childAspectRatio: 0.70,
                          ),
                          itemCount: startOffset + daysCount,
                          itemBuilder: (context, index) {
                            if (index < startOffset) {
                              return const SizedBox.shrink();
                            }
                            final dayNum = index - startOffset + 1;
                            final dateKey =
                                "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}";

                            final moodData = _monthMoods[dateKey];
                            final isToday = dateKey == todayStr;

                            return GestureDetector(
                              onTap: moodData != null
                                  ? () => _showMoodDetail(context, moodData)
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isToday
                                      ? Border.all(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (moodData != null) ...[
                                      MoodBunnyIcon(
                                        moodIndex: moodData['moodIndex'] as int?,
                                        emoji: moodData['emoji'] as String?,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$dayNum',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isToday
                                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                              : theme.colorScheme.surfaceContainerHighest
                                                  .withValues(alpha: 0.25),
                                        ),
                                        child: Text(
                                          '$dayNum',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                            color: isToday
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mood Collection Recap (Seperti Gambar 2) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Koleksi Suasana Hati',
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$checkInCount hari tercatat',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Mini Bunny Row Counters
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (idx) {
                            final count = moodFrequency[idx] ?? 0;
                            return Column(
                              children: [
                                MoodBunnyIcon(moodIndex: idx, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  '$count x',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            checkInCount > 0
                                ? 'Hebat! Setiap langkah kecilmu mengamati perasaan adalah bentuk cinta pada diri sendiri 🌸'
                                : 'Belum ada catatan bulan ini. Mulai check-in hari ini yuk untuk mengoleksi kelinci lucumu!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
