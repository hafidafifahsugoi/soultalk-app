import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../helper/api_helper.dart';
import '../theme/app_theme.dart';
import '../providers/profile_provider.dart';
import 'summary_screen.dart';

// ─────────────────────────────────────────────
//  Warna khusus layar video call
// ─────────────────────────────────────────────
class _VColors {
  static const bg1 = Color(0xFF0F1628); // biru tinta gelap
  static const bg2 = Color(0xFF1E1740); // ungu tinta gelap
  static const bg3 = Color(0xFF2A1F52); // ungu medium

  static const glass = Color(0x26FFFFFF); // putih 15%
  static const glassBorder = Color(0x33FFFFFF); // putih 20%
  static const glassDark = Color(0x40000000); // hitam 25%

  static const orbBlue = Color(0xFF6E8BD6);
  static const orbPurple = Color(0xFFCBB6E6);

  static const statusListen = Color(0xFF5BBD9B); // hijau tenang
  static const statusThink = Color(0xFFD4A84B); // kuning amber
  static const statusSpeak = Color(0xFF7B9FE0); // biru soft

  static const userBubble = Color(0x33FFFFFF);
  static const aiBubble = Color(0x1ACBB6E6);
}

// ─────────────────────────────────────────────
//  Model percakapan (bisa di-append)
// ─────────────────────────────────────────────
class _ChatLine {
  final bool isAi;
  final String text;
  const _ChatLine({required this.isAi, required this.text});
}

