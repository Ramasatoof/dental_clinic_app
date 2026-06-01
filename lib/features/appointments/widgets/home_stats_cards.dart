import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class HomeStatsCards extends StatelessWidget {
  final bool isArabic;
  final int todayCount;
  final int attendedCount;
  final double todaySum;
  final double monthlySum;

  const HomeStatsCards({
    super.key,
    required this.isArabic,
    required this.todayCount,
    required this.attendedCount,
    required this.todaySum,
    required this.monthlySum,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  bool _isMobileContext(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = _isMobileContext(context);

    return Wrap(
      spacing: isMobile ? 10 : 18,
      runSpacing: isMobile ? 10 : 18,
      alignment: WrapAlignment.center,
      children: [
        _statCard(
          context,
          tr("مرضى اليوم", "Today's Patients"),
          todayCount.toString(),
          Icons.person,
        ),
        _statCard(
          context,
          tr("الحضور", "Attendance"),
          attendedCount.toString(),
          Icons.check_circle,
        ),
        _statCard(
          context,
          tr("حساب اليوم", "Today's Account"),
          "${todaySum.toStringAsFixed(0)} JD",
          Icons.monetization_on,
        ),
        _statCard(
          context,
          tr("حساب الشهر", "Monthly Account"),
          "${monthlySum.toStringAsFixed(0)} JD",
          Icons.account_balance_wallet,
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final bool isMobile = _isMobileContext(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = isMobile ? min(160, (screenWidth - 42) / 2) : 220;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(isMobile ? 13 : 20),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: isMobile ? 8 : 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: lapisBlue, size: isMobile ? 24 : 32),
          SizedBox(height: isMobile ? 7 : 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 11.5 : 14,
              color: _textSecondary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 3 : 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 17 : 22,
              color: lapisBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}