import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Today's Revenue detail — admin manual control (Phase 3 §6):
/// add other income / expense, and void today's entries. Reflects immediately.
class TodayRevenueScreen extends ConsumerStatefulWidget {
  const TodayRevenueScreen({super.key});

  @override
  ConsumerState<TodayRevenueScreen> createState() => _TodayRevenueScreenState();
}

class _TodayRevenueScreenState extends ConsumerState<TodayRevenueScreen> {
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _entries = {'payments': [], 'income': [], 'expenses': []};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([dio.get('/fees/daily-revenue'), dio.get('/fees/today')]);
      _summary = (results[0].data as Map).cast<String, dynamic>();
      _entries = (results[1].data as Map).cast<String, dynamic>();
    } catch (_) {/* shown as zeros */}
    if (mounted) setState(() => _loading = false);
  }

  double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  Future<void> _addEntry(bool income) async {
    final catCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(income ? 'Add Other Income' : 'Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount ₹', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amtCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    try {
      await ref.read(dioProvider).post(income ? '/fees/income' : '/fees/expenses', data: {
        'category': catCtrl.text.trim().isEmpty ? 'Other' : catCtrl.text.trim(),
        'amount': amount,
        'note': noteCtrl.text.trim(),
      });
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save entry')));
    }
  }

  Future<void> _void(String kind, String id) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void entry'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason', isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Void', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/fees/void', data: {'kind': kind, 'id': id, 'reason': reasonCtrl.text.trim()});
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not void')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Today's Revenue")),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(heroTag: 'inc', onPressed: () => _addEntry(true), icon: const Icon(Icons.add), label: const Text('Income')),
            const SizedBox(width: 12),
            FloatingActionButton.extended(heroTag: 'exp', backgroundColor: AppColors.error, onPressed: () => _addEntry(false), icon: const Icon(Icons.remove), label: const Text('Expense')),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 20),
                    _section('Fee Collections', (_entries['payments'] as List?) ?? [], 'payment', (e) => '${e['student_name'] ?? ''} • ${e['mode'] ?? ''}'),
                    _section('Other Income', (_entries['income'] as List?) ?? [], 'income', (e) => '${e['category'] ?? ''}${e['note'] != null && e['note'] != '' ? ' • ${e['note']}' : ''}'),
                    _section('Expenses', (_entries['expenses'] as List?) ?? [], 'expense', (e) => '${e['category'] ?? ''}${e['note'] != null && e['note'] != '' ? ' • ${e['note']}' : ''}'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(
        children: [
          _row('Total Revenue', _n(_summary['total_revenue']), color: AppColors.success, bold: true),
          const Divider(),
          _row('Amount Received', _n(_summary['amount_received'])),
          _row('Back Due Received', _n(_summary['back_due'])),
          _row('Fine Received', _n(_summary['fine_received'])),
          _row('Expense', _n(_summary['expense'])),
          _row('Discount', _n(_summary['discount']), color: AppColors.error),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: color ?? AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(_fmt.format(amount), style: TextStyle(fontSize: 14, color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _section(String title, List entries, String kind, String Function(Map) subtitle) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...entries.map((raw) {
          final e = (raw as Map).cast<String, dynamic>();
          final voided = e['voided_at'] != null;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle(e),
                    style: TextStyle(fontSize: 13, decoration: voided ? TextDecoration.lineThrough : null, color: voided ? AppColors.textSecondary : AppColors.textPrimary),
                  ),
                ),
                Text(_fmt.format(_n(e['amount'])), style: TextStyle(fontWeight: FontWeight.w600, decoration: voided ? TextDecoration.lineThrough : null)),
                if (voided)
                  const Padding(padding: EdgeInsets.only(left: 8), child: Text('VOID', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700)))
                else
                  IconButton(icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error), onPressed: () => _void(kind, e['id'] as String)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
