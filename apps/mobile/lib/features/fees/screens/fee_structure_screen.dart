import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

const _frequencies = ['monthly', 'quarterly', 'annual', 'one_time'];

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/classes');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Admin sets the fee structure (heads: name, amount, frequency, per-class or
/// all-classes) and triggers invoice generation for a month from the same screen.
class FeeStructureScreen extends ConsumerStatefulWidget {
  const FeeStructureScreen({super.key});

  @override
  ConsumerState<FeeStructureScreen> createState() => _FeeStructureScreenState();
}

class _FeeStructureScreenState extends ConsumerState<FeeStructureScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _heads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/fees/heads');
      _heads = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _classLabel(Map<String, dynamic> h, List<Map<String, dynamic>> classes) {
    if (h['class_id'] == null) return 'All Classes';
    final c = classes.firstWhere((c) => c['id'] == h['class_id'], orElse: () => {});
    return c.isEmpty ? 'Class' : 'Class ${c['name']}';
  }

  Future<void> _editHead({Map<String, dynamic>? existing}) async {
    final classes = await ref.read(_classesProvider.future);
    if (!mounted) return;
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final amountCtrl = TextEditingController(text: existing?['amount']?.toString() ?? '');
    String frequency = existing?['frequency'] as String? ?? 'monthly';
    Map<String, dynamic>? selectedClass = existing?['class_id'] != null
        ? classes.firstWhere((c) => c['id'] == existing!['class_id'], orElse: () => {})
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Fee Head' : 'Edit Fee Head'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g. Tuition Fee)')),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ ')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1).replaceAll('_', ' ')))).toList(),
                  onChanged: (v) => setSt(() => frequency = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>?>(
                  value: selectedClass?.isEmpty ?? true ? null : selectedClass,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: [
                    const DropdownMenuItem<Map<String, dynamic>?>(value: null, child: Text('All Classes')),
                    ...classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))),
                  ],
                  onChanged: (v) => setSt(() => selectedClass = v),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await ref.read(dioProvider).delete('/fees/heads/${existing['id']}');
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: nameCtrl.text.trim().isEmpty || double.tryParse(amountCtrl.text.trim()) == null
                  ? null
                  : () async {
                      final body = {
                        'name': nameCtrl.text.trim(),
                        'amount': double.parse(amountCtrl.text.trim()),
                        'frequency': frequency,
                        'classId': selectedClass?['id'],
                      };
                      if (existing == null) {
                        await ref.read(dioProvider).post('/fees/heads', data: body);
                      } else {
                        await ref.read(dioProvider).put('/fees/heads/${existing['id']}', data: body);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvoices() async {
    final classes = await ref.read(_classesProvider.future);
    if (!mounted) return;
    DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
    Map<String, dynamic>? selectedClass;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Generate Invoices'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Turns the fee structure into per-student dues for a month. Safe to re-run — already-paid invoices are untouched.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: month,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  if (picked != null) setSt(() => month = DateTime(picked.year, picked.month));
                },
                child: Text('Month: ${month.year}-${month.month.toString().padLeft(2, '0')}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>?>(
                value: selectedClass,
                decoration: const InputDecoration(labelText: 'Class (optional)'),
                items: [
                  const DropdownMenuItem<Map<String, dynamic>?>(value: null, child: Text('All Classes')),
                  ...classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))),
                ],
                onChanged: (v) => setSt(() => selectedClass = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
                Navigator.pop(ctx);
                try {
                  final res = await ref.read(dioProvider).post('/fees/invoices/generate', data: {
                    'month': monthStr,
                    if (selectedClass != null) 'classId': selectedClass!['id'],
                  });
                  if (mounted) {
                    final d = res.data as Map<String, dynamic>;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${d['studentsProcessed']} students — ${d['created']} created, ${d['updated']} updated, ${d['skipped']} skipped')));
                  }
                } catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate invoices')));
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(_classesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fee Structure'),
        actions: [
          IconButton(tooltip: 'Generate Invoices', icon: const Icon(Icons.receipt_long_outlined), onPressed: _generateInvoices),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _editHead(), icon: const Icon(Icons.add), label: const Text('Add Fee Head')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : classesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load classes')),
              data: (classes) => _heads.isEmpty
                  ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No fee heads set up yet', style: TextStyle(color: AppColors.textSecondary)))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _heads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final h = _heads[i];
                        return GestureDetector(
                          onTap: () => _editHead(existing: h),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('${_classLabel(h, classes)} · ${h['frequency']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text('₹${h['amount']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
