import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(_AuthInterceptor());
  return dio;
});

class _AuthInterceptor extends QueuedInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Attempt silent refresh
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString(AppConstants.refreshTokenKey);
      if (refresh != null) {
        try {
          final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
          final res = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
          final newToken = res.data['accessToken'] as String;
          await prefs.setString(AppConstants.tokenKey, newToken);
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retry = await dio.fetch(err.requestOptions);
          return handler.resolve(retry);
        } catch (_) {
          await prefs.clear();
        }
      }
    }
    handler.next(err);
  }
}

// Simple API response wrapper
class ApiResult<T> {
  final T? data;
  final String? error;
  const ApiResult.success(this.data) : error = null;
  const ApiResult.failure(this.error) : data = null;
  bool get isSuccess => error == null;
}
