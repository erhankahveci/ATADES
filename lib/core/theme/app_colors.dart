import 'package:flutter/material.dart';

class AppColors {
  // --- Ana Marka Renkleri (React kodundan alındı) ---
  static const Color primary = Color(0xFF103669);
  static const Color primaryDark = Color(0xFF0D2B54);

  // --- EKLEME: Gradyan ve Modern Dokunuşlar İçin ---
  static const Color primaryAccent = Color(
    0xFF6366F1,
  ); // Profildeki modern mor/mavi gradyan için
  static const Color cardShadow = Color(
    0x0F000000,
  ); // Kartlar için çok hafif profesyonel gölge

  // React: style={{backgroundColor: '#a81e10'}}
  static const Color secondary = Color(0xFFA81E10);

  // --- Arka Plan Renkleri ---
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundDark = Color(0xFF121212);

  // --- EKLEME: Yüzey ve Ayırıcılar ---
  static const Color surface = Colors.white;
  static const Color divider = Color(
    0xFFF1F3F5,
  ); // Menü aralarındaki çok ince çizgiler için

  // --- Kart ve Yüzey Renkleri ---
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);

  // --- Metin ve İkon Renkleri ---
  static const Color textPrimary = Color(0xFF202B5D);
  static const Color textSecondary = Color(0xFF62718D);

  // --- EKLEME: Pasif metinler ---
  static const Color textHint = Color(
    0xFF9CA3AF,
  ); // "GÜVENLİK AYARLARI" gibi başlıklar için

  static const Color textWhite = Colors.white;

  // --- Input ve Border Renkleri ---
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color inputFocusBorder = primary;

  // --- EKLEME: Input Dolgusu ---
  static const Color inputFill = Color(
    0xFFF9FAFB,
  ); // Şifre değiştirme alanlarının iç dolgusu

  // --- Durum Renkleri ---
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color error = Color(0xFFD32F2F);
}
