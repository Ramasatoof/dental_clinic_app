import 'dart:html' as html;

class AppPreferences {
  static const String _languageKey = 'clinic_language';
  static const String _themeKey = 'clinic_theme';
  static const String _usernameKey = 'clinic_username';
  static const String _roleKey = 'clinic_role';
  static const String _lastRouteKey = 'clinic_last_route';

  // ─────────────────────────────────────────────
  // Language
  // ─────────────────────────────────────────────
  static bool getSavedIsArabic() {
    final value = html.window.localStorage[_languageKey];
    if (value == null) return true;
    return value == 'ar';
  }

  static void saveLanguage(bool isArabic) {
    html.window.localStorage[_languageKey] = isArabic ? 'ar' : 'en';
  }

  // ─────────────────────────────────────────────
  // Theme
  // ─────────────────────────────────────────────
  static bool getSavedIsDark() {
    final value = html.window.localStorage[_themeKey];
    return value == 'dark';
  }

  static void saveTheme(bool isDark) {
    html.window.localStorage[_themeKey] = isDark ? 'dark' : 'light';
  }

  // ─────────────────────────────────────────────
  // Session
  // ─────────────────────────────────────────────
  static void saveSession({
    required String username,
    required String role,
    String lastRoute = '/home',
  }) {
    saveUsername(username);
    saveRole(role);
    saveLastRoute(lastRoute);
  }

  static void saveUsername(String username) {
    html.window.localStorage[_usernameKey] = username.trim();
  }

  static String? getSavedUsername() {
    final value = html.window.localStorage[_usernameKey];
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static void saveRole(String role) {
    html.window.localStorage[_roleKey] = role.trim();
  }

  static String? getSavedRole() {
    final value = html.window.localStorage[_roleKey];
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static bool hasValidSession() {
    final username = getSavedUsername();
    final role = getSavedRole();

    return username != null &&
        username.trim().isNotEmpty &&
        role != null &&
        role.trim().isNotEmpty;
  }

  static void clearSession() {
    html.window.localStorage.remove(_usernameKey);
    html.window.localStorage.remove(_roleKey);
    html.window.localStorage.remove(_lastRouteKey);
  }

  // ─────────────────────────────────────────────
  // Last Route
  // ─────────────────────────────────────────────
  static void saveLastRoute(String route) {
    final cleanRoute = route.trim();

    if (cleanRoute.isEmpty) {
      html.window.localStorage[_lastRouteKey] = '/home';
      return;
    }

    html.window.localStorage[_lastRouteKey] = cleanRoute;
  }

  static String getLastRoute() {
    final value = html.window.localStorage[_lastRouteKey];

    if (value == null || value.trim().isEmpty) {
      return '/home';
    }

    return value;
  }
}