// API Configuration for User APK
class ApiConfig {
  // Backend API URL should be supplied via --dart-define=BACKEND_URL
  // Defaults to local development if the value is not provided.
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  // Firebase Project ID
  static const String projectId = 'dadacabs-099';
  
  // API Endpoints
  static const String users = '/users';
  static const String trips = '/trips';
  static const String payments = '/payments';
  static const String master = '/master';
  static const String drivers = '/drivers';
}
