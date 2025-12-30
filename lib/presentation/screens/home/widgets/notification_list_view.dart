// lib/presentation/screens/home/widgets/notification_list_view.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../detail/notification_detail_screen.dart';

class NotificationListView extends StatefulWidget {
  final Function(Map<String, dynamic>)? onMapAction;

  const NotificationListView({super.key, this.onMapAction});

  @override
  State<NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<NotificationListView> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>>? _stream;
  Set<dynamic> _followedFaultIds = {};

  String _selectedFilter = 'Tümü';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showOnlyOpen = false;
  bool _showOnlyFollowed = false;
  bool _isAscending = false;

  bool _isAdmin = false;
  String? _adminDepartment;

  List<String> _categories = [
    'Tümü',
    'Teknik Arıza',
    'Sağlık',
    'Güvenlik',
    'Çevre/Temizlik',
    'Kayıp-Buluntu',
    'Diğer',
  ];

  final List<String> _allCategoriesList = [
    'Tümü',
    'Teknik Arıza',
    'Sağlık',
    'Güvenlik',
    'Çevre/Temizlik',
    'Kayıp-Buluntu',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _checkUserRoleAndDepartment();
    _fetchFollowedIds();
    _setupStream();
  }

  Future<void> _checkUserRoleAndDepartment() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await _supabase
          .from('profiles')
          .select('role, department')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _isAdmin = (response['role'] == 'admin');
          _adminDepartment = response['department'];

