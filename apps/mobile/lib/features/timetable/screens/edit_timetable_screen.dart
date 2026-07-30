import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/school_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_button.dart';

/// Indexed by timetable day number − 1 (1 = Mon … 7 = Sun).
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/classes');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final _teachersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/teachers');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Admin sets a section's weekly timetable: pick class → section, edit the
/// Mon–Sat grid, Save writes the whole week in one POST /academics/timetable/bulk.
class EditTimetableScreen extends ConsumerStatefulWidget {
  const EditTimetableScreen({super.key});

  @override
  ConsumerState<EditTimetableScreen> createState() => _EditTimetableScreenState();
}

class _EditTimetableScreenState extends ConsumerState<EditTimetableScreen> {
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSection;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _slots = []; // {day, periodNo, subject, teacherId, teacherName, startTime, endTime}
  bool _loadingSections = false;
  bool _loadingSlots = false;
  bool _saving = false;
  int _selectedDay = 1;

  Future<void> _loadSections(String classId) async {
    setState(() { _loadingSections = true; _selectedSection = null; _slots = []; });
    try {
      final res = await ref.read(dioProvider).get('/classes/sections', queryParameters: {'classId': classId});
      _sections = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loadingSections = false);
  }

  Future<void> _loadSlots(String sectionId) async {
    setState(() => _loadingSlots = true);
    try {
      final res = await ref.read(dioProvider).get('/academics/timetable', queryParameters: {'sectionId': sectionId});
      _slots = (res.data as List)
          .cast<Map<String, dynamic>>()
          .map((s) => {
                'day': s['day'],
                'periodNo': s['period_no'],
                'subject': s['subject'],
                'teacherId': s['teacher_id'],
                'teacherName': s['teacher_name'],
                'startTime': (s['start_time'] as String?)?.substring(0, 5),
                'endTime': (s['end_time'] as String?)?.substring(0, 5),
              })
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingSlots = false);
  }

  Future<void> _save() async {
    if (_selectedSection == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/academics/timetable/bulk', data: {
        'sectionId': _selectedSection!['id'],
        'slots': _slots.map((s) => {
              'day': s['day'],
              'periodNo': s['periodNo'],
              'subject': s['subject'],
              'teacherId': s['teacherId'],
              'startTime': s['startTime'],
              'endTime': s['endTime'],
            }).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timetable saved')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save — try again')));
    }
    if (mounted) setState(() => _saving = false);
  }

  /// `day` is passed in rather than read from `_selectedDay` because the day
  /// actually shown is derived from the school's configured working days.
  Future<void> _editSlot({Map<String, dynamic>? existing, required int periodNo, required int day}) async {
    final teachers = await ref.read(_teachersProvider.future);
    final subjectCtrl = TextEditingController(text: existing?['subject'] as String? ?? '');
    String? teacherId = existing?['teacherId'] as String?;
    TimeOfDay start = _parseTime(existing?['startTime'] as String?) ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = _parseTime(existing?['endTime'] as String?) ?? const TimeOfDay(hour: 9, minute: 45);

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Period $periodNo — ${_dayNames[day - 1]}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: teacherId,
                  decoration: const InputDecoration(labelText: 'Teacher'),
                  items: teachers.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name']?.toString() ?? ''))).toList(),
                  onChanged: (v) => setSt(() => teacherId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: ctx, initialTime: start);
                          if (t != null) setSt(() => start = t);
                        },
                        child: Text('Start ${start.format(ctx)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: ctx, initialTime: end);
                          if (t != null) setSt(() => end = t);
                        },
                        child: Text('End ${end.format(ctx)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'delete': true}),
                child: const Text('Remove', style: TextStyle(color: AppColors.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: subjectCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, {
                        'subject': subjectCtrl.text.trim(),
                        'teacherId': teacherId,
                        'teacherName': teachers.firstWhere((t) => t['id'] == teacherId, orElse: () => {})['name'],
                        'startTime': _fmtTod(start),
                        'endTime': _fmtTod(end),
                      }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _slots.removeWhere((s) => s['day'] == day && s['periodNo'] == periodNo);
      if (result['delete'] != true) {
        _slots.add({'day': day, 'periodNo': periodNo, ...result});
      }
    });
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null || !t.contains(':')) return null;
    final p = t.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
  }

  String _fmtTod(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(_classesProvider);
    final config = ref.watch(schoolConfigValueProvider);
    // Periods and days come from this school's settings, not a hardcoded Mon–Sat × 8.
    final dayPeriods = List.generate(config.periodsPerDay, (i) => i + 1);
    final workingDays = config.workingDayNumbers;
    // The stored choice may not be a working day (default Mon, or the setting
    // changed since) — fall back to the school's first working day.
    final selectedDay = workingDays.contains(_selectedDay) ? _selectedDay : workingDays.first;
    final daySlots = {for (final s in _slots.where((s) => s['day'] == selectedDay)) s['periodNo'] as int: s};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Timetable')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: classesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Failed to load classes'),
                    data: (classes) => _dropdown<Map<String, dynamic>>(
                      hint: 'Class',
                      value: _selectedClass,
                      items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v);
                        if (v != null) _loadSections(v['id'] as String);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _loadingSections
                      ? const LinearProgressIndicator()
                      : _dropdown<Map<String, dynamic>>(
                          hint: 'Section',
                          value: _selectedSection,
                          items: _sections.map((s) => DropdownMenuItem(value: s, child: Text('Section ${s['name']}'))).toList(),
                          onChanged: (v) {
                            setState(() => _selectedSection = v);
                            if (v != null) _loadSlots(v['id'] as String);
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedSection != null) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: workingDays.map((day) {
                    final selected = day == selectedDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_dayNames[day - 1]),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedDay = day),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loadingSlots
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: dayPeriods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final periodNo = dayPeriods[i];
                          final slot = daySlots[periodNo];
                          return GestureDetector(
                            onTap: () => _editSlot(existing: slot, periodNo: periodNo, day: selectedDay),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: slot != null ? Colors.white : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: slot != null ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider, style: slot != null ? BorderStyle.solid : BorderStyle.solid),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36, alignment: Alignment.center,
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('$periodNo', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: slot != null
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(slot['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                              Text(
                                                [if (slot['teacherName'] != null) slot['teacherName'].toString(), '${slot['startTime']}-${slot['endTime']}'].join(' · '),
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          )
                                        : const Text('Tap to add a period', style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                  Icon(slot != null ? Icons.edit_outlined : Icons.add, color: AppColors.textSecondary, size: 18),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              LoadingButton(label: 'Save Timetable', loading: _saving, onPressed: _save),
            ] else
              const Expanded(child: Center(child: Text('Select a class and section', style: TextStyle(color: AppColors.textSecondary)))),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({required String hint, required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.textSecondary)),
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
        ),
      ),
    );
  }
}
