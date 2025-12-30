import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;
  bool _acceptTerms = false;

  // --- ŞİFRE GÜCÜ İÇİN DEĞİŞKENLER ---
  double _passwordStrength = 0.0;
  String _strengthText = "";
  Color _strengthColor = Colors.grey;

  String? _selectedDepartment;

  final List<String> _departments = [
    'Bilgisayar Mühendisliği',
    'Elektrik-Elektronik Mühendisliği',
    'Makine Mühendisliği',
    'İnşaat Mühendisliği',
    'Endüstri Mühendisliği',
    'Tıp Fakültesi',
    'Hukuk Fakültesi',
    'İktisadi ve İdari Bilimler',
    'Fen Fakültesi',
    'Eğitim Fakültesi',
    'İlahiyat Fakültesi',
    'Teknik Arıza',
    'Sağlık',
    'Güvenlik',
    'Çevre/Temizlik',
    'Kayıp-Buluntu',
    'Genel',
    'Diğer',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- KULLANIM KOŞULLARI PENCERESİ ---
  void _showTermsAndPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "Kullanım Koşulları ve Gizlilik Politikası",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // MADDE 1
                      Text(
                        "1. Giriş",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Atatürk Üniversitesi Teknik Destek Sistemi'ne hoş geldiniz. Bu uygulamayı kullanarak aşağıdaki şartları kabul etmiş sayılırsınız.",
                        style: TextStyle(color: Colors.black87, height: 1.5),
                      ),
                      SizedBox(height: 16),

                      // MADDE 2 - DÜZELTİLEN KISIM
                      Text(
                        "2. Veri Gizliliği ve Güvenliği",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Kayıt sırasında sağladığınız kişisel veriler (Ad Soyad, E-posta, Bölüm vb.) sadece üniversite içi teknik destek süreçlerinin yönetilmesi ve size geri bildirim yapılması amacıyla kullanılacaktır. Verileriniz, yasal zorunluluklar haricinde üçüncü şahıslarla asla paylaşılmayacaktır.",
                        style: TextStyle(color: Colors.black87, height: 1.5),
                      ),
                      SizedBox(height: 16),

                      // MADDE 3
                      Text(
                        "3. Kullanıcı Sorumlulukları",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "- Kullanıcılar, oluşturdukları bildirimlerin doğruluğundan sorumludur.\n- Sistemin amacı dışında kullanılması, asılsız ihbarlarda bulunulması yasaktır.\n- Hesabınızın güvenliğini sağlamak sizin sorumluluğunuzdadır, şifrenizi kimseyle paylaşmayın.",
                        style: TextStyle(color: Colors.black87, height: 1.5),
                      ),
                      SizedBox(height: 16),

                      // MADDE 4
                      Text(
                        "4. Bildirimler ve Fotoğraflar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Yüklediğiniz fotoğraflar sadece ilgili arızanın tespiti ve çözümü için yetkili personel tarafından görüntülenebilir. Genel ahlaka aykırı içerik paylaşımı hesabınızın kapatılmasına neden olabilir.",
                        style: TextStyle(color: Colors.black87, height: 1.5),
                      ),
                      SizedBox(height: 16),

                      // MADDE 5
                      Text(
                        "5. Değişiklikler",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Yönetim, bu koşulları önceden haber vermeksizin değiştirme hakkını saklı tutar.",
                        style: TextStyle(color: Colors.black87, height: 1.5),
                      ),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Okudum, Anladım",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ŞİFRE GÜCÜ HESAPLAMA
  void _checkPasswordStrength(String password) {
    double strength = 0.0;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _strengthText = "";
        _strengthColor = Colors.grey;
      });
      return;
    }
    bool hasMinLength = password.length >= 6;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );
    bool isLong = password.length >= 10;

    if (hasMinLength) strength += 0.2;
    if (hasUppercase) strength += 0.2;
    if (hasDigits) strength += 0.2;
    if (hasSpecialCharacters) strength += 0.2;
    if (isLong) strength += 0.2;

    String text;
    Color color;

    if (strength <= 0.2) {
      text = "Çok Zayıf";
      color = AppColors.error;
    } else if (strength <= 0.4) {
      text = "Zayıf";
      color = Colors.orangeAccent;
    } else if (strength <= 0.6) {
      text = "Orta";
      color = Colors.yellow[700]!;
    } else if (strength <= 0.8) {
      text = "İyi";
      color = Colors.lightGreen;
    } else {
      text = "Çok Güçlü";
      color = AppColors.success;
    }

    setState(() {
      _passwordStrength = strength;
      _strengthText = text;
      _strengthColor = color;
    });
  }

  String _getFriendlyErrorMessage(String error) {
    if (error.contains("User already registered"))
      return "Bu e-posta adresiyle zaten bir kayıt mevcut.";
    if (error.contains("Password should be at least"))
      return "Şifreniz çok kısa.";
    if (error.contains("Network request failed"))
      return "İnternet bağlantınızı kontrol edin.";
    return "Kayıt işlemi başarısız: $error";
  }

  // KAYIT FONKSİYONU
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    // 1. GÜVENLİK ADIMI: Okul Maili Kontrolü
    bool isValidDomain =
        email.endsWith('@atauni.edu.tr') ||
        email.endsWith('@ogr.atauni.edu.tr');

    if (!isValidDomain) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Sadece '@atauni.edu.tr' veya '@ogr.atauni.edu.tr' uzantılı kurumsal e-posta ile kayıt olabilirsiniz.",
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen kullanım koşullarını kabul edin."),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen bağlı olduğunuz birimi seçin."),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final department = _selectedDepartment!;

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'department': department},
      );

      final user = authResponse.user;
      if (user == null) throw 'Kullanıcı oluşturulamadı.';

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'E-posta Onayı Gerekli',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'Kaydınızı tamamlamak için '),
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' adresine gönderdiğimiz onay bağlantısına tıklayın.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Anladım, Giriş Yap',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (e is AuthException) message = e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(message)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.backgroundLight, Color(0xFFE5E7EB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Kayıt Ol",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Kampüs bildirim sistemine katılın",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 32),

                          _buildCustomInput(
                            label: "Ad Soyad",
                            hint: "Adınız Soyadınız",
                            controller: _nameController,
                            icon: Icons.person_outline,
                            inputType: TextInputType.name,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty)
                                return "Ad Soyad giriniz";
                              if (val.trim().split(' ').length < 2)
                                return "Lütfen ad ve soyad giriniz";
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          _buildCustomInput(
                            label: "E-posta",
                            hint: "ornek@atauni.edu.tr",
                            controller: _emailController,
                            icon: Icons.email_outlined,
                            inputType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return "E-posta giriniz";
                              if (!val.contains('@'))
                                return "Geçerli bir e-posta giriniz";
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          _buildDepartmentDropdown(),

                          const SizedBox(height: 20),

                          _buildCustomInput(
                            label: "Şifre",
                            hint: "En az 6 karakter",
                            controller: _passwordController,
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isPasswordObscure: _isPasswordObscure,
                            onTogglePassword: () {
                              setState(() {
                                _isPasswordObscure = !_isPasswordObscure;
                              });
                            },
                            onChanged: (val) => _checkPasswordStrength(val),
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return "Şifre giriniz";
                              if (val.length < 6)
                                return "Şifre en az 6 karakter olmalıdır";
                              return null;
                            },
                          ),

                          if (_passwordController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                left: 4,
                                right: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _passwordStrength,
                                      backgroundColor: Colors.grey[200],
                                      color: _strengthColor,
                                      minHeight: 5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _strengthText,
                                    style: TextStyle(
                                      color: _strengthColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          _buildCustomInput(
                            label: "Şifre Tekrar",
                            hint: "Şifrenizi tekrar girin",
                            controller: _confirmPasswordController,
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isPasswordObscure: _isConfirmPasswordObscure,
                            onTogglePassword: () {
                              setState(() {
                                _isConfirmPasswordObscure =
                                    !_isConfirmPasswordObscure;
                              });
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return "Şifreyi tekrar giriniz";
                              if (val != _passwordController.text)
                                return "Şifreler eşleşmiyor";
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _acceptTerms = !_acceptTerms;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _acceptTerms
                                        ? AppColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _acceptTerms
                                          ? AppColors.primary
                                          : AppColors.inputBorder,
                                      width: 2,
                                    ),
                                  ),
                                  child: _acceptTerms
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showTermsAndPrivacyPolicy,
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                            height: 1.4,
                                          ),
                                      children: [
                                        const TextSpan(
                                          text: "Şunları kabul ediyorum: ",
                                        ),
                                        const TextSpan(
                                          text:
                                              "Kullanım Koşulları ve Gizlilik Politikası",
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Kayıt Ol",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Zaten hesabınız var mı? ",
                        style: theme.textTheme.bodySmall,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Giriş Yapın",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "© 2025 ATADES Teknik Destek Sistemi",
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Image.asset(
            'assets/images/logo/Ataturkuni_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.handyman,
                color: AppColors.primary,
                size: 80,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Birim",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          hint: Text(
            "Biriminizi seçin",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.business_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.textSecondary,
          ),
          isExpanded: true,
          items: _departments.map((String department) {
            return DropdownMenuItem<String>(
              value: department,
              child: Text(
                department,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedDepartment = newValue;
            });
          },
          validator: (val) {
            if (val == null || val.isEmpty) return "Birim seçiniz";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCustomInput({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool isPasswordObscure = true,
    VoidCallback? onTogglePassword,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && isPasswordObscure,
          keyboardType: inputType,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            suffixIcon: isPassword && onTogglePassword != null
                ? IconButton(
                    icon: Icon(
                      isPasswordObscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator:
              validator ??
              (val) {
                if (val == null || val.isEmpty) return "$label giriniz";
                return null;
              },
        ),
      ],
    );
  }
}
