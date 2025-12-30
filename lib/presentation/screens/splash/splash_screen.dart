// lib/presentation/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    //Sayfa yüklendiği an Native Splash'i kaldır.

    FlutterNativeSplash.remove();

    // 2. Animasyon Ayarları
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 1.5 saniye
    );

    // LOGO ANİMASYONU:
    // Native Splash'te logo zaten tam boyutta duruyor.
    // Flutter başladığında 1.0 (Normal) boyuttan başlayıp 1.15'e (Hafifçe Büyüme) gidecek.
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Yazılar sonradan yavaşça belirecek.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.4,
          1.0,
          curve: Curves.easeIn,
        ), // İlk %40'lık sürede yazı yok
      ),
    );

    _controller.forward();

    // 3. Kontrol ve Yönlendirme
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    // En az 2 saniye bekle ki animasyon görünsün (Keyifli bir geçiş için)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Oturum Kontrolü
    final session = Supabase.instance.client.auth.currentSession;

    // Yönlendirme (Fade efektiyle yumuşak geçiş)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            session != null ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ekran genişliğine göre logo boyutunu ayarla
    final double screenWidth = MediaQuery.of(context).size.width;
    // Native splash genelde ekranın belli bir oranıdır. %40 iyi bir başlangıç noktasıdır.
    // Eğer zıplama olursa bu oranı (0.4) biraz artırıp azaltarak deneyebilirsiniz.
    final double logoSize = screenWidth * 0.4;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO ---
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // Native Splash'te gölge yoksa buraya da koymayın.
                    ),
                    child: Image.asset(
                      'assets/images/logo/app_icon.png', // Logo yolunuz
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- YAZILAR (Sonradan Geliyor) ---
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        "ATADES",
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Kampüs Takip Sistemi",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
