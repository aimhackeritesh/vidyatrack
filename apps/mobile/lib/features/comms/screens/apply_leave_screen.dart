import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Apply for leave. Teacher applies for self; a parent passes [studentId] for a child.
/// The backend resolves the applicant from the JWT role.
class ApplyLeaveScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const ApplyLeaveScreen({super.key, this.studentId});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  DateTime? _from;
  DateTime? _to;
  final _reason = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_from == null || _to == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick from and to dates')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post('/notifications/leave', data: {
        if (widget.studentId != null) 'studentId': widget.studentId,
        'fromDate': DateFormat('yyyy-MM-dd').format(_from!),
        'toDate': DateFormat('yyyy-MM-dd').format(_to!),
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Leave request submitted'), backgroundColor: AppColors.success));
      Navigator.of(context).pop();
    } catch (_) {
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not submit leave'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dateTile('From', _from, () => _pick(true)),
          const SizedBox(height: 12),
          _dateTile('To', _to, () => _pick(false)),
          const SizedBox(height: 16),
          TextField(controller: _reason, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true)),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit Request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Select date' : DateFormat('dd MMM yyyy').format(value),
            style: TextStyle(color: value == null ? AppColors.textSecondary : AppColors.textPrimary)),
      ),
    );
  }
}
