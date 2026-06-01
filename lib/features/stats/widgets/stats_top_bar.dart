import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightBlue = AppThemeColors.lightBlue;

class StatsTopBar extends StatelessWidget {
  final bool isArabic;
  final int viewType;
  final ValueChanged<int> onViewChanged;

  const StatsTopBar({
    super.key,
    required this.isArabic,
    required this.viewType,
    required this.onViewChanged,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  TextDirection get _pageDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);

  bool _isMobileWidth(double width) => width < 700;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = _isMobileWidth(constraints.maxWidth);

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                alignment:
                    isArabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewType == 0
                          ? tr("التقرير المالي", "Financial Report")
                          : tr("التحليل البياني", "Data Analysis"),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: lapisBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 48,
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment:
                    isArabic ? Alignment.centerLeft : Alignment.centerRight,
                child: Directionality(
                  textDirection: _pageDirection,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _tabBtn(
                        context,
                        tr("الجدول", "Table"),
                        0,
                        Icons.table_chart,
                      ),
                      _tabBtn(
                        context,
                        tr("الرسومات", "Charts"),
                        1,
                        Icons.auto_graph,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  viewType == 0
                      ? tr("التقرير المالي", "Financial Report")
                      : tr("التحليل البياني", "Data Analysis"),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: lapisBlue,
                  ),
                ),
                Container(
                  height: 4,
                  width: 60,
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Directionality(
              textDirection: _pageDirection,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _tabBtn(
                    context,
                    tr("الجدول", "Table"),
                    0,
                    Icons.table_chart,
                  ),
                  _tabBtn(
                    context,
                    tr("الرسومات", "Charts"),
                    1,
                    Icons.auto_graph,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabBtn(
    BuildContext context,
    String label,
    int index,
    IconData icon,
  ) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final bool active = viewType == index;

    return ElevatedButton.icon(
      onPressed: () => onViewChanged(index),
      icon: Icon(
        icon,
        size: isMobile ? 17 : 20,
        color: active ? Colors.white : lapisBlue,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : lapisBlue,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 13 : 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? lapisBlue : _surface(context),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 20,
          vertical: isMobile ? 10 : 15,
        ),
        side: const BorderSide(color: lapisBlue, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        ),
        elevation: 0,
      ),
    );
  }
}