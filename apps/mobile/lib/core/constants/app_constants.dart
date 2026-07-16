class AppConstants {
  static const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000/api/v1');
  static const appName = 'VidyaTrack';
  static const tokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const schoolIdKey = 'school_id';
  static const userRoleKey = 'user_role';
  static const userRoleIdKey = 'user_role_id';
  static const userKey = 'user_json';
  static const schoolCodeKey = 'school_code';
  static const schoolNameKey = 'school_name';
  static const mustChangePasswordKey = 'must_change_password';
}
