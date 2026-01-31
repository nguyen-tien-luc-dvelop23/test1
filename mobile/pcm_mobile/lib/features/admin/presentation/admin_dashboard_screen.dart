import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;
  List<dynamic> _bookings = [];
  List<dynamic> _members = [];
  List<dynamic> _transactions = [];
  List<dynamic> _tournaments = [];

  // Analytics
  double _totalRevenue = 0;
  List<double> _weeklyRevenue = List.filled(7, 0.0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final b = await ApiService.adminAllBookings();
    final m = await ApiService.getMembers();
    final t = await ApiService.adminAllTransactions();
    final tr = await ApiService.getTournaments();

    if (!mounted) return;

    // Process Analytics
    double total = 0;
    List<double> weekly = List.filled(7, 0.0);
    final now = DateTime.now();
    
    for (var tx in t) {
      final amount = (tx['amount'] ?? 0).toDouble();
      
      // Fix: Revenue = Money spent by users (negative transactions)
      // Deposits (+) are just increasing balance, not revenue from services.
      // Refunds (+) reduce revenue.
      // So: Revenue += -amount (if amount < 0)
      //     Revenue -= amount (if amount > 0 and type is Refund) -> complicated.
      // Simple approach: Revenue = Sum of |amount| for all 'BookingPayment' and 'TournamentEntry'.
      
      final type = tx['type'] ?? '';
      double income = 0;

      if (amount < 0) {
        // Spending is revenue for the system
        income = amount.abs();
      } else if (type == 'BookingRefund') {
         // Refund reduces revenue
         income = -amount;
      }

      total += income;
      
      // Fix: Backend returns 'createdDate' or 'CreatedDate', not 'createdAt'
      final dateStr = tx['createdDate'] ?? tx['createdAt'];
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final diff = now.difference(date).inDays;
          if (diff >= 0 && diff < 7) {
            int idx = 6 - diff;
            if (idx >= 0 && idx < 7) {
              weekly[idx] += income;
            }
          }
        }
      }
    }

    setState(() {
      _bookings = b;
      _members = m;
      _transactions = t;
      _tournaments = tr;
      _totalRevenue = total;
      _weeklyRevenue = weekly;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Đặt sân'),
            Tab(text: 'Thành viên'),
            Tab(text: 'Giao dịch'),
            Tab(text: 'Giải đấu'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 4
          ? FloatingActionButton(
              onPressed: _showAddTournamentDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tab,
                children: [
                  _buildOverview(),
                  _buildBookings(),
                  _buildMembers(),
                  _buildTransactions(),
                  _buildTournaments(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Stats Cards
        Row(
          children: [
            Expanded(child: _StatCard(
              title: 'Thành viên', 
              value: _members.length.toString(), 
              icon: Icons.people, 
              color: Colors.blue
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              title: 'Doanh thu', 
              value: '${(_totalRevenue/1000).toStringAsFixed(0)}k', 
              icon: Icons.attach_money, 
              color: Colors.green
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(
              title: 'Đặt sân', 
              value: _bookings.length.toString(), 
              icon: Icons.sports_tennis, 
              color: Colors.orange
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              title: 'Sân đấu', 
              value: '4', // Hardcoded or fetch
              icon: Icons.stadium, 
              color: Colors.purple
            )),
          ],
        ),

        const SizedBox(height: 24),

        // 2. Chart Section
        const Text('Doanh thu 7 ngày qua', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (_weeklyRevenue.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, double.infinity),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.blueGrey,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(rod.toY),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('dd/MM').format(date),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _weeklyRevenue.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value,
                      color: Colors.blueAccent,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: (_weeklyRevenue.reduce((a, b) => a > b ? a : b) * 1.2).clamp(100.0, double.infinity),
                        color: Colors.grey.shade100,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Text('Hành động nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Tạo giải đấu'),
              onPressed: _showAddTournamentDialog,
            ),
            ActionChip(
              avatar: const Icon(Icons.refresh),
              label: const Text('Cập nhật dữ liệu'),
              onPressed: _loadAll,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookings() {
   if (_bookings.isEmpty) return const Center(child: Text('Chưa có lịch đặt sân'));
    return ListView.builder(
      itemCount: _bookings.length,
      itemBuilder: (ctx, i) {
        final b = _bookings[i];
        final courtName = b['court'] != null ? b['court']['name'] : 'Sân ?';
        return ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(courtName ?? 'Sân ?'),
          subtitle: Text('${b['startTime']} - ${b['endTime']}'),
          trailing: Text(b['status'] ?? ''),
        );
      },
    );
  }

  Widget _buildMembers() {
    if (_members.isEmpty) return const Center(child: Text('Không có member'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final m = _members[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(m['fullName'] ?? ''),
            subtitle: Text('${m['email']} • Tier: ${m['tier']}'),
            trailing: Text('Wallet: ${(m['walletBalance'] ?? 0)}'),
          ),
        );
      },
    );
  }

  Widget _buildTransactions() {
    if (_transactions.isEmpty) return const Center(child: Text('Không có giao dịch'));
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (ctx, i) {
        final t = _transactions[i];
        final amount = (t['amount'] ?? 0).toDouble();
        final color = amount >= 0 ? Colors.green : Colors.red;
        return ListTile(
          leading: Icon(Icons.attach_money, color: color),
          title: Text(t['description'] ?? 'Giao dịch'),
          trailing: Text('${amount}đ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildTournaments() {
    if (_tournaments.isEmpty) return const Center(child: Text('Chưa có giải đấu'));
    return ListView.builder(
      itemCount: _tournaments.length,
      itemBuilder: (ctx, i) {
        final t = _tournaments[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.amber),
            title: Text(t['name'] ?? 'Giải đấu'),
            subtitle: Text('Phí: ${t['entryFee']}đ - Player: ${t['maxPlayers']}'),
            trailing: Text(t['status'] ?? 'Upcoming'),
          ),
        );
      },
    );
  }

  void _showAddTournamentDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final playersCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    String type = 'SingleElimination';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo giải đấu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên giải')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
                TextField(controller: feeCtrl, decoration: const InputDecoration(labelText: 'Phí tham gia'), keyboardType: TextInputType.number),
                TextField(controller: playersCtrl, decoration: const InputDecoration(labelText: 'Số người tối đa'), keyboardType: TextInputType.number),
                DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  items: const [
                     DropdownMenuItem(value: 'SingleElimination', child: Text('Loại trực tiếp')),
                     DropdownMenuItem(value: 'RoundRobin', child: Text('Vòng tròn')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                ListTile(
                  title: Text(startDate == null ? 'Chọn ngày bắt đầu' : DateFormat('dd/MM/yyyy').format(startDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: DateTime.now());
                    if (d != null) setDialogState(() => startDate = d);
                  },
                ),
                ListTile(
                  title: Text(endDate == null ? 'Chọn ngày kết thúc' : DateFormat('dd/MM/yyyy').format(endDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: DateTime.now());
                    if (d != null) setDialogState(() => endDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                 await ApiService.createTournament(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  startDate: startDate ?? DateTime.now(),
                  endDate: endDate ?? DateTime.now(),
                  entryFee: double.tryParse(feeCtrl.text) ?? 0,
                  maxPlayers: int.tryParse(playersCtrl.text) ?? 16,
                  type: type,
                );
                if (mounted) {
                  Navigator.pop(context);
                  _loadAll();
                }
              }, 
              child: const Text('Tạo')
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade900)),
          Text(title, style: TextStyle(color: color.shade700)),
        ],
      ),
    );
  }
}
