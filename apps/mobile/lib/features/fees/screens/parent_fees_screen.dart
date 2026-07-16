import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

Color _statusColor(String status) {
  switch (status) {
    case 'paid': return AppColors.success;
    case 'partial': return const Color(0xFFFF8A65);
    case 'overdue': return AppColors.error;
    case 'waived': return AppColors.textSecondary;
    default: return AppColors.primary; // pending
  }
}

/// Parent/student Fees tab — pending dues + payment history for their child,
/// replaces the old "coming soon" placeholder. `GET /fees/my-dues` is
/// ownership-scoped server-side (parent only ever sees their own child).
class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  bool _loading = true;
  double _totalOutstanding = 0;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/fees/my-dues');
      final data = res.data as Map<String, dynamic>;
      _totalOutstanding = double.tryParse(data['totalOutstanding']?.toString() ?? '0') ?? 0;
      _invoices = (data['invoices'] as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _monthLabel(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? '' : DateFormat('MMMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fees')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _totalOutstanding > 0 ? AppColors.error : AppColors.success,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_totalOutstanding > 0 ? 'Total Outstanding' : 'All fees paid', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(_fmt.format(_totalOutstanding), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Invoices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_invoices.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No invoices yet', style: TextStyle(color: AppColors.textSecondary))))
                  else
                    ..._invoices.map((inv) {
                      final due = double.tryParse(inv['due_amount']?.toString() ?? '0') ?? 0;
                      final paid = double.tryParse(inv['paid_amount']?.toString() ?? '0') ?? 0;
                      final balance = (due - paid).clamp(0, double.infinity);
                      final status = inv['status']?.toString() ?? 'pending';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => context.push('/fees/invoice/${inv['id']}'),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_monthLabel(inv['month']?.toString()), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status))),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_fmt.format(due), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (balance > 0) Text('Due ${_fmt.format(balance)}', style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
