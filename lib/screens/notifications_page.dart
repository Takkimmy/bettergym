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
  final Set<String> _expandedNotifications = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).loadNotifications();
    });
  }

  void _clearAllNotifications() {
    ref.read(notificationsProvider.notifier).clearAll();
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0000),
        title: const Text(
          'CLEAR ALL ALERTS?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'This will remove all risk notifications.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNotifications() async {
    await ref.read(notificationsProvider.notifier).loadNotifications();
  }

  void _removeNotification(String id) {
    ref.read(notificationsProvider.notifier).removeNotification(id);
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedNotifications.contains(id)) {
        _expandedNotifications.remove(id);
      } else {
        _expandedNotifications.add(id);
      }
    });
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final isExpanded = _expandedNotifications.contains(notification.id);

    return GestureDetector(
      onTap: () => _toggleExpanded(notification.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2B0000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Text(
                        notification.timeAgo,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.redAccent),
                const SizedBox(height: 10),
                const Text(
                  'This alert indicates a possible injury risk or repeated bad form pattern. Please review your movement before continuing.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _removeNotification(notification.id),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'ACKNOWLEDGE RISK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
        backgroundColor: navyBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            color: mintGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () => _showClearAllDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: currentNotifications.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentNotifications.length,
                itemBuilder: (context, index) {
                  final notification = currentNotifications[index];

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
      ),
    );
  }
}
