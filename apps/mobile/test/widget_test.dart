// VidyaTrack smoke + logic tests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidyatrack/core/router/app_router.dart';
import 'package:vidyatrack/shared/widgets/coming_soon_screen.dart';
import 'package:vidyatrack/features/auth/screens/login_screen.dart';

void main() {
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
