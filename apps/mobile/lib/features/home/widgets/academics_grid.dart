import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/coming_soon_screen.dart';

/// [role] decides where "Class Routine" (timetable) lands: admin edits the
/// grid, teacher sees their own teaching schedule.
class AcademicsGrid extends StatelessWidget {
  final String role;
  const AcademicsGrid({super.key, this.role = 'teacher'});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile('Study Material', AppColors.tilePink, Icons.menu_book_rounded, const Color(0xFFE57373),
          onTap: (ctx) => ctx.push('/study-material', extra: {'canUpload': true})),
      _Tile('Class Routine', AppColors.tilePeach, Icons.calendar_today_rounded, const Color(0xFFFF8A65),
          onTap: (ctx) => role == 'admin'
              ? ctx.push('/timetable/edit')
              : ctx.push('/timetable/view', extra: {'endpoint': '/academics/timetable/my-teaching', 'showSection': true})),
      const _Tile('Home Work', AppColors.tileBlue, Icons.assignment_outlined, Color(0xFF42A5F5)),
      const _Tile('Result', AppColors.tilePurple, Icons.bar_chart_rounded, Color(0xFFAB47BC)),
      const _Tile('Attendance', AppColors.tileLavender, Icons.fact_check_outlined, Color(0xFF7E57C2)),
      _Tile('Syllabus', AppColors.tileGreen, Icons.auto_stories_outlined, const Color(0xFF66BB6A),
          onTap: (ctx) => ctx.push('/syllabus', extra: {'canEdit': true})),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.3,
        children: tiles.map((t) => _GridTile(tile: t)).toList(),
      ),
    );
  }
}

class AccountGrid extends StatelessWidget {
  const AccountGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile('Total Revenue', AppColors.tileBlue, Icons.account_balance_wallet_outlined, const Color(0xFF42A5F5),
          onTap: (ctx) => ctx.push('/revenue/today')),
      _Tile('Fee Structure', AppColors.tileLavender, Icons.request_quote_outlined, const Color(0xFF7E57C2),
          onTap: (ctx) => ctx.push('/fees/structure')),
      const _Tile('Student Wise Report', AppColors.tilePeach, Icons.people_outline_rounded, Color(0xFFFF8A65)),
      const _Tile('Expenses', AppColors.tileMauve, Icons.receipt_long_outlined, Color(0xFF8D6E63)),
      _Tile('Generate Report', AppColors.tileOrange, Icons.summarize_outlined, const Color(0xFFFF7043),
          onTap: (ctx) => ctx.push('/reports/defaulters')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.3,
        children: tiles.map((t) => _GridTile(tile: t)).toList(),
      ),
    );
  }
}

class _Tile {
  final String label;
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final void Function(BuildContext)? onTap;
  const _Tile(this.label, this.bg, this.icon, this.iconColor, {this.onTap});
}

class _GridTile extends StatelessWidget {
  final _Tile tile;
  const _GridTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => tile.onTap != null
          ? tile.onTap!(context)
          : Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(title: tile.label))),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: tile.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Icon(tile.icon, size: 40, color: tile.iconColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(tile.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tile.iconColor)),
            ),
          ],
        ),
      ),
    );
  }
}
