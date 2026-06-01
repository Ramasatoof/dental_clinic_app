import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

class AppointmentsEmptyState extends StatelessWidget {
  final bool isArabic;
  final String? arabicText;
  final String? englishText;

  const AppointmentsEmptyState({
    super.key,
    required this.isArabic,
    this.arabicText,
    this.englishText,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  String get _message {
    return tr(
      arabicText ?? "لا يوجد حجوزات",
      englishText ?? "No bookings found",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _message,
        style: TextStyle(
          color: _textSecondary(context),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget padded(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(
          _message,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _textSecondary(context),
          ),
        ),
      ),
    );
  }
}