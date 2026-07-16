import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// One bottom-navigation destination within a role shell.
class RoleTab {
  final String location;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const RoleTab({required this.location, required this.icon, required this.activeIcon, required this.label});
}

/// Thin shell that supplies the role's persistent bottom navigation bar.
///
/// Each tab destination keeps its own `Scaffold` (app bar / body); this shell
/// only owns the bottom bar, matching the pattern already used in the app.
class RoleShell extends StatelessWidget {
  final String location;
  final Widget child;
  final List<RoleTab> tabs;
  const RoleShell({super.key, required this.location, required this.child, required this.tabs});

  int get _index {
    final exact = tabs.indexWhere((t) => location == t.location);
    if (exact >= 0) return exact;
    // Fall back to the longest matching prefix (for detail routes under a tab).
    var best = 0, bestLen = -1;
    for (var j = 0; j < tabs.length; j++) {
      if (location.startsWith(tabs[j].location) && tabs[j].location.length > bestLen) {
        best = j;
        bestLen = tabs[j].location.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        onTap: (i) {
          if (i != index) context.go(tabs[i].location);
        },
        items: [
          for (final t in tabs)
            BottomNavigationBarItem(icon: Icon(t.icon), activeIcon: Icon(t.activeIcon), label: t.label),
        ],
      ),
    );
  }
}
