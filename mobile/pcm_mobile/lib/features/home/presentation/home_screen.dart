import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/session_provider.dart';
import '../../../services/api_service.dart';
import '../../wallet/presentation/wallet_screen.dart';
import '../../challenge/presentation/challenge_screen.dart';

// Callback to change tab in AppShell
typedef TabChangeCallback = void Function(int index);

class HomeScreen extends ConsumerStatefulWidget {
  final TabChangeCallback? onTabChange;

  const HomeScreen({super.key, this.onTabChange});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<dynamic> _upcomingBookings = [];
  List<dynamic> _tournaments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final bookings = await ApiService.getMyBookings();
      final tournaments = await ApiService.getTournaments(status: 'Open');
      if (!mounted) return;
      setState(() {
        _upcomingBookings = bookings.where((b) {
          try {
            final start = DateTime.parse(b['startTime']);
            return start.isAfter(DateTime.now()) && b['status'] != 'Cancelled';
          } catch (_) {
            return false;
          }
        }).take(3).toList();
        _tournaments = tournaments.take(3).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          // 2. Hero Banner
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C853).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/home_banner.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00C853), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: const Text('New Season 2026', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PICKLEBALL PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. 3D Menu Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _build3DMenuItem(
                title: 'Đặt sân',
                imagePath: 'assets/images/icon_booking_3d.png',
                color: const Color(0xFFE8F5E9), // Light Green
                onTap: () => widget.onTabChange?.call(1),
              ),
              _build3DMenuItem(
                title: 'Giải đấu',
                imagePath: 'assets/images/icon_trophy_3d.png',
                color: const Color(0xFFFFF8E1), // Light Yellow
                onTap: () => widget.onTabChange?.call(2),
              ),
              _build3DMenuItem(
                title: 'Thách đấu',
                imagePath: 'assets/images/icon_challenge_3d.png',
                color: const Color(0xFFFFEBEE), // Light Pink
                onTap: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChallengeScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          if (_loading) 
            const Center(child: CircularProgressIndicator())
          else ...[
            // 4. Upcoming Bookings Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lịch sắp tới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton(
                  onPressed: () => widget.onTabChange?.call(1),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            
            if (_upcomingBookings.isEmpty)
              _buildEmptyState('Bạn chưa có lịch đặt sân nào')
            else
              ..._upcomingBookings.map((booking) => _buildBookingCard(booking)),
              
             const SizedBox(height: 24),

            // 5. Open Tournaments Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giải đấu đang mở', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton(
                  onPressed: () => widget.onTabChange?.call(2),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),

            if (_tournaments.isEmpty)
              _buildEmptyState('Chưa có giải đấu nào')
            else
              ..._tournaments.map((tournament) => _buildTournamentCard(tournament)),
          ]
        ],
      ),
    );
  }

  Widget _build3DMenuItem({required String title, required String imagePath, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80, // Size for the icon container
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  IconData fallbackIcon = Icons.image;
                  if (title == 'Đặt sân') fallbackIcon = Icons.calendar_month;
                  if (title == 'Giải đấu') fallbackIcon = Icons.emoji_events;
                  if (title == 'Thách đấu') fallbackIcon = Icons.sports_tennis;
                  
                  return Icon(fallbackIcon, size: 32, color: Colors.black54);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    Color statusColor = Colors.orange;
    String statusText = booking['status'] ?? 'Pending';
    if (statusText == 'Confirmed') statusColor = Colors.green;
    if (statusText == 'Cancelled') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_tennis, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['court']?['name'] ?? 'Sân Pickleball',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM - HH:mm').format(DateTime.parse(booking['startTime'])),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(dynamic tournament) {
    final participants = (tournament['participants'] as List?)?.length ?? 0;
    final maxPlayers = tournament['maxPlayers'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.orange.withOpacity(0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: const Icon(Icons.emoji_events, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   tournament['name'] ?? '',
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                 ),
                 const SizedBox(height: 4),
                 Text(
                   '$participants/$maxPlayers người • ${NumberFormat.currency(locale: 'vi', symbol: '₫').format(tournament['entryFee'] ?? 0)}',
                   style: TextStyle(color: Colors.grey[600], fontSize: 13),
                 ),
               ],
             ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
