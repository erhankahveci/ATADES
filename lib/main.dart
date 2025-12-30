// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/change_password_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';

// Arka planda bildirim gelirse bu fonksiyon tetiklenir
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Arka plan mesajı alındı: ${message.messageId}");
}

Future<void> main() async {
  // Flutter motorunu başlatıyoruz
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Splash ekranını biz hazır olana kadar ekranda tutuyoruz
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // .env Dosyasını Yüklüyoruz

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Env dosyası yüklenemedi: $e");
    // .env dosyası yoksa uygulama çökmemeli ama Supabase çalışmayabilir.
  }

  // Türkçe tarih formatını yüklüyoruz
  try {
    await initializeDateFormatting('tr', null);
  } catch (e) {
    debugPrint("Tarih formatı yükleme hatası: $e");
  }

  // 5. Firebase servislerini başlatıyoruz
  await Firebase.initializeApp();

  // 6. Arka plan bildirim dinleyicisini kaydediyoruz
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 7. Supabase veritabanı bağlantısını başlatıyoruz
  // Artık AppConstants değerleri .env dosyasından çekiliyor.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Kullanıcıyı acil durum kanalına abone yap

  try {
    await FirebaseMessaging.instance.subscribeToTopic('emergency_channel');
    debugPrint("Acil durum kanalına abone olundu.");
  } catch (e) {
    debugPrint("Kanala abone olma hatası: $e");
  }

  // Eğer oturum bozuksa (Session var ama User yoksa) çıkış yaptırıyoruz
  try {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;
    if (session != null && user == null) {
      await Supabase.instance.client.auth.signOut();
    }
  } catch (e) {
    // Hata durumunda güvenli çıkış
    await Supabase.instance.client.auth.signOut();
  }

  // Bildirim izni istiyoruz ve token alıyoruz
  await _setupFCM();

  runApp(const MyApp());
}

// Kullanıcıdan bildirim izni ister ve token alır
Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint('Kullanıcı izni: ${settings.authorizationStatus}');

  // Eğer izin verildiyse token'ı alıp veritabanına kaydetmeyi deneriz
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    String? token = await messaging.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token"); // Test için log
      await _saveTokenToDatabase(token);
    }

    // Token değişirse yenisini kaydeder
    messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToDatabase(newToken);
    });
  }
}

// Token'ı veritabanındaki profiles tablosuna kaydeder
Future<void> _saveTokenToDatabase(String token) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    // Eğer kullanıcı giriş yapmamışsa kaydedemeyiz, çıkarız
    if (userId == null) return;

    await Supabase.instance.client
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', userId);

    debugPrint("Token veritabanına kaydedildi.");
  } catch (e) {
    debugPrint("Token kaydetme hatası: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Giriş çıkış işlemlerini dinleyen yapıyı kuruyoruz
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final session = data.session;

      // Kullanıcı giriş yaptıysa
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (session != null) {
          // Böylece kullanıcının bildirim token'ı kesinlikle veri tabanında olur
          FirebaseMessaging.instance.getToken().then((token) {
            if (token != null) _saveTokenToDatabase(token);
          });

          // Giriş yapınca da tekrar abone olmayı deneyebiliriz (garanti olsun diye)
          FirebaseMessaging.instance.subscribeToTopic('emergency_channel');
        }
      }

      // Çıkış yapılırsa giriş ekranına at
      if (event == AuthChangeEvent.signedOut) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }

      // Şifre sıfırlama isteği gelirse o ekrana yönlendir
      if (event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ATADES',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      // Başlangıçta Splash ekranını gösteriyoruz
      home: const SplashScreen(),
    );
  }
}
