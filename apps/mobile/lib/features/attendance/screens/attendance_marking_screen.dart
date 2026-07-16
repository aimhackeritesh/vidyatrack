import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final String sectionId;
  final String sectionName;

  const AttendanceMarkingScreen({super.key, required this.sectionId, required this.sectionName});

  @override
  ConsumerState<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  late String _date;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() => ref.read(attendanceNotifierProvider.notifier).loadRoster(widget.sectionId, _date));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = await ref.read(attendanceNotifierProvider.notifier).submit(widget.sectionId, _date);
    if (!mounted) return;
    final pending = ref.read(attendanceNotifierProvider).pendingSync;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pending > 0 ? 'Saved offline — will sync when online ($pending pending)' : 'Attendance submitted!'),
          backgroundColor: pending > 0 ? Colors.orange : AppColors.success,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceNotifierProvider);
    final filtered = state.records.where((r) => _search.isEmpty || r.name.toLowerCase().contains(_search.toLowerCase()) || r.rollNo.toString().contains(_search)).toList();

    final present = state.records.where((r) => r.status == StudentStatus.present).length;
    final absent = state.records.where((r) => r.status == StudentStatus.absent).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.sectionName, style: const TextStyle(fontSize: 14)),
            Text(_date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          if (state.pendingSync > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${state.pendingSync} pending', style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.orange.shade100,
              ),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorRetry(
                  message: state.error!,
                  onRetry: () => ref.read(attendanceNotifierProvider.notifier).loadRoster(widget.sectionId, _date),
                )
              : state.records.isEmpty
                  ? _EmptyRoster(sectionId: widget.sectionId, sectionName: widget.sectionName) // B5: explicit empty state
                  : Column(
              children: [
                // ── Summary bar ──────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _StatusPill('P: $present', AppColors.successLight, AppColors.success),
                      const SizedBox(width: 8),
                      _StatusPill('A: $absent', AppColors.errorLight, AppColors.error),
                      const Spacer(),
                      TextButton(onPressed: () => ref.read(attendanceNotifierProvider.notifier).markAll(StudentStatus.present), child: const Text('All P')),
                      TextButton(onPressed: () => ref.read(attendanceNotifierProvider.notifier).markAll(StudentStatus.absent), child: const Text('All A')),
                    ],
                  ),
                ),

                // ── Search bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or roll no',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),

                // ── Student list ─────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _StudentTile(record: filtered[i]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            // B5: disabled when there are no students to mark.
            onPressed: (state.submitting || state.records.isEmpty) ? null : _submit,
            child: state.submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(state.records.isEmpty
                    ? 'No students to mark'
                    : 'Submit Attendance (${state.records.length} students)'),
          ),
        ),
      ),
    );
  }
}

class _StudentTile extends ConsumerWidget {
  final AttendanceRecord record;
  const _StudentTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPresent = record.status == StudentStatus.present;
    final isAbsent = record.status == StudentStatus.absent;

    return GestureDetector(
      onTap: () => ref.read(attendanceNotifierProvider.notifier).toggleStatus(record.studentId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAbsent ? AppColors.error.withValues(alpha: 0.4) : (isPresent ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Roll no
            SizedBox(
              width: 32,
              child: Text('${record.rollNo}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(record.name.isNotEmpty ? record.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            // Name
            Expanded(child: Text(record.name, style: const TextStyle(fontWeight: FontWeight.w500))),
            // Status buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBtn('P', StudentStatus.present, record, ref, AppColors.success),
                const SizedBox(width: 6),
                _StatusBtn('A', StudentStatus.absent, record, ref, AppColors.error),
                const SizedBox(width: 6),
                _StatusBtn('L', StudentStatus.late, record, ref, Colors.orange),
                const SizedBox(width: 6),
                _StatusBtn('LV', StudentStatus.leave, record, ref, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBtn extends ConsumerWidget {
  final String label;
  final StudentStatus status;
  final AttendanceRecord record;
  final WidgetRef ref;
  final Color color;

  const _StatusBtn(this.label, this.status, this.record, this.ref, this.color);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = record.status == status;
    return GestureDetector(
      onTap: () => ref.read(attendanceNotifierProvider.notifier).setStatus(record.studentId, status),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color : AppColors.divider),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700))),
      ),
    );
  }
}

// B5: shown when the section has no enrolled (active) students.
// Only admin/teacher can reach this screen, so the "Add Students" action is safe.
class _EmptyRoster extends StatelessWidget {
  final String sectionId;
  final String sectionName;
  const _EmptyRoster({required this.sectionId, required this.sectionName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No students enrolled in this section yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add students to this section to start marking attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/students/add', extra: {'sectionId': sectionId, 'sectionLabel': sectionName}),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add Students'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatusPill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
