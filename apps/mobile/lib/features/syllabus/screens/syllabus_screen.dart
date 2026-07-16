import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/file_upload_field.dart';
import '../../../shared/widgets/loading_button.dart';

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/classes');
  return (res.data as List).cast<Map<String, dynamic>>();
});

/// Syllabus browser. [canEdit] (admin/teacher) adds a class picker + Add/Edit/Delete;
/// otherwise (parent/student) it loads the caller's own class via `/academics/syllabus/my`.
class SyllabusScreen extends ConsumerStatefulWidget {
  final bool canEdit;
  const SyllabusScreen({super.key, this.canEdit = false});

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selectedClass;

  @override
  void initState() {
    super.initState();
    if (!widget.canEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = widget.canEdit && _selectedClass != null
          ? await ref.read(dioProvider).get('/academics/syllabus', queryParameters: {'classId': _selectedClass!['id']})
          : await ref.read(dioProvider).get('/academics/syllabus/my');
      _items = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editEntry({Map<String, dynamic>? existing}) async {
    if (_selectedClass == null) return;
    final subjectCtrl = TextEditingController(text: existing?['subject'] as String? ?? '');
    final topics = List<Map<String, dynamic>>.from(
      (existing?['topics_json'] as List?)?.map((t) => Map<String, dynamic>.from(t as Map)) ?? []);
    String? fileUrl = existing?['file_url'] as String?;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Subject' : 'Edit ${existing['subject']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: subjectCtrl, enabled: existing == null, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                ...topics.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.value['title']?.toString() ?? '')),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            onPressed: () => setSt(() => topics.removeAt(e.key)),
                          ),
                        ],
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Add topic'),
                        onSubmitted: (v) {
                          if (v.trim().isEmpty) return;
                          setSt(() => topics.add({'title': v.trim(), 'done': false}));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FileUploadField(initialUrl: fileUrl, onChanged: (u) => setSt(() => fileUrl = u)),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await ref.read(dioProvider).delete('/academics/syllabus/${existing['id']}');
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: subjectCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      await ref.read(dioProvider).post('/academics/syllabus', data: {
                        'classId': _selectedClass!['id'],
                        'subject': subjectCtrl.text.trim(),
                        'topics': topics,
                        'fileUrl': fileUrl,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(_classesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Syllabus')),
      floatingActionButton: widget.canEdit && _selectedClass != null
          ? FloatingActionButton.extended(onPressed: () => _editEntry(), icon: const Icon(Icons.add), label: const Text('Add Subject'))
          : null,
      body: Column(
        children: [
          if (widget.canEdit)
            Padding(
              padding: const EdgeInsets.all(16),
              child: classesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Failed to load classes'),
                data: (classes) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      hint: const Text('Select class', style: TextStyle(color: AppColors.textSecondary)),
                      value: _selectedClass,
                      items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v);
                        _load();
                      },
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (widget.canEdit && _selectedClass == null)
                    ? const Center(child: Text('Select a class', style: TextStyle(color: AppColors.textSecondary)))
                    : _items.isEmpty
                        ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No syllabus published yet', style: TextStyle(color: AppColors.textSecondary)))])
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final s = _items[i];
                              final topics = (s['topics_json'] as List? ?? []).cast<Map<String, dynamic>>();
                              final done = topics.where((t) => t['done'] == true).length;
                              return Container(
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                                child: ExpansionTile(
                                  title: Text(s['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: topics.isNotEmpty ? Text('$done / ${topics.length} topics covered', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
                                  trailing: widget.canEdit
                                      ? IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editEntry(existing: s))
                                      : null,
                                  children: [
                                    ...topics.map((t) => ListTile(
                                          dense: true,
                                          leading: Icon(t['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: t['done'] == true ? AppColors.success : AppColors.textSecondary),
                                          title: Text(t['title']?.toString() ?? ''),
                                        )),
                                    if (s['file_url'] != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                        child: LoadingButton(
                                          label: 'Download Syllabus',
                                          loading: false,
                                          onPressed: () => launchUrl(Uri.parse(s['file_url'].toString()), mode: LaunchMode.externalApplication),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
