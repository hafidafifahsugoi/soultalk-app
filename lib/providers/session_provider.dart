import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../helper/database_helper.dart';
import '../helper/api_helper.dart';

class SessionItem {
  final String title;
  final String time;
  final String duration;
  final String moodAbbr;
  final String primaryMood;
  final String emoji;
  final String accuracy;
  final List<String> observations;
  final int messageCount;

  const SessionItem({
    required this.title,
    required this.time,
    required this.duration,
    required this.moodAbbr,
    required this.primaryMood,
    required this.emoji,
    required this.accuracy,
    required this.observations,
    required this.messageCount,
  });
}

class SessionProvider extends ChangeNotifier {
  final List<SessionItem> _sessions = [];
  final List<Map<String, dynamic>> _moodHistoryList = [];

  List<SessionItem> get sessions => List.unmodifiable(_sessions);
  List<Map<String, dynamic>> get moodHistoryList => List.unmodifiable(_moodHistoryList);

  SessionProvider() {
    _loadSessions();
    loadMoodHistory();
  }

  Future<void> loadMoodHistory() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final loaded = await dbHelper.getMoodRecords(7); // Ambil riwayat mood 7 hari terakhir
      _moodHistoryList.clear();
      _moodHistoryList.addAll(loaded.reversed); // Urutkan kronologis dari kiri ke kanan untuk grafik
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveMoodCheckIn(int moodIndex, String emoji, String label, {String? note}) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.insertOrUpdateMoodRecord(moodIndex, emoji, label, note);
      await loadMoodHistory();
    } catch (_) {}
  }

  Future<void> clearMoodHistory() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.clearAllMoodRecords();
      _moodHistoryList.clear();
      notifyListeners();
    } catch (_) {}
  }

  static const List<SessionItem> _defaultSessions = [
    SessionItem(
      title: 'Mengelola stres pekerjaan',
      time: 'Kemarin',
      duration: '12 mnt',
      moodAbbr: 'St',
      primaryMood: 'Sedikit Lelah',
      emoji: '😔',
      accuracy: '85%',
      observations: [
        'Pikiranmu terdeteksi sedang mengalami kelelahan mental yang cukup terasa.',
        'Beban utamamu saat ini terpantau berasal dari tekanan aktivitas pekerjaan.',
        'Meskipun lelah, kamu luar biasa karena tetap tenang dan stabil saat bercerita.',
      ],
      messageCount: 24,
    ),
    SessionItem(
      title: 'Tidur & rutinitas malam',
      time: '2 hari lalu',
      duration: '8 mnt',
      moodAbbr: 'Ti',
      primaryMood: 'Lega & Tenang',
      emoji: '😌',
      accuracy: '91%',
      observations: [
        'Kualitas rileksasi tubuhmu malam ini meningkat secara signifikan.',
        'Fokus pikiranmu beralih ke istirahat dan melepaskan ketegangan otot.',
        'Melanjutkan rutinitas ini akan membantumu tidur lebih nyenyak malam ini.',
      ],
      messageCount: 16,
    ),
    SessionItem(
      title: 'Merasa kewalahan',
      time: '4 hari lalu',
      duration: '15 mnt',
      moodAbbr: 'Kw',
      primaryMood: 'Kewalahan',
      emoji: '😟',
      accuracy: '70%',
      observations: [
        'Pikiranmu memproses banyak informasi sekaligus, memicu rasa kewalahan.',
        'Kurangi beban kognitif hari ini dengan memprioritaskan hanya satu hal kecil.',
        'Kamu sudah berusaha keras. Istirahatlah sejenak untuk memulihkan tenagamu.',
      ],
      messageCount: 30,
    ),
    SessionItem(
      title: 'Diskusi kecemasan masa depan',
      time: '1 minggu lalu',
      duration: '9 mnt',
      moodAbbr: 'Cm',
      primaryMood: 'Seimbang',
      emoji: '😊',
      accuracy: '78%',
      observations: [
        'Terdeteksi adanya sedikit kekhawatiran tentang rencana jangka panjang.',
        'Namun, kemampuan regulasi emosimu membantu menstabilkan kecemasan.',
        'Fokus pada hal-hal kecil yang bisa kamu kendalikan di saat ini.',
      ],
      messageCount: 12,
    ),
    SessionItem(
      title: 'Merayakan keberhasilan kecil',
      time: '2 minggu lalu',
      duration: '15 mnt',
      moodAbbr: 'Bh',
      primaryMood: 'Bahagia',
      emoji: '😄',
      accuracy: '95%',
      observations: [
        'Energi positif dan kepuasan diri terpancar sangat kuat hari ini.',
        'Apresiasi diri atas usaha keras yang telah membuahkan hasil manis.',
        'Pertahankan momen berharga ini untuk memicu produktivitas ke depan.',
      ],
      messageCount: 20,
    ),
  ];

  Future<void> _loadSessions() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      List<SessionItem> loaded = await dbHelper.getAllSessions();

      if (loaded.isEmpty) {
        // Seed default sessions on first load
        for (final session in _defaultSessions) {
          await dbHelper.insertSession(session);
        }
        loaded = await dbHelper.getAllSessions();
      }

      _sessions.clear();
      _sessions.addAll(loaded);
      notifyListeners();
    } catch (_) {}

    await fetchSessionsFromBackend();
  }

  Future<void> fetchSessionsFromBackend() async {
    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/sessions');
      final res = await http.get(url, headers: ApiHelper.headers());
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final List<SessionItem> loaded = data.map((json) {
          final List<dynamic> obsRaw = json['observations'] ?? [];
          final List<String> obsList = obsRaw.map((e) => e.toString()).toList();
          return SessionItem(
            title: json['title'] as String,
            time: json['time'] as String,
            duration: json['duration'] as String,
            moodAbbr: json['moodAbbr'] as String,
            primaryMood: json['primaryMood'] as String,
            emoji: json['emoji'] as String,
            accuracy: json['accuracy'] as String,
            observations: obsList,
            messageCount: json['messageCount'] as int,
          );
        }).toList();

        _sessions.clear();
        _sessions.addAll(loaded);
        notifyListeners();

        // Sync local SQLite cache to keep offline access healthy
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.clearAll();
        for (final session in loaded) {
          await dbHelper.insertSession(session);
        }
      }
    } catch (_) {}
  }

  Future<void> addSession(SessionItem item) async {
    _sessions.insert(0, item);
    notifyListeners();

    try {
      await DatabaseHelper.instance.insertSession(item);
    } catch (_) {}

    if (ApiHelper.token == null) return;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/sessions');
      final body = jsonEncode({
        'title': item.title,
        'time': item.time,
        'duration': item.duration,
        'moodAbbr': item.moodAbbr,
        'primaryMood': item.primaryMood,
        'emoji': item.emoji,
        'accuracy': item.accuracy,
        'observations': item.observations,
        'messageCount': item.messageCount,
      });
      await http.post(url, headers: ApiHelper.headers(), body: body);
    } catch (_) {}
  }

  Future<bool> clearSessions() async {
    _sessions.clear();
    notifyListeners();

    try {
      await DatabaseHelper.instance.clearAll();
    } catch (_) {}

    if (ApiHelper.token == null) return true;
    try {
      final url = Uri.parse('${ApiHelper.baseUrl}/api/sessions');
      final res = await http.delete(url, headers: ApiHelper.headers());
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
