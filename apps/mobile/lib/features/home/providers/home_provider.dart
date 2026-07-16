import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Dashboard data providers ──────────────────────────────────────────────────

final attendanceChartProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/attendance/dashboard');
  return res.data as Map<String, dynamic>;
});

final dailyRevenueProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get('/fees/daily-revenue');
    return res.data as Map<String, dynamic>;
  } catch (_) {
    return {
      'total_revenue': 0, 'amount_received': 0, 'back_due': 0,
      'fine_received': 0, 'expense': 0, 'discount': 0,
    };
  }
});

final schoolProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/schools/profile');
  return res.data as Map<String, dynamic>;
});

final unreadNotifCountProvider = FutureProvider<int>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get('/users/notifications/unread-count');
    return (res.data['count'] as num).toInt();
  } catch (_) {
    return 0;
  }
});
