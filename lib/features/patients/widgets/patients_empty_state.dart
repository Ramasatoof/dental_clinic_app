import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

class PatientsEmptyState extends StatelessWidget {
  final bool isArabic;

  const PatientsEmptyState({
    super.key,
    required this.isArabic,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _surface(BuildContext context) => AppThemeColors.surface(context);

  Color _border(BuildContext context) => AppThemeColors.border(context);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        border: Border.all(color: _border(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          tr("لا يوجد مرضى", "No patients found"),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget simpleText(BuildContext context) {
    return Center(
      child: Text(
        tr("لا يوجد مرضى", "No patients found"),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _textSecondary(context),
        ),
      ),
    );
  }
}