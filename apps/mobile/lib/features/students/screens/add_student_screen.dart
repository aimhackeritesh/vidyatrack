import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Admin/Teacher form to enrol a student. On success the API returns one-time
/// Student + Parent credentials, which we hand to the Credential Slip screen.
class AddStudentScreen extends ConsumerStatefulWidget {
  final String? presetSectionId;
  final String? presetSectionLabel;
  const AddStudentScreen({super.key, this.presetSectionId, this.presetSectionLabel});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rollNo = TextEditingController();
  final _admissionNo = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSection;
  String _gender = 'M';
  DateTime? _dob;
  bool _submitting = false;

  bool get _locked => widget.presetSectionId != null;

  @override
  void initState() {
    super.initState();
    if (!_locked) _loadClasses();
  }

  @override
  void dispose() {
    _name.dispose();
    _rollNo.dispose();
    _admissionNo.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final res = await ref.read(dioProvider).get('/classes');
      setState(() => _classes = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {/* shown via empty dropdown */}
  }

  Future<void> _loadSections(String classId) async {
    setState(() {
      _sections = [];
      _selectedSection = null;
    });
    try {
      final res = await ref.read(dioProvider).get('/classes/sections', queryParameters: {'classId': classId});
      setState(() => _sections = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final sectionId = widget.presetSectionId ?? _selectedSection?['id'] as String?;
    if (sectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a class and section')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ref.read(dioProvider).post('/students', data: {
        'name': _name.text.trim(),
        'sectionId': sectionId,
        if (_rollNo.text.trim().isNotEmpty) 'rollNo': int.tryParse(_rollNo.text.trim()),
        if (_admissionNo.text.trim().isNotEmpty) 'admissionNo': _admissionNo.text.trim(),
        'gender': _gender,
        if (_dob != null) 'dob': DateFormat('yyyy-MM-dd').format(_dob!),
        'guardianName': _guardianName.text.trim(),
        'guardianPhone': _guardianPhone.text.trim(),
        'admissionDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      final data = res.data as Map<String, dynamic>;
      final student = (data['student'] as Map?) ?? {};
      final credentials = (data['credentials'] as Map?) ?? {};
      final prefs = await SharedPreferences.getInstance();
      final className = widget.presetSectionLabel ??
          'Class ${student['class_name'] ?? ''} - ${student['section_name'] ?? ''}';
      if (!mounted) return;
      context.go('/credential-slip', extra: {
        'schoolName': prefs.getString(AppConstants.schoolNameKey) ?? 'VidyaTrack',
        'schoolCode': prefs.getString(AppConstants.schoolCodeKey) ?? '',
        'studentName': student['name'] ?? _name.text.trim(),
        'className': className,
        'student': credentials['student'],
        'parent': credentials['parent'],
        'homePath': homePathForRole(prefs.getString(AppConstants.userRoleKey)),
      });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add student'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Student'),
        actions: [
          IconButton(
            tooltip: 'Bulk import (CSV)',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.push('/students/bulk-import'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Section: ${widget.presetSectionLabel ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Student name *'),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter name' : null,
            ),
            const SizedBox(height: 14),
            if (!_locked) ...[
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedClass,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class *'),
                items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class ${c['name']}'))).toList(),
                onChanged: (v) {
                  setState(() => _selectedClass = v);
                  if (v != null) _loadSections(v['id'] as String);
                },
                validator: (v) => v == null ? 'Select class' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedSection,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Section *'),
                items: _sections.map((s) => DropdownMenuItem(value: s, child: Text('Section ${s['name']}'))).toList(),
                onChanged: (v) => setState(() => _selectedSection = v),
                validator: (v) => v == null ? 'Select section' : null,
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rollNo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Roll no'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Male')),
                      DropdownMenuItem(value: 'F', child: Text('Female')),
                      DropdownMenuItem(value: 'O', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? 'M'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _admissionNo,
              decoration: const InputDecoration(labelText: 'Admission no', hintText: 'Leave blank to auto-generate'),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2018, 1, 1),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of birth'),
                child: Text(_dob == null ? 'Optional' : DateFormat('dd MMM yyyy').format(_dob!),
                    style: TextStyle(color: _dob == null ? AppColors.textSecondary : AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _guardianName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Guardian name *'),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter guardian name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _guardianPhone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Guardian phone *'),
              validator: (v) => (v == null || v.length != 10) ? 'Enter 10-digit phone' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Add Student & Generate Logins'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
