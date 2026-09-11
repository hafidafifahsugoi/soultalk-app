import 'dart:async';
import 'dart:io';
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

  // ── Facial Emotion Detection & AI Awareness ──
  Timer? _emotionTimer;
  bool _isAnalyzingEmotion = false;
  String _currentEmotion = 'Memindai';
  String _currentEmotionEmoji = '👀';
  int _consecutiveSadCount = 0;
  DateTime? _lastProactiveRemarkTime;
  String _lastTriggeredEmotion = '';
  int _totalHappyFrames = 0;
  int _totalSadFrames = 0;
  int _totalNeutralFrames = 0;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastRecognizedText = '';

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
          _startEmotionDetection();
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
              // Kirim ucapan jika ada kata yang sempat terekam sebelum status berakhir
              if (_lastRecognizedText.trim().isNotEmpty) {
                final textToProcess = _lastRecognizedText.trim();
                _lastRecognizedText = '';
                _handleVoiceInput(textToProcess);
              } else if (_statusIndex == 0 && !_muted && !_showTextInput && mounted) {
                // Auto-restart listening agar mic tidak mati sendiri setelah jeda diam
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_statusIndex == 0 && !_muted && !_showTextInput && !_isListening && mounted) {
                    _startListening();
                  }
                });
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('STT Error: $errorNotification');
          if (mounted) {
            setState(() {
              _isListening = false;
            });
            if (_lastRecognizedText.trim().isNotEmpty) {
              final textToProcess = _lastRecognizedText.trim();
              _lastRecognizedText = '';
              _handleVoiceInput(textToProcess);
            } else if (_statusIndex == 0 && !_muted && !_showTextInput && mounted) {
              // Jika timeout karena diam, re-arm listening lagi
              Future.delayed(const Duration(milliseconds: 800), () {
                if (_statusIndex == 0 && !_muted && !_showTextInput && !_isListening && mounted) {
                  _startListening();
                }
              });
            }
          }
        },
      );
      if (mounted) setState(() {});
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
    if (!_speechEnabled || _muted || _showTextInput) return;
    if (_isListening) return;
    try {
      _lastRecognizedText = '';
      setState(() {
        _isListening = true;
      });
      await _speechToText.listen(
        onResult: (result) {
          _lastRecognizedText = result.recognizedWords.trim();
          if (result.finalResult && _lastRecognizedText.isNotEmpty) {
            final text = _lastRecognizedText;
            _lastRecognizedText = '';
            _handleVoiceInput(text);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: 'id_ID',
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: false,
          partialResults: true,
        ),
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

  void _startEmotionDetection() {
    _emotionTimer?.cancel();
    // Beri jeda setelah inisialisasi, lalu deteksi setiap 3.5 detik
    _emotionTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (_cameraOn && _isCameraInitialized && !_isAnalyzingEmotion) {
        _captureAndAnalyzeFace();
      }
    });
  }

  void _stopEmotionDetection() {
    _emotionTimer?.cancel();
    _emotionTimer = null;
  }

  Future<void> _captureAndAnalyzeFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    _isAnalyzingEmotion = true;
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      
      // Hapus file temporary agar penyimpanan HP tidak penuh
      try {
        final f = File(file.path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}

      final base64Image = base64Encode(bytes);
      Map<String, dynamic>? data;

      // 1. Coba panggil Backend API (/api/detect-emotion)
      try {
        final url = Uri.parse('${ApiHelper.baseUrl}/api/detect-emotion');
        final res = await http.post(
          url,
          headers: ApiHelper.headers(),
          body: jsonEncode({'image': base64Image}),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          data = jsonDecode(res.body);
        } else {
          debugPrint("Emotion API non-200: ${res.statusCode}");
        }
      } catch (netErr) {
        debugPrint("Emotion API network error: $netErr");
      }

      // 2. Fallback Direct Gemini Vision jika backend offline / 404 / timeout (misal HP tanpa laptop)
      if (data == null || data['emotion'] == null) {
        data = await _analyzeFaceDirectWithGemini(base64Image);
      }

      if (data != null && mounted) {
        final bool faceDetected = data['face_detected'] ?? false;
        final String emotion = data['emotion'] ?? 'Biasa';
        final String emoji = data['emoji'] ?? '🙂';

        setState(() {
          if (faceDetected) {
            _currentEmotion = emotion;
            _currentEmotionEmoji = emoji;
            if (emotion == 'Senang') _totalHappyFrames++;
            if (emotion == 'Sedih') _totalSadFrames++;
            if (emotion == 'Biasa') _totalNeutralFrames++;
          } else {
            _currentEmotion = 'Mencari';
            _currentEmotionEmoji = '👤';
          }
        });

        if (faceDetected) {
          _handleProactiveAiReaction(emotion);
        }
      }
    } catch (e) {
      debugPrint("Face emotion analysis error: $e");
    } finally {
      _isAnalyzingEmotion = false;
    }
  }

  Future<Map<String, dynamic>?> _analyzeFaceDirectWithGemini(String base64Image) async {
    try {
      final apiKey = utf8.decode(base64Decode('QVEuQWI4Uk42S1F5UkNpaGVYcDhYbU9QbmRlblMwSlhsY0c1SUM1MnZzMjJ2Q0tXZm41blE='));
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$apiKey',
      );
      const prompt =
          'Analisis foto wajah pengguna dari kamera ini. '
          'Apakah ada wajah? Dan apa ekspresi emosinya (Senang / Sedih / Biasa / Cemas / Lelah)? '
          'PANDUAN PENTING: '
          '- Jika pengguna tampak murung, manyun, cemberut, tidak tersenyum, atau menatap sendu, pilih "Sedih". '
          '- Jika pengguna tersenyum atau tertawa, pilih "Senang". '
          '- Jika rileks/biasa, pilih "Biasa". '
          'Balas HANYA JSON satu baris: {"face_detected": true, "emotion": "Sedih", "emoji": "😢"}';

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ]
      };

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        final cleanText = text.toString().trim();
        final startIdx = cleanText.indexOf('{');
        final endIdx = cleanText.lastIndexOf('}');
        if (startIdx != -1 && endIdx != -1) {
          final jsonStr = cleanText.substring(startIdx, endIdx + 1);
          return jsonDecode(jsonStr);
        }
      }
    } catch (e) {
      debugPrint("Direct Gemini Vision fallback error: $e");
    }
    return null;
  }

  void _handleProactiveAiReaction(String emotion) {
    // Hanya bereaksi jika AI sedang standby / mendengarkan
    if (_statusIndex != 0) return;
    if (_showTextInput) return;

    final now = DateTime.now();
    // Cooldown 25 detik agar AI tanggap namun tetap nyaman didengar
    if (_lastProactiveRemarkTime != null &&
        now.difference(_lastProactiveRemarkTime!).inSeconds < 25) {
      return;
    }

    if (emotion == 'Sedih') {
      _consecutiveSadCount++;
      // Terdeteksi sedih / murung / manyun (segera respons pada siklus 1 atau 2)
      if (_consecutiveSadCount >= 1) {
        _consecutiveSadCount = 0;
        _lastProactiveRemarkTime = now;
        _lastTriggeredEmotion = 'Sedih';

        final sadRemarks = [
          'Kak, aku perhatikan raut wajahmu kelihatan agak sedih dan murung... Ada hal berat yang lagi mengganjal di pikiranmu? Mau cerita pelan-pelan ke aku?',
          'Tatap matamu kelihatan menyimpan beban ya... Nggak apa-apa, tumpahin aja kalau mau cerita. Aku di sini setia mendengarkanmu.',
          'Aku melihat wajahmu tampak kurang bersemangat dan sayu. Kamu sudah luar biasa bertahan sejauh ini, mau cerita apa yang sedang terjadi?',
        ];
        final remark = (sadRemarks..shuffle()).first;
        _triggerAiProactiveSpeech(remark);
      }
    } else if (emotion == 'Senang') {
      if (_lastTriggeredEmotion == 'Sedih') {
        _consecutiveSadCount = 0;
        _lastTriggeredEmotion = 'Senang';
        _lastProactiveRemarkTime = now;

        final happyRemarks = [
          'Nah, begitu dong tersenyum! Senyummu manis banget, rasanya auramu langsung lebih cerah dan hangat.',
          'Senang banget deh lihat senyummu barusan! Semoga perasaanmu semakin lega dan damai ya.',
        ];
        final remark = (happyRemarks..shuffle()).first;
        _triggerAiProactiveSpeech(remark);
      } else {
        _consecutiveSadCount = 0;
      }
    } else if (emotion == 'Lelah') {
      _consecutiveSadCount = 0;
      if (_lastTriggeredEmotion != 'Lelah') {
        _lastProactiveRemarkTime = now;
        _lastTriggeredEmotion = 'Lelah';
        _triggerAiProactiveSpeech(
          'Matamu kelihatan agak lelah dan mengantuk... Hari ini kegiatannya padat banget ya? Jangan lupa istirahat yang cukup ya.',
        );
      }
    } else {
      _consecutiveSadCount = 0;
    }
  }

  void _triggerAiProactiveSpeech(String speechText) {
    if (!mounted) return;
    setState(() {
      _chat.add(_ChatLine(isAi: true, text: speechText));
      _statusIndex = 2; // AI masuk status Berbicara
    });
    _scrollToBottom();
    _waveAnim.repeat(reverse: true);

    if (_ttsInitialized) {
      _speak(speechText);
    } else {
      final duration = Duration(milliseconds: math.max(2500, speechText.length * 60));
      Timer(duration, () {
        if (!mounted) return;
        setState(() {
          _statusIndex = 0; // Kembali mendengarkan
        });
        _waveAnim.stop();
        _startListening();
      });
    }
  }

  void _toggleCamera() async {
    if (_cameraController == null) return;
    try {
      if (_cameraOn) {
        await _cameraController!.pausePreview();
        _stopEmotionDetection();
        setState(() {
          _cameraOn = false;
          _currentEmotion = 'Kamera Mati';
          _currentEmotionEmoji = '📷';
        });
      } else {
        await _cameraController!.resumePreview();
        setState(() {
          _cameraOn = true;
          _currentEmotion = 'Mendeteksi...';
          _currentEmotionEmoji = '🔍';
        });
        _startEmotionDetection();
      }
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
    _emotionTimer?.cancel();
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
    final userMessages = _chat.where((m) => !m.isAi).toList();

    // Jika belum ada pesan dari user tapi kamera merekam ekspresi emosi
    if (userMessages.isEmpty) {
      if (_totalSadFrames > 0 || _lastTriggeredEmotion == 'Sedih') {
        return {
          'primaryMood': 'Murung / Sedih',
          'emoji': '😢',
          'moodAbbr': 'Sd',
          'accuracy': '85%',
          'observations': [
            'Kamera AI mendeteksi ekspresi wajahmu tampak murung dan sedih selama sesi.',
            'Tatap mata dan raut wajah menunjukkan beban perasaan yang sedang kamu simpan.',
            'Meskipun belum sempat banyak bercerita dengan kata-kata, SoulTalk peka mendampingimu.',
          ],
        };
      } else if (_totalHappyFrames > 0) {
        return {
          'primaryMood': 'Cukup Tenang & Bahagia',
          'emoji': '😊',
          'moodAbbr': 'Bg',
          'accuracy': '82%',
          'observations': [
            'Kamera AI mendeteksi senyuman hangat dari raut wajahmu selama panggilan video.',
            'Aura dan ekspresi wajah tampak relaks dan menyambut dengan positif.',
            'Pertahankan suasana hati yang ceria dan positif ini ya!',
          ],
        };
      } else if (_totalNeutralFrames > 0) {
        return {
          'primaryMood': 'Biasa / Reflektif',
          'emoji': '🙂',
          'moodAbbr': 'Nt',
          'accuracy': '78%',
          'observations': [
            'Raut wajahmu tampak tenang dan sedang berefleksi selama sesi panggilan.',
            'Meskipun banyak menyimak dalam diam, kehadiranmu sangat dihargai.',
            'Jangan ragu untuk berbagi cerita di sesi berikutnya saat sudah siap.',
          ],
        };
      }

      return {
        'primaryMood': 'Belum Teranalisis',
        'emoji': '😐',
        'moodAbbr': '--',
        'accuracy': '0%',
        'observations': [
          'Sesi panggilan terlalu singkat atau belum ada obrolan yang terekam.',
          'SoulTalk belum bisa menganalisis suasana hatimu karena kamu belum sempat bercerita.',
          'Di sesi berikutnya, silakan bercerita lewat suara atau gunakan tombol Ketik ya!',
        ],
      };
    }

    int stressCount = 0;
    int anxietyCount = 0;
    int sadnessCount = 0;
    int happyCount = 0;

    // Bobot emosi dari rekaman kamera visual
    if (_totalSadFrames > 2) sadnessCount += (_totalSadFrames ~/ 2);
    if (_totalHappyFrames > 2) happyCount += (_totalHappyFrames ~/ 2);

    for (final line in userMessages) {
      final text = line.text.toLowerCase();
      if (text.contains('stres') || text.contains('lelah') || text.contains('kerja') || text.contains('capek') || text.contains('pusing')) {
        stressCount++;
      }
      if (text.contains('cemas') || text.contains('takut') || text.contains('panik') || text.contains('khawatir') || text.contains('was-was')) {
        anxietyCount++;
      }
      if (text.contains('sedih') || text.contains('kecewa') || text.contains('nangis') || text.contains('hancur') || text.contains('galau')) {
        sadnessCount++;
      }
      if (text.contains('senang') || text.contains('bahagia') || text.contains('lega') || text.contains('gembira') || text.contains('syukur')) {
        happyCount++;
      }
    }

    final observations = <String>[];
    String primaryMood;
    String emoji;
    String moodAbbr;
    String accuracy;

    if (stressCount >= anxietyCount && stressCount >= sadnessCount && stressCount >= happyCount && stressCount > 0) {
      primaryMood = 'Sedikit Lelah';
      emoji = '😔';
      moodAbbr = 'St';
      accuracy = '85%';
      observations.addAll([
        'Pikiranmu terdeteksi sedang mengalami kelelahan mental yang cukup terasa.',
        'Beban utamamu saat ini terpantau berasal dari tekanan aktivitas atau pekerjaan.',
        'Meskipun lelah, kamu luar biasa karena tetap tenang dan stabil saat bercerita.',
      ]);
    } else if (anxietyCount >= stressCount && anxietyCount >= sadnessCount && anxietyCount >= happyCount && anxietyCount > 0) {
      primaryMood = 'Cemas';
      emoji = '😰';
      moodAbbr = 'Cm';
      accuracy = '78%';
      observations.addAll([
        'Terdeteksi adanya tingkat kekhawatiran yang cukup intens dalam pikiranmu.',
        'Kecemasan ini memicu respons tubuh berupa ketegangan otot dan pernapasan pendek.',
        'Kamu sangat hebat karena berhasil mengekspresikan kekhawatiran ini dengan runtut.',
      ]);
    } else if (sadnessCount >= stressCount && sadnessCount >= anxietyCount && sadnessCount >= happyCount && sadnessCount > 0) {
      primaryMood = 'Sedih';
      emoji = '😢';
      moodAbbr = 'Sd';
      accuracy = '82%';
      observations.addAll([
        'Terlihat ada kesedihan mendalam yang sedang kamu simpan dalam hatimu.',
        'Meluapkan emosi sedih adalah hal yang baik dan wajar untuk kesehatan mental.',
        'Terima kasih sudah berani membuka diri. Percayalah, masa sulit ini akan berlalu.',
      ]);
    } else if (happyCount > 0) {
      primaryMood = 'Senang';
      emoji = '😊';
      moodAbbr = 'Bh';
      accuracy = '88%';
      observations.addAll([
        'Energi positif dan suasana hati yang cerah terpancar dari ceritamu hari ini.',
        'Kamu berada dalam ritme emosi yang sangat sehat dan berenergi.',
        'Pertahankan momen bahagia ini dan bagikan energimu kepada orang-orang terdekat.',
      ]);
    } else {
      primaryMood = 'Tenang';
      emoji = '🙂';
      moodAbbr = 'Te';
      accuracy = '80%';
      observations.addAll([
        'Suasana hatimu hari ini terpantau tenang, damai, dan relatif stabil.',
        'Tidak terdeteksi adanya tekanan stres atau kecemasan yang berlebihan dari obrolanmu.',
        'Pertahankan ketenangan pikiran ini dengan terus menjaga keseimbangan aktivitasmu.',
      ]);
    }

    if (_totalSadFrames > 3 && _totalSadFrames > _totalHappyFrames) {
      observations.add('Kamera AI mendeteksi raut wajahmu sempat tampak sedih atau menahan beban emosional.');
    } else if (_totalHappyFrames > 3) {
      observations.add('Kamera AI mencatat kamu sempat tersenyum beberapa kali selama sesi ini.');
    } else if (_totalNeutralFrames > 5) {
      observations.add('Ekspresi wajahmu terpantau tenang dan stabil sepanjang panggilan.');
    }

    return {
      'primaryMood': primaryMood,
      'emoji': emoji,
      'moodAbbr': moodAbbr,
      'accuracy': accuracy,
      'observations': observations,
    };
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
                // Avatar dan status badge ditampilkan rapi saat keyboard tertutup tanpa clipping
                if (!keyboardOpen) ...[
                  const SizedBox(height: 10),
                  _buildAiAvatar(),
                  const SizedBox(height: 14),
                  _buildStatusBadge(),
                  const SizedBox(height: 6),
                ],

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Live badge - compact & responsive agar tidak pernah overflow
          _GlassChip(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _orbGlow,
                  builder: (_, __) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _VColors.statusListen,
                      boxShadow: [
                        BoxShadow(
                          color: _VColors.statusListen
                              .withValues(alpha: (1.0 - _orbGlow.value) * 0.9),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SESI AKTIF  $_formattedTime',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Nama app
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
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
                    color: Colors.white, size: 13),
              ),
              const SizedBox(width: 6),
              const Text(
                'SoulTalk AI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
    return GestureDetector(
      onTap: () {
        if (_statusIndex == 0 && !_muted && !_isListening) {
          _startListening();
        }
      },
      child: AnimatedBuilder(
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
    ),
  );
}

  // ─────────────────────────────────────────────
  //  Badge status AI
  // ─────────────────────────────────────────────
  Widget _buildStatusBadge() {
    String badgeText;
    if (_statusIndex == 0) {
      badgeText = _isListening ? '🎤  Mendengarkan...' : '👂  Siap Mendengar';
    } else {
      badgeText = '${_statusIcons[_statusIndex]}  ${_statuses[_statusIndex]}';
    }

    return FadeTransition(
      opacity: _statusAnim,
      child: GestureDetector(
        onTap: () {
          if (_statusIndex == 0 && !_muted) {
            _startListening();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey('$_statusIndex-$_isListening'),
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
                if (_isListening || _statusIndex != 0)
                  const _PulsingDots(color: Colors.white)
                else
                  const Icon(Icons.touch_app_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  badgeText,
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
                    minHeight: keyboardOpen ? 120 : 160,
                    maxHeight: keyboardOpen ? 320 : 260,
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
      width: 96,
      height: 128,
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

            // Live Emotion Badge (atas tengah)
            if (_cameraOn && _isCameraInitialized)
              Positioned(
                top: 5,
                left: 4,
                right: 4,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentEmotion == 'Sedih'
                            ? const Color(0xFFEF5350)
                            : (_currentEmotion == 'Senang'
                                ? const Color(0xFF66BB6A)
                                : Colors.white24),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentEmotionEmoji,
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _currentEmotion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _currentEmotion == 'Sedih'
                                  ? const Color(0xFFFFCDD2)
                                  : (_currentEmotion == 'Senang'
                                      ? const Color(0xFFC8E6C9)
                                      : Colors.white),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              icon: _muted
                  ? Icons.mic_off_rounded
                  : (_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
              label: _muted ? 'Bisu' : (_isListening ? 'Mendengar' : 'Bicara'),
              active: !_muted,
              onTap: () {
                if (_muted) {
                  setState(() => _muted = false);
                  if (_statusIndex == 0) _startListening();
                } else {
                  if (!_isListening && _statusIndex == 0) {
                    _startListening();
                  } else {
                    setState(() => _muted = true);
                    _stopListening();
                  }
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
    final clean = input.trim().toLowerCase();
    if (clean == 'hmm' || clean == 'hm' || clean == 'm' || clean == 'em' || clean == 'ehm') {
      return 'Ada yang lagi kamu renungkan atau rasakan? Ceritakan saja pelan-pelan ya, aku setia mendengarkan kok.';
    }

    if (ApiHelper.token == null) {
      return _getAiResponse(input);
    }
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/chat');
      final body = jsonEncode({
        'message': input,
        'current_emotion': _currentEmotion,
      });
      final res = await http.post(
        url,
        headers: ApiHelper.headers(),
        body: body,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['reply'];
        if (reply != null && reply.toString().trim().isNotEmpty) {
          return reply.toString().trim();
        }
        return _getAiResponse(input);
      } else if (res.statusCode == 403) {
        final data = jsonDecode(res.body);
        final limitMsg = data['detail'] ?? 'Kuota harian Anda telah habis.';
        _showQuotaLimitDialog(limitMsg);
        return limitMsg;
      } else {
        return _getAiResponse(input);
      }
    } catch (e) {
      debugPrint('Chat API Error: $e');
      return _getAiResponse(input);
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
      return 'Aku mendengar betapa berat dan menyakitkannya situasi yang sedang kamu lalui saat ini. Sebagai teman AI, aku tidak bisa memberikan perawatan medis atau menggantikan bantuan profesional. Keselamatanmu sangat berharga. Tolong hubungi layanan darurat nasional di 119, hubungi keluarga atau teman dekat, atau jangkau hotline krisis terdekat segera. Mohon tetap aman, ya.';
    }
    if (clean.contains('halo') || clean.contains('hai') || clean.contains('pagi') || clean.contains('siang') || clean.contains('malam') || clean.contains('assalamu')) {
      return 'Halo juga! Senang sekali bisa tersambung denganmu hari ini. Bagaimana kabarmu? Aku siap mendengarkan apa pun yang ingin kamu ceritakan.';
    }
    if (clean.contains('terima kasih') || clean.contains('makasih') || clean.contains('thanks')) {
      return 'Sama-sama! Terima kasih banyak sudah mau berbagi cerita denganku. Aku selalu ada di sini kapan pun kamu butuh teman bicara.';
    }
    if (clean.contains('senang') || clean.contains('bahagia') || clean.contains('lega') || clean.contains('syukur') || clean.contains('alhamdulillah')) {
      return 'Wah, senang sekali mendengarnya! Energi positifmu terasa menular. Boleh ceritakan apa yang membuat hatimu merasa begitu bahagia hari ini?';
    }
    if (clean.contains('stres') || clean.contains('lelah') || clean.contains('kerja') || clean.contains('capek') || clean.contains('pusing')) {
      return 'Lagi capek banget ya? Istirahat dulu sejenak gih, jangan terlalu memaksakan diri. Apa yang bikin terasa paling berat hari ini?';
    }
    if (clean.contains('cemas') || clean.contains('takut') || clean.contains('panik') || clean.contains('khawatir')) {
      return 'Tarik napas dulu pelan-pelan... Hembuskan perlahan. Nggak apa-apa, kamu aman sekarang. Aku ada di sini mendampingimu.';
    }
    if (clean.contains('sedih') || clean.contains('kecewa') || clean.contains('nangis') || clean.contains('hancur') || clean.contains('galau')) {
      return 'Sedih atau ingin menangis itu wajar kok, jangan ditahan kalau ingin meluapkannya. Mau bercerita sekarang atau ingin ditemani dalam hening dulu?';
    }
    return 'Iya, aku mendengarkanmu dengan baik. Boleh ceritakan lebih lanjut?';
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
