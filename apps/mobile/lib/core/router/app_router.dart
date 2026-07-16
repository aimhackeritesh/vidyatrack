import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/role_picker_screen.dart';
import '../../features/home/screens/admin_home_screen.dart';
import '../../features/home/screens/teacher_home_screen.dart';
import '../../features/home/screens/parent_home_screen.dart';
import '../../features/home/screens/student_home_screen.dart';
import '../../features/home/screens/account_screen.dart';
import '../../features/home/screens/academics_screen.dart';
import '../../features/attendance/screens/class_section_picker_screen.dart';
import '../../features/attendance/screens/attendance_marking_screen.dart';
import '../../features/attendance/screens/my_attendance_screen.dart';
import '../../features/attendance/screens/holiday_calendar_screen.dart';
import '../../features/students/screens/bulk_import_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/auth/screens/force_change_password_screen.dart';
import '../../features/students/screens/add_student_screen.dart';
import '../../features/students/screens/credential_slip_screen.dart';
import '../../features/revenue/screens/today_revenue_screen.dart';
import '../../features/comms/screens/create_notice_screen.dart';
import '../../features/comms/screens/leave_approvals_screen.dart';
import '../../features/comms/screens/suggestions_inbox_screen.dart';
import '../../features/comms/screens/apply_leave_screen.dart';
import '../../features/academics/screens/homework_list_screen.dart';
import '../../features/academics/screens/results_screen.dart';
import '../../features/academics/screens/create_homework_screen.dart';
import '../../features/reports/screens/defaulters_screen.dart';
import '../../features/timetable/screens/timetable_view_screen.dart';
import '../../features/timetable/screens/edit_timetable_screen.dart';
import '../../features/syllabus/screens/syllabus_screen.dart';
import '../../features/study_material/screens/study_material_screen.dart';
import '../../features/fees/screens/fee_structure_screen.dart';
import '../../features/fees/screens/parent_fees_screen.dart';
import '../../features/fees/screens/invoice_detail_screen.dart';
import '../../shared/widgets/role_shell.dart';
import '../constants/app_constants.dart';

/// Single place that decides where a successful auth response should land:
/// role-picker → forced password change → the role's home.
void navigateAfterAuth(BuildContext context, Map<String, dynamic> result) {
  if (result['requiresRoleSelection'] == true) {
    context.go('/role-picker', extra: result);
  } else if (result['mustChangePassword'] == true) {
    context.go('/force-change-password');
  } else {
    context.go(homePathForRole(result['role'] as String?));
  }
}

/// Maps a role to its landing route. Used by splash / OTP / role-picker.
String homePathForRole(String? role) {
  switch (role) {
    case 'admin':
      return '/home/admin';
    case 'teacher':
      return '/home/teacher';
    case 'parent':
      return '/home/parent';
    case 'student':
      return '/home/student';
    default:
      return '/login';
  }
}

