import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_button.dart';

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/classes');
  return (res.data as List).cast<Map<String, dynamic>>();
});

final _selectedClassProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final _selectedSectionProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final _sectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cls = ref.watch(_selectedClassProvider);
  if (cls == null) return [];
  final res = await ref.watch(dioProvider).get('/classes/sections', queryParameters: {'classId': cls['id']});
  return (res.data as List).cast<Map<String, dynamic>>();
});

class ClassSectionPickerScreen extends ConsumerWidget {
  const ClassSectionPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(_classesProvider);
    final sectionsAsync = ref.watch(_sectionsProvider);
    final selectedClass = ref.watch(_selectedClassProvider);
    final selectedSection = ref.watch(_selectedSectionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Class & Section'),
        actions: [
          IconButton(
            tooltip: 'Holiday calendar',
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () => context.push('/attendance/holidays'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final extra = (selectedClass != null && selectedSection != null)
              ? {
                  'sectionId': selectedSection['id'] as String,
                  'sectionLabel': 'Class ${selectedClass['name']} - Section ${selectedSection['name']}',
                }
              : null;
          context.push('/students/add', extra: extra);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Student'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Class dropdown ──────────────────────────────────────────
            classesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load classes'),
              data: (classes) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    hint: const Text('Select class', style: TextStyle(color: AppColors.textSecondary)),
                    value: selectedClass,
                    items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                    onChanged: (v) {
                      ref.read(_selectedClassProvider.notifier).state = v;
                      ref.read(_selectedSectionProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Section dropdown ────────────────────────────────────────
            sectionsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load sections'),
              data: (sections) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    hint: const Text('Select section', style: TextStyle(color: AppColors.textSecondary)),
                    value: selectedSection,
                    items: sections.map((s) => DropdownMenuItem(value: s, child: Text('Section ${s['name']}'))).toList(),
                    onChanged: (v) => ref.read(_selectedSectionProvider.notifier).state = v,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  ),
                ),
              ),
            ),

            const Spacer(),

            LoadingButton(
              label: 'Select',
              loading: false,
              onPressed: selectedClass != null && selectedSection != null
                  ? () {
                      final label = 'Class ${selectedClass['name']} - Section ${selectedSection['name']}';
                      context.push('/attendance/mark', extra: {
                        'sectionId': selectedSection['id'] as String,
                        'sectionName': label,
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
