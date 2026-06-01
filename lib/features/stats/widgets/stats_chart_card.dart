import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class StatsChartCard extends StatelessWidget {
  final bool isArabic;
  final String title;
  final Widget chart;

  const StatsChartCard({
    super.key,
    required this.isArabic,
    required this.title,
    required this.chart,
  });

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);

  bool _isMobileWidth(BuildContext context) {
    return MediaQuery.of(context).size.width < 700;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobileWidth(context);

    return Container(
      height: isMobile ? 360 : 400,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: lapisBlue,
            ),
          ),
          Divider(height: 35, color: _border(context)),
          Expanded(child: chart),
        ],
      ),
    );
  }
}