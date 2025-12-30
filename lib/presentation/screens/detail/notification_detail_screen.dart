import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

// Harita ekranina yonlendirmek icin kullanilacak arguman sinifi
class MapNavigationArgs {
  final double latitude;
  final double longitude;
  final String faultId;

  MapNavigationArgs({
    required this.latitude,
    required this.longitude,
    required this.faultId,
  });
}

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> faultData;

  const NotificationDetailScreen({super.key, required this.faultData});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isAdmin = false;
  bool _isUpdating = false;
  bool _isFollowing = false;

  // Yerel degiskenler
  late String _currentStatus;
  late String _currentDescription;

  // Bildirimi gonderen kullanicinin bilgileri
  Map<String, dynamic>? _senderProfile;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.faultData['status'] ?? 'Açık';
    _currentDescription = widget.faultData['description'] ?? '';
    _checkUserRoleAndFollowStatus();
  }

  Future<void> _checkUserRoleAndFollowStatus() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      // Admin kontrolu
      final bool isAdminUser = (profile['role'] == 'admin');

      // Takip durumu kontrolu
      final followRes = await _supabase
          .from('follows')
          .select()
          .eq('user_id', userId)
          .eq('fault_id', widget.faultData['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isAdmin = isAdminUser;
          _isFollowing = (followRes != null);
        });

        // Eger kullanici admin ise, bildirimi gonderen kisinin bilgilerini cek
        if (isAdminUser) {
          _fetchSenderProfile();
        }
      }
    } catch (e) {
      debugPrint('Rol veya takip kontrol hatasi: $e');
    }
  }

  // Gonderen kisinin bilgilerini (Ad Soyad, Birim, Tel, E-posta) ceken fonksiyon
  Future<void> _fetchSenderProfile() async {
    try {
      // Once faults tablosundaki user_id bilgisini aliyoruz
      final senderId = widget.faultData['user_id'];

      if (senderId == null) {
        setState(
          () => _profileError = "Bu bildirimin kullanıcı ID bilgisi yok.",
        );
        return;
      }

      // Profili cekiyoruz, burada department (birim) bilgisini de istiyoruz
      final profile = await _supabase
          .from('profiles')
          .select('full_name, email, department')
          .eq('id', senderId)
          .single();

      if (mounted) {
        setState(() {
          _senderProfile = profile;
          _profileError = null; // Hata yoksa temizle
        });
      }
    } catch (e) {
      debugPrint('Profil cekme hatasi: $e');
      if (mounted) {
        setState(() {
          // Ekrana basmak icin hatayi kaydediyoruz
          _profileError = "Kullanıcı bilgisi çekilemedi.\nSebep: $e";
        });
      }
    }
  }

  // Takip etme veya takibi birakma islemi
  Future<void> _toggleFollow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isUpdating = true);
    try {
      if (_isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('user_id', userId)
            .eq('fault_id', widget.faultData['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Takipten çıkıldı"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await _supabase.from('follows').insert({
          'user_id': userId,
          'fault_id': widget.faultData['id'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Arıza takip ediliyor"),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
      if (mounted) setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // Durum guncelleme islemi (Sadece admin)
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await _supabase
          .from('faults')
          .update({'status': newStatus})
          .eq('id', widget.faultData['id']);
      if (mounted) {
        setState(() => _currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Durum güncellendi: $newStatus"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Güncelleme hatası")));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // Aciklama duzenleme penceresi (Sadece admin)
  Future<void> _editDescription() async {
    final TextEditingController controller = TextEditingController(
      text: _currentDescription,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Açıklamayı Düzenle",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: "Yeni açıklamayı buraya girin...",
            hintStyle: GoogleFonts.inter(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Dialogu kapat
              await _saveDescription(controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDescription(String newDescription) async {
    if (newDescription.trim() == _currentDescription) return;

    setState(() => _isUpdating = true);
    try {
      await _supabase
          .from('faults')
          .update({'description': newDescription})
          .eq('id', widget.faultData['id']);

      if (mounted) {
        setState(() => _currentDescription = newDescription);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Açıklama başarıyla güncellendi."),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Açıklama güncellenemedi."),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // Bildirimi KALICI OLARAK SILME islemi
  Future<void> _terminateFault() async {
    debugPrint("Silme fonksiyonu çağrıldı");
    debugPrint("Fault ID: ${widget.faultData['id']}");

    // 1. ÖZELLEŞTİRİLMİŞ ONAY PENCERESİ
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Bildirimi Sil?",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Bu bildirim kalıcı olarak silinecek ve geri alınamayacaktır.\n\nTüm veriler ve takip bilgileri kaybolacaktır. Devam etmek istiyor musunuz?",
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    debugPrint("Kullanıcı vazgeçti");
                    Navigator.pop(c, false);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    "Vazgeç",
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint("Kullanıcı onayladı");
                    Navigator.pop(c, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Evet, Sil",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    debugPrint("Dialog sonucu: $confirm");

    if (confirm != true) {
      debugPrint("Onay alınamadı, işlem iptal");
      return;
    }

    debugPrint("Veritabanı silme işlemi başlıyor...");
    setState(() => _isUpdating = true);

    try {
      // ADIM 1: Önce follows tablosundaki takip kayıtlarını sil
      debugPrint("Takip kayıtları siliniyor...");
      await _supabase
          .from('follows')
          .delete()
          .eq('fault_id', widget.faultData['id']);

      debugPrint("Takip kayıtları silindi");

      // ADIM 2: Şimdi bildirimi sil
      debugPrint("Bildirim siliniyor...");
      final response = await _supabase
          .from('faults')
          .delete()
          .eq('id', widget.faultData['id'])
          .select();

      debugPrint("Bildirim silindi: $response");

      if (mounted) {
        // BAŞARI BİLDİRİMİ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Bildirim başarıyla silindi.",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        debugPrint("🔙 Sayfa kapatılıyor...");
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, {'deleted': true});
        }
      }
    } catch (e) {
      debugPrint("Silme Hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Silme hatası: $e"),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        debugPrint("🏁 İşlem tamamlandı");
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _launchGoogleMaps() async {
    final lat = widget.faultData['latitude'];
    final lng = widget.faultData['longitude'];
    if (lat != null && lng != null) {
      final url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }

  void _goToMapScreen() {
    Navigator.pop(context, {
      'action': 'goToMap',
      'faultData': widget.faultData,
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      String rawDate = dateString.replaceAll('Z', '').replaceAll('+00:00', '');
      final date = DateTime.parse(rawDate);
      return "${date.day}.${date.month}.${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Çözüldü':
        return const Color(0xFF4CAF50); // Yesil
      case 'İnceleniyor':
        return const Color(0xFFFF9800); // Turuncu
      case 'Sonlandırıldı':
        return const Color(0xFF757575); // Koyu Gri
      default:
        return const Color(0xFFE53935); // Kirmizi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: widget.faultData['photo_url'] != null
                  ? Image.network(
                      widget.faultData['photo_url'],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- DURUM VE TARIH ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_currentStatus),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentStatus.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(widget.faultData['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- KATEGORI VE BASLIK ---
                  Text(
                    widget.faultData['category'] ??
                        widget.faultData['department'] ??
                        'Genel',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.faultData['title'] ?? 'Başlıksız',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- ACIKLAMA ---
                  const Text(
                    "Açıklama",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentDescription.isNotEmpty
                        ? _currentDescription
                        : 'Açıklama bulunmuyor.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // KULLANICI ISLEMLERI (Admin Degilse)
                  if (!_isAdmin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdating ? null : _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: _isFollowing
                                    ? Colors.grey
                                    : AppColors.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              _isFollowing
                                  ? Icons.notifications_off
                                  : Icons.notifications_active,
                              color: _isFollowing
                                  ? Colors.grey
                                  : AppColors.primary,
                            ),
                            label: Text(
                              _isFollowing ? "Takibi Bırak" : "Takip Et",
                              style: TextStyle(
                                color: _isFollowing
                                    ? Colors.grey
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _goToMapScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text(
                              "Haritada Gör",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _launchGoogleMaps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.directions, color: Colors.white),
                        label: const Text(
                          "Yol Tarifi Al (Google Maps)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // YONETICI PANELI (Admin Ise)
                  if (_isAdmin) ...[
                    const Divider(height: 40, thickness: 1.5),
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "YÖNETİCİ PANELİ",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // KULLANICI BILGI KARTI
                    if (_profileError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _profileError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_senderProfile != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.account_circle,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Bildiren Kullanıcı",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildUserInfoRow(
                                    Icons.person_outline,
                                    "Ad Soyad",
                                    _senderProfile!['full_name'] ??
                                        'Belirtilmemiş',
                                  ),
                                  const Divider(height: 24),
                                  _buildUserInfoRow(
                                    Icons.work_outline,
                                    "Birim",
                                    _senderProfile!['department'] ??
                                        'Belirtilmemiş',
                                  ),
                                  const Divider(height: 24),
                                  _buildUserInfoRow(
                                    Icons.email_outlined,
                                    "E-posta",
                                    _senderProfile!['email'] ?? 'Belirtilmemiş',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),

                    _isUpdating
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              // 1. Durum Degistirme
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAdminButton(
                                      "İnceleniyor",
                                      Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildAdminButton(
                                      "Çözüldü",
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 2. Aciklama Duzenle
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _editDescription,
                                  icon: const Icon(Icons.edit),
                                  label: const Text("Açıklamayı Düzenle"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // 3. Harita / Yol Tarifi
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _goToMapScreen,
                                      icon: const Icon(Icons.map),
                                      label: const Text("Harita"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _launchGoogleMaps,
                                      icon: const Icon(Icons.directions),
                                      label: const Text("Yol Tarifi"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // 4. SONLANDIRMA BUTONU
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _terminateFault,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade100,
                                    foregroundColor: Colors.red.shade700,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                  ),
                                  label: const Text(
                                    "BİLDİRİMİ SİL",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kullanici bilgileri icin yardimci satir tasarimi
  Widget _buildUserInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Admin durum guncelleme buton tasarimi
  Widget _buildAdminButton(String status, Color color) {
    final bool isActive = _currentStatus != status;

    return ElevatedButton(
      onPressed: isActive ? () => _updateStatus(status) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isActive ? 2 : 0,
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
