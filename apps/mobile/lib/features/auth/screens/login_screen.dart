import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).sendOtp(
      schoolCode: _codeCtrl.text.trim().toUpperCase(),
      phone: _phoneCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
      return;
    }
    context.push('/otp', extra: {'schoolCode': _codeCtrl.text.trim().toUpperCase(), 'phone': _phoneCtrl.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.school_rounded, size: 44, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      const Text('VidyaTrack', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Text('Smart School Management', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                const Text('Welcome Back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Login with your school code & mobile', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _codeCtrl,
                  label: 'School Code',
                  hint: 'e.g. VDTRK2627DEMO01',
                  prefixIcon: Icons.domain_rounded,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Enter school code' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneCtrl,
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter mobile number';
                    if (v.length != 10) return 'Enter 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                LoadingButton(
                  label: 'Send OTP',
                  loading: _loading,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => _showPasswordDialog(),
                    child: const Text('Login with ID & Password', style: TextStyle(color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog() {
    final idCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Login with ID & Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Login ID e.g. STU-2026001', isDense: true)),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (_codeCtrl.text.trim().isEmpty) {
                messenger.showSnackBar(const SnackBar(content: Text('Enter your School Code first')));
                return;
              }
              if (idCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
              Navigator.pop(context);
              setState(() => _loading = true);
              final result = await ref.read(authProvider.notifier).loginPassword(
                schoolCode: _codeCtrl.text.trim().toUpperCase(),
                loginId: idCtrl.text.trim().toUpperCase(),
                password: passCtrl.text,
              );
              setState(() => _loading = false);
              if (!mounted) return;
              if (result['error'] != null) {
                messenger.showSnackBar(SnackBar(content: Text(result['error'].toString()), backgroundColor: AppColors.error));
                return;
              }
              navigateAfterAuth(context, result);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
