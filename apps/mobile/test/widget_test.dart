// VidyaTrack smoke + logic tests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidyatrack/core/config/school_config.dart';
import 'package:vidyatrack/core/router/app_router.dart';
import 'package:vidyatrack/shared/widgets/coming_soon_screen.dart';
import 'package:vidyatrack/features/auth/screens/login_screen.dart';

void main() {
  group('SchoolConfig (V4 settings)', () {
    test('defaults mirror the API registry defaults', () {
      const c = SchoolConfig.defaults();
      expect(c.periodsPerDay, 8);
      expect(c.defaulterThreshold, 75);
      expect(c.dueDateDay, 10);
      expect(c.workingDayNumbers, [1, 2, 3, 4, 5, 6]);
      expect(c.language, 'en');
      expect(c.showLogo, isTrue);
    });

    test('reads typed values out of an API response', () {
      final c = SchoolConfig.fromResponse({
        'settings': {
          'timetable.periods_per_day': 6,
          'attendance.defaulter_threshold': 65,
          'branding.show_logo': false,
          'locale.language': 'hi',
          'academic.working_days': ['mon', 'wed', 'fri'],
        },
        'version': 'abc123',
      });
      expect(c.periodsPerDay, 6);
      expect(c.defaulterThreshold, 65);
      expect(c.showLogo, isFalse);
      expect(c.language, 'hi');
      expect(c.workingDayNumbers, [1, 3, 5]);
      expect(c.version, 'abc123');
      // Unset keys still resolve to the registry default.
      expect(c.dueDateDay, 10);
    });

    test('an empty working-days list falls back to Mon–Sat rather than an unusable editor', () {
      final c = SchoolConfig.fromResponse({
        'settings': {'academic.working_days': <String>[]},
        'version': 'v',
      });
      expect(c.workingDayNumbers, [1, 2, 3, 4, 5, 6]);
    });

    test('survives a wrong-typed value instead of throwing', () {
      final c = SchoolConfig.fromResponse({
        'settings': {'timetable.periods_per_day': 'not a number'},
        'version': 'v',
      });
      expect(c.periodsPerDay, 8);
    });

    test('cache round-trips, and a corrupt cache decodes to null', () {
      final c = SchoolConfig.fromResponse({
        'settings': {'timetable.periods_per_day': 6},
        'version': 'v9',
      });
      final restored = SchoolConfig.decode(c.encode());
      expect(restored, isNotNull);
      expect(restored!.periodsPerDay, 6);
      expect(restored.version, 'v9');
      expect(SchoolConfig.decode('{not json'), isNull);
      expect(SchoolConfig.decode(null), isNull);
    });
  });

  group('homePathForRole (role → landing route)', () {
    test('maps each role to its shell home', () {
      expect(homePathForRole('admin'), '/home/admin');
      expect(homePathForRole('teacher'), '/home/teacher');
      expect(homePathForRole('parent'), '/home/parent');
      expect(homePathForRole('student'), '/home/student');
    });

    test('unknown / null role falls back to login', () {
      expect(homePathForRole('superadmin'), '/login');
      expect(homePathForRole(null), '/login');
      expect(homePathForRole('nonsense'), '/login');
    });
  });

  testWidgets('ComingSoonScreen renders its title and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ComingSoonScreen(title: 'Fees', message: 'Arrives soon.'),
    ));
    expect(find.text('Fees'), findsWidgets);
    expect(find.text('Arrives soon.'), findsOneWidget);
    expect(find.byIcon(Icons.construction_rounded), findsOneWidget);
  });

  testWidgets('LoginScreen renders the password login fields', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));
    expect(find.text('School Code'), findsOneWidget);
    expect(find.text('Phone or Login ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
