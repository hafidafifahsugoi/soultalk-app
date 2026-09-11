import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/session_provider.dart';

/// Layanan untuk mengelola data di Cloud Firestore (profil, sesi chat, riwayat mood).
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Koleksi utama pengguna
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ==================== PROFIL PENGGUNA ====================

  /// Membuat dokumen profil pengguna baru saat pertama kali register.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    String phone = '',
    String bio = '',
  }) async {
    await _usersCollection.doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
      'avatarPath': 'assets/images/user-avatar.png',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Mengambil data profil pengguna berdasarkan UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Memperbarui informasi profil pengguna.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    final updateData = Map<String, dynamic>.from(data);
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    await _usersCollection.doc(uid).set(updateData, SetOptions(merge: true));
  }

  // ==================== SESI CHAT & MEDITASI ====================

  CollectionReference<Map<String, dynamic>> _userSessions(String uid) =>
      _usersCollection.doc(uid).collection('sessions');

  /// Menyimpan riwayat sesi percakapan/meditasi ke Cloud Firestore.
  Future<void> saveSession(String uid, SessionItem session) async {
    await _userSessions(uid).add({
      'title': session.title,
      'time': session.time,
      'duration': session.duration,
      'moodAbbr': session.moodAbbr,
      'primaryMood': session.primaryMood,
      'emoji': session.emoji,
      'accuracy': session.accuracy,
      'observations': session.observations,
      'messageCount': session.messageCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mengambil seluruh riwayat sesi pengguna dari Cloud Firestore.
  Future<List<SessionItem>> getSessions(String uid) async {
    try {
      final snapshot = await _userSessions(uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final List<dynamic> obsRaw = data['observations'] ?? [];
        final List<String> obsList =
            obsRaw.map((item) => item.toString()).toList();

        return SessionItem(
          title: data['title'] ?? '',
          time: data['time'] ?? '',
          duration: data['duration'] ?? '',
          moodAbbr: data['moodAbbr'] ?? '',
          primaryMood: data['primaryMood'] ?? '',
          emoji: data['emoji'] ?? '😊',
          accuracy: data['accuracy'] ?? '80%',
          observations: obsList,
          messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Menghapus seluruh sesi pengguna.
  Future<void> clearSessions(String uid) async {
    final snapshot = await _userSessions(uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ==================== RIWAYAT MOOD CHECK-IN ====================

  CollectionReference<Map<String, dynamic>> _userMoodRecords(String uid) =>
      _usersCollection.doc(uid).collection('mood_records');

  /// Menyimpan check-in mood harian ke Firestore.
  Future<void> saveMoodCheckIn(
    String uid,
    int moodIndex,
    String emoji,
    String label, {
    String? note,
  }) async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await _userMoodRecords(uid).doc(todayStr).set({
      'date': todayStr,
      'moodIndex': moodIndex,
      'emoji': emoji,
      'label': label,
      'note': note ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Mengambil riwayat mood untuk grafik harian.
  Future<List<Map<String, dynamic>>> getMoodRecords(String uid, int limit) async {
    try {
      final snapshot = await _userMoodRecords(uid)
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Mengambil seluruh riwayat mood untuk kalender bulanan.
  Future<List<Map<String, dynamic>>> getAllMoodRecords(String uid) async {
    try {
      final snapshot = await _userMoodRecords(uid)
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Menghapus riwayat mood pengguna.
  Future<void> clearMoodRecords(String uid) async {
    final snapshot = await _userMoodRecords(uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
