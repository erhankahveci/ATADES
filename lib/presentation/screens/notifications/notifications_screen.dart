// lib/presentation/screens/notifications/notifications_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _streamSubscription;
  final Set<String> _locallyReadIds = {};

  @override
  void initState() {
    super.initState();
    _setupNotificationStream();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationStream() {
    _streamSubscription = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (mounted) {
              setState(() {
                _notifications = data;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  // Tarih formatı, okundu işaretleme ve silme fonksiyonları
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0 && date.day == now.day) {
        return "Bugün ${DateFormat('HH:mm').format(date)}";
      } else if (diff.inDays <= 1 && date.day == now.day - 1) {
        return "Dün ${DateFormat('HH:mm').format(date)}";
      } else {
        return DateFormat('dd MMM, HH:mm', 'tr').format(date);
      }
    } catch (e) {
      return "";
    }
  }

  Future<void> _markAsReadInstant(String notificationId) async {
    setState(() {
      _locallyReadIds.add(notificationId);
    });
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  Future<void> _deleteNotificationInstant(String notificationId) async {
    setState(() {
      _notifications.removeWhere((item) => item['id'] == notificationId);
    });
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {}
  }

  Future<void> _deleteAllNotifications() async {
    if (_notifications.isEmpty) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Tümünü Temizle?",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Tüm bildirimleriniz silinecektir.",
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("İptal", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Temizle",
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() {
      _notifications.clear();
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('notifications').delete().eq('user_id', userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Temizlendi"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {}
  }

  //Scaffold ve AppBar kaldırıldı, Column kullanıldı.
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FC),
      child: Column(
        children: [
          // 1. ÜST BUTON ALANI (AppBar yerine)
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                4,
                12,
                0,
              ), // Boşluğu buradan ayarlıyoruz
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _deleteAllNotifications,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero, // Boşlukları azaltır
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: Text(
                    "Tümünü Temizle",
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

          // 2. LİSTE
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: _notifications.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final bool isRead =
                          (notif['is_read'] ?? false) ||
                          _locallyReadIds.contains(notif['id']);
                      return _buildNotificationCard(notif, isRead);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, bool isRead) {
    final String title = (notif['title'] ?? '').toString().toUpperCase();
    final bool isEmergency = title.contains('ACİL') || title.contains('UYARI');

    final Color bgColor = isEmergency ? const Color(0xFFFEF2F2) : Colors.white;
    final Color borderColor = isEmergency
        ? const Color(0xFFEF4444)
        : (isRead ? Colors.transparent : AppColors.primary.withOpacity(0.3));

    final IconData iconData = isEmergency
        ? Icons.warning_amber_rounded
        : (isRead
              ? Icons.mark_email_read_outlined
              : Icons.notifications_active);

    final Color iconColor = isEmergency
        ? const Color(0xFFDC2626)
        : (isRead ? Colors.grey.shade500 : AppColors.primary);

    final Color iconBgColor = isEmergency
        ? const Color(0xFFFEE2E2)
        : (isRead
              ? const Color(0xFFF2F4F7)
              : AppColors.primary.withOpacity(0.1));

    return Dismissible(
      key: Key(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotificationInstant(notif['id']),
      child: InkWell(
        onTap: () {
          if (!isRead) _markAsReadInstant(notif['id']);
          _showNotificationDetail(context, notif);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isEmergency ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif['title'] ?? 'Bildirim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: isEmergency || !isRead
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isEmergency
                                  ? const Color(0xFF991B1B)
                                  : (isRead
                                        ? const Color(0xFF4F566B)
                                        : Colors.black),
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(notif['created_at']),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isEmergency
                                ? const Color(0xFFDC2626)
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif['body'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isEmergency
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFF697386),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteNotificationInstant(notif['id']),
                  icon: Icon(
                    Icons.close,
                    color: isEmergency
                        ? const Color(0xFFEF4444)
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Henüz bildirim yok",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            "Tüm bildirimleriniz burada listelenir",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetail(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationDetailSheet(
        notification: notification,
        formatDate: _formatDate,
      ),
    );
  }
}

// Detay sayfası
class _NotificationDetailSheet extends StatefulWidget {
  final Map<String, dynamic> notification;
  final Function(String) formatDate;
  const _NotificationDetailSheet({
    required this.notification,
    required this.formatDate,
  });
  @override
  State<_NotificationDetailSheet> createState() =>
      _NotificationDetailSheetState();
}

class _NotificationDetailSheetState extends State<_NotificationDetailSheet> {
  Map<String, dynamic>? _faultData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFaultDetails();
  }

  Future<void> _fetchFaultDetails() async {
    final faultId = widget.notification['fault_id'];
    if (faultId != null) {
      try {
        final data = await Supabase.instance.client
            .from('faults')
            .select('photo_url, status, department')
            .eq('id', faultId)
            .maybeSingle();
        if (mounted) setState(() => _faultData = data);
      } catch (e) {}
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.notification['title'].toString().toUpperCase();
    final bool isEmergency = title.contains('ACİL') || title.contains('UYARI');
    final String statusText = _faultData?['status'] ?? 'Bilgi Yok';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEmergency
                      ? const Color(0xFFFEF2F2)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEmergency
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color: isEmergency
                      ? const Color(0xFFDC2626)
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification['title'],
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isEmergency
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF1A1F36),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.formatDate(widget.notification['created_at']),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEmergency
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEmergency
                    ? const Color(0xFFFECACA)
                    : Colors.grey.shade200,
              ),
            ),
            child: Text(
              widget.notification['body'],
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: isEmergency
                    ? const Color(0xFF7F1D1D)
                    : const Color(0xFF4F566B),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_faultData != null) ...[
            if (_faultData!['photo_url'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _faultData!['photo_url'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              "Durum: $statusText",
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1F36),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                "Kapat",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
