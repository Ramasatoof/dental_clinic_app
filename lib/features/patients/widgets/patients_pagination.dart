import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;

class PatientsPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final bool isDark;
  final ValueChanged<int> onPageChanged;

  const PatientsPagination({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.isDark,
    required this.onPageChanged,
  });

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      isDark ? const Color(0xFF1F2937) : lightGray.withOpacity(0.85);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _softFill(context),
        border: Border(top: BorderSide(color: _border(context))),
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              color: currentPage > 1
                  ? _textPrimary(context)
                  : _textSecondary(context),
              onPressed: currentPage > 1
                  ? () => onPageChanged(currentPage - 1)
                  : null,
            ),
            for (int i = totalPages; i >= 1; i--)
              GestureDetector(
                onTap: () => onPageChanged(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
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
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              color: currentPage < totalPages
                  ? _textPrimary(context)
                  : _textSecondary(context),
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}