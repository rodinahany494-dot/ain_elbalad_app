class ApiConfig {
  static const String baseUrl = 'https://deanne-thoughtless-extendedly.ngrok-free.dev';

  static String get login => '$baseUrl/api/user/login';
  static String get socialLogin => '$baseUrl/api/user/social-login';
  static String get register => '$baseUrl/api/user/register';
  static String get forgotPassword => '$baseUrl/api/user/password/forgot';
  static String get verifyCode => '$baseUrl/api/user/password/verify';
  static String get resetPassword => '$baseUrl/api/user/password/reset';

  // Adjust these two if your backend uses different paths.
  static String get profile => '$baseUrl/api/user/profile';
  static String get updateProfilePhoto => '$baseUrl/api/user/profile/update-photo';
  static String get notifications => '$baseUrl/api/user/notifications';
  static String get logout => '$baseUrl/api/user/logout';

  // Reports & Tracking
  static String get createReport => '$baseUrl/api/reports/create';
  static String get myTickets => '$baseUrl/api/reports/my-tickets';
  static String trackReport(int id) => '$baseUrl/api/reports/track/$id';
}
