import 'package:flutter/material.dart';
import '../widgets/academics_grid.dart' show AcademicsGrid;
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/role_gate.dart';

/// Teacher "Academics" tab — study material, homework, results, syllabus grid.
/// Tiles open their own screens in Phase 4.
class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGate(
      allowed: const ['teacher', 'admin'],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Academics')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              AcademicsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
