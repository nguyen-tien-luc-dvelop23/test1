import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class AdminTournamentsScreen extends StatefulWidget {
  const AdminTournamentsScreen({super.key});

  @override
  State<AdminTournamentsScreen> createState() => _AdminTournamentsScreenState();
}

class _AdminTournamentsScreenState extends State<AdminTournamentsScreen> {
  List<dynamic> _tournaments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() => _loading = true);
    final tournaments = await ApiService.getTournaments();
    if (!mounted) return;
    setState(() {
      _tournaments = tournaments;
      _loading = false;
    });
  }

  void _showTournamentDialog({Map<String, dynamic>? tournament}) {
    final isEdit = tournament != null;
    final nameController = TextEditingController(text: tournament?['name'] ?? '');
    final descController = TextEditingController(text: tournament?['description'] ?? '');
    final feeController = TextEditingController(
      text: tournament?['entryFee']?.toString() ?? '50000',
    );
    final maxController = TextEditingController(
      text: tournament?['maxPlayers']?.toString() ?? '16',
    );

    DateTime startDate = tournament?['startDate'] != null
        ? DateTime.parse(tournament!['startDate'])
        : DateTime.now().add(const Duration(days: 7));
    DateTime endDate = tournament?['endDate'] != null
        ? DateTime.parse(tournament!['endDate'])
        : DateTime.now().add(const Duration(days: 14));

    String selectedType = tournament?['type'] ?? 'SingleElimination';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Sửa giải đấu' : 'Thêm giải mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên giải',
                    prefixIcon: Icon(Icons.emoji_events),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Ngày bắt đầu'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Ngày kết thúc'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  decoration: const InputDecoration(
                    labelText: 'Phí tham gia (VNĐ)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxController,
                  decoration: const InputDecoration(
                    labelText: 'Số người tối đa',
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Loại giải',
                    prefixIcon: Icon(Icons.sports_tennis),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SingleElimination',
                      child: Text('Loại trực tiếp'),
                    ),
                    DropdownMenuItem(
                      value: 'RoundRobin',
                      child: Text('Vòng tròn'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên giải')),
                  );
                  return;
                }

                final success = isEdit
                    ? await ApiService.updateTournament(
                        tournamentId: tournament!['id'],
                        name: nameController.text,
                        description: descController.text,
                        startDate: startDate,
                        endDate: endDate,
                        entryFee: double.parse(feeController.text),
                        maxPlayers: int.parse(maxController.text),
                        type: selectedType,
                      )
                    : await ApiService.createTournament(
                        name: nameController.text,
                        description: descController.text,
                        startDate: startDate,
                        endDate: endDate,
                        entryFee: double.parse(feeController.text),
                        maxPlayers: int.parse(maxController.text),
                        type: selectedType,
                      );

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Đã cập nhật giải' : 'Đã thêm giải thành công!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadTournaments();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTournament(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa giải "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteTournament(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa giải'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadTournaments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý giải đấu'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tournaments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có giải nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bấm nút + để thêm giải mới',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTournaments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tournaments.length,
                    itemBuilder: (context, index) {
                      final tournament = _tournaments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(tournament['status']),
                            child: const Icon(Icons.emoji_events, color: Colors.white),
                          ),
                          title: Text(
                            tournament['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tournament['description'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                '${tournament['maxPlayers']} người • ${NumberFormat.currency(locale: 'vi', symbol: '₫').format(tournament['entryFee'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _getStatusText(tournament['status']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(tournament['status']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showTournamentDialog(tournament: tournament),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTournament(
                                  tournament['id'],
                                  tournament['name'],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTournamentDialog(),
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Thêm giải'),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Open':
        return Colors.green;
      case 'Ongoing':
        return Colors.orange;
      case 'Finished':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'Open':
        return '🟢 Đang mở';
      case 'Ongoing':
        return '🟠 Đang diễn ra';
      case 'Finished':
        return '⚫ Đã kết thúc';
      default:
        return '';
    }
  }
}
