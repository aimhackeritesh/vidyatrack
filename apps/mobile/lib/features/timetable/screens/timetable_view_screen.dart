import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Read-only weekly timetable. Used by parent/student (`/academics/timetable/my`,
/// resolves the caller's own/child's section) and teacher (`/academics/timetable/my-teaching`,
/// their own periods across every section they teach — `showSection: true` labels each row).
class TimetableViewScreen extends ConsumerStatefulWidget {
  final String endpoint;
  final bool showSection;
  const TimetableViewScreen({super.key, required this.endpoint, this.showSection = false});

  @override
  ConsumerState<TimetableViewScreen> createState() => _TimetableViewScreenState();
}

class _TimetableViewScreenState extends ConsumerState<TimetableViewScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _slots = [];
  int _selectedDay = DateTime.now().weekday; // 1=Mon..7=Sun, matches backend

  @override
  void initState() {
    super.initState();
    if (_selectedDay > 6) _selectedDay = 1; // Sunday → default to Monday view
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get(widget.endpoint);
      _slots = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = _slots.where((s) => s['day'] == _selectedDay).toList()
      ..sort((a, b) => (a['period_no'] as num).compareTo(b['period_no'] as num));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Timetable')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: List.generate(6, (i) {
                          final day = i + 1;
                          final selected = day == _selectedDay;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_dayNames[i]),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedDay = day),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Expanded(
                    child: dayItems.isEmpty
                        ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No periods scheduled', style: TextStyle(color: AppColors.textSecondary)))])
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: dayItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final s = dayItems[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                      child: Text('${s['period_no']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (widget.showSection && s['class_name'] != null) 'Class ${s['class_name']}-${s['section_name']}',
                                              if (s['teacher_name'] != null) s['teacher_name'].toString(),
                                            ].join(' · '),
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('${_fmtTime(s['start_time']?.toString())} - ${_fmtTime(s['end_time']?.toString())}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
