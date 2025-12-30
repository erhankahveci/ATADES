// lib/data/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Şu anki oturum açmış kullanıcı
  User? get currentUser => _client.auth.currentUser;

  // Kullanıcı oturum açık mı?
  bool get isAuthenticated => _client.auth.currentUser != null;

  // 1. Giriş Yap (Login)
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw e.toString();
    }
  }

  // 2. Kayıt Ol (Register)
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String department,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'department': department},
      );
    } catch (e) {
      throw e.toString();
    }
  }

  // 3. Çıkış Yap
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 4. Mevcut Kullanıcının Tam Profilini Getir (YENİ!)
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      if (currentUser == null) return null;

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Profil getirilemedi: $e');
    }
  }

  // 5. Kullanıcı Rolünü Getir (MEVCUT - Korundu)
  Future<String> getUserRole() async {
    if (currentUser == null) return 'User';

    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', currentUser!.id)
          .single();

      return response['role'] as String;
    } catch (e) {
      return 'User'; // Hata durumunda varsayılan
    }
  }

  // 6. Admin Kontrolü
  Future<bool> isAdmin() async {
    try {
      final role = await getUserRole();
      return role.trim().toLowerCase() == 'admin';
    } catch (e) {
      return false;
    }
  }

  // 7. Profili Güncelle
  Future<void> updateProfile({String? fullName, String? department}) async {
    try {
      if (currentUser == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (department != null) updates['department'] = department;

      if (updates.isNotEmpty) {
        await _client
            .from('profiles')
            .update(updates)
            .eq('id', currentUser!.id);
      }
    } catch (e) {
      throw Exception('Profil güncellenemedi: $e');
    }
  }

  // 8. Şifre Değiştir
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('Şifre değiştirilemedi: $e');
    }
  }

  // 9. Şifre Sıfırlama Maili Gönder
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Şifre sıfırlama maili gönderilemedi: $e');
    }
  }

  // 10. Tüm Kullanıcıları Listele (Admin)
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final isAdminUser = await isAdmin();
      if (!isAdminUser) {
        throw Exception('Bu işlem için yetkiniz yok');
      }

      final response = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Kullanıcılar getirilemedi: $e');
    }
  }

  // 11. Kullanıcı Rolünü Değiştir (Admin)
  Future<void> updateUserRole(String userId, String newRole) async {
    try {
      final isAdminUser = await isAdmin();
      if (!isAdminUser) {
        throw Exception('Bu işlem için yetkiniz yok');
      }

      await _client.from('profiles').update({'role': newRole}).eq('id', userId);
    } catch (e) {
      throw Exception('Rol güncellenemedi: $e');
    }
  }

  // 12. Mevcut Şifreyi Doğrula (Güvenlik İçin)
  Future<bool> validateCurrentPassword(String currentPassword) async {
    final user = currentUser;
    if (user == null || user.email == null) return false;

    try {
      // Arka planda mevcut bilgilerle tekrar giriş yapmayı dene
      await _client.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      return true; // Giriş başarılıysa şifre doğrudur
    } catch (e) {
      return false; // Hata verdiyse şifre yanlıştır
    }
  }

  // Auth state değişikliklerini dinle
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
