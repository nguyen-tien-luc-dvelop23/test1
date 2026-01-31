import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class AdminCourtsScreen extends StatefulWidget {
  const AdminCourtsScreen({super.key});

  @override
  State<AdminCourtsScreen> createState() => _AdminCourtsScreenState();
}

class _AdminCourtsScreenState extends State<AdminCourtsScreen> {
  List<dynamic> _courts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    setState(() => _loading = true);
    final courts = await ApiService.getCourts();
    if (!mounted) return;
    setState(() {
      _courts = courts;
      _loading = false;
    });
  }

  Future<void> _showCourtDialog({Map<String, dynamic>? court}) async {
    final nameCtrl = TextEditingController(text: court?['name'] ?? '');
    final locationCtrl = TextEditingController(text: court?['location'] ?? '');
    final priceCtrl = TextEditingController(
      text: court != null ? court['pricePerHour'].toString() : '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(court == null ? 'Thêm sân mới' : 'Sửa thông tin sân'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên sân',
                  prefixIcon: Icon(Icons.sports_tennis),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vị trí',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giá/giờ (VNĐ)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final location = locationCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text);

              if (name.isEmpty || location.isEmpty || price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin hợp lệ')),
                );
                return;
              }

              bool success;
              if (court == null) {
                success = await ApiService.createCourt(
                  name: name,
                  location: location,
                  pricePerHour: price,
                );
              } else {
                success = await ApiService.updateCourt(
                  courtId: court['id'] as int,
                  name: name,
                  location: location,
                  pricePerHour: price,
                );
              }

              if (!context.mounted) return;
              Navigator.pop(context, success);
            },
            child: Text(court == null ? 'Thêm' : 'Cập nhật'),
          ),
        ],
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(court == null ? 'Đã thêm sân thành công!' : 'Đã cập nhật sân!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadCourts();
    }
  }

  Future<void> _deleteCourt(int courtId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa sân "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteCourt(courtId);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa sân thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadCourts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa sân thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Quản lý sân', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_tennis, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có sân nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bấm nút + để thêm sân mới',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courts.length,
                  itemBuilder: (context, index) {
                    final court = _courts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sports_tennis, color: Colors.white),
                        ),
                        title: Text(
                          court['name'] ?? 'Sân ${court['id']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(court['location'] ?? 'Chưa có vị trí'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${court['pricePerHour']} VNĐ/giờ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showCourtDialog(court: court),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCourt(
                                court['id'] as int,
                                court['name'] ?? 'Sân ${court['id']}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCourtDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sân'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