// ─── Per-role bottom-nav definitions (§3.2 of the v2 plan) ───────────────────
const _adminTabs = [
  RoleTab(location: '/home/admin', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  RoleTab(location: '/home/attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, label: 'Attendance'),
  RoleTab(location: '/home/account', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Account'),
  RoleTab(location: '/home/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];
const _teacherTabs = [
  RoleTab(location: '/home/teacher', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  RoleTab(location: '/home/teacher/attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, label: 'Attendance'),
  RoleTab(location: '/home/teacher/academics', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Academics'),
  RoleTab(location: '/home/teacher/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];
const _parentTabs = [
  RoleTab(location: '/home/parent', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  RoleTab(location: '/home/parent/attendance', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check_rounded, label: 'Attendance'),
  RoleTab(location: '/home/parent/fees', icon: Icons.payment_outlined, activeIcon: Icons.payment_rounded, label: 'Fees'),
  RoleTab(location: '/home/parent/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];
const _studentTabs = [
  RoleTab(location: '/home/student', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  RoleTab(location: '/home/student/homework', icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Homework'),
  RoleTab(location: '/home/student/results', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Results'),
  RoleTab(location: '/home/student/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>;
          return OtpScreen(schoolCode: extra['schoolCode']!, phone: extra['phone']!);
        },
      ),
      GoRoute(
        path: '/role-picker',
        builder: (_, state) => RolePickerScreen(data: state.extra as Map<String, dynamic>),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/force-change-password', builder: (_, __) => const ForceChangePasswordScreen()),
      GoRoute(path: '/revenue/today', builder: (_, __) => const TodayRevenueScreen()),
      GoRoute(
        path: '/notices/create',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateNoticeScreen(
            title: extra?['title'] as String? ?? 'Create Notice',
            presetAudience: extra?['audience'] as String?,
          );
        },
      ),
      GoRoute(path: '/leave/approvals', builder: (_, __) => const LeaveApprovalsScreen()),
      GoRoute(
        path: '/leave/apply',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ApplyLeaveScreen(studentId: extra?['studentId'] as String?);
        },
      ),
      GoRoute(path: '/my-attendance', builder: (_, __) => const MyAttendanceScreen()),
      GoRoute(path: '/homework/my', builder: (_, __) => const HomeworkListScreen()),
      GoRoute(path: '/homework/create', builder: (_, __) => const CreateHomeworkScreen()),
      GoRoute(path: '/results/my', builder: (_, __) => const ResultsScreen()),
      GoRoute(path: '/reports/defaulters', builder: (_, __) => const DefaultersScreen()),
      GoRoute(
        path: '/timetable/view',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TimetableViewScreen(
            endpoint: extra['endpoint'] as String? ?? '/academics/timetable/my',
            showSection: extra['showSection'] as bool? ?? false,
          );
        },
      ),
      GoRoute(path: '/timetable/edit', builder: (_, __) => const EditTimetableScreen()),
      GoRoute(
        path: '/syllabus',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SyllabusScreen(canEdit: extra?['canEdit'] as bool? ?? false);
        },
      ),
      GoRoute(
        path: '/study-material',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return StudyMaterialScreen(canUpload: extra?['canUpload'] as bool? ?? false);
        },
      ),
      GoRoute(path: '/fees/structure', builder: (_, __) => const FeeStructureScreen()),
      GoRoute(path: '/fees/invoice/:id', builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!)),
      GoRoute(path: '/attendance/holidays', builder: (_, __) => const HolidayCalendarScreen()),
      GoRoute(path: '/students/bulk-import', builder: (_, __) => const BulkImportScreen()),
      GoRoute(path: '/suggestions', builder: (_, __) => const SuggestionsInboxScreen()),
      GoRoute(
        path: '/students/add',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddStudentScreen(
            presetSectionId: extra?['sectionId'] as String?,
            presetSectionLabel: extra?['sectionLabel'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/credential-slip',
        builder: (_, state) => CredentialSlipScreen(data: state.extra as Map<String, dynamic>),
      ),
      // Full-screen attendance marking, reachable from any role's section picker.
      GoRoute(
        path: '/attendance/mark',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>;
          return AttendanceMarkingScreen(sectionId: extra['sectionId']!, sectionName: extra['sectionName']!);
        },
      ),

      // ─── Admin shell ───────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => RoleShell(location: state.matchedLocation, tabs: _adminTabs, child: child),
        routes: [
          GoRoute(path: '/home/admin', builder: (_, __) => const AdminHomeScreen()),
          GoRoute(path: '/home/attendance', builder: (_, __) => const ClassSectionPickerScreen()),
          GoRoute(path: '/home/account', builder: (_, __) => const AccountScreen()),
          GoRoute(path: '/home/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ─── Teacher shell ─────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => RoleShell(location: state.matchedLocation, tabs: _teacherTabs, child: child),
        routes: [
          GoRoute(path: '/home/teacher', builder: (_, __) => const TeacherHomeScreen()),
          GoRoute(path: '/home/teacher/attendance', builder: (_, __) => const ClassSectionPickerScreen()),
          GoRoute(path: '/home/teacher/academics', builder: (_, __) => const AcademicsScreen()),
          GoRoute(path: '/home/teacher/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ─── Parent shell ──────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => RoleShell(location: state.matchedLocation, tabs: _parentTabs, child: child),
        routes: [
          GoRoute(path: '/home/parent', builder: (_, __) => const ParentHomeScreen()),
          GoRoute(path: '/home/parent/attendance', builder: (_, __) => const MyAttendanceScreen()),
          GoRoute(path: '/home/parent/fees', builder: (_, __) => const ParentFeesScreen()),
          GoRoute(path: '/home/parent/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ─── Student shell ─────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => RoleShell(location: state.matchedLocation, tabs: _studentTabs, child: child),
        routes: [
          GoRoute(path: '/home/student', builder: (_, __) => const StudentHomeScreen()),
          GoRoute(path: '/home/student/homework', builder: (_, __) => const HomeworkListScreen()),
          GoRoute(path: '/home/student/results', builder: (_, __) => const ResultsScreen()),
          GoRoute(path: '/home/student/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final role = prefs.getString(AppConstants.userRoleKey);
    final mustChange = prefs.getBool(AppConstants.mustChangePasswordKey) ?? false;
    if (!mounted) return;
    if (token == null) {
      context.go('/login');
      return;
    }
    if (mustChange) {
      context.go('/force-change-password');
      return;
    }
    context.go(homePathForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 80, color: Color(0xFF1E88E5)),
            SizedBox(height: 16),
            Text('VidyaTrack', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5))),
            SizedBox(height: 8),
            Text('Smart School Management', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
