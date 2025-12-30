// lib/presentation/screens/home/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/user_profile.dart';

// Sayfalar
import 'widgets/notification_list_view.dart';
import '../admin/admin_dashboard.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  UserProfile? _userProfile;
  int _selectedIndex = 0; // Varsayılan sekme: Akış (0)
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Haritaya veri taşımak için
  Map<String, dynamic>? _pendingMapFocusData;

  @override
  void initState() {
    super.initState();
    _initUserProfile();

    // Bildirim tıklamalarını dinle
    _setupFirebaseInteraction();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  // Bildirime tıklanınca çalışacak kod
  Future<void> _setupFirebaseInteraction() async {
    // 1. Uygulama KAPALIYKEN bildirime tıklanıp açılırsa:
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. Uygulama ARKA PLANDAYKEN bildirime tıklanıp öne gelirse:
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  // Yönlendirme Mantığı
  void _handleMessage(RemoteMessage message) {
    // Edge Function'dan gönderdiğimiz { "route": "/notifications" } verisi var mı?
    if (message.data['route'] == '/notifications') {
      // Önce açık olan ekstra pencereler varsa kapat
      Navigator.of(context).popUntil((route) => route.isFirst);

      if (mounted) {
        setState(() {
          // Sadece sekmeyi 2 yapıyoruz (Bildirimler sekmesi)
          _selectedIndex = 2;
        });

        // Geçiş animasyonunu tetikle
        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initUserProfile() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
        if (index != 1) _pendingMapFocusData = null;
      });
      _animationController.reset();
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleNavigationResult(Map<String, dynamic> result) {
    if (result['action'] == 'goToMap') {
      setState(() {
        _selectedIndex = 1;
        _pendingMapFocusData = result['faultData'];
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  Widget _buildAppBarTitle() {
    if (_selectedIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Arıza Akışı",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Kampüsteki güncel sorunlar ve çözümler",
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    String titleText = "";
    switch (_selectedIndex) {
      case 1:
        titleText = "Harita";
        break;
      case 2:
        titleText = "Bildirimler";
        break;
      case 3:
        titleText = (_userProfile?.isAdmin == true)
            ? "Yönetim Paneli"
            : "Profil";
        break;
      case 4:
        titleText = "Profil";
        break;
      default:
        titleText = "Arıza Takip";
    }

    return Text(
      titleText,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final isAdmin = _userProfile?.isAdmin ?? false;

    final List<_NavItem> navItems = [
      _NavItem(
        screen: NotificationListView(onMapAction: _handleNavigationResult),
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
        label: 'Akış',
      ),
      _NavItem(
        screen: MapScreen(initialFocusFault: _pendingMapFocusData),
        icon: Icons.map_rounded,
        activeIcon: Icons.map_rounded,
        label: 'Harita',
      ),
      _NavItem(
        screen: const NotificationsScreen(),
        icon: Icons.notifications_rounded,
        activeIcon: Icons.notifications_rounded,
        label: 'Bildirimler',
      ),
      if (isAdmin)
        _NavItem(
          screen: const AdminDashboard(),
          icon: Icons.admin_panel_settings_rounded,
          activeIcon: Icons.admin_panel_settings_rounded,
          label: 'Yönetim',
        ),
      _NavItem(
        screen: ProfileScreen(userProfile: _userProfile!),
        icon: Icons.person_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
      ),
    ];

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;
    Widget activeScreen = navItems[_selectedIndex].screen;

    // Harita sekmesinde miyiz kontrolü
    final bool isMapScreen = _selectedIndex == 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: isMapScreen
          ? _buildMapScreenWithFixedAppBar(activeScreen)
          : _buildNormalScreenWithScrollableAppBar(activeScreen),
      bottomNavigationBar: _buildAnimatedBottomBar(navItems),
    );
  }

  // Harita ekranı için SABİT AppBar
  Widget _buildMapScreenWithFixedAppBar(Widget screen) {
    return Column(
      children: [
        // Sabit AppBar
        Container(
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo/Ataturkuni_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.bolt, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Başlık
                  Text(
                    "Harita",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Harita içeriği
        Expanded(child: screen),
      ],
    );
  }

  // Diğer ekranlar için kaydıralabilir AppBar
  Widget _buildNormalScreenWithScrollableAppBar(Widget screen) {
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            forceElevated: innerBoxIsScrolled,
            pinned: false,
            floating: true,
            snap: true,
            centerTitle: false,
            toolbarHeight: 70,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 12, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo/Ataturkuni_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.bolt, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            leadingWidth: 64,
            title: _buildAppBarTitle(),
          ),
        ];
      },
      body: FadeTransition(opacity: _fadeAnimation, child: screen),
    );
  }

  Widget _buildAnimatedBottomBar(List<_NavItem> items) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final int index = items.indexOf(item);
          final bool isSelected = _selectedIndex == index;
          return InkWell(
            onTap: () => _onItemTapped(index),
            borderRadius: BorderRadius.circular(50),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? item.activeIcon : item.icon,
                    size: 24,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      width: isSelected ? null : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem({
    required this.screen,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
