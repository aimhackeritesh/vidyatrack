import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';

/// One-time credential slip shown after creating a student.
/// `data` shape: { schoolName, schoolCode, studentName, className,
///                 student:{loginId,password}, parent:{loginId,password?,reused?} }
class CredentialSlipScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const CredentialSlipScreen({super.key, required this.data});

  String get _slipText {
    final s = data['student'] as Map? ?? {};
    final p = data['parent'] as Map? ?? {};
    final b = StringBuffer();
    b.writeln('${data['schoolName'] ?? 'VidyaTrack'} — Login details');
    b.writeln('School Code: ${data['schoolCode'] ?? ''}');
    b.writeln('Student: ${data['studentName'] ?? ''}  (${data['className'] ?? ''})');
    b.writeln('');
    b.writeln('STUDENT LOGIN');
    b.writeln('  ID: ${s['loginId'] ?? ''}');
    b.writeln('  Password: ${s['password'] ?? ''}');
    b.writeln('');
    if (p['reused'] == true) {
      b.writeln('PARENT LOGIN: ${p['loginId'] ?? ''} (uses existing account & password)');
    } else {
      b.writeln('PARENT LOGIN');
      b.writeln('  ID: ${p['loginId'] ?? ''}');
      b.writeln('  Password: ${p['password'] ?? ''}');
    }
    b.writeln('');
    b.writeln('Download the VidyaTrack app and log in with School Code + ID + Password.');
    b.writeln('You will be asked to set a new password on first login.');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = data['student'] as Map? ?? {};
    final p = data['parent'] as Map? ?? {};
    final reused = p['reused'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Credentials'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_user_rounded, size: 56, color: AppColors.success),
            const SizedBox(height: 8),
            Center(child: Text('${data['studentName'] ?? 'Student'} added', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            Center(child: Text('${data['className'] ?? ''}', style: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(height: 20),
            const Text(
              'Share these credentials now — the passwords are shown only once.',
              style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _CredCard(
              title: 'Student Login',
              icon: Icons.school_rounded,
              loginId: s['loginId']?.toString() ?? '',
              password: s['password']?.toString() ?? '',
            ),
            const SizedBox(height: 12),
            _CredCard(
              title: 'Parent Login',
              icon: Icons.family_restroom_rounded,
              loginId: p['loginId']?.toString() ?? '',
              password: reused ? null : p['password']?.toString(),
              note: reused ? 'Linked to an existing parent account (same password as before).' : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _slipText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials copied')));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Share.share(_slipText, subject: 'VidyaTrack login details'),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go(data['homePath']?.toString() ?? '/home/admin'),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String loginId;
  final String? password;
  final String? note;
  const _CredCard({required this.title, required this.icon, required this.loginId, this.password, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 20, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          _kv('Login ID', loginId),
          if (password != null) ...[const SizedBox(height: 6), _kv('Password', password!)],
          if (note != null) ...[const SizedBox(height: 6), Text(note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.5))),
      ],
    );
  }
}
