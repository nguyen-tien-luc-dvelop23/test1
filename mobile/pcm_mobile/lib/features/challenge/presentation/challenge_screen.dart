import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/session_provider.dart';
import '../../../services/api_service.dart';

class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _challenges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _loading = true);
    final data = await ApiService.getChallenges();
    if (mounted) {
      setState(() {
        _challenges = data;
        _loading = false;
      });
    }
  }

  Future<void> _createChallenge(DateTime time, int? opponentId) async {
    // Show blocking loading dialog? For now just SnackBar feedback
    final error = await ApiService.createChallenge(scheduledTime: time, opponentId: opponentId);
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã tạo kèo đấu thành công!')));
        _loadChallenges();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Tạo kèo thất bại. $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5), // Keep it longer to read
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final myId = user?.memberId;

    final openChallenges = _challenges.where((c) => c['status'] == 'Open' || (c['status'] == 'Pending' && c['player2Id'] == myId)).toList();
    final myChallenges = _challenges.where((c) => 
      c['player1Id'] == myId || (c['player1Id'] != myId && c['player2Id'] == myId && c['status'] != 'Pending')
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sàn đấu Pickleball'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Kèo đấu & Lời mời'),
            Tab(text: 'Kèo của tôi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(openChallenges, isMyList: false, myId: myId),
          _buildList(myChallenges, isMyList: true, myId: myId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        label: const Text('Tạo kèo'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool isMyList, int? myId}) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text('Chưa có kèo nào'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final p1 = item['player1'] ?? {};
        final time = DateTime.tryParse(item['scheduledTime'] ?? '') ?? DateTime.now();
        final isMe = p1['id'] == myId;
        final isPendingForMe = item['status'] == 'Pending' && item['player2Id'] == myId;

        String titleText = '${p1['fullName'] ?? 'Ẩn danh'} tìm đối thủ';
        if (item['status'] == 'Pending') {
          titleText = '${p1['fullName']} thách đấu BẠN!';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isPendingForMe ? 4 : 1,
          color: isPendingForMe ? Colors.orange.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: p1['avatarUrl'] != null ? NetworkImage(p1['avatarUrl']) : null,
              child: p1['avatarUrl'] == null ? Text((p1['fullName'] ?? 'U')[0].toUpperCase()) : null,
            ),
            title: Text(titleText, style: TextStyle(fontWeight: isPendingForMe ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(DateFormat('HH:mm dd/MM/yyyy').format(time)),
            trailing: isMyList
                ? _buildStatusChip(item['status'])
                : (isMe 
                    ? const Text('Của bạn', style: TextStyle(color: Colors.grey))
                    : ElevatedButton(
                        style: isPendingForMe ? ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white) : null,
                        onPressed: () async {
                          final error = await ApiService.acceptChallenge(item['id']);
                          if (mounted) {
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('❌ Không thể nhận kèo này. $error'),
                                backgroundColor: Colors.red,
                              ));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('✅ Đã chấp nhận kèo đấu!'),
                                backgroundColor: Colors.green,
                              ));
                              _loadChallenges();
                            }
                          }
                        },
                        child: Text(isPendingForMe ? 'Chấp nhận' : 'Nhận kèo'),
                      )),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    String text = status;
    if (status == 'Open') { color = Colors.green; text = 'Đang tìm'; }
    if (status == 'Pending') { color = Colors.orange; text = 'Chờ trả lời'; }
    if (status == 'Scheduled') { color = Colors.blue; text = 'Đã chốt'; }
    if (status == 'Finished') { color = Colors.black; text = 'Kết thúc'; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _CreateChallengeDialog(),
    );

    if (result != null) {
      final date = result['date'] as DateTime;
      final opponent = result['opponent'] as Map<String, dynamic>?; // Can be null
      _createChallenge(date, opponent?['id']);
    }
  }
}

class _CreateChallengeDialog extends StatefulWidget {
  const _CreateChallengeDialog();

  @override
  State<_CreateChallengeDialog> createState() => _CreateChallengeDialogState();
}

class _CreateChallengeDialogState extends State<_CreateChallengeDialog> {
  DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
  dynamic selectedOpponent;
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      setState(() => _searching = true);
      final results = await ApiService.searchMembers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use ScaffoldMessenger logic or simple dialog size fix
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return AlertDialog(
      title: const Text('Tạo kèo đấu'),
      contentPadding: const EdgeInsets.all(20),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thời gian:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 7)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                    );
                    if (time != null) {
                      setState(() {
                        selectedDate = DateTime(
                          date.year, date.month, date.day, time.hour, time.minute
                        );
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('HH:mm dd/MM/yyyy').format(selectedDate)),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Đối thủ (Tùy chọn):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (selectedOpponent != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text((selectedOpponent['fullName'] ?? 'U')[0])),
                  title: Text(selectedOpponent['fullName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      selectedOpponent = null;
                      _searchController.clear();
                    }),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên để tìm...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching ? const SizedBox(width: 16, height: 16, child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        helperText: 'Để trống để tạo kèo chung (Open)',
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200), // Max height constraint
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final name = user['fullName'] ?? user['FullName'] ?? 'Unknown';
                            final email = user['email'] ?? user['Email'] ?? '';
                            
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                              subtitle: Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              onTap: () {
                                setState(() {
                                  selectedOpponent = user;
                                  _searchResults = [];
                                  _searchController.clear();
                                });
                              },
                            );
                          },
                        ),
                      )
                    else if (_searchController.text.isNotEmpty && !_searching)
                       const Padding(
                         padding: EdgeInsets.only(top: 8.0),
                         child: Text('Không tìm thấy người dùng nào.', style: TextStyle(color: Colors.grey)),
                       ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'date': selectedDate,
              'opponent': selectedOpponent
            });
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}
