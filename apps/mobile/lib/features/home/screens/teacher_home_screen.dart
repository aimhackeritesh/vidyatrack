import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Teacher Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications'))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Good Morning!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _ActionCard(
              icon: Icons.fact_check_outlined,
              title: 'Mark Attendance',
              subtitle: 'Attendance for your classes',
              color: AppColors.tileBlue,
              iconColor: AppColors.primary,
              onTap: () => context.go('/home/teacher/attendance'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.assignment_outlined,
              title: 'Assign Homework',
              subtitle: 'Post homework to your sections',
              color: AppColors.tilePink,
              iconColor: const Color(0xFFE57373),
              onTap: () => context.push('/homework/create'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.menu_book_rounded,
              title: 'Study Material',
              subtitle: 'Upload notes and resources',
              color: AppColors.tileGreen,
              iconColor: const Color(0xFF66BB6A),
              onTap: () => context.push('/study-material', extra: {'canUpload': true}),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.event_available_outlined,
              title: 'Apply Leave',
              subtitle: 'Request leave from admin',
              color: AppColors.tilePurple,
              iconColor: const Color(0xFFAB47BC),
              onTap: () => context.push('/leave/apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: iconColor)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 16),
          ],
        ),
      ),
    );
  }
}
