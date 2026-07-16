import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/home_provider.dart';
import '../widgets/attendance_chart_card.dart';
import '../widgets/daily_revenue_card.dart';
import '../widgets/quick_links_row.dart';
import '../widgets/academics_grid.dart';
import '../widgets/comm_speed_dial.dart';
import 'app_drawer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  String _schoolName = '';
  String _schoolCode = '';

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
  }

  Future<void> _loadSchoolInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _schoolCode = prefs.getString(AppConstants.schoolCodeKey) ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolProfileProvider);
    final unreadAsync = ref.watch(unreadNotifCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      // B4: the comms FAB is a proper Scaffold FAB so it floats above content
      // predictably (no overlap with the Daily Revenue rows).
      floatingActionButton: const CommSpeedDial(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
                // ─── App Bar ─────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  leading: Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  title: schoolAsync.when(
                    data: (s) => Text(s['code'] ?? _schoolCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    loading: () => Text(_schoolCode, style: const TextStyle(fontSize: 14)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  actions: [
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                          onPressed: () => context.push('/notifications'),
                        ),
                        unreadAsync.when(
                          data: (count) => count > 0
                              ? Positioned(
                                  top: 8, right: 8,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                    child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Welcome ─────────────────────────────────────
                        schoolAsync.when(
                          data: (s) {
                            final name = s['name'] ?? '';
                            if (_schoolName != name) Future.microtask(() => setState(() => _schoolName = name));
                            return Text('Welcome $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
                          },
                          loading: () => Container(width: 200, height: 20, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
                          error: (_, __) => const Text('Welcome', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 20),

                        // ─── Attendance chart cards (swipeable) ──────────
                        const AttendanceChartRow(),
                        const SizedBox(height: 20),

                        // ─── Quick Links ─────────────────────────────────
                        const Text('Quick Links', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        const QuickLinksRow(),
                        const SizedBox(height: 20),

                        // ─── Daily Revenue ───────────────────────────────
                        const DailyRevenueCard(),
                        const SizedBox(height: 20),

                        // ─── Academics grid ──────────────────────────────
                        const Text('Academics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        const AcademicsGrid(role: 'admin'),
                        const SizedBox(height: 20),

                        // ─── Account grid ────────────────────────────────
                        const Text('Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        const AccountGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }
}
