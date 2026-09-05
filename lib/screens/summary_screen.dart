import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import 'main_shell.dart';

// ─────────────────────────────────────────────────────────────
//  Palet warna
// ─────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF6E8BD6);
  static const accent = Color(0xFFCBB6E6);
  static const success = Color(0xFF58B99A);
  static const stress = Color(0xFFE5725C);
  static const amber = Color(0xFFD4A84B);

  // Ikon rekomendasi
  static const rec1Bg = Color(0xFFE8F0FF);
  static const rec1Icon = Color(0xFF5B7DD8);
  static const rec2Bg = Color(0xFFE8F8F2);
  static const rec2Icon = Color(0xFF58B99A);
  static const rec3Bg = Color(0xFFF0EAFF);
  static const rec3Icon = Color(0xFF8B6FD4);
  static const rec4Bg = Color(0xFFFFF4E8);
  static const rec4Icon = Color(0xFFD4A84B);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 7),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────
//  Data
// ─────────────────────────────────────────────────────────────
class _Rec {
  final IconData icon;
  final String title;
  final String desc;
  final Color bg;
  final Color iconColor;
  const _Rec(this.icon, this.title, this.desc, this.bg, this.iconColor);
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    this.fromCall = false,
    this.durationSeconds,
    this.messageCount,
    this.primaryMood,
    this.emoji,
    this.moodAbbr,
    this.accuracy,
    this.observations,
    this.sessionItem,
  });

  final bool fromCall;
  final int? durationSeconds;
  final int? messageCount;
  final String? primaryMood;
  final String? emoji;
  final String? moodAbbr;
  final String? accuracy;
  final List<String>? observations;
  final SessionItem? sessionItem;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Getters for dynamic data
  String get primaryMood => widget.sessionItem?.primaryMood ?? widget.primaryMood ?? 'Sedikit Lelah';
  String get emoji => widget.sessionItem?.emoji ?? widget.emoji ?? '😔';
  String get accuracy => widget.sessionItem?.accuracy ?? widget.accuracy ?? '85%';
  String get durationText => widget.sessionItem?.duration ?? _formatDuration(widget.durationSeconds ?? 0);
  
  String get messageText {
    if (widget.sessionItem != null) {
      return '${widget.sessionItem!.messageCount} pesan';
    }
    return '${widget.messageCount ?? 24} pesan';
  }
  
  List<String> get observations => widget.sessionItem?.observations ?? widget.observations ?? _defaultObservations;

  static const _defaultObservations = [
    'Pikiranmu terdeteksi sedang mengalami kelelahan mental yang cukup terasa.',
    'Beban utamamu saat ini terpantau berasal dari tekanan aktivitas pekerjaan.',
    'Meskipun lelah, kamu luar biasa karena tetap tenang dan stabil saat bercerita.',
  ];

  static const _recs = [
    _Rec(Icons.directions_walk_rounded, 'Jalan-jalan singkat',
        'Luangkan 10–15 menit di luar', _C.rec1Bg, _C.rec1Icon),
    _Rec(Icons.water_drop_outlined, 'Minum air putih',
        'Hidrasi cukup menjernihkan pikiran', _C.rec2Bg, _C.rec2Icon),
    _Rec(Icons.air_rounded, 'Latihan pernapasan',
        'Box breathing 4-4-4-4 selama 5 menit', _C.rec3Bg, _C.rec3Icon),
    _Rec(Icons.bedtime_outlined, 'Istirahat yang cukup',
        'Tidur 7–8 jam malam ini', _C.rec4Bg, _C.rec4Icon),
  ];

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0 dtk';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '$s dtk';
    if (s == 0) return '$m mnt';
    return '$m mnt $s dtk';
  }

  double _parseAccuracy(String acc) {
    final clean = acc.replaceAll('%', '').trim();
    final parsed = double.tryParse(clean) ?? 85.0;
    return parsed / 100.0;
  }

  String _getCalmPercentage() {
    final abbr = widget.sessionItem?.moodAbbr ?? widget.moodAbbr ?? 'St';
    if (abbr == 'Te') return '90%';
    if (abbr == 'Cm') return '40%';
    if (abbr == 'Sd') return '50%';
    return '72%';
  }
  String _getStressPercentage() {
    final abbr = widget.sessionItem?.moodAbbr ?? widget.moodAbbr ?? 'St';
    if (abbr == 'Te') return '15%';
    if (abbr == 'Cm') return '78%';
    if (abbr == 'Sd') return '60%';
    return '85%';
  }
  String _getEnergyPercentage() {
    final abbr = widget.sessionItem?.moodAbbr ?? widget.moodAbbr ?? 'St';
    if (abbr == 'Te') return '80%';
    if (abbr == 'Cm') return '50%';
    if (abbr == 'Sd') return '40%';
    return '60%';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _ctrl.dispose();
    super.dispose();
  }

  // ── back Android saat fromCall → ke MainShell
  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !widget.fromCall,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.fromCall) _goHome();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      _buildMoodCard(),
                      const SizedBox(height: 12),
                      _buildStatsRow(),
                      const SizedBox(height: 28),
                      _sectionTitle('Hal yang kamu ceritakan'),
                      const SizedBox(height: 12),
                      _buildObservations(),
                      const SizedBox(height: 28),
                      _sectionTitle('Rekomendasi'),
                      const SizedBox(height: 12),
                      _buildRecommendations(),
                      if (widget.fromCall) ...[
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Header gradient melengkung
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.primary, _C.accent],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tombol back (hanya saat standalone, bukan setelah call)
          if (!widget.fromCall) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 4),

          // Checkmark + judul
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Obrolan tadi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 4),
                    Text('Terima kasih sudah bercerita. Ini yang kita pelajari hari ini.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                        )),
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
  //  Kartu analisis mood + confidence bar
  // ─────────────────────────────────────────────
  Widget _buildMoodCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label atas
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: _C.primary, size: 15),
              ),
              const SizedBox(width: 8),
              Text('SUASANA HATI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 1.1,
                  )),
            ],
          ),
          const SizedBox(height: 18),

          // Emoji + mood
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _C.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(primaryMood,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: _C.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('Suasana hati dominan',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Confidence
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kesesuaian Suasana Hati',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(accuracy,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _C.primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _parseAccuracy(accuracy)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Stack(children: [
                Container(height: 9, color: _C.primary.withValues(alpha: 0.10)),
                FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    height: 9,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_C.primary, _C.accent]),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: theme.colorScheme.outline),
          const SizedBox(height: 16),

          // 3 badge mini
          Row(children: [
            _MiniBadge(_getCalmPercentage(), 'Tenang', _C.success, Icons.spa_outlined),
            const SizedBox(width: 8),
            _MiniBadge(_getStressPercentage(), 'Tekanan', _C.stress, Icons.bolt_rounded),
            const SizedBox(width: 8),
            _MiniBadge(_getEnergyPercentage(), 'Energi', _C.amber, Icons.electric_bolt_outlined),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Statistik sesi — 2 chip
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(children: [
      _StatChip(
          icon: Icons.timer_outlined,
          label: 'Durasi',
          value: durationText,
          color: _C.primary,
          bg: _C.rec1Bg),
      const SizedBox(width: 10),
      _StatChip(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Pesan',
          value: messageText,
          color: _C.rec3Icon,
          bg: _C.rec3Bg),
    ]);
  }

  // ─────────────────────────────────────────────
  //  Observasi AI — kartu tunggal dengan divider
  // ─────────────────────────────────────────────
  Widget _buildObservations() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          ...observations.asMap().entries.map((e) {
            final isLast = e.key == observations.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [_C.primary, _C.accent]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13.5,
                            height: 1.55,
                          )),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 54,
                    endIndent: 16,
                    color: theme.colorScheme.outline),
            ]);
          }),
          Divider(height: 1, color: theme.colorScheme.outline),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: _C.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Refleksi kecil',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Apa satu hal kecil yang ingin kamu bawa atau renungkan dari percakapan kita hari ini?',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Rekomendasi — 4 kartu, warna berbeda
  // ─────────────────────────────────────────────
  Widget _buildRecommendations() {
    return Column(
      children: _recs
          .map((r) => _RecCard(
                rec: r,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _RecBottomSheet(rec: r),
                  );
                },
              ))
          .toList(),
    );
  }

  // ─────────────────────────────────────────────
  //  Tombol Simpan Laporan — satu, clean
  // ─────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
        label: const Text('Simpan Lembar Cerita',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            )),
      ),
    );
  }

  void _onSave() {
    final String currentTitle = widget.fromCall 
        ? 'Refleksi Sesi Panggilan' 
        : (widget.sessionItem?.title ?? 'Sesi Cerita');
        
    final currentAbbr = widget.sessionItem?.moodAbbr ?? widget.moodAbbr ?? 'St';
    
    final newItem = SessionItem(
      title: currentTitle,
      time: 'Baru saja',
      duration: durationText,
      moodAbbr: currentAbbr,
      primaryMood: primaryMood,
      emoji: emoji,
      accuracy: accuracy,
      observations: observations,
      messageCount: widget.sessionItem?.messageCount ?? widget.messageCount ?? 24,
    );

    // Save to provider
    Provider.of<SessionProvider>(context, listen: false).addSession(newItem);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_rounded, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Text('Lembar cerita berhasil disimpan',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));

    // Wait a brief moment, then go back to home
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _goHome();
      }
    });
  }

  Widget _sectionTitle(String t) {
    final theme = Theme.of(context);
    return Text(t,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ));
  }
}

