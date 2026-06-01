import 'dart:html' as html;
import 'package:flutter/material.dart';

class AppPreferences {
  static const String _languageKey = 'clinic_language';
  static const String _themeKey = 'clinic_theme';

  static const String _sessionUsernameKey = 'clinic_session_username';
  static const String _sessionRoleKey = 'clinic_session_role';
  static const String _sessionLoginTimeKey = 'clinic_session_login_time';

  static const int sessionDurationHours = 12;

  static bool getSavedIsArabic() {
    final value = html.window.localStorage[_languageKey];

    if (value == null) return true;

    return value == 'ar';
  }

  static void saveLanguage(bool isArabic) {
    html.window.localStorage[_languageKey] = isArabic ? 'ar' : 'en';
  }

  static ThemeMode getSavedThemeMode() {
    final value = html.window.localStorage[_themeKey];

    if (value == 'dark') return ThemeMode.dark;

    return ThemeMode.light;
  }

  static bool getSavedIsDark() {
    return getSavedThemeMode() == ThemeMode.dark;
  }

  static void saveTheme(bool isDark) {
    html.window.localStorage[_themeKey] = isDark ? 'dark' : 'light';
  }

  static void saveSession({
    required String username,
    required String role,
  }) {
    html.window.localStorage[_sessionUsernameKey] = username;
    html.window.localStorage[_sessionRoleKey] = role;
    html.window.localStorage[_sessionLoginTimeKey] =
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String? getSavedUsername() {
    return html.window.localStorage[_sessionUsernameKey];
  }

  static String? getSavedRole() {
    return html.window.localStorage[_sessionRoleKey];
  }

  static bool hasValidSession() {
    final username = getSavedUsername();
    final role = getSavedRole();
    final loginTimeText = html.window.localStorage[_sessionLoginTimeKey];

    if (username == null || username.trim().isEmpty) return false;
    if (role == null || role.trim().isEmpty) return false;
    if (loginTimeText == null || loginTimeText.trim().isEmpty) return false;

    final loginTimeMillis = int.tryParse(loginTimeText);
    if (loginTimeMillis == null) {
      clearSession();
      return false;
    }

    final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimeMillis);
    final now = DateTime.now();
    final difference = now.difference(loginTime);

    if (difference.inHours >= sessionDurationHours) {
      clearSession();
      return false;
    }

    return true;
  }

  static void clearSession() {
    html.window.localStorage.remove(_sessionUsernameKey);
    html.window.localStorage.remove(_sessionRoleKey);
    html.window.localStorage.remove(_sessionLoginTimeKey);
  }
}

class AppThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(AppPreferences.getSavedThemeMode());

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void setLight() {
    themeMode.value = ThemeMode.light;
    AppPreferences.saveTheme(false);
  }

  static void setDark() {
    themeMode.value = ThemeMode.dark;
    AppPreferences.saveTheme(true);
  }

  static void toggleTheme() {
    if (isDark) {
      setLight();
    } else {
      setDark();
    }
  }
}

class AppThemeColors {
  static const Color lapisBlue = Color(0xFF26619C);
  static const Color lightGray = Color(0xFFF2F2F2);
  static const Color lightBlue = Color(0xFF3E7CB1);

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: lightGray,
    cardColor: Colors.white,
    dividerColor: const Color(0xFFE0E0E0),
    primaryColor: lapisBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: lapisBlue,
      brightness: Brightness.light,
      primary: lapisBlue,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lapisBlue,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    cardColor: const Color(0xFF111827),
    dividerColor: const Color(0xFF334155),
    primaryColor: const Color(0xFF1D4F82),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1D4F82),
      secondary: Color(0xFF60A5FA),
      surface: Color(0xFF111827),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B2944),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  static Color pageBg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surface(BuildContext context) => Theme.of(context).cardColor;

  static Color border(BuildContext context) => Theme.of(context).dividerColor;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;

  static Color appBar(BuildContext context) =>
      Theme.of(context).appBarTheme.backgroundColor ?? lapisBlue;

  static Color warningBar(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF7F1D1D)
          : Colors.red.shade700;

  static Color searchFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : Colors.white;

  static Color selectedTile(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E3A5F)
          : lapisBlue.withOpacity(0.08);
}
