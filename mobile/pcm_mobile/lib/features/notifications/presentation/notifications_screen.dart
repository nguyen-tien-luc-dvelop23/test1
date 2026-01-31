import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/api_service.dart';
import '../../../../core/notifications/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<List<dynamic>>? _notificationsFuture;
  DateTime? _lastReadTime;

  @override
  void initState() {
    super.initState();
    _loadData(); // No need for SharedPreferences
  }

  void _loadData() {
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  Future<void> _markAllAsRead() async {
    final success = await ApiService.markAllNotificationsAsRead();
    if (success) {
      if (!mounted) return;
      setState(() {
        _notificationsFuture = _fetchNotifications(); // Refresh list to show 'read' state
      });
      // Refresh global badge
      ref.read(notificationCountProvider.notifier).refresh();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả đã xem')),
      );
    }
  }

  Future<List<dynamic>> _fetchNotifications() async {
    // Directly fetch from API via the wrapper
    return await ApiService.getUnifiedNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (_notificationsFuture == null || snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Chưa có thông báo nào', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = notifications[index];
              final title = item['title'] ?? 'Thông báo';
              final message = item['message'] ?? '';
              final dateStr = item['created'] ?? '';
              final isRead = item['isRead'] ?? false;
              final type = item['type'] as String?;
              
              // Select icon based on content keywords or type
              IconData icon = Icons.notifications_outlined;
              Color iconColor = Colors.blueGrey;

              final lowerTitle = title.toString().toLowerCase();
              
              if (type == 'deposit' || lowerTitle.contains('nạp')) {
                icon = Icons.attach_money;
                iconColor = Colors.green;
              } else if (type == 'booking' || lowerTitle.contains('đặt sân') || lowerTitle.contains('booking')) {
                icon = Icons.calendar_month;
                iconColor = Colors.blue; 
              } else if (type == 'payment' || lowerTitle.contains('thanh toán')) {
                 icon = Icons.payment;
                 iconColor = Colors.orange;
              } else if (lowerTitle.contains('giải') || lowerTitle.contains('đấu')) {
                icon = Icons.emoji_events;
                iconColor = Colors.deepPurple;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  child: Icon(icon, color: iconColor),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    if (dateStr.isNotEmpty)
                      Text(
                        _formatDate(dateStr),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: !isRead ? const _UnreadDot() : null,
                tileColor: !isRead ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1) : null,
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: scheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}


