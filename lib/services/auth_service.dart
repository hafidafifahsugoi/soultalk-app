import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// Layanan untuk mengelola autentikasi pengguna menggunakan Firebase Auth.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Mendapatkan user Firebase yang sedang aktif.
  User? get currentUser => _auth.currentUser;

  /// Stream perubahan status autentikasi.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Mendaftarkan pengguna baru dengan email dan kata sandi.
  Future<UserCredential> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String bio = '',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);

        // Buat profil pengguna di Firestore
        await _firestoreService.createUserProfile(
          uid: user.uid,
          name: name,
          email: email.trim(),
          phone: phone,
          bio: bio,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthErrorMessage(e);
    } catch (e) {
      throw 'Gagal mendaftar: ${e.toString()}';
    }
  }

  /// Masuk dengan email dan kata sandi.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthErrorMessage(e);
    } catch (e) {
      throw 'Gagal masuk: ${e.toString()}';
    }
  }

  /// Keluar dari sesi akun saat ini.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Mengirim email untuk reset kata sandi.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthErrorMessage(e);
    } catch (e) {
      throw 'Gagal mengirim email reset: ${e.toString()}';
    }
  }

  /// Mengubah kode error Firebase menjadi pesan bahasa Indonesia yang ramah pengguna.
  static String getReadableAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
        return 'Kata sandi salah. Silakan coba lagi.';
      case 'invalid-credential':
        return 'Email atau kata sandi tidak cocok. Silakan periksa kembali.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan gunakan email lain atau langsung masuk.';
      case 'invalid-email':
        return 'Format alamat email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'network-request-failed':
        return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan gagal. Silakan tunggu beberapa saat lagi.';
      case 'user-disabled':
        return 'Akun pengguna ini telah dinonaktifkan.';
      default:
        return e.message ?? 'Terjadi kesalahan autentikasi (${e.code}).';
    }
  }
}
