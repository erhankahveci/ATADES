import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> fault;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.fault,
    required this.onTap,
  });

  // Duruma göre renk belirleme (Madde 37)
  Color _getStatusColor(String? status) {
    if (status == 'Çözüldü') return Colors.green;
    if (status == 'İnceleniyor') return Colors.orange;
    return Colors.red; // Açık olanlar
  }

  // Bölüme göre ikon belirleme (Madde 36)
  IconData _getIcon(String? dept) {
    if (dept == 'Elektrik') return Icons.flash_on;
    if (dept == 'Su') return Icons.water_drop;
    return Icons.report_problem;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(_getIcon(fault['department']), color: AppColors.primary, size: 20),
        ),
        title: Text(
          fault['title'] ?? 'Başlıksız',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          fault['description'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fault['status'] ?? 'Açık',
              style: TextStyle(
                color: _getStatusColor(fault['status']),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(DateTime.parse(fault['created_at'])),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}