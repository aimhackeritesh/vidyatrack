import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// UI-side role guard (defence in depth — the API enforces roles authoritatively
/// via the RolesGuard). Renders [child] only when the signed-in role is allowed.
class RoleGate extends StatelessWidget {
  final List<String> allowed;
  final Widget child;
  const RoleGate({super.key, required this.allowed, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final role = snap.data!.getString(AppConstants.userRoleKey);
        if (role == null || !allowed.contains(role)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('You do not have access to this section.', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
