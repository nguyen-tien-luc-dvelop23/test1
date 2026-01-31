import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../../../core/session/session_provider.dart';
import '../../../core/notifications/notification_provider.dart';
import '../../../services/api_service.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = false;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final txs = await ApiService.walletTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _loading = false;
    });
    await ref.read(sessionProvider.notifier).refresh();
  }

  String _formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
  }

  Future<void> _showDepositSheet() async {
    final amountCtrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final random = Random();
    final content = 'PCM${DateTime.now().millisecondsSinceEpoch}${random.nextInt(99).toString().padLeft(2, '0')}';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nạp tiền vào ví', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary)),
              const SizedBox(height: 4),
              const Text('Quét mã QR bên dưới để nạp tiền tự động', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              // QR Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: 'VietQR|account=luc|content=$content',
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: Text(content, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Số tiền nạp (VNĐ)',
                  hintText: 'Nhập số tiền...',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(amountCtrl.text);
                  if (value == null || value <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                    );
                    return;
                  }
                  
                  // Optimistic UI update or blocking loading could go here
                  
                  final ok = await ApiService.deposit(
                    amount: value,
                    description: 'QR:$content',
                  );
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Nạp tiền thành công!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    await _loadData();
                    // Refresh notification count
                    ref.read(notificationCountProvider.notifier).refresh();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Giao dịch thất bại. Vui lòng thử lại.'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Xác nhận đã chuyển khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance = ref.watch(sessionProvider).valueOrNull?.walletBalance ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Balance Card
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E88E5), // Blue 600
                  Color(0xFF1565C0), // Blue 800
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decoration Circles
                Positioned(
                  right: -30,
                  top: -30,
                  child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withOpacity(0.1)),
                ),
                Positioned(
                  left: -40,
                  bottom: -40,
                  child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1)),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet, color: Colors.white.withOpacity(0.9)),
                              const SizedBox(width: 8),
                              Text('Số dư khả dụng', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16)),
                            ],
                          ),
                          Icon(Icons.verified_user_outlined, color: Colors.white.withOpacity(0.5)),
                        ],
                      ),
                      Text(
                        _formatCurrency(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('**** **** **** 1234', style: TextStyle(color: Colors.white70, letterSpacing: 2)),
                          const Spacer(),
                          const Text('PCM WALLET', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 2. Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showDepositSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Nạp tiền'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {}, // Future feature
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Lịch sử'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Transactions Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Giao dịch gần đây', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: _loadData, child: const Text('Làm mới')),
            ],
          ),
          const SizedBox(height: 8),

          // 4. List
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: scheme.outline),
                    const SizedBox(height: 12),
                    Text('Chưa có giao dịch nào', style: TextStyle(color: scheme.outline)),
                  ],
                ),
              ),
            )
          else
            ..._transactions.map((t) {
              final amount = t['amount'] ?? 0;
              final isPositive = amount >= 0;
              final dateStr = t['createdAt']; // Assuming API returns this
              DateTime date = DateTime.now();
              if (dateStr != null) {
                date = DateTime.tryParse(dateStr) ?? DateTime.now();
              }

              return Card(
                elevation: 0,
                color: scheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(
                    t['description'] ?? t['type'] ?? 'Giao dịch',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('HH:mm dd/MM/yyyy').format(date),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  trailing: Text(
                    '${isPositive ? '+' : ''}${_formatCurrency(amount)}',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }),
            
           // Safe area for bottom padding
           const SizedBox(height: 40),
        ],
      ),
    );
  }
}