          if (_isAdmin &&
              _adminDepartment != null &&
              _adminDepartment != 'Genel' &&
              _adminDepartment != 'Tümü') {
            _categories = [_adminDepartment!];
            _selectedFilter = _adminDepartment!;
          } else {
            _categories = List.from(_allCategoriesList);
            _selectedFilter = 'Tümü';
          }
        });
      }
    } catch (e) {
      debugPrint('Rol kontrol hatasi: $e');
    }
  }

  void _setupStream() {
    setState(() {
      if (_isAdmin &&
          _adminDepartment != null &&
          _adminDepartment != 'Genel' &&
          _adminDepartment != 'Tümü') {
        _stream = _supabase
            .from('faults')
            .stream(primaryKey: ['id'])
            .eq('category', _adminDepartment!)
            .order('created_at', ascending: false);
      } else {
        _stream = _supabase
            .from('faults')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false);
      }
    });
  }

  Future<void> _fetchFollowedIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response = await _supabase
          .from('follows')
          .select('fault_id')
          .eq('user_id', userId);
      if (mounted) {
        setState(() {
          _followedFaultIds = (response as List)
              .map((e) => e['fault_id'])
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('Takip hatasi: $e');
    }
  }

  Future<void> _refreshData() async {
    await _checkUserRoleAndDepartment();
    await _fetchFollowedIds();
    _setupStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sağlık':
        return Icons.local_hospital;
      case 'Güvenlik':
        return Icons.security;
      case 'Çevre/Temizlik':
        return Icons.cleaning_services;
      case 'Kayıp-Buluntu':
        return Icons.biotech;
      case 'Teknik Arıza':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Sağlık':
        return Colors.red;
      case 'Güvenlik':
        return Colors.blue.shade700;
      case 'Çevre/Temizlik':
        return Colors.green;
      case 'Kayıp-Buluntu':
        return Colors.purple;
      case 'Teknik Arıza':
        return Colors.orange.shade800;
      default:
        return AppColors.primary;
    }
  }

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

  String _formatTimeAgo(String timestamp) {
    try {
      final date = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      if (difference.inMinutes < 1) return 'Şimdi';
      if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce';
      if (difference.inHours < 24) return '${difference.inHours} sa önce';
      return DateFormat('dd MMM', 'tr').format(date);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _stream == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                final allFaults = snapshot.data ?? [];

                final filteredFaults = allFaults.where((fault) {
                  final category =
                      fault['category'] ?? fault['department'] ?? 'Diğer';

                  final matchesCategory =
                      _selectedFilter == 'Tümü' || category == _selectedFilter;

                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      (fault['title'] ?? '').toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      (fault['description'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                  final matchesOpen =
                      !_showOnlyOpen || fault['status'] == 'Açık';
                  final isFollowed = _followedFaultIds.contains(fault['id']);
                  final matchesFollowed = !_showOnlyFollowed || isFollowed;

                  return matchesCategory &&
                      matchesSearch &&
                      matchesOpen &&
                      matchesFollowed;
                }).toList();

                if (_isAscending) {
                  filteredFaults.sort(
                    (a, b) => a['created_at'].compareTo(b['created_at']),
                  );
                } else {
                  filteredFaults.sort(
                    (a, b) => b['created_at'].compareTo(a['created_at']),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  edgeOffset: 20,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildSearchAndFilters(),
                      _buildListArea(filteredFaults),
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 100),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  _isSearching = value.isNotEmpty;
                }),
                decoration: InputDecoration(
                  hintText: 'Bildirim ara...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildQuickFilter(
                  label: "Sadece Açıklar",
                  isSelected: _showOnlyOpen,
                  onTap: () => setState(() => _showOnlyOpen = !_showOnlyOpen),
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                _buildQuickFilter(
                  label: "Takip Ettiklerim",
                  isSelected: _showOnlyFollowed,
                  onTap: () =>
                      setState(() => _showOnlyFollowed = !_showOnlyFollowed),
                  color: AppColors.primary,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isAscending = !_isAscending),
                  tooltip: "Tarihe Göre Sırala",
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedFilter == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_categories.length > 1)
                          ? (selected) =>
                                setState(() => _selectedFilter = category)
                          : null,
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.inputBorder,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListArea(List<Map<String, dynamic>> filteredFaults) {
    if (filteredFaults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kayıt bulunamadı',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildFaultCard(filteredFaults[index]),
          childCount: filteredFaults.length,
        ),
      ),
    );
  }

  Widget _buildFaultCard(Map<String, dynamic> fault) {
    final category = fault['category'] ?? fault['department'] ?? 'Diğer';
    final status = fault['status'] ?? 'Açık';
    final photoUrl = fault['photo_url'];
    final statusColor = _getStatusColor(status);
    final categoryColor = _getCategoryColor(category);
    final isFollowed = _followedFaultIds.contains(fault['id']);
    final profile = fault['profiles'];
    final faultDataForDetail = {...fault, 'is_followed': isFollowed};

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  NotificationDetailScreen(faultData: faultDataForDetail),
            ),
          );

          // Silme algılandığında refresh tetikle
          if (result is Map && result['deleted'] == true) {
            debugPrint("🔄 Silme algılandı, liste yenileniyor...");
            if (mounted) {
              // Stream'i yeniden başlat
              _setupStream();
              // Takip listesini güncelle
              await _fetchFollowedIds();
              // UI'ı güncelle
              setState(() {});
            }
          } else {
            // Normal durumda sadece takip durumunu güncelle
            await _fetchFollowedIds();
          }

          // Harita yönlendirmesi
          if (result is Map &&
              result['action'] == 'goToMap' &&
              widget.onMapAction != null) {
            widget.onMapAction!(Map<String, dynamic>.from(result));
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  photoUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 180,
                    color: Colors.grey[100],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            size: 18,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTimeAgo(fault['created_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fault['title'] ?? 'Başlıksız Bildirim',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fault['description'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (_isAdmin && profile != null) ...[
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "${profile['full_name']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'Çözüldü'
                                  ? Icons.check_circle
                                  : Icons.info,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isFollowed) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.bookmark,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                      if (_isAdmin && fault['latitude'] != null) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => {
                            if (widget.onMapAction != null)
                              {
                                widget.onMapAction!({
                                  'action': 'goToMap',
                                  'faultData': fault,
                                }),
                              },
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.map,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
