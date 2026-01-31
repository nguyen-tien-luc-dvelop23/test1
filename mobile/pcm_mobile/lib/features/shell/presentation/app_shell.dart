import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_provider.dart';
import '../../../core/notifications/notification_provider.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../booking/presentation/booking_screen.dart';
import '../../tournament/presentation/tournament_screen.dart';
import '../../wallet/presentation/wallet_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../../services/api_service.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _changeTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onTabChange: _changeTab),
      const BookingScreen(),
      const TournamentScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];

    final session = ref.watch(sessionProvider);

    final fullName = session.valueOrNull?.fullName ?? 'Người dùng';
    final balance = session.valueOrNull?.walletBalance ?? 0;
    final isAdmin = session.valueOrNull?.isAdmin ?? false;

    final avatarUrl = session.valueOrNull?.avatarUrl;

    return Scaffold(
      drawer: isAdmin ? const _AdminDrawer() : null,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 20, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Xin chào, $fullName! 👋',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  )
                  .then((_) => setState(() {})), // Refresh on return
              icon: _NotificationBell(),
              tooltip: 'Thông báo',
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => ref.read(sessionProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Booking',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Giải',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Ví',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationCountProvider);
    return _BellWithBadge(count: count);
  }
}

class _BellWithBadge extends StatelessWidget {
  const _BellWithBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: scheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    void open(Widget page) {
      Navigator.of(context).pop(); // close drawer
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Quản lý (Admin)'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Dashboard'),
              onTap: () => open(const AdminDashboardScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
