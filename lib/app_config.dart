class ApiConfig {
  static const String baseUrl = 'https://deanne-thoughtless-extendedly.ngrok-free.dev';
  static const String googleMapsApiKey = 'AIzaSyCr5LrrlJOwLW2X0CazUeRzeFXjZXzL5Ag';
  static const String googleWebClientId = '1035120408996-a91ob41i07kic8gp2m3ug2gvakrspmh1.apps.googleusercontent.com';

  // =====================
  // User APIs
  // =====================
  static String get login => '$baseUrl/api/user/login';
  static String get socialLogin => '$baseUrl/api/user/social-login';
  static String get register => '$baseUrl/api/user/register';
  static String get verifyEmail => '$baseUrl/api/user/verify-email';
  static String get forgotPassword => '$baseUrl/api/user/password/forgot';
  static String get verifyCode => '$baseUrl/api/user/password/verify';
  static String get resetPassword => '$baseUrl/api/user/password/reset';

  // Adjust these two if your backend uses different paths.
  static String get profile => '$baseUrl/api/user/profile';
  static String get updateProfile => '$baseUrl/api/user/update-profile';
  static String get updateProfilePhoto => '$baseUrl/api/user/profile/update-photo';
  static String get notifications => '$baseUrl/api/user/notifications';
  static String get logout => '$baseUrl/api/user/logout';

  // Reports & Tracking
  static String get createReport => '$baseUrl/api/reports/create';
  static String get myTickets => '$baseUrl/api/reports/my-tickets';
  static String trackReport(int id) => '$baseUrl/api/reports/track/$id';

  // =====================
  // Technician APIs
  // =====================
  static String get technicianLogin => '$baseUrl/api/technician/login';
  static String get technicianNotifications => '$baseUrl/api/technician/notifications';
  static String get myTasks => '$baseUrl/api/technician/my-tasks';
  static String get completedTasks => '$baseUrl/api/technician/completed-tasks';
  static String get inProgressTasks => '$baseUrl/api/technician/in-progress-tasks';
  static String technicianTaskDetails(int id) =>
      '$baseUrl/api/technician/task-details/$id';
  static String technicianStartTask(int id) =>
      '$baseUrl/api/technician/start-task/$id';
  static String technicianCompletedTaskDetails(int id) =>
      '$baseUrl/api/technician/completed-task-details/$id';
  static String technicianSubmitUpdate(int id) =>
      '$baseUrl/api/technician/submit-update/$id';
}

