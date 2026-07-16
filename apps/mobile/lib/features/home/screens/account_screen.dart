import 'package:flutter/material.dart';
import '../widgets/academics_grid.dart' show AccountGrid;
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Admin "Account" tab — the finance/reports grid. Individual tiles open their
/// own screens in later phases (Phase 3 revenue, Phase 4 reports).
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Account')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finance & Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              AccountGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
