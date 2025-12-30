import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Fontlar için
import 'app_colors.dart';

class AppTheme {
  // AYDINLIK TEMA
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundLight,

    // Renk Şeması
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.cardLight,
      error: AppColors.error,
    ),

    // Metin Teması
    textTheme: TextTheme(
      headlineMedium: GoogleFonts.inter(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: GoogleFonts.inter(color: AppColors.textPrimary),
      bodySmall: GoogleFonts.inter(color: AppColors.textSecondary),
    ),

    // TextField Tasarımı - React formlarına benzesin diye
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      // Normal Kenarlık (#e5e7eb)
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // React: rounded-lg
        borderSide: const BorderSide(color: AppColors.inputBorder),
      ),
      // Tıklanınca Kenarlık (Primary Blue)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      // Hata Kenarlığı
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      // İkon ve Label renkleri
      prefixIconColor: AppColors.textSecondary,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
    ),

    // Buton Tasarımı (Giriş Yap butonu)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, // Lacivert
        foregroundColor: AppColors.textWhite, // Beyaz yazı
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        elevation: 4, // React: shadow-lg
      ),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: AppColors.secondary, // Kırmızı alt çizgi
          width: 2,
        ),
      ),
    ),
  );

  // --- KARANLIK TEMA (Gece Modu) ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.backgroundDark,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.cardDark,
    ),

    textTheme: TextTheme(
      headlineMedium: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: GoogleFonts.inter(color: Colors.grey[300]),
      bodySmall: GoogleFonts.inter(color: Colors.grey[500]),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardDark, // Koyu gri input içi
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      prefixIconColor: Colors.grey[400],
      labelStyle: TextStyle(color: Colors.grey[400]),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