// ─────────────────────────────────────────────────────────────
//  Widget Helpers
// ─────────────────────────────────────────────────────────────

class _MiniBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  const _MiniBadge(this.value, this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _C.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ]),
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  final _Rec rec;
  final VoidCallback onTap;
  const _RecCard({required this.rec, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _C.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: rec.bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(rec.icon, color: rec.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(rec.desc,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: rec.bg, borderRadius: BorderRadius.circular(9)),
                child:
                    Icon(Icons.arrow_forward_rounded, color: rec.iconColor, size: 14),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RecBottomSheet extends StatefulWidget {
  final _Rec rec;
  const _RecBottomSheet({required this.rec});

  @override
  State<_RecBottomSheet> createState() => _RecBottomSheetState();
}

class _RecBottomSheetState extends State<_RecBottomSheet> with SingleTickerProviderStateMixin {
  // Breathing states
  bool _breathingActive = false;
  int _breathTimer = 4;
  String _breathStatus = 'Siap memulai?';
  Timer? _timer;
  late final AnimationController _breathAnim;

  // Hydration states
  int _waterGlasses = 0;

  @override
  void initState() {
    super.initState();
    _breathAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathAnim.dispose();
    super.dispose();
  }

  void _startBreathing() {
    _breathAnim.forward();
    setState(() {
      _breathingActive = true;
      _breathTimer = 4;
      _breathStatus = 'Tarik Napas';
    });

    int cycle = 0; // 0: Tarik, 1: Tahan, 2: Hembus, 3: Tahan
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_breathTimer > 1) {
          _breathTimer--;
        } else {
          _breathTimer = 4;
          cycle = (cycle + 1) % 4;
          if (cycle == 0) {
            _breathStatus = 'Tarik Napas';
            _breathAnim.forward(from: 0);
          } else if (cycle == 1) {
            _breathStatus = 'Tahan Napas';
          } else if (cycle == 2) {
            _breathStatus = 'Hembuskan';
            _breathAnim.reverse(from: 1);
          } else {
            _breathStatus = 'Tahan Napas';
          }
        }
      });
    });
  }

  void _stopBreathing() {
    _timer?.cancel();
    _breathAnim.stop();
    setState(() {
      _breathingActive = false;
      _breathStatus = 'Latihan Selesai';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBreathing = widget.rec.title.contains('pernapasan');
    final isWater = widget.rec.title.contains('air putih');
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.rec.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.rec.icon, color: widget.rec.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rec.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    Text(
                      widget.rec.desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Content based on recommendation type
          if (isBreathing) ...[
            _buildBreathingContent(theme)
          ] else if (isWater) ...[
            _buildWaterContent(theme)
          ] else ...[
            _buildGeneralContent(theme)
          ],
        ],
      ),
    );
  }

  Widget _buildBreathingContent(ThemeData theme) {
    return Column(
      children: [
        const Text(
          'Metode Box Breathing 4-4-4-4\nMembantu menurunkan detak jantung dan menenangkan saraf cemas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 32),

        // Visual pulsing circle
        Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.25).animate(
              CurvedAnimation(parent: _breathAnim, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.rec.iconColor.withValues(alpha: 0.15),
                border: Border.all(color: widget.rec.iconColor.withValues(alpha: 0.35), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: widget.rec.iconColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _breathStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: widget.rec.iconColor,
                      ),
                    ),
                    if (_breathingActive) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$_breathTimer s',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: widget.rec.iconColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Start/Stop button
        ElevatedButton(
          onPressed: _breathingActive ? _stopBreathing : _startBreathing,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.rec.iconColor,
            foregroundColor: Colors.white,
          ),
          child: Text(_breathingActive ? 'Hentikan Sesi' : 'Mulai Latihan Pernapasan'),
        ),
      ],
    );
  }

  Widget _buildWaterContent(ThemeData theme) {
    return Column(
      children: [
        const Text(
          'Menjaga hidrasi membantu otak berpikir jernih dan menurunkan stres hormonal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Glasses logging interface
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _waterGlasses;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedScale(
                scale: filled ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.local_drink_rounded,
                  size: 38,
                  color: filled ? widget.rec.iconColor : theme.colorScheme.outline,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Text(
          _waterGlasses >= 5 
              ? 'Luar biasa! Target hidrasimu hari ini tercapai! 🎉'
              : 'Kamu sudah minum $_waterGlasses dari 5 gelas target hidrasi hari ini.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 32),

        // Increment button
        ElevatedButton(
          onPressed: _waterGlasses >= 5 ? null : () {
            setState(() {
              _waterGlasses++;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.rec.iconColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('+ Minum Segelas Air'),
        ),
      ],
    );
  }

  Widget _buildGeneralContent(ThemeData theme) {
    final isWalk = widget.rec.title.contains('jalan');
    final tips = isWalk
        ? [
            'Tinggalkan gawai dan layar komputer Anda sejenak.',
            'Berjalanlah santai di luar atau area taman selama 10–15 menit.',
            'Amati 5 benda berwarna hijau di sekitarmu untuk teknik grounding.',
            'Biarkan sinar matahari sore atau pagi menghangatkan kulitmu.'
          ]
        : [
            'Redupkan lampu kamar 30 menit sebelum waktu tidur Anda.',
            'Hindari bermain HP atau laptop di atas tempat tidur.',
            'Gunakan wewangian aromaterapi atau lavender jika tersedia.',
            'Lakukan stretching ringan atau tulis jurnal singkat untuk melepas pikiran.'
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isWalk 
              ? 'Langkah sehat untuk menyegarkan pikiranmu yang jenuh:'
              : 'Langkah praktis untuk mendapatkan istirahat berkualitas malam ini:',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: widget.rec.iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.rec.iconColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Saya Mengerti'),
        ),
      ],
    );
  }
}
