import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Placeholder for a tab/feature that is planned for a later phase.
/// Used so navigation always lands somewhere informative — never a dead tap.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String message;
  const ComingSoonScreen({
    super.key,
    required this.title,
    this.message = 'This section is coming in a future update.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
