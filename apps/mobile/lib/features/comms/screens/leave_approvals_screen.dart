import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin approvals queue for leave requests (teacher self / parent-for-child).
class LeaveApprovalsScreen extends ConsumerStatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  ConsumerState<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends ConsumerState<LeaveApprovalsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('/notifications/leave', queryParameters: {'status': 'pending'});
      _items = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _act(String id, bool approve) async {
    try {
      await ref.read(dioProvider).post('/notifications/leave/$id/act', data: {'approve': approve});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Approved' : 'Rejected')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
    }
  }

  String _d(dynamic v) {
    final dt = DateTime.tryParse(v?.toString() ?? '');
    return dt != null ? DateFormat('dd MMM').format(dt) : v?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Leave Approvals')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No pending requests', style: TextStyle(color: AppColors.textSecondary)))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = _items[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e['applicant_name']?.toString() ?? 'Applicant', style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${e['applicant_type']} • ${_d(e['from_date'])} → ${_d(e['to_date'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                if (e['reason'] != null && e['reason'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(e['reason'].toString(), style: const TextStyle(fontSize: 13)),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(onPressed: () => _act(e['id'] as String, false), child: const Text('Reject', style: TextStyle(color: AppColors.error))),
                                    const SizedBox(width: 8),
                                    ElevatedButton(onPressed: () => _act(e['id'] as String, true), child: const Text('Approve')),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
