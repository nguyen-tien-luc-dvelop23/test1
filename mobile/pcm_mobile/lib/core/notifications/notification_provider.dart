import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

class NotificationCountNotifier extends StateNotifier<int> {
  NotificationCountNotifier() : super(0) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();
      state = count;
    } catch (e) {
      print('Error getting unread count: $e');
      state = 0;
    }
  }
}

final notificationCountProvider = StateNotifierProvider<NotificationCountNotifier, int>((ref) {
  return NotificationCountNotifier();
});
