import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/loading_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String schoolCode;
  final String phone;

  const OtpScreen({super.key, required this.schoolCode, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrlrs = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) { t.cancel(); return; }
      setState(() => _resendCountdown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrlrs) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otp => _ctrlrs.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter complete 6-digit OTP')));
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).verifyOtp(
      schoolCode: widget.schoolCode,
      phone: widget.phone,
      otp: _otp,
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error']), backgroundColor: AppColors.error));
      return;
    }

    navigateAfterAuth(context, result);
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    await ref.read(authProvider.notifier).sendOtp(schoolCode: widget.schoolCode, phone: widget.phone);
    setState(() => _resendCountdown = 30);
    _startTimer();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP resent!')));
  }

  @override
  Widget build(BuildContext context) {
    final masked = '*' * (widget.phone.length - 4) + widget.phone.substring(widget.phone.length - 4);
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('Verify OTP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Enter the 6-digit OTP sent to +91 $masked', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrlrs[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
                    if (v.isEmpty && i > 0) FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
                    if (_otp.length == 6) _verify();
                  },
                )),
              ),
              const SizedBox(height: 40),
              LoadingButton(label: 'Verify OTP', loading: _loading, onPressed: _verify),
              const SizedBox(height: 20),
              Center(
                child: _resendCountdown > 0
                    ? Text('Resend OTP in $_resendCountdown s', style: const TextStyle(color: AppColors.textSecondary))
                    : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    );
  }
}
