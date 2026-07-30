import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../network/api_client.dart';

/// This school's effective settings, as resolved by the API from the settings
/// registry plus the school's own overrides (`GET /schools/config`).
///
/// The raw map is kept as-is, so adding a setting server-side needs no change
/// here until a screen wants to read it — at which point it's one getter.
class SchoolConfig {
  final Map<String, dynamic> _values;

  /// Hash of the resolved values. Changes only when a value changes, so it's
  /// what we compare against the cached copy.
  final String version;

  const SchoolConfig._(this._values, this.version);

  /// Used before the first successful fetch, and on a fresh install offline.
  /// The fallbacks below mirror the API registry defaults.
  const SchoolConfig.defaults() : _values = const {}, version = '';

  factory SchoolConfig.fromResponse(Map<String, dynamic> body) => SchoolConfig._(
        (body['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
        body['version']?.toString() ?? '',
      );

  String encode() => jsonEncode({'settings': _values, 'version': version});

  static SchoolConfig? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return SchoolConfig.fromResponse(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt cache — fall back to defaults / network
    }
  }

  T _get<T>(String key, T fallback) {
    final v = _values[key];
    if (v is T) return v;
    if (fallback is int && v is num) return v.toInt() as T;
    return fallback;
  }

  // ── Academic ───────────────────────────────────────────────────────────────
  int get yearStartMonth => _get<int>('academic.year_start_month', 4);

  /// Lower-case short day names, e.g. ['mon','tue','wed','thu','fri','sat'].
  List<String> get workingDays {
    final raw = _values['academic.working_days'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((d) => d.toString().toLowerCase()).toList();
    }
    return const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  }

  /// Working days as timetable day numbers (1 = Mon … 7 = Sun), ascending.
  /// Always non-empty: a school with no working days configured would leave the
  /// timetable editor with nothing to edit, so we fall back to Mon–Sat.
  List<int> get workingDayNumbers {
    const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final days = workingDays;
    final nums = <int>[];
    for (var i = 0; i < order.length; i++) {
      if (days.contains(order[i])) nums.add(i + 1);
    }
    return nums.isEmpty ? const [1, 2, 3, 4, 5, 6] : nums;
  }

  // ── Timetable ──────────────────────────────────────────────────────────────
  int get periodsPerDay => _get<int>('timetable.periods_per_day', 8);

  // ── Attendance ─────────────────────────────────────────────────────────────
  int get defaulterThreshold => _get<int>('attendance.defaulter_threshold', 75);
  String get attendanceMode => _get<String>('attendance.mode', 'daily');

  // ── Fees ───────────────────────────────────────────────────────────────────
  int get dueDateDay => _get<int>('fees.due_date_day', 10);
  int get lateFinePerDay => _get<int>('fees.late_fine_per_day', 0);
  String get invoicePrefix => _get<String>('fees.invoice_prefix', 'INV');

  // ── Grading ────────────────────────────────────────────────────────────────
  String get gradingScheme => _get<String>('grading.scheme', 'percent');

  // ── Locale & branding ──────────────────────────────────────────────────────
  String get language => _get<String>('locale.language', 'en');
  String get primaryColorHex => _get<String>('branding.primary_color', '#1E88E5');
  bool get showLogo => _get<bool>('branding.show_logo', true);

  // ── Feature flags ──────────────────────────────────────────────────────────
  bool get onlinePaymentsEnabled => _get<bool>('features.online_payments', true);
  bool get materialsEnabled => _get<bool>('features.materials', true);
}

/// Fetches this school's config once per app run and caches it in
/// SharedPreferences, so a cold start without network still renders the
/// school's own settings rather than platform defaults.
final schoolConfigProvider = FutureProvider<SchoolConfig>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = SchoolConfig.decode(prefs.getString(AppConstants.schoolConfigKey));
  try {
    final res = await ref.watch(dioProvider).get('/schools/config');
    final fresh = SchoolConfig.fromResponse((res.data as Map).cast<String, dynamic>());
    if (fresh.version != cached?.version) {
      await prefs.setString(AppConstants.schoolConfigKey, fresh.encode());
    }
    return fresh;
  } catch (_) {
    // Offline, unauthenticated, or a server hiccup — last known config, else defaults.
    return cached ?? const SchoolConfig.defaults();
  }
});

/// Synchronous read for screens: the fetched config once available, registry
/// defaults until then. Config should never block or break a screen.
final schoolConfigValueProvider = Provider<SchoolConfig>((ref) {
  return ref.watch(schoolConfigProvider).valueOrNull ?? const SchoolConfig.defaults();
});
