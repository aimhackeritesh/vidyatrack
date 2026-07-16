import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(schoolProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: schoolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load profile')),
        data: (school) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ── School logo ────────────────────────────────────────────
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: school['logo_url'] != null
                    ? ClipOval(child: Image.network(school['logo_url'], fit: BoxFit.cover))
                    : const Icon(Icons.school_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),

              // ── Fields ────────────────────────────────────────────────
              _ReadonlyField('School Name', school['name'] ?? ''),
              const SizedBox(height: 12),
              _ReadonlyField('School Code', school['code'] ?? ''),
              const SizedBox(height: 12),
              _ReadonlyField('Email Address', school['email'] ?? ''),
              const SizedBox(height: 12),
              _ReadonlyField('Mobile Number', school['phone'] ?? ''),
              const SizedBox(height: 12),
              _ReadonlyField('Principal Name', school['principal_name'] ?? ''),
              const SizedBox(height: 12),
              _ReadonlyField('Address', '${school['address'] ?? ''}, ${school['city'] ?? ''}'),
              const SizedBox(height: 32),

              // ── Logout ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),

              // ── Change Password ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () => _showChangePasswordDialog(context, ref),
                  child: const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Old password', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'New password', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final oldPw = oldCtrl.text.trim();
              final newPw = newCtrl.text.trim();
              if (oldPw.isEmpty || newPw.length < 8) {
                messenger.showSnackBar(const SnackBar(content: Text('Enter old password and a new password (min 8 chars)')));
                return;
              }
              Navigator.pop(context);
              final error = await ref.read(authProvider.notifier).changePassword(oldPassword: oldPw, newPassword: newPw);
              messenger.showSnackBar(SnackBar(
                content: Text(error ?? 'Password changed successfully'),
                backgroundColor: error == null ? AppColors.success : AppColors.error,
              ));
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadonlyField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
