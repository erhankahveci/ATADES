import 'package:intl/intl.dart';

class DateHelper {
  /// ISO formatındaki tarihi (Supabase'den gelen) okunabilir formata çevirir.
  /// Örn: "Şimdi", "5 dk önce", "2 sa önce", "10 Eki 2025"
  static String formatTimeAgo(String? timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Şimdi';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      // 1 haftadan eskiyse tam tarih göster
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    }
  }

  /// Tarihi standart formatta gösterir (10.12.2025)
  static String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }
}
