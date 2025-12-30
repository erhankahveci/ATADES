class Validators {
  // E-posta Doğrulama
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'E-posta adresi gerekli';
    }
    // Basit Regex kontrolü
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Geçerli bir e-posta adresi giriniz';
    }
    return null;
  }

  // Şifre Doğrulama
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre gerekli';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    return null;
  }

  // Ad Soyad Doğrulama
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ad Soyad gerekli';
    }
    if (value.trim().split(' ').length < 2) {
      return 'Lütfen ad ve soyad giriniz';
    }
    return null;
  }

  // Boş Alan Kontrolü (Departman vb. için)
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName seçilmelidir';
    }
    return null;
  }
}
