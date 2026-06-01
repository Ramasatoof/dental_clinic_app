import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;

class StatsPagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final bool isDark;
  final ValueChanged<int> onPageChanged;

  const StatsPagination({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.isDark,
    required this.onPageChanged,
  });

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);

  Color _softFill(BuildContext context) =>
      isDark ? const Color(0xFF1F2937) : lightGray;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _softFill(context),
        border: Border(top: BorderSide(color: _border(context))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          for (int i = 1; i <= totalPages; i++)
            GestureDetector(
              onTap: () => onPageChanged(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: currentPage == i ? lapisBlue : _surface(context),
                  borderRadius: BorderRadius.circular(5),
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
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}