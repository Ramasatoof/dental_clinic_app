import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'core/preferences/app_preferences.dart' as prefs;
import 'core/theme/app_theme_controller.dart' as theme;

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/setup_screen.dart';

import 'features/appointments/screens/home_screen.dart';
import 'features/appointments/screens/bookings_screen.dart';

import 'features/patients/screens/patients_screen.dart';
import 'features/patients/screens/patient_account_screen.dart';

import 'features/materials/screens/materials_screen.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/xray/screens/xray_analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String bookings = '/bookings';
  static const String patients = '/patients';
  static const String patientAccount = '/patient-account';
  static const String materials = '/materials';
  static const String xray = '/xray';
  static const String stats = '/stats';
  static const String setup = '/setup';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: theme.AppThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Dental Clinic App',
          theme: theme.AppThemeColors.lightTheme,
          darkTheme: theme.AppThemeColors.darkTheme,
          themeMode: mode,
          home: const AppStartScreen(),
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.patientAccount:
        return _patientAccountRoute(settings);

      case AppRoutes.setup:
        return _setupRoute(settings);

      default:
        return null;
    }
  }

  MaterialPageRoute _patientAccountRoute(RouteSettings settings) {
    final args = _routeArgs(settings);

    final patientId = (args['patientId'] ?? '').toString().trim();
    final patientName = (args['patientName'] ?? '').toString().trim();
    final username = (args['username'] ?? '').toString().trim();
    final isArabic = _boolArg(args['isArabic'], fallback: true);

    if (patientId.isEmpty) {
      prefs.AppPreferences.saveLastRoute(AppRoutes.patients);

      return MaterialPageRoute(
        builder: (_) => PatientsScreen(
          username: username,
          initialArabic: isArabic,
        ),
      );
    }

    return MaterialPageRoute(
      builder: (_) => PatientAccountScreen(
        patientId: patientId,
        patientName: patientName,
        username: username,
        isArabic: isArabic,
      ),
    );
  }

  MaterialPageRoute _setupRoute(RouteSettings settings) {
    final args = _routeArgs(settings);

    return MaterialPageRoute(
      builder: (_) => TreatmentsSetupScreen(
        username: (args['username'] ?? '').toString(),
        initialArabic: _boolArg(args['initialArabic'], fallback: true),
      ),
    );
  }

  Map<String, dynamic> _routeArgs(RouteSettings settings) {
    final args = settings.arguments;
    if (args is Map<String, dynamic>) return args;
    if (args is Map) return Map<String, dynamic>.from(args);
    return <String, dynamic>{};
  }

  bool _boolArg(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }
}

class AppStartScreen extends StatelessWidget {
  const AppStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSession = prefs.AppPreferences.hasValidSession();

    if (!hasSession) {
      return const LoginScreen();
    }

    final username = prefs.AppPreferences.getSavedUsername() ?? '';
    final role = prefs.AppPreferences.getSavedRole() ?? 'admin';
    final isArabic = prefs.AppPreferences.getSavedIsArabic();
    final lastRoute = prefs.AppPreferences.getLastRoute();

    return _screenForLastRoute(
      lastRoute: lastRoute,
      username: username,
      role: role,
      isArabic: isArabic,
    );
  }

  Widget _screenForLastRoute({
    required String? lastRoute,
    required String username,
    required String role,
    required bool isArabic,
  }) {
    switch (lastRoute) {
      case AppRoutes.bookings:
        return BookingsScreen(
          username: username,
          initialArabic: isArabic,
        );

      case AppRoutes.patients:
      case AppRoutes.patientAccount:
        return PatientsScreen(
          username: username,
          initialArabic: isArabic,
        );

      case AppRoutes.materials:
        return MaterialsScreen(
          username: username,
          initialArabic: isArabic,
        );

      case AppRoutes.xray:
        return XRayAnalysisScreen(
          username: username,
          initialArabic: isArabic,
        );

   case AppRoutes.stats:
  return StatsScreen(
    username: username,
    initialView: 0,
    initialArabic: isArabic,
  );

      case AppRoutes.setup:
        return TreatmentsSetupScreen(
          username: username,
          initialArabic: isArabic,
        );

      case AppRoutes.home:
      default:
        return HomeScreen(
          username: username,
          role: role,
          initialArabic: isArabic,
        );
    }
  }
}