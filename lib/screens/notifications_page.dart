import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; 
import '../state/notifications_provider.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String timeAgo;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
  });
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {

  void _removeNotification(String id) {
    ref.read(notificationsProvider.notifier).removeNotification(id);
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mintGreen.withOpacity(0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.notifications, color: mintGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              notification.timeAgo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNotifications = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: navyBlue, 
      appBar: AppBar(
        backgroundColor: navyBlue, // Uniform AppBar color
        elevation: 0, // Flat design to match main layout
        centerTitle: true, // Centered alignment
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: mintGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
      ),
      body: currentNotifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentNotifications.length, // CHANGE HERE
              itemBuilder: (context, index) {
                final notification = currentNotifications[index]; // CHANGE HERE
                
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeNotification(notification.id),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  child: _buildNotificationCard(notification),
                );
              },
            ),
    );
  }
}