import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/config/school_config.dart';
import '../../../core/constants/app_constants.dart';

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Dio _dio;
  final Ref _ref;
  AuthNotifier(this._dio, this._ref) : super(const AsyncValue.data(null));

  Future<String?> sendOtp({required String schoolCode, required String phone}) async {
    try {
      await _dio.post('/auth/send-otp', data: {'schoolCode': schoolCode, 'phone': phone});
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOtp({required String schoolCode, required String phone, required String otp}) async {
    try {
      final res = await _dio.post('/auth/verify-otp', data: {'schoolCode': schoolCode, 'phone': phone, 'otp': otp});
      final data = res.data as Map<String, dynamic>;
      if (data['requiresRoleSelection'] == true) return data;
      await _saveSession(data);
      return data;
    } on DioException catch (e) {
      return {'error': _extractError(e)};
    }
  }

  /// Login with School Code + (Login ID or phone) + password.
  /// Returns the response map (`{error}` on failure, session/role-selection data on success).
  Future<Map<String, dynamic>> loginPassword({required String schoolCode, String? phone, String? loginId, required String password}) async {
    try {
      final res = await _dio.post('/auth/login-password', data: {
        'schoolCode': schoolCode,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (loginId != null && loginId.isNotEmpty) 'loginId': loginId,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      if (data['requiresRoleSelection'] == true) return data;
      await _saveSession(data);
      return data;
    } on DioException catch (e) {
      return {'error': _extractError(e)};
    }
  }

  Future<Map<String, dynamic>> selectRole(String userRoleId) async {
    try {
      final res = await _dio.post('/auth/select-role', data: {'userRoleId': userRoleId});
      final data = res.data as Map<String, dynamic>;
      await _saveSession(data);
      return data;
    } on DioException catch (e) {
      return {'error': _extractError(e)};
    }
  }

  Future<String?> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      await _dio.post('/auth/change-password', data: {'oldPassword': oldPassword, 'newPassword': newPassword});
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // includes the cached school config
    _ref.invalidate(schoolConfigProvider);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['accessToken'] != null) await prefs.setString(AppConstants.tokenKey, data['accessToken']);
    if (data['refreshToken'] != null) await prefs.setString(AppConstants.refreshTokenKey, data['refreshToken']);
    if (data['role'] != null) await prefs.setString(AppConstants.userRoleKey, data['role']);
    if (data['schoolId'] != null) await prefs.setString(AppConstants.schoolIdKey, data['schoolId']);
    if (data['userRoleId'] != null) await prefs.setString(AppConstants.userRoleIdKey, data['userRoleId']);
    if (data['user'] != null) await prefs.setString(AppConstants.userKey, jsonEncode(data['user']));
    await prefs.setBool(AppConstants.mustChangePasswordKey, data['mustChangePassword'] == true);

    // Bootstrap this school's config for the new session. Dropping the previous
    // school's cached copy matters when signing in as a different school on the
    // same device — otherwise the old school's periods/threshold would persist.
    await prefs.remove(AppConstants.schoolConfigKey);
    _ref.invalidate(schoolConfigProvider);
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['message']?.toString() ?? data['error']?.toString() ?? 'Something went wrong';
    return e.message ?? 'Network error';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(dioProvider), ref);
});
