import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Teacher/Admin: assign homework to a section.
class CreateHomeworkScreen extends ConsumerStatefulWidget {
  const CreateHomeworkScreen({super.key});

  @override
  ConsumerState<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends ConsumerState<CreateHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  Map<String, dynamic>? _class;
  Map<String, dynamic>? _section;
  DateTime? _due;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _subject.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final res = await ref.read(dioProvider).get('/classes');
      setState(() => _classes = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _loadSections(String classId) async {
    setState(() {
      _sections = [];
      _section = null;
    });
    try {
      final res = await ref.read(dioProvider).get('/classes/sections', queryParameters: {'classId': classId});
      setState(() => _sections = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_section == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a section')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/academics/homework', data: {
        'sectionId': _section!['id'],
        'subject': _subject.text.trim().isEmpty ? 'General' : _subject.text.trim(),
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        if (_due != null) 'dueDate': DateFormat('yyyy-MM-dd').format(_due!),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework assigned'), backgroundColor: AppColors.success));
      Navigator.of(context).pop();
    } catch (_) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin', 'teacher'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Assign Homework')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _class,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                onChanged: (v) {
                  setState(() => _class = v);
                  if (v != null) _loadSections(v['id'] as String);
                },
                validator: (v) => v == null ? 'Select class' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _section,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Section *'),
                items: _sections.map((s) => DropdownMenuItem(value: s, child: Text('Section ${s['name']}'))).toList(),
                onChanged: (v) => setState(() => _section = v),
                validator: (v) => v == null ? 'Select section' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Details', alignLabelWithHint: true)),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (picked != null) setState(() => _due = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due date'),
                  child: Text(_due == null ? 'Optional' : DateFormat('dd MMM yyyy').format(_due!),
                      style: TextStyle(color: _due == null ? AppColors.textSecondary : AppColors.textPrimary)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Assign Homework'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
