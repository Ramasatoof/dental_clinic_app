import 'package:flutter/material.dart';

import '../../features/appointments/screens/bookings_screen.dart' as bookings;
import '../../features/appointments/screens/home_screen.dart' as home;
import '../../features/materials/screens/materials_screen.dart';
import '../../features/patients/screens/patients_screen.dart' as patients;
import '../../features/stats/screens/stats_screen.dart' as stats;
import '../../features/xray/screens/xray_analysis_screen.dart' as xray;

class CustomLayoutUtils {
  const CustomLayoutUtils._();

  static double numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double desktopUiScale(double width) {
    if (width < 1100) return 1.0;
    return 0.82;
  }

  static String? routeNameForPage(Widget page) {
    if (page is home.HomeScreen) return '/home';
    if (page is bookings.BookingsScreen) return '/bookings';
    if (page is patients.PatientsScreen) return '/patients';
    if (page is xray.XRayAnalysisScreen) return '/xray';
    if (page is MaterialsScreen) return '/materials';
    if (page is stats.StatsScreen) return '/stats';
    return null;
  }

  static String normalizeSearchText(String value) {
    const digitMap = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var result = value.trim().toLowerCase();

    digitMap.forEach((from, to) {
      result = result.replaceAll(from, to);
    });

    return result;
  }
}
