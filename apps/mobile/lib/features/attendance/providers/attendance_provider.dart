import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../../../core/network/api_client.dart';

// ── Offline queue DB ──────────────────────────────────────────────────────────
Future<Database> _openDb() async {
  final path = p.join(await getDatabasesPath(), 'vidyatrack.db');
  return openDatabase(
    path,
    version: 1,
    onCreate: (db, _) => db.execute('''
      CREATE TABLE att_queue (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    '''),
  );
}

const _uuid = Uuid();

// ── Attendance state for a section ───────────────────────────────────────────
enum StudentStatus { present, absent, late, leave }

class AttendanceRecord {
  final String studentId;
  final String name;
  final int rollNo;
  final String? photoUrl;
  StudentStatus status;

  AttendanceRecord({required this.studentId, required this.name, required this.rollNo, this.photoUrl, this.status = StudentStatus.present});
}

class AttendanceState {
  final List<AttendanceRecord> records;
  final bool loading;
  final String? error;
  final bool submitting;
  final int pendingSync;

  const AttendanceState({this.records = const [], this.loading = false, this.error, this.submitting = false, this.pendingSync = 0});

  AttendanceState copyWith({List<AttendanceRecord>? records, bool? loading, String? error, bool? submitting, int? pendingSync}) {
    return AttendanceState(
      records: records ?? this.records,
      loading: loading ?? this.loading,
      error: error,
      submitting: submitting ?? this.submitting,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Dio _dio;
  AttendanceNotifier(this._dio) : super(const AttendanceState());

  Future<void> loadRoster(String sectionId, String date) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _dio.get('/attendance/section', queryParameters: {'sectionId': sectionId, 'date': date});
      final data = res.data as Map<String, dynamic>;
      final students = (data['students'] as List).cast<Map<String, dynamic>>();
      final records = students.map((s) {
        final serverStatus = s['status'] as String?;
        return AttendanceRecord(
          studentId: s['id'] as String,
          name: s['name'] as String,
          rollNo: (s['roll_no'] as num?)?.toInt() ?? 0,
          photoUrl: s['photo_url'] as String?,
          status: _parseStatus(serverStatus),
        );
      }).toList();
      state = state.copyWith(loading: false, records: records);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.receiveTimeout) {
        // Offline: load from local SQLite cache
        await _loadFromCache(sectionId, date);
      } else {
        state = state.copyWith(loading: false, error: 'Failed to load roster');
      }
    }
  }

  void toggleStatus(String studentId) {
    final updated = state.records.map((r) {
      if (r.studentId == studentId) {
        r.status = r.status == StudentStatus.present ? StudentStatus.absent : StudentStatus.present;
      }
      return r;
    }).toList();
    state = state.copyWith(records: updated);
  }

  void setStatus(String studentId, StudentStatus status) {
    final updated = state.records.map((r) {
      if (r.studentId == studentId) r.status = status;
      return r;
    }).toList();
    state = state.copyWith(records: updated);
  }

  void markAll(StudentStatus status) {
    final updated = state.records.map((r) { r.status = status; return r; }).toList();
    state = state.copyWith(records: updated);
  }

  Future<String?> submit(String sectionId, String date) async {
    state = state.copyWith(submitting: true);
    final payload = {
      'sectionId': sectionId,
      'date': date,
      'session': 'full_day',
      'records': state.records.map((r) => {'studentId': r.studentId, 'status': r.status.name}).toList(),
    };

    try {
      await _dio.post('/attendance/sessions', data: payload);
      state = state.copyWith(submitting: false);
      return null;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.receiveTimeout) {
        // Queue locally
        await _enqueueOffline(payload);
        state = state.copyWith(submitting: false, pendingSync: state.pendingSync + 1);
        return null; // success (queued)
      }
      state = state.copyWith(submitting: false, error: 'Submit failed');
      return 'Submit failed: ${e.message}';
    }
  }

  Future<void> syncPending() async {
    final db = await _openDb();
    final pending = await db.query('att_queue', where: 'synced=0');
    int synced = 0;
    for (final row in pending) {
      try {
        final payload = jsonDecode(row['payload'] as String);
        await _dio.post('/attendance/sessions', data: payload);
        await db.update('att_queue', {'synced': 1}, where: 'id=?', whereArgs: [row['id']]);
        synced++;
      } catch (_) {}
    }
    if (synced > 0) state = state.copyWith(pendingSync: (state.pendingSync - synced).clamp(0, 999));
  }

  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    final db = await _openDb();
    await db.insert('att_queue', {'id': _uuid.v4(), 'payload': jsonEncode(payload), 'created_at': DateTime.now().toIso8601String(), 'synced': 0});
  }

  Future<void> _loadFromCache(String sectionId, String date) async {
    final db = await _openDb();
    final rows = await db.query('att_queue', where: 'synced=0');
    // Find latest queued entry for this section+date
    for (final row in rows.reversed) {
      final p = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (p['sectionId'] == sectionId && p['date'] == date) {
        final recs = (p['records'] as List).cast<Map<String, dynamic>>();
        final records = recs.map((r) => AttendanceRecord(
          studentId: r['studentId'] as String,
          name: r['name'] as String? ?? '',
          rollNo: 0,
          status: _parseStatus(r['status'] as String?),
        )).toList();
        state = state.copyWith(loading: false, records: records);
        return;
      }
    }
    state = state.copyWith(loading: false, error: 'Offline — no cached data');
  }

  StudentStatus _parseStatus(String? s) {
    switch (s) {
      case 'absent': return StudentStatus.absent;
      case 'late': return StudentStatus.late;
      case 'leave': return StudentStatus.leave;
      default: return StudentStatus.present;
    }
  }
}

final attendanceNotifierProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier(ref.watch(dioProvider));
});

// Pending sync count for status bar
final pendingSyncProvider = Provider<int>((ref) => ref.watch(attendanceNotifierProvider).pendingSync);
