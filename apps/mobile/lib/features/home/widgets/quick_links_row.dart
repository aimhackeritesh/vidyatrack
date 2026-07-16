import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/coming_soon_screen.dart';

class QuickLinksRow extends StatelessWidget {
  const QuickLinksRow({super.key});

  @override
  Widget build(BuildContext context) {
    void soon(String title) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title)),
        );
    final links = [
      _QuickLink('Student\nSearch', Icons.search_rounded, const Color(0xFF64B5F6), () => soon('Student Search')),
      _QuickLink('Suggestion', Icons.lightbulb_outline_rounded, const Color(0xFF81C784), () => context.push('/suggestions')),
      _QuickLink('Generate\nReport', Icons.assessment_outlined, const Color(0xFFFFB74D), () => context.push('/reports/defaulters')),
      _QuickLink('Notice', Icons.campaign_outlined, const Color(0xFFBA68C8), () => context.push('/notices/create')),
      _QuickLink('Leave', Icons.event_available_outlined, const Color(0xFFFF8A65), () => context.push('/leave/approvals')),
    ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: links.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _QuickLinkTile(link: links[i]),
      ),
    );
  }
}

class _QuickLink {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink(this.label, this.icon, this.color, this.onTap);
}

class _QuickLinkTile extends StatelessWidget {
  final _QuickLink link;
  const _QuickLinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: link.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: link.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(link.icon, color: link.color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            link.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF424242)),
          ),
        ],
      ),
    );
  }
}
