import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/notifications_page.dart'; // Gives us access to AppNotification

// This controls the data globally.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    return []; // Starts empty. No fake red dots.
  }

  void removeNotification(String id) {
    // Rebuilds the list without the deleted item
    state = state.where((n) => n.id != id).toList();
  }

  void addNotification(AppNotification n) {
    // Adds a new notification and updates the app
    state = [...state, n];
  }
}

// The wire that connects your UI to the data
final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(() {
  return NotificationsNotifier();
});