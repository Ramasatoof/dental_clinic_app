import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class MaterialsPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final bool isMobile;
  final ValueChanged<int> onPageChanged;

  const MaterialsPagination({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.isMobile,
    required this.onPageChanged,
  });

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : Colors.grey.shade50;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 56 : 66),
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
            spacing: isMobile ? 4 : 6,
            runSpacing: isMobile ? 4 : 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                visualDensity:
                    isMobile ? VisualDensity.compact : VisualDensity.standard,
                icon: Icon(Icons.chevron_right, size: isMobile ? 20 : 24),
                color: currentPage > 0
                    ? _textPrimary(context)
                    : _textSecondary(context).withOpacity(0.45),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              for (int i = totalPages - 1; i >= 0; i--)
                GestureDetector(
                  onTap: () => onPageChanged(i),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 2),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 5 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: currentPage == i ? lapisBlue : _surface(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: lapisBlue),
                    ),
                    child: Text(
                      '${i + 1}',
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
                color: currentPage < totalPages - 1
                    ? _textPrimary(context)
                    : _textSecondary(context).withOpacity(0.45),
                onPressed: currentPage < totalPages - 1
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