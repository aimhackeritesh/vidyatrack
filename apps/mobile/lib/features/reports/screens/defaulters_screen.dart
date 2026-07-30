import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/school_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin/teacher attendance defaulters report (students below a % threshold).
class DefaultersScreen extends ConsumerStatefulWidget {
  const DefaultersScreen({super.key});

  @override
  ConsumerState<DefaultersScreen> createState() => _DefaultersScreenState();
}

class _DefaultersScreenState extends ConsumerState<DefaultersScreen> {
  bool _loading = true;
  /// Null until the first load, which uses the school's configured threshold
  /// (`attendance.defaulter_threshold`). Set once the user picks a value.
  int? _threshold;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Omitting `threshold` lets the API apply this school's configured value.
      final res = await ref.read(dioProvider).get(
            '/attendance/defaulters',
            queryParameters: {if (_threshold != null) 'threshold': _threshold},
          );
      _items = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(schoolConfigValueProvider).defaulterThreshold;
    final selected = _threshold ?? configured;
    // The school's configured threshold may not be one of the preset options
    // (it's any value 40–95), and DropdownButton asserts if `value` isn't in
    // `items` — so fold it into the list.
    final options = <int>{60, 70, 75, 80, 90, configured, selected}.toList()..sort();

    return RoleGate(
      allowed: const ['admin', 'teacher'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Attendance Defaulters')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('Below ', style: TextStyle(color: AppColors.textSecondary)),
                  DropdownButton<int>(
                    value: selected,
                    items: options.map((t) => DropdownMenuItem(value: t, child: Text('$t%'))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _threshold = v);
                        _load();
                      }
                    },
                  ),
                  const Spacer(),
                  if (!_loading) Text('${_items.length} students', style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('No defaulters 🎉', style: TextStyle(color: AppColors.textSecondary)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final d = _items[i];
                              // `pct` comes from a Postgres ROUND(…)::NUMERIC, which
                              // node-postgres returns as a String to preserve precision —
                              // a direct `as num?` cast throws. Same idiom as
                              // attendance_chart_card.dart.
                              final pct = double.tryParse(d['pct']?.toString() ?? '') ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                                child: Row(
                                  children: [
                                    CircleAvatar(radius: 16, backgroundColor: AppColors.error.withValues(alpha: 0.1), child: Text('${d['roll_no'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('Class ${d['class']} - ${d['section']}  •  ${d['present']}/${d['total']} days', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
