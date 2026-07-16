import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../timetable/screens/timetable_view_screen.dart';

/// Student home: today's timetable, homework due, study material, syllabus, attendance %.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My School'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Hello!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _Tile(Icons.schedule_rounded, "Today's Timetable", AppColors.tileBlue, const Color(0xFF42A5F5),
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableViewScreen(endpoint: '/academics/timetable/my')))),
          const SizedBox(height: 12),
          _Tile(Icons.assignment_outlined, 'Homework Due', AppColors.tilePink, const Color(0xFFE57373), () => context.push('/homework/my')),
          const SizedBox(height: 12),
          _Tile(Icons.menu_book_rounded, 'Study Material', AppColors.tileGreen, const Color(0xFF66BB6A), () => context.push('/study-material')),
          const SizedBox(height: 12),
          _Tile(Icons.auto_stories_outlined, 'Syllabus', AppColors.tilePurple, const Color(0xFFAB47BC), () => context.push('/syllabus')),
          const SizedBox(height: 12),
          _Tile(Icons.fact_check_outlined, 'My Attendance', AppColors.tileLavender, const Color(0xFF7E57C2), () => context.push('/my-attendance')),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;
  const _Tile(this.icon, this.label, this.bg, this.iconColor, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: iconColor)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 16),
          ],
        ),
      ),
    );
  }
}
