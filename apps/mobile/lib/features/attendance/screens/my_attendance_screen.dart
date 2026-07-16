import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Monthly attendance for the caller's own/child record (parent + student).
/// Calls `/attendance/me`; shows the month %, counts, and a per-day list.
class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = DateFormat('yyyy-MM').format(_month);
      final res = await ref.read(dioProvider).get('/attendance/me', queryParameters: {'month': m});
      final d = res.data as Map<String, dynamic>;
      _summary = (d['summary'] as Map).cast<String, dynamic>();
      _records = ((d['records'] as List?) ?? []).cast<Map<String, dynamic>>();
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not load attendance';
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'absent':
        return AppColors.error;
      case 'late':
        return Colors.orange;
      case 'leave':
        return Colors.blue;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_summary['pct'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Text(DateFormat('MMMM yyyy').format(_month), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
            else ...[
              // Percentage card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))]),
                child: Column(
                  children: [
                    Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: pct >= 75 ? AppColors.success : AppColors.error)),
                    const Text('Attendance this month', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('Present', _summary['present'], AppColors.success),
                        _stat('Absent', _summary['absent'], AppColors.error),
                        _stat('Late', _summary['late'], Colors.orange),
                        _stat('Leave', _summary['leave'], Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_records.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No attendance recorded this month', style: TextStyle(color: AppColors.textSecondary))))
              else
                ..._records.map((r) {
                  final status = r['status']?.toString() ?? 'present';
                  final date = DateTime.tryParse(r['date']?.toString() ?? '');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                    child: Row(
                      children: [
                        Text(date != null ? DateFormat('EEE, dd MMM').format(date) : '', style: const TextStyle(fontSize: 13)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, dynamic value, Color color) {
    return Column(
      children: [
        Text('${value ?? 0}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
