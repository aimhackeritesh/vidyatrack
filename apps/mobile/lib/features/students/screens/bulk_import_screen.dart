import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin: bulk-create students from pasted CSV.
/// Columns: name, class, section, guardianName, guardianPhone  (header row optional).
class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final _csv = TextEditingController(
    text: 'name, class, section, guardian name, guardian phone\n',
  );
  bool _importing = false;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _csv.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parse(String text) {
    final rows = <Map<String, dynamic>>[];
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final cols = line.split(',').map((c) => c.trim()).toList();
      // skip a header row
      if (cols.first.toLowerCase() == 'name') continue;
      rows.add({
        'name': cols.isNotEmpty ? cols[0] : '',
        'class': cols.length > 1 ? cols[1] : '',
        'section': cols.length > 2 ? cols[2] : '',
        'guardianName': cols.length > 3 ? cols[3] : '',
        'guardianPhone': cols.length > 4 ? cols[4] : '',
      });
    }
    return rows;
  }

  Future<void> _import() async {
    final rows = _parse(_csv.text);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to import')));
      return;
    }
    setState(() => _importing = true);
    try {
      final res = await ref.read(dioProvider).post('/students/bulk-import', data: {'rows': rows});
      setState(() => _result = (res.data as Map).cast<String, dynamic>());
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import failed'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Bulk Import Students')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Paste one student per line:\nname, class, section, guardian name, guardian phone',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _csv,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import'),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  _pill('${result['imported'] ?? 0} imported', AppColors.success),
                  const SizedBox(width: 8),
                  _pill('${result['failed'] ?? 0} failed', AppColors.error),
                ],
              ),
              const SizedBox(height: 12),
              ...(((result['credentials'] as List?) ?? []).map((raw) {
                final c = (raw as Map).cast<String, dynamic>();
                final s = (c['student'] as Map?) ?? {};
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                  child: Text('${c['name']} • ${s['loginId']} / ${s['password']}', style: const TextStyle(fontSize: 13)),
                );
              })),
              ...(((result['errors'] as List?) ?? []).map((raw) {
                final e = (raw as Map).cast<String, dynamic>();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('Row ${e['row']} (${e['name']}): ${e['error']}', style: const TextStyle(fontSize: 12, color: AppColors.error)),
                );
              })),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
