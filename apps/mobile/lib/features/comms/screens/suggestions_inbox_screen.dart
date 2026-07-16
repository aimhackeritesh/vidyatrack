import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin suggestions inbox — list open suggestions and reply (notifies sender).
class SuggestionsInboxScreen extends ConsumerStatefulWidget {
  const SuggestionsInboxScreen({super.key});

  @override
  ConsumerState<SuggestionsInboxScreen> createState() => _SuggestionsInboxScreenState();
}

class _SuggestionsInboxScreenState extends ConsumerState<SuggestionsInboxScreen> {
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
      final res = await ref.read(dioProvider).get('/notifications/suggestions', queryParameters: {'status': 'all'});
      _items = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reply(Map<String, dynamic> s) async {
    final ctrl = TextEditingController(text: s['reply']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Your reply')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(dioProvider).post('/notifications/suggestions/${s['id']}/reply', data: {'reply': ctrl.text.trim()});
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send reply')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Suggestions')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No suggestions yet', style: TextStyle(color: AppColors.textSecondary)))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _items[i];
                          final closed = s['status'] == 'closed';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(s['from_name']?.toString() ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                                    if (closed) const Text('Replied', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(s['body']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                                if (s['reply'] != null && s['reply'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Reply: ${s['reply']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  ),
                                ],
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(onPressed: () => _reply(s), child: Text(closed ? 'Edit reply' : 'Reply')),
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
