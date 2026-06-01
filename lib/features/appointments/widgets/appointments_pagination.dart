import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;

class AppointmentsPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final bool isDark;
  final ValueChanged<int> onPageChanged;

  const AppointmentsPagination({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.isDark,
    required this.onPageChanged,
  });

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);

  Color _softFill(BuildContext context) =>
      isDark ? const Color(0xFF1F2937) : lightGray.withOpacity(0.85);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 56 : 68),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 12,
        horizontal: isMobile ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: _softFill(context),
        border: Border(top: BorderSide(color: _border(context))),
      ),
      child: Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: isMobile ? 4 : 6,
            runSpacing: isMobile ? 4 : 6,
            children: [
              IconButton(
                visualDensity:
                    isMobile ? VisualDensity.compact : VisualDensity.standard,
                icon: Icon(Icons.chevron_right, size: isMobile ? 20 : 24),
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              for (int i = 1; i <= totalPages; i++)
                GestureDetector(
                  onTap: () => onPageChanged(i),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 11 : 13,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: currentPage == i ? lapisBlue : _surface(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: lapisBlue),
                    ),
                    child: Text(
                      "$i",
                      style: TextStyle(
                        color: currentPage == i ? Colors.white : lapisBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ),
                ),
              IconButton(
                visualDensity:
                    isMobile ? VisualDensity.compact : VisualDensity.standard,
                icon: Icon(Icons.chevron_left, size: isMobile ? 20 : 24),
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}