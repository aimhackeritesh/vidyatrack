import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_button.dart';

final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// Invoice detail: amount, status, and payment history. Reachable by
/// admin/teacher (any invoice) and parent/student (ownership-enforced server-side).
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _loading = true;
  bool _paying = false;
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _payments = [];
  String? _role;

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _role = p.getString(AppConstants.userRoleKey));
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/fees/invoice/${widget.invoiceId}');
      final data = res.data as Map<String, dynamic>;
      _invoice = (data['invoice'] as Map).cast<String, dynamic>();
      _payments = (data['payments'] as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  Future<void> _payNow(double balance) async {
    setState(() => _paying = true);
    try {
      final dio = ref.read(dioProvider);
      final orderRes = await dio.post('/fees/pay/order', data: {'invoiceId': widget.invoiceId});
      final order = orderRes.data as Map<String, dynamic>;

      // Simulate the checkout round-trip so the full parent-pays flow is
      // demoable without a real merchant account.
      await Future.delayed(const Duration(milliseconds: 1200));
      final mockPaymentId = 'mock_pay_${const Uuid().v4()}';

      final verifyRes = await dio.post('/fees/pay/verify', data: {
        'invoiceId': widget.invoiceId,
        'orderId': order['orderId'],
        'paymentId': mockPaymentId,
        'signature': 'mock',
      });
      final result = verifyRes.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment successful — receipt ${result['receiptNo']}')),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed — try again')));
    }
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    final due = _invoice != null ? _n(_invoice!['due_amount']) : 0.0;
    final paidTotal = _payments.where((p) => p['voided_at'] == null).fold<double>(0, (sum, p) => sum + _n(p['amount']));
    final balance = (due - paidTotal).clamp(0, double.infinity);
    final month = _invoice != null ? DateTime.tryParse(_invoice!['month']?.toString() ?? '') : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(month != null ? DateFormat('MMMM yyyy').format(month) : 'Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(child: Text('Invoice not found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Total Due', _fmt.format(due)),
                          _row('Paid', _fmt.format(paidTotal)),
                          const Divider(height: 24),
                          _row('Balance', _fmt.format(balance), bold: true, color: balance > 0 ? AppColors.error : AppColors.success),
                          if (_invoice!['due_date'] != null) ...[
                            const SizedBox(height: 8),
                            Text('Due by ${DateFormat('dd MMM yyyy').format(DateTime.parse(_invoice!['due_date']))}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          if (balance > 0 && (_role == 'parent' || _role == 'student')) ...[
                            const SizedBox(height: 16),
                            LoadingButton(label: 'Pay Now', loading: _paying, onPressed: () => _payNow(balance.toDouble())),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (_payments.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('No payments yet', style: TextStyle(color: AppColors.textSecondary))))
                    else
                      ..._payments.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p['voided_at'] != null ? AppColors.error : AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_fmt.format(_n(p['amount'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        '${p['mode']} · ${p['receipt_no'] ?? ''}${p['voided_at'] != null ? ' · VOIDED' : ''}',
                                        style: TextStyle(fontSize: 11, color: p['voided_at'] != null ? AppColors.error : AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (p['paid_at'] != null)
                                  Text(DateFormat('dd MMM').format(DateTime.parse(p['paid_at'])), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          )),
                  ],
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 18 : 14, color: color)),
        ],
      ),
    );
  }
}
