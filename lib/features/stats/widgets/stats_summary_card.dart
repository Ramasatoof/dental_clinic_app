import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

class StatsSummaryCard extends StatelessWidget {
  final bool isArabic;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const StatsSummaryCard({
    super.key,
    required this.isArabic,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  bool _isMobileWidth(BuildContext context) {
    return MediaQuery.of(context).size.width < 700;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobileWidth(context);

    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 36 : 44,
            height: isMobile ? 36 : 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(isMobile ? 11 : 14),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          SizedBox(width: isMobile ? 9 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: _textSecondary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 11.5 : 13,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  value,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: isMobile ? 15.5 : 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}