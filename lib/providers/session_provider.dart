import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../helper/database_helper.dart';
import '../helper/api_helper.dart';
import '../services/firestore_service.dart';

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
  final FirestoreService _firestoreService = FirestoreService();

  List<SessionItem> get sessions => List.unmodifiable(_sessions);
  List<Map<String, dynamic>> get moodHistoryList => List.unmodifiable(_moodHistoryList);

  /// Total sesi pengguna secara real-time
  int get totalSessions => _sessions.length;

  /// Rata-rata indikator ketenangan pengguna (misal: '90%')
  String get averageCalm {
    if (_sessions.isEmpty) return '0%';
    double total = 0;
    int count = 0;
    for (final s in _sessions) {
      final match = RegExp(r'(\d+)').firstMatch(s.accuracy);
      if (match != null) {
        final val = double.tryParse(match.group(1)!);
        if (val != null) {
          total += val;
          count++;
          continue;
        }
      }
      if (s.moodAbbr == 'Te') {
        total += 90;
      } else if (s.moodAbbr == 'Bh') {
        total += 95;
      } else if (s.moodAbbr == 'Cm') {
        total += 40;
      } else if (s.moodAbbr == 'Sd') {
        total += 50;
      } else if (s.moodAbbr == 'Kw') {
        total += 45;
      } else {
        total += 75;
      }
      count++;
    }
    if (count == 0) return '0%';
    return '${(total / count).round()}%';
  }

  /// Total durasi seluruh sesi obrolan/meditasi secara presisi
  String get totalDurationFormatted {
    if (_sessions.isEmpty) return '0m';
    int totalSeconds = 0;
    for (final s in _sessions) {
      final minMatch = RegExp(r'(\d+)\s*(?:mnt|m|min)', caseSensitive: false).firstMatch(s.duration);
      if (minMatch != null) {
        totalSeconds += (int.tryParse(minMatch.group(1)!) ?? 0) * 60;
      }
      final secMatch = RegExp(r'(\d+)\s*(?:dtk|s|sec)', caseSensitive: false).firstMatch(s.duration);
      if (secMatch != null) {
        totalSeconds += int.tryParse(secMatch.group(1)!) ?? 0;
      }
    }
    if (totalSeconds == 0) return '1m';
    if (totalSeconds < 60) {
      return '$totalSeconds dtk';
    }
    final totalMins = (totalSeconds / 60).round();
    if (totalMins >= 60) {
      final hours = totalMins ~/ 60;
      final mins = totalMins % 60;
      return mins > 0 ? '${hours}j ${mins}m' : '${hours}j';
    }
    return '${totalMins}m';
  }

  /// Menghitung hari beruntun (streak) secara real-time
  int get streakDays {
    if (_sessions.isEmpty && _moodHistoryList.isEmpty) return 0;
    final Set<String> activeDates = {};
    for (final item in _moodHistoryList) {
      final d = item['date']?.toString();
      if (d != null && d.length >= 10) {
        activeDates.add(d.substring(0, 10));
      }
    }
    final today = DateTime.now();
    final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_sessions.isNotEmpty) {
      activeDates.add(todayStr);
    }
    int streak = 0;
    DateTime checkDate = today;
    final checkDateStr = '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
    if (!activeDates.contains(checkDateStr)) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      if (activeDates.contains(yesterdayStr)) {
        checkDate = yesterday;
      } else {
        return _sessions.isNotEmpty ? 1 : 0;
      }
    }
    while (true) {
      final dStr = '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (activeDates.contains(dStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak > 0 ? streak : (_sessions.isNotEmpty ? 1 : 0);
  }

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

    await loadMoodHistoryFromFirestore();
  }

  Future<void> loadMoodHistoryFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final records = await _firestoreService.getMoodRecords(user.uid, 7);
      if (records.isNotEmpty) {
        _moodHistoryList.clear();
        _moodHistoryList.addAll(records.reversed);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> saveMoodCheckIn(int moodIndex, String emoji, String label, {String? note}) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.insertOrUpdateMoodRecord(moodIndex, emoji, label, note);
      await loadMoodHistory();
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.saveMoodCheckIn(user.uid, moodIndex, emoji, label, note: note);
      } catch (_) {}
    }
  }

  /// Ambil rekaman suasana hati untuk bulan tertentu (lokal SQLite & fallback Firestore)
  Future<List<Map<String, dynamic>>> getMoodRecordsForMonth(int year, int month) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final local = await dbHelper.getMoodRecordsByMonth(year, month);
      if (local.isNotEmpty) return local;
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final monthStr = month.toString().padLeft(2, '0');
        final all = await _firestoreService.getAllMoodRecords(user.uid);
        return all.where((m) => (m['date'] as String? ?? '').startsWith('$year-$monthStr')).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Ambil semua rekaman suasana hati (untuk statistik / kalender)
  Future<List<Map<String, dynamic>>> getAllMoodRecords() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final local = await dbHelper.getAllMoodRecords();
      if (local.isNotEmpty) return local;
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        return await _firestoreService.getAllMoodRecords(user.uid);
      } catch (_) {}
    }
    return [];
  }

  Future<void> clearMoodHistory() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.clearAllMoodRecords();
      _moodHistoryList.clear();
      notifyListeners();
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.clearMoodRecords(user.uid);
      } catch (_) {}
    }
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

    await fetchSessionsFromFirestore();
    await fetchSessionsFromBackend();
  }

  /// Mengambil sesi percakapan/meditasi langsung dari Cloud Firestore
  Future<void> fetchSessionsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final loaded = await _firestoreService.getSessions(user.uid);
      if (loaded.isNotEmpty) {
        _sessions.clear();
        _sessions.addAll(loaded);
        notifyListeners();

        // Sync local SQLite cache
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.clearAll();
        for (final session in loaded) {
          await dbHelper.insertSession(session);
        }
      }
    } catch (_) {}
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

    // Simpan ke Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.saveSession(user.uid, item);
      } catch (_) {}
    }

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

    // Hapus dari Cloud Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestoreService.clearSessions(user.uid);
      } catch (_) {}
    }

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