// ─────────────────────────────────────────────
//  Screen utama
// ─────────────────────────────────────────────
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  // ── State ──
  bool _muted = false;
  bool _cameraOn = true;
  int _seconds = 0;
  int _statusIndex = 0;
  bool _showTextInput = false;
  final _inputController = TextEditingController();

  Timer? _timer;
  Timer? _statusTimer;
  Timer? _chatTimer;

  // ── Real AI Integration ──
  bool _useRealAi = false;

  // ── Real Hardware Controllers ──
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsInitialized = false;

  // ── Status AI ──
  static const _statuses = ['Mendengarkan', 'Berpikir', 'Berbicara'];
  static const _statusIcons = ['🎤', '🧠', '🗣️'];
  static const _statusColors = [
    _VColors.statusListen,
    _VColors.statusThink,
    _VColors.statusSpeak,
  ];

  // ── Percakapan dinamis (dimulai kosong) ──
  final List<_ChatLine> _chat = [];
  final ScrollController _chatScroll = ScrollController();

  // ── AnimationControllers ──
  late final AnimationController _orbPulse; // napas orb lambat
  late final AnimationController _orbGlow; // glow ping cepat
  late final AnimationController _waveAnim; // gelombang suara
  late final AnimationController _statusAnim; // fade status badge
  late final AnimationController _chatEntrance; // slide-in chat panel

  // ── Animations ──
  late final Animation<double> _orbScale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initAi();
    _requestPermissionsAndInitHardware();

    // Napas orb (3 detik bolak-balik)
    _orbPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _orbScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _orbPulse, curve: Curves.easeInOut),
    );

    // Glow ping cepat
    _orbGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _glowOpacity = CurvedAnimation(parent: _orbGlow, curve: Curves.easeOut);

    // Animasi gelombang suara
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Animasi status fade
    _statusAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;

    // Slide-in chat panel
    _chatEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Timer durasi panggilan
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // AI starts in Mendengarkan state
    _statusIndex = 0;
  }

  void _initAi() {
    _useRealAi = ApiHelper.token != null;
  }

  Future<void> _requestPermissionsAndInitHardware() async {
    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (cameraGranted) {
        await _initCamera();
      } else {
        debugPrint("Camera permission denied");
      }

      if (micGranted) {
        await _initSpeechToText();
      } else {
        debugPrint("Microphone permission denied");
      }

      await _initTts();

      if (mounted) {
        final profile = Provider.of<ProfileProvider>(context, listen: false);
        final firstName = profile.name.isNotEmpty ? profile.name.split(' ').first : 'teman';
        final greetingText = 'Halo $firstName! Aku di sini bersamamu. Bagaimana perasaanmu hari ini?';
        
        setState(() {
          _chat.clear();
          _chat.add(_ChatLine(
            isAi: true,
            text: greetingText,
          ));
        });

        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _speak(greetingText);
            setState(() {
              _statusIndex = 2; // AI is speaking
            });
            _waveAnim.repeat(reverse: true);
          }
        });
      }
    } catch (e) {
      debugPrint("Error initializing hardware/permissions: $e");
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final frontCamera = _cameras!.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  Future<void> _initSpeechToText() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: $errorNotification');
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (e) {
      debugPrint("STT initialization failed: $e");
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _statusIndex = 0; // Mendengarkan (Listening)
          });
          _waveAnim.stop();
          _startListening();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) {
          setState(() {
            _statusIndex = 0; // Mendengarkan (Listening)
          });
          _waveAnim.stop();
          _startListening();
        }
      });

      _ttsInitialized = true;
    } catch (e) {
      debugPrint("TTS initialization failed: $e");
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _isListening || _muted || _showTextInput) return;
    try {
      setState(() => _isListening = true);
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            final text = result.recognizedWords.trim();
            _handleVoiceInput(text);
          }
        },
        localeId: 'id_ID',
        pauseFor: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint("STT listen failed: $e");
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _stopListening() async {
    if (_isListening) {
      try {
        await _speechToText.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _speak(String text) async {
    if (!_ttsInitialized) return;
    try {
      await _flutterTts.stop();
      _stopListening();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS speak failed: $e");
    }
  }

  void _handleVoiceInput(String text) {
    if (text.isEmpty) return;
    _stopListening();
    _inputController.text = text;
    _handleSendInput();
  }

  void _toggleCamera() async {
    if (_cameraController == null) return;
    try {
      if (_cameraOn) {
        await _cameraController!.pausePreview();
      } else {
        await _cameraController!.resumePreview();
      }
      setState(() {
        _cameraOn = !_cameraOn;
      });
    } catch (e) {
      debugPrint("Toggle camera failed: $e");
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _timer?.cancel();
    _statusTimer?.cancel();
    _chatTimer?.cancel();
    _cameraController?.dispose();
    _orbPulse.dispose();
    _orbGlow.dispose();
    _waveAnim.dispose();
    _statusAnim.dispose();
    _chatEntrance.dispose();
    _chatScroll.dispose();
    _inputController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> _determineMood() {
    int stressCount = 0;
    int anxietyCount = 0;
    int sadnessCount = 0;

    for (final line in _chat) {
      if (!line.isAi) {
        final text = line.text.toLowerCase();
        if (text.contains('stres') || text.contains('lelah') || text.contains('kerja')) {
          stressCount++;
        }
        if (text.contains('cemas') || text.contains('takut') || text.contains('panik')) {
          anxietyCount++;
        }
        if (text.contains('sedih') || text.contains('kecewa') || text.contains('nangis')) {
          sadnessCount++;
        }
      }
    }

    if (stressCount >= anxietyCount && stressCount >= sadnessCount && stressCount > 0) {
      return {
        'primaryMood': 'Sedikit Lelah',
        'emoji': '😔',
        'moodAbbr': 'St',
        'accuracy': '85%',
        'observations': [
          'Pikiranmu terdeteksi sedang mengalami kelelahan mental yang cukup terasa.',
          'Beban utamamu saat ini terpantau berasal dari tekanan aktivitas pekerjaan.',
          'Meskipun lelah, kamu luar biasa karena tetap tenang dan stabil saat bercerita.',
        ],
      };
    } else if (anxietyCount >= stressCount && anxietyCount >= sadnessCount && anxietyCount > 0) {
      return {
        'primaryMood': 'Cemas',
        'emoji': '😰',
        'moodAbbr': 'Cm',
        'accuracy': '78%',
        'observations': [
          'Terdeteksi adanya tingkat kekhawatiran yang cukup intens dalam pikiranmu.',
          'Kecemasan ini memicu respons tubuh berupa ketegangan otot dan pernapasan pendek.',
          'Kamu sangat hebat karena berhasil mengekspresikan kecemasan ini dengan runtut.',
        ],
      };
    } else if (sadnessCount >= stressCount && sadnessCount >= anxietyCount && sadnessCount > 0) {
      return {
        'primaryMood': 'Sedih',
        'emoji': '😢',
        'moodAbbr': 'Sd',
        'accuracy': '82%',
        'observations': [
          'Terlihat ada kesedihan mendalam yang sedang kamu simpan dalam hatimu.',
          'Meluapkan emosi sedih adalah hal yang baik dan wajar untuk kesehatan mental.',
          'Terima kasih sudah berani membuka diri. Percayalah, mendung ini akan berlalu.',
        ],
      };
    } else {
      return {
        'primaryMood': 'Tenang',
        'emoji': '😊',
        'moodAbbr': 'Te',
        'accuracy': '90%',
        'observations': [
          'Suasana hatimu hari ini terpantau tenang, damai, dan sangat stabil.',
          'Tidak terdeteksi adanya tekanan stres atau kecemasan yang berlebihan.',
          'Pertahankan ketenangan pikiran ini dengan terus melakukan kebiasaan baik.',
        ],
      };
    }
  }

  void _endCall() {
    final moodData = _determineMood();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => SummaryScreen(
          fromCall: true,
          durationSeconds: _seconds,
          messageCount: _chat.length,
          primaryMood: moodData['primaryMood'] as String,
          emoji: moodData['emoji'] as String,
          moodAbbr: moodData['moodAbbr'] as String,
          accuracy: moodData['accuracy'] as String,
          observations: moodData['observations'] as List<String>,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: _VColors.bg1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Latar gradient mesh ──
          _buildBackground(size),

          // ── 2. Partikel bintang halus ──
          const _StarField(),

          // ── 3. Konten utama ──
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                
                // Group spacing, avatar, and status badge into a single AnimatedContainer to prevent tree changes and focus loss
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: keyboardOpen ? 0 : 312,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        _buildAiAvatar(),
                        const SizedBox(height: 16),
                        _buildStatusBadge(),
                      ],
                    ),
                  ),
                ),

                // Chat panel with a stable parent container path to prevent ScrollController crashes
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildChatPanel(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextInputField(),
                if (!keyboardOpen) ...[
                  const SizedBox(height: 8),
                  _buildControls(),
                ],
              ],
            ),
          ),

          // ── 4. Preview kamera user (floating top-right) ──
          if (!keyboardOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              right: 16,
              child: _buildUserCamera(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Latar belakang: gradient mesh + radial glow
  // ─────────────────────────────────────────────
  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _orbPulse,
      builder: (_, __) {
        return CustomPaint(
          painter: _BgPainter(pulse: _orbPulse.value),
          size: size,
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Top bar: timer kiri + nama kanan
  // ─────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Live badge
          _GlassChip(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _orbGlow,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _VColors.statusListen,
                      boxShadow: [
                        BoxShadow(
                          color: _VColors.statusListen
                              .withValues(alpha: (1.0 - _orbGlow.value) * 0.9),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '● SIMULASI PANGGILAN  $_formattedTime',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Nama app
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_VColors.orbBlue, _VColors.orbPurple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _VColors.orbBlue.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'SoulTalk AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Avatar AI + ring glow + wave indicator
  // ─────────────────────────────────────────────
  Widget _buildAiAvatar() {
    return AnimatedBuilder(
      animation: Listenable.merge([_orbScale, _glowOpacity, _waveAnim]),
      builder: (_, __) {
        final isSpeaking = _statusIndex == 2;
        final glowColor = _statusColors[_statusIndex];

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ring glow terluar (fade out)
              Opacity(
                opacity: (1.0 - _orbGlow.value) * 0.18,
                child: Transform.scale(
                  scale: 1.0 + _orbGlow.value * 0.35,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),

              // Ring medium
              Opacity(
                opacity: (1.0 - _orbGlow.value) * 0.28,
                child: Transform.scale(
                  scale: 1.0 + _orbGlow.value * 0.18,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: glowColor.withValues(alpha: 0.5), width: 1.5),
                    ),
                  ),
                ),
              ),

              // Halo blur
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Orb utama (bernafas)
              Transform.scale(
                scale: _orbScale.value,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [
                        Color(0xFFEEF3FF),
                        _VColors.orbBlue,
                        _VColors.orbPurple,
                        Color(0xFF1E1740),
                      ],
                      stops: [0.0, 0.45, 0.75, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.45),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: _VColors.orbPurple.withValues(alpha: 0.20),
                        blurRadius: 60,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/ai-avatar.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _OrbFallback(
                          speaking: isSpeaking, waveAnim: _waveAnim),
                    ),
                  ),
                ),
              ),

              // Indikator gelombang suara (saat berbicara)
              if (isSpeaking)
                Positioned(
                  bottom: 18,
                  child: _WaveIndicator(animation: _waveAnim),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Badge status AI
  // ─────────────────────────────────────────────
  Widget _buildStatusBadge() {
    return FadeTransition(
      opacity: _statusAnim,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Container(
          key: ValueKey(_statusIndex),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [
                _statusColors[_statusIndex].withValues(alpha: 0.85),
                _statusColors[_statusIndex].withValues(alpha: 0.60),
              ],
            ),
            border: Border.all(
              color: _statusColors[_statusIndex].withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _statusColors[_statusIndex].withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulsingDots(color: Colors.white),
              const SizedBox(width: 10),
              Text(
                '${_statusIcons[_statusIndex]}  ${_statuses[_statusIndex]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Panel percakapan (glassmorphism)
  // ─────────────────────────────────────────────
  Widget _buildChatPanel() {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _chatEntrance, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _chatEntrance,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _VColors.glassDark,
            border: Border.all(color: _VColors.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _VColors.statusListen,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'PERCAKAPAN LANGSUNG',
                        style: TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Bubble percakapan
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: keyboardOpen ? 320 : 180,
                  ),
                  child: ListView.builder(
                    controller: _chatScroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: _chat.length,
                    itemBuilder: (_, i) => _ChatBubble(line: _chat[i]),
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
  //  Preview kamera user (floating)
  // ─────────────────────────────────────────────
  Widget _buildUserCamera() {
    return Container(
      width: 82,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _VColors.glassBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Feed kamera / fallback
            _cameraOn
                ? (_isCameraInitialized && _cameraController != null
                    ? SizedBox.expand(
                        child: CameraPreview(_cameraController!),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A2E3D), Color(0xFF151821)],
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                          ),
                        ),
                      ))
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1C2235), Color(0xFF100D1E)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.videocam_off_rounded,
                          color: Color(0x80FFFFFF), size: 26),
                    ),
                  ),

            // Label "Kamu"
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Kamu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Indikator mute
            if (_muted)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.destructive,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(Icons.mic_off_rounded,
                      color: Colors.white, size: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Kontrol bawah (glassmorphism pill)
  // ─────────────────────────────────────────────
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: _VColors.glassDark,
          border: Border.all(color: _VColors.glassBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mikrofon
            _ControlBtn(
              icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _muted ? 'Bisu' : 'Mikrofon',
              active: !_muted,
              onTap: () {
                setState(() {
                  _muted = !_muted;
                });
                if (_muted) {
                  _stopListening();
                } else if (_statusIndex == 0) {
                  _startListening();
                }
              },
            ),

            // Kamera
            _ControlBtn(
              icon: _cameraOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: _cameraOn ? 'Kamera' : 'Kamera Mati',
              active: _cameraOn,
              onTap: _toggleCamera,
            ),

            // Akhiri panggilan
            _EndCallBtn(onTap: _endCall),

            // Ketik (Keyboard Input Toggle)
            _ControlBtn(
              icon: Icons.keyboard_rounded,
              label: 'Ketik',
              active: _showTextInput,
              onTap: () {
                setState(() {
                  _showTextInput = !_showTextInput;
                });
                if (_showTextInput) {
                  _stopListening();
                } else if (_statusIndex == 0) {
                  _startListening();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputField() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _showTextInput
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _VColors.glassDark,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _VColors.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: 'Ketik sesuatu untuk diceritakan...',
                        hintStyle: TextStyle(color: Color(0x80FFFFFF), fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                      onSubmitted: (_) => _handleSendInput(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: _VColors.orbBlue),
                    onPressed: _handleSendInput,
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chat.add(_ChatLine(isAi: false, text: text));
    });
    _inputController.clear();
    _scrollToBottom();

    // Matikan timer rotasi status otomatis agar tidak tumpang tindih
    _statusTimer?.cancel();

    // AI masuk status Berpikir (indeks 1)
    setState(() {
      _statusIndex = 1; // Berpikir
    });
    _waveAnim.stop();
    _stopListening();

    // Dapatkan respons (nyata atau simulasi)
    String responseText;
    if (_useRealAi) {
      responseText = await _getRealAiResponse(text);
    } else {
      // Simulasi delay berpikir 1.2 detik
      await Future.delayed(const Duration(milliseconds: 1200));
      responseText = _getAiResponse(text);
    }

    if (!mounted) return;

    // AI masuk status Berbicara (indeks 2)
    setState(() {
      _statusIndex = 2; // Berbicara
      _chat.add(_ChatLine(isAi: true, text: responseText));
    });
    _scrollToBottom();
    _waveAnim.repeat(reverse: true);

    if (_ttsInitialized) {
      _speak(responseText);
    } else {
      final speakDurationMs = math.max(2000, math.min(6000, responseText.length * 60));
      Timer(Duration(milliseconds: speakDurationMs), () {
        if (!mounted) return;
        setState(() {
          _statusIndex = 0; // Mendengarkan
        });
        _waveAnim.stop();
        _startListening();
      });
    }
  }

  Future<String> _getRealAiResponse(String input) async {
    if (ApiHelper.token == null) {
      return _getAiResponse(input);
    }
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/chat');
      final body = jsonEncode({'message': input});
      final res = await http.post(
        url,
        headers: ApiHelper.headers(),
        body: body,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['reply'] ?? 'Maaf, aku tidak bisa mendengar dengan jelas. Bisa ulangi?';
      } else if (res.statusCode == 403) {
        final data = jsonDecode(res.body);
        final limitMsg = data['detail'] ?? 'Kuota harian Anda telah habis.';
        _showQuotaLimitDialog(limitMsg);
        return limitMsg;
      } else {
        return 'Maaf, koneksiku sedang terganggu sejenak. Aku tetap di sini mendengarkanmu.';
      }
    } catch (e) {
      debugPrint('Chat API Error: $e');
      return 'Maaf, koneksiku sedang terganggu sejenak. Aku tetap di sini mendengarkanmu.';
    }
  }

  void _showQuotaLimitDialog(String limitMsg) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_VColors.bg2, _VColors.bg3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _VColors.glassBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: _VColors.statusThink,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Batas Kuota Tercapai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  limitMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _VColors.statusListen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Tutup dialog
                    _endCall(); // Akhiri panggilan dan masuk ke SummaryScreen
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getAiResponse(String input) {
    final clean = input.toLowerCase();
    final distressKeywords = [
      "bunuh diri", "akhiri hidup", "ingin mati", "menyakiti diri", 
      "sayat pergelangan", "minum racun", "lompat dari", "gantung diri", 
      "potong nadi", "self harm", "suicide"
    ];
    if (distressKeywords.any((k) => clean.contains(k))) {
      return 'Aku mendengar betapa berat dan menyakitkannya situasi yang sedang kamu lalui saat ini. Sebagai teman AI, aku tidak bisa memberikan perawatan medis atau menggantikan bantuan profesional. Keselamatanmu sangat berharga. Tolong hubungi layanan darurat nasional di 119, hubungi keluarga atau teman dekat, atau jangkau hotline pencegahan bunuh diri/krisis terdekat segera. Mohon tetap aman, ya.';
    }
    if (clean.contains('stres') || clean.contains('lelah') || clean.contains('kerja')) {
      return 'Lagi capek banget ya? Istirahat dulu gih, jangan dipaksain. Apa yang bikin paling berasa berat hari ini?';
    }
    if (clean.contains('cemas') || clean.contains('takut') || clean.contains('panik')) {
      return 'Tarik napas dulu pelan-pelan... Hembusin. Nggak apa-apa, santai aja. Aku di sini kok.';
    }
    if (clean.contains('sedih') || clean.contains('kecewa') || clean.contains('nangis')) {
      return 'Sedih atau pengen nangis itu wajar kok, keluarin aja. Mau cerita sekarang atau cuma mau ditemenin?';
    }
    return 'Iya, aku dengerin kok. Terus gimana kelanjutannya?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGET HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Chip kaca semi-transparan
class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _VColors.glass,
        border: Border.all(color: _VColors.glassBorder, width: 1),
      ),
      child: child,
    );
  }
}

/// Tiga titik berdenyut
class _PulsingDots extends StatefulWidget {
  final Color color;
  const _PulsingDots({required this.color});

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_c.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5 * scale,
              height: 5 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.5 + 0.5 * scale),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Gelombang suara (5 bar)
class _WaveIndicator extends StatelessWidget {
  final AnimationController animation;
  const _WaveIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        const heights = [8.0, 14.0, 20.0, 14.0, 8.0];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (i) {
            final phase = (animation.value + i * 0.2) % 1.0;
            final h = heights[i] * (0.5 + 0.5 * math.sin(phase * math.pi));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Fallback isi orb saat gambar tidak tersedia
class _OrbFallback extends StatelessWidget {
  final bool speaking;
  final AnimationController waveAnim;
  const _OrbFallback({required this.speaking, required this.waveAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [
            Color(0xFFEEF3FF),
            _VColors.orbBlue,
            _VColors.orbPurple,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 44),
          if (speaking)
            Positioned(
              bottom: 20,
              child: _WaveIndicator(animation: waveAnim),
            ),
        ],
      ),
    );
  }
}

/// Bubble percakapan
class _ChatBubble extends StatelessWidget {
  final _ChatLine line;
  const _ChatBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final isAi = line.isAi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) ...[
            // Avatar AI kecil
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_VColors.orbBlue, _VColors.orbPurple],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 12),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAi ? 4 : 16),
                  bottomRight: Radius.circular(isAi ? 16 : 4),
                ),
                color: isAi ? _VColors.aiBubble : _VColors.userBubble,
                border: Border.all(
                  color: isAi
                      ? _VColors.orbPurple.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(
                    isAi ? 'SoulTalk AI' : 'Kamu',
                    style: TextStyle(
                      color: isAi
                          ? _VColors.orbPurple.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    line.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isAi) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Tombol kontrol biasa (mic / kamera)
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.destructive.withValues(alpha: 0.85),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: active
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.destructive.withValues(alpha: 0.30),
                        blurRadius: 14,
                      ),
                    ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol akhiri panggilan (merah, lebih besar)
class _EndCallBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndCallBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF5350), Color(0xFFB71C1C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.55),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Akhiri',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Latar belakang gradient mesh + radial glow
class _BgPainter extends CustomPainter {
  final double pulse;
  _BgPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient mesh dasar
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_VColors.bg1, _VColors.bg2, _VColors.bg3],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Radial glow biru di tengah atas
    final glowBlue = Paint()
      ..shader = RadialGradient(
        colors: [
          _VColors.orbBlue.withValues(alpha: 0.18 + pulse * 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.35),
          radius: size.width * 0.65));
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.35),
        size.width * 0.65, glowBlue);

    // Radial glow ungu kiri bawah
    final glowPurple = Paint()
      ..shader = RadialGradient(
        colors: [
          _VColors.orbPurple.withValues(alpha: 0.12 + pulse * 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.75),
          radius: size.width * 0.5));
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.75),
        size.width * 0.5, glowPurple);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.pulse != pulse;
}

/// Partikel bintang halus (statis, dihasilkan sekali)
class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  // Posisi bintang deterministik (bukan random setiap frame)
  static final _stars = List.generate(55, (i) {
    final x = ((i * 137.508 + 23) % 100) / 100;
    final y = ((i * 97.31 + 11) % 100) / 100;
    final r = 0.6 + (i % 5) * 0.25;
    final a = 0.15 + (i % 4) * 0.08;
    return (x: x, y: y, r: r, a: a);
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        Paint()..color = Colors.white.withValues(alpha: s.a),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}
