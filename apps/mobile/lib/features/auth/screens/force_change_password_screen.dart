import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_constants.dart';

/// Shown after first login with a generated (temporary) password.
/// The user must set a new password before reaching their home shell.
class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends ConsumerState<ForceChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_oldCtrl.text.isEmpty || _newCtrl.text.length < 8) {
      messenger.showSnackBar(const SnackBar(content: Text('New password must be at least 8 characters')));
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      messenger.showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).changePassword(oldPassword: _oldCtrl.text, newPassword: _newCtrl.text);
    setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.mustChangePasswordKey, false);
    final role = prefs.getString(AppConstants.userRoleKey);
    if (!mounted) return;
    context.go(homePathForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.lock_reset_rounded, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Set a new password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('For your security, please change the temporary password you were given.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 28),
              TextField(controller: _oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password')),
              const SizedBox(height: 16),
              TextField(controller: _newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 8 chars)')),
              const SizedBox(height: 16),
              TextField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Change Password'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Logout', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
