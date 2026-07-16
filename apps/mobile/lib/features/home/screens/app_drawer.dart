import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/providers/auth_provider.dart';

// Static support / store / legal links used by the drawer.
const _supportEmail = 'mailto:support@vidyatrack.in';
const _playStoreUrl = 'https://play.google.com/store/apps/details?id=in.vidyatrack.app';
const _privacyUrl = 'https://vidyatrack.in/privacy';
const _termsUrl = 'https://vidyatrack.in/terms';

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(0), bottomRight: Radius.circular(0))),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────────────────────────────────
            _DrawerHeader(),
            const Divider(height: 1),

            // ─── Menu items ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Live Class / Gallery / Polls are Phase 2 — hidden until built
                  // (zero-dead-buttons rule).
                  _DrawerItem(Icons.home_outlined, 'Home', () { Navigator.pop(context); context.go('/home/admin'); }),
                  _DrawerItem(Icons.info_outline_rounded, 'About Us', () { Navigator.pop(context); _showAbout(context); }),
                  _DrawerItem(Icons.headset_mic_outlined, 'Support', () { Navigator.pop(context); _launch(_supportEmail); }),
                  const Divider(),
                  _DrawerItem(Icons.star_outline_rounded, 'Rate us on Play Store', () { Navigator.pop(context); _launch(_playStoreUrl); }),
                  _DrawerItem(Icons.shield_outlined, 'Privacy Policy', () { Navigator.pop(context); _launch(_privacyUrl); }),
                  _DrawerItem(Icons.gavel_outlined, 'Terms & Conditions', () { Navigator.pop(context); _launch(_termsUrl); }),
                ],
              ),
            ),

            // ─── Logout ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.primary),
                title: const Text('Logout', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAbout(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: AppConstants.appName,
    applicationVersion: '1.0.0',
    applicationIcon: const Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
    children: const [
      SizedBox(height: 8),
      Text('VidyaTrack — smart school management for attendance, fees, and communication.'),
    ],
  );
}

class _DrawerHeader extends StatefulWidget {
  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(AppConstants.schoolNameKey) ?? 'School';
    if (mounted) setState(() => _name = name);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(_name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 24,
    );
  }
}
