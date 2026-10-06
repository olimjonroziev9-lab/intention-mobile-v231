class AppConfig {
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Intention School');
  static const requiredRole = String.fromEnvironment('APP_ROLE', defaultValue: '');
  static const apiBase = 'https://www.intentiontest.helioho.st/api/v1/mobile/';
  static const website = 'https://www.intentiontest.helioho.st';

  static String roleTitle(String role) => switch (role) {
    'admin' => 'Intention Admin',
    'teacher' => 'Intention Teacher',
    'assistant' => 'Intention Assistant',
    'student' => 'Intention Student',
    'parent' => 'Intention Parent',
    'methodologist' => 'Intention Methodologist',
    _ => appName,
  };
}
