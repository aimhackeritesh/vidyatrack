import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/file_upload_field.dart';

final _classesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/classes');
  return (res.data as List).cast<Map<String, dynamic>>();
});

IconData _iconFor(String? type) {
  if (type == 'pdf' || (type?.contains('pdf') ?? false)) return Icons.picture_as_pdf_rounded;
  if (type == 'image' || (type?.contains('image') ?? false)) return Icons.image_rounded;
  return Icons.link_rounded;
}

/// Browse + (for admin/teacher) upload study material. [canUpload] shows the FAB;
/// parent/student get `/academics/materials/my` (their own class, no picker needed).
class StudyMaterialScreen extends ConsumerStatefulWidget {
  final bool canUpload;
  const StudyMaterialScreen({super.key, this.canUpload = false});

  @override
  ConsumerState<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends ConsumerState<StudyMaterialScreen> {
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
      final res = widget.canUpload
          ? await ref.read(dioProvider).get('/academics/materials')
          : await ref.read(dioProvider).get('/academics/materials/my');
      _items = (res.data as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    final classes = await ref.read(_classesProvider.future);
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    Map<String, dynamic>? selectedClass;
    String? fileUrl;
    String fileType = 'link';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Upload Study Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                  onChanged: (v) => setSt(() => selectedClass = v),
                ),
                const SizedBox(height: 12),
                FileUploadField(onChanged: (u) => setSt(() {
                  fileUrl = u;
                  fileType = u != null && u.toLowerCase().contains('.pdf') ? 'pdf' : (u != null ? 'image' : 'link');
                })),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: titleCtrl.text.trim().isEmpty || selectedClass == null
                  ? null
                  : () async {
                      await ref.read(dioProvider).post('/academics/materials', data: {
                        'classId': selectedClass!['id'],
                        'subject': subjectCtrl.text.trim().isEmpty ? 'General' : subjectCtrl.text.trim(),
                        'title': titleCtrl.text.trim(),
                        'fileUrl': fileUrl,
                        'type': fileType,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Study Material')),
      floatingActionButton: widget.canUpload
          ? FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.upload_file_rounded), label: const Text('Upload'))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 160), Center(child: Text('No study material yet', style: TextStyle(color: AppColors.textSecondary)))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44, alignment: Alignment.center,
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_iconFor(m['type']?.toString()), color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text(
                                      [m['subject']?.toString(), m['class_name'] != null ? 'Class ${m['class_name']}' : null].whereType<String>().join(' · '),
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (m['file_url'] != null)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                                  onPressed: () => launchUrl(Uri.parse(m['file_url'].toString()), mode: LaunchMode.externalApplication),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
