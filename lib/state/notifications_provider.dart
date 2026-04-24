import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/notifications_page.dart';
import '../services/local_db_service.dart';
import '../services/api_services.dart';

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    return [];
  }

  Future<void> loadNotifications() async {
    final rows = await LocalDBService.instance.getNotifications();

    state = rows.map((row) {
      return AppNotification(
        id: row['id'].toString(),
        title: row['title']?.toString() ?? '',
        message: row['message']?.toString() ?? '',
        timeAgo: _formatTimeAgo(row['created_at']?.toString()),
      );
    }).toList();
  }

  Future<void> removeNotification(String id) async {
    final intId = int.tryParse(id);
    if (intId == null) return;

    final success = await ApiService.markNotificationAsRead(intId);

    if (success) {
      await LocalDBService.instance.markNotificationAsRead(intId);
      state = state.where((n) => n.id != id).toList();
    }
  }

  Future<void> addNotification(AppNotification n) async {
    state = [n, ...state];
  }

  String _formatTimeAgo(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(createdAt).toLocal();
      final difference = DateTime.now().difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hr ago';
      } else if (difference.inDays == 1) {
        return '1 day ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (_) {
      return createdAt;
    }
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);
