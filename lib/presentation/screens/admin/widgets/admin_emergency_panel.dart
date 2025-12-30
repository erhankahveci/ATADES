import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class AdminEmergencyPanel extends StatefulWidget {
  const AdminEmergencyPanel({super.key});

  @override
  State<AdminEmergencyPanel> createState() => _AdminEmergencyPanelState();
}

class _AdminEmergencyPanelState extends State<AdminEmergencyPanel> {
  final _titleController = TextEditingController(text: "ACİL DURUM UYARISI");
  final _bodyController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // --- ACİL BİLDİRİM GÖNDERME FONKSİYONU ---
  Future<void> _sendEmergencyBroadcast() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir mesaj içeriği giriniz.")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Acil Durum Yayını"),
        content: const Text(
          "Bu bildirim kampüsteki TÜM KULLANICILARA gönderilecek. Onaylıyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("YAYINLA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. Adım: Tüm kullanıcıların ID'lerini çek
      final List<dynamic> profiles = await _supabase
          .from('profiles')
          .select('id');

      if (profiles.isEmpty) throw "Kullanıcı bulunamadı.";

      // 2. Adım: Her kullanıcı için bir bildirim nesnesi oluştur
      final List<Map<String, dynamic>> notifications = profiles.map((p) {
        return {
          'user_id': p['id'], // Bildirimin gideceği kişi
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // 3. Adım: Toplu Ekleme (Bulk Insert) Yap
      await _supabase.from('notifications').insert(notifications);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${profiles.length} kullanıcıya acil bildirim gönderildi.",
            ),
            backgroundColor: Colors.green,
          ),
        );
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata oluştu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5), // Hafif Kırmızı Arka Plan
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Acil Durum Yayını",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFC53030),
                    ),
                  ),
                  Text(
                    "Tüm kullanıcılara anlık bildirim",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Başlık Girişi
          TextField(
            controller: _titleController,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "Bildirim Başlığı",
              labelStyle: TextStyle(color: Colors.red.shade300),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              prefixIcon: const Icon(Icons.title, color: Colors.red, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Mesaj Girişi
          TextField(
            controller: _bodyController,
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.black87),
            decoration: InputDecoration(
              labelText: "Mesaj İçeriği",
              hintText:
                  "Örn: Kampüs girişinde gaz sızıntısı var, lütfen uzak durun.",
              labelStyle: TextStyle(color: Colors.red.shade300),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Gönder Butonu
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendEmergencyBroadcast,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC53030), // Koyu Kırmızı
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isLoading ? "GÖNDERİLİYOR..." : "TÜM KULLANICILARA YAYINLA",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
