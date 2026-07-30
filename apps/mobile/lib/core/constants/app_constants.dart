class AppConstants {
  // Default points at the deployed API so a plain release build works out of the
  // box. Override for local dev with:
  //   --dart-define=API_URL=http://10.0.2.2:3000/api/v1   (Android emulator → host)
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api-production-28467.up.railway.app/api/v1',
  );
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
  static const schoolConfigKey = 'school_config';
}
