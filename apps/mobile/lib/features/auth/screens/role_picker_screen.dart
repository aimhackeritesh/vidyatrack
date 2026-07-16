import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class RolePickerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const RolePickerScreen({super.key, required this.data});

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen> {
  bool _loading = false;

  Future<void> _selectRole(Map<String, dynamic> roleEntry) async {
    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).selectRole(roleEntry['id']);
    setState(() => _loading = false);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'].toString())));
      return;
    }
    navigateAfterAuth(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final roles = (widget.data['roles'] as List).cast<Map<String, dynamic>>();
    final user = widget.data['user'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text('Select Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Hello, ${user['name'] ?? 'User'}! Choose a profile to continue.', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final r = roles[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(r['role']).withValues(alpha: 0.15),
                          radius: 24,
                          child: Icon(_roleIcon(r['role']), color: _roleColor(r['role'])),
                        ),
                        title: Text(_roleLabel(r['role']), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r['schoolName'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: _loading ? null : () => _selectRole(r),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppColors.primary;
      case 'teacher': return const Color(0xFF388E3C);
      case 'parent': return const Color(0xFFE64A19);
      default: return AppColors.accent;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'teacher': return Icons.cast_for_education_rounded;
      case 'parent': return Icons.family_restroom_rounded;
      default: return Icons.person_rounded;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'School Admin';
      case 'teacher': return 'Teacher';
      case 'parent': return 'Parent';
      case 'student': return 'Student';
      default: return role;
    }
  }
}
