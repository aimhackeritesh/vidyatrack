import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Report card for the caller's own/child results (`/academics/results/my`),
/// grouped by exam.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _byExam = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/academics/results/my');
      final rows = (res.data as List).cast<Map<String, dynamic>>();
      final map = <String, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final key = r['exam_name']?.toString() ?? 'Exam';
        (map[key] ??= []).add(r);
      }
      _byExam = map;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Results')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _byExam.isEmpty
                  ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No results published yet', style: TextStyle(color: AppColors.textSecondary)))])
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: _byExam.entries.map((entry) {
                        final subjects = entry.value;
                        final total = subjects.fold<double>(0, (s, r) => s + _n(r['marks']));
                        final max = subjects.fold<double>(0, (s, r) => s + _n(r['max_marks']));
                        final pct = max > 0 ? (total / max * 100) : 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                                  Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w700, color: pct >= 33 ? AppColors.success : AppColors.error)),
                                ],
                              ),
                              const Divider(),
                              ...subjects.map((r) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(r['subject']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                                        Text('${_n(r['marks']).toStringAsFixed(0)} / ${_n(r['max_marks']).toStringAsFixed(0)}${r['grade'] != null ? '  (${r['grade']})' : ''}',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
    );
  }
}
