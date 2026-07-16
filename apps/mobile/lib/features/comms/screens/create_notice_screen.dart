import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin: compose a notice. Sending fans out a notification to the audience.
/// Reused for "Notify Student / Notify Faculty" (audience preset).
class CreateNoticeScreen extends ConsumerStatefulWidget {
  final String title;
  final String? presetAudience;
  const CreateNoticeScreen({super.key, this.title = 'Create Notice', this.presetAudience});

  @override
  ConsumerState<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends ConsumerState<CreateNoticeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late String _audience;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _audience = widget.presetAudience ?? 'all';
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a title and message')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post('/notifications/notices', data: {
        'audience': _audience,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
      });
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Notice sent'), backgroundColor: AppColors.success));
      Navigator.of(context).pop();
    } catch (_) {
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not send notice'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _audience,
              decoration: const InputDecoration(labelText: 'Send to'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Everyone')),
                DropdownMenuItem(value: 'parents', child: Text('All Parents')),
                DropdownMenuItem(value: 'teachers', child: Text('All Teachers')),
                DropdownMenuItem(value: 'students', child: Text('All Students')),
              ],
              onChanged: (v) => setState(() => _audience = v ?? 'all'),
            ),
            const SizedBox(height: 16),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            TextField(controller: _body, maxLines: 5, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Notice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
