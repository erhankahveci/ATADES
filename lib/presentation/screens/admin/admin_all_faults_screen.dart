// lib/presentation/screens/admin/admin_all_faults_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../detail/notification_detail_screen.dart';

class AdminAllFaultsScreen extends StatefulWidget {
  const AdminAllFaultsScreen({super.key});

  @override
  State<AdminAllFaultsScreen> createState() => _AdminAllFaultsScreenState();
}

class _AdminAllFaultsScreenState extends State<AdminAllFaultsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  // Stream ve Veri
  late Stream<List<Map<String, dynamic>>> _stream;

  // Filtre Değişkenleri
  String _searchQuery = '';
  String _selectedDepartment = 'Tümü';
  String _selectedStatus = 'Tümü';

  // Listeler
  final List<String> _departments = [
    'Tümü',
    'Teknik Arıza',
    'Sağlık',
    'Güvenlik',
    'Çevre/Temizlik',
    'Kayıp-Buluntu',
    'Diğer',
  ];

  final List<String> _statuses = ['Tümü', 'Açık', 'İnceleniyor', 'Çözüldü'];

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    // Admin olduğu için tüm veriyi en yeniden en eskiye doğru çekiyoruz
    _stream = _supabase
        .from('faults')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- YARDIMCI FONKSİYONLAR ---

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Açık':
        return AppColors.error;
      case 'İnceleniyor':
        return AppColors.warning;
      case 'Çözüldü':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sağlık':
        return Icons.local_hospital;
      case 'Güvenlik':
        return Icons.security;
      case 'Çevre/Temizlik':
        return Icons.cleaning_services;
      case 'Teknik Arıza':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return "";
    try {
      final date = DateTime.parse(timestamp).toLocal();
      return DateFormat('dd MMM HH:mm', 'tr').format(date);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "Tüm Bildirimler",
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // --- 1. ARAMA VE FİLTRE ALANI ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Arama Çubuğu
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Başlık veya açıklama ara...",
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),

                // Dropdown Filtreler (Yan Yana)
                Row(
                  children: [
                    // Birim Filtresi
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textSecondary,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (val) =>
                                setState(() => _selectedDepartment = val!),
                            items: _departments
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Durum Filtresi
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.filter_list,
                              color: AppColors.textSecondary,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged: (val) =>
                                setState(() => _selectedStatus = val!),
                            items: _statuses
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- 2. LİSTE ALANI ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allData = snapshot.data ?? [];

                // FİLTRELEME MANTIĞI
                final filteredData = allData.where((fault) {
                  final title = (fault['title'] ?? '').toString().toLowerCase();
                  final desc = (fault['description'] ?? '')
                      .toString()
                      .toLowerCase();
                  final category = fault['category'] ?? 'Diğer';
                  final status = fault['status'] ?? 'Açık';
                  final query = _searchQuery.toLowerCase();

                  // Arama Kontrolü
                  bool matchesSearch =
                      title.contains(query) || desc.contains(query);

                  // Birim Kontrolü
                  bool matchesDept =
                      _selectedDepartment == 'Tümü' ||
                      category == _selectedDepartment;

                  // Durum Kontrolü
                  bool matchesStatus =
                      _selectedStatus == 'Tümü' || status == _selectedStatus;

                  return matchesSearch && matchesDept && matchesStatus;
                }).toList();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Kayıt bulunamadı",
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sonuç Sayısı Göstergesi
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        "${filteredData.length} bildirim listeleniyor",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          return _buildAdminFaultCard(
                            context,
                            filteredData[index],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Yönetici İçin Özelleştirilmiş Kart
  Widget _buildAdminFaultCard(
    BuildContext context,
    Map<String, dynamic> fault,
  ) {
    final status = fault['status'] ?? 'Açık';
    final color = _getStatusColor(status);
    final category = fault['category'] ?? 'Genel';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationDetailScreen(faultData: fault),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol: Fotoğraf veya İkon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade100,
                  child: fault['photo_url'] != null
                      ? Image.network(
                          fault['photo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.broken_image,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : Icon(
                          _getCategoryIcon(category),
                          color: AppColors.primary,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Orta: Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fault['title'] ?? 'Başlıksız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(fault['created_at']),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Sağ: Durum Badge'i
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
