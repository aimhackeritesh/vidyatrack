import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../../../core/theme/app_theme.dart';

class DailyRevenueCard extends ConsumerWidget {
  const DailyRevenueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rev = ref.watch(dailyRevenueProvider);

    return GestureDetector(
      onTap: () => context.push('/revenue/today').then((_) => ref.invalidate(dailyRevenueProvider)),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: rev.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (_, __) => const Text('Could not load revenue'),
        data: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Revenue', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Row('Total Revenue', d['total_revenue'], highlight: AppColors.success),
            _Row('Amount Received', d['amount_received']),
            _Row('Back Due Received', d['back_due']),
            _Row('Fine Received', d['fine_received']),
            _Row('Expense', d['expense']),
            _Row('Discount', d['discount'], highlight: AppColors.error),
          ],
        ),
      ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color? highlight;

  const _Row(this.label, this.value, {this.highlight});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    final color = highlight ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: highlight != null ? FontWeight.w600 : FontWeight.normal)),
          Text(fmt.format(amount), style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
