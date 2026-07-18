import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_button.dart';

/// Password login: School Code + (phone or login-ID) + password.
/// OTP/SMS is not wired in V1, so this is the single login path.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // A 10-digit number is a phone; anything else (e.g. STU-2026001) is a login ID.
    final id = _idCtrl.text.trim();
    final isPhone = RegExp(r'^\d{10}$').hasMatch(id);

    final result = await ref.read(authProvider.notifier).loginPassword(
          schoolCode: _codeCtrl.text.trim().toUpperCase(),
          phone: isPhone ? id : null,
          loginId: isPhone ? null : id.toUpperCase(),
          password: _passCtrl.text,
        );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'].toString()), backgroundColor: AppColors.error));
      return;
    }
    navigateAfterAuth(context, result);
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
                const Text('Log in with your school code & password', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                  controller: _idCtrl,
                  label: 'Phone or Login ID',
                  hint: '10-digit phone or e.g. STU-2026001',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your phone or login ID' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: 'Your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  suffixIcon: _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  onSuffixTap: () => setState(() => _obscure = !_obscure),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 32),
                LoadingButton(
                  label: 'Login',
                  loading: _loading,
                  onPressed: _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
