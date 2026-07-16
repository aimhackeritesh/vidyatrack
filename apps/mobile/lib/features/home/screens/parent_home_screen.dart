import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  Future<void> _applyLeave(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ref.read(dioProvider).get('/fees/my-dues');
      final studentId = (res.data as Map)['studentId'] as String?;
      if (!context.mounted) return;
      if (studentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No child linked to this account')));
        return;
      }
      context.push('/leave/apply', extra: {'studentId': studentId});
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load your child — try again')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Parent Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Child', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _ParentTile(Icons.fact_check_outlined, 'Attendance', AppColors.tileBlue, AppColors.primary, () => context.go('/home/parent/attendance')),
            const SizedBox(height: 12),
            _ParentTile(Icons.schedule_rounded, 'Timetable', AppColors.tileLavender, const Color(0xFF7E57C2),
                () => context.push('/timetable/view', extra: {'endpoint': '/academics/timetable/my'})),
            const SizedBox(height: 12),
            _ParentTile(Icons.payment_outlined, 'Fee Status', AppColors.tilePeach, const Color(0xFFFF8A65), () => context.go('/home/parent/fees')),
            const SizedBox(height: 12),
            _ParentTile(Icons.assignment_outlined, 'Homework', AppColors.tilePink, const Color(0xFFE57373), () => context.push('/homework/my')),
            const SizedBox(height: 12),
            _ParentTile(Icons.bar_chart_rounded, 'Results', AppColors.tilePurple, const Color(0xFFAB47BC), () => context.push('/results/my')),
            const SizedBox(height: 12),
            _ParentTile(Icons.menu_book_rounded, 'Study Material', AppColors.tilePink, const Color(0xFFE57373), () => context.push('/study-material')),
            const SizedBox(height: 12),
            _ParentTile(Icons.auto_stories_outlined, 'Syllabus', AppColors.tileGreen, const Color(0xFF66BB6A), () => context.push('/syllabus')),
            const SizedBox(height: 12),
            _ParentTile(Icons.campaign_outlined, 'Notices', AppColors.tileGreen, const Color(0xFF66BB6A), () => context.push('/notifications')),
            const SizedBox(height: 12),
            _ParentTile(Icons.event_available_outlined, 'Apply Leave', AppColors.tilePurple, const Color(0xFFAB47BC), () => _applyLeave(context, ref)),
          ],
        ),
      ),
    );
  }
}

class _ParentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;
  const _ParentTile(this.icon, this.label, this.bg, this.iconColor, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: iconColor)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 14),
          ],
        ),
      ),
    );
  }
}
