import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class PatientsHeader extends StatelessWidget {
  final bool isArabic;
  final bool isMobileLayout;
  final AsyncSnapshot<QuerySnapshot> snapshot;
  final int rowsPerPage;
  final VoidCallback onAddPatient;
  final ValueChanged<int> onRowsPerPageChanged;
  final Future<void> Function(List<QueryDocumentSnapshot> docs) onExportPdf;
  final Future<void> Function(List<QueryDocumentSnapshot> docs) onExportExcel;

  const PatientsHeader({
    super.key,
    required this.isArabic,
    required this.isMobileLayout,
    required this.snapshot,
    required this.rowsPerPage,
    required this.onAddPatient,
    required this.onRowsPerPageChanged,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  @override
  Widget build(BuildContext context) {
    return isMobileLayout
        ? _buildMobileHeader(context)
        : _buildDesktopHeader(context);
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr("قائمة المرضى", "Patients List"),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: lapisBlue,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildPrintButton(context),
                _buildRowsPerPageSelector(context),
              ],
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onAddPatient,
          icon: const Icon(Icons.add, color: Colors.white, size: 22),
          label: Text(
            tr("إضافة مريض جديد", "Add New Patient"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: lapisBlue,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    final CrossAxisAlignment actionAlignment =
        isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            tr("قائمة المرضى", "Patients List"),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: lapisBlue,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: actionAlignment,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: isArabic
                    ? [
                        _buildPrintButton(context, compact: true),
                        const SizedBox(width: 10),
                        _buildRowsPerPageSelector(context, compact: true),
                      ]
                    : [
                        _buildRowsPerPageSelector(context, compact: true),
                        const SizedBox(width: 10),
                        _buildPrintButton(context, compact: true),
                      ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onAddPatient,
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: Text(
                  tr("إضافة مريض جديد", "Add New Patient"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lapisBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrintButton(
    BuildContext context, {
    bool compact = false,
  }) {
    return PopupMenuButton<int>(
      offset: Offset(0, compact ? 42 : 50),
      color: _surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 15),
      ),
      onSelected: (val) async {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          if (val == 1) await onExportPdf(snapshot.data!.docs);
          if (val == 2) await onExportExcel(snapshot.data!.docs);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          height: compact ? 40 : 48,
          value: 1,
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
                size: compact ? 17 : 20,
              ),
              SizedBox(width: compact ? 8 : 10),
              Text(
                tr("تصدير PDF", "Export PDF"),
                style: TextStyle(
                  color: _textPrimary(context),
                  fontSize: compact ? 12.5 : 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: compact ? 40 : 48,
          value: 2,
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                color: Colors.green,
                size: compact ? 17 : 20,
              ),
              SizedBox(width: compact ? 8 : 10),
              Text(
                tr("تصدير Excel", "Export Excel"),
                style: TextStyle(
                  color: _textPrimary(context),
                  fontSize: compact ? 12.5 : 14,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: compact ? 40 : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: lapisBlue,
          borderRadius: BorderRadius.circular(compact ? 7 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print, size: compact ? 14 : 16, color: Colors.white),
            SizedBox(width: compact ? 6 : 8),
            Text(
              tr("طباعة", "Print"),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: compact ? 12.5 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowsPerPageSelector(
    BuildContext context, {
    bool compact = false,
  }) {
    final bool isMobile = compact || MediaQuery.of(context).size.width < 700;
    final double buttonHeight = isMobile ? 36 : 42;
    final double menuWidth = isMobile ? 112 : 132;

    return PopupMenuButton<int>(
      tooltip: tr("عدد الصفوف", "Rows per page"),
      offset: Offset(0, buttonHeight + 6),
      color: _surface(context),
      elevation: 8,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth + 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        side: BorderSide(color: _border(context)),
      ),
      onSelected: onRowsPerPageChanged,
      itemBuilder: (context) => [10, 50, 100].map((value) {
        final bool selected = rowsPerPage == value;

        return PopupMenuItem<int>(
          value: value,
          height: isMobile ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: selected ? lapisBlue.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: isMobile ? 15 : 16,
                  color: selected ? lapisBlue : _textSecondary(context),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  tr("إظهار $value", "Show $value"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? lapisBlue : _textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12.5 : 13.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: buttonHeight,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(isMobile ? 8 : 9),
          border: Border.all(color: lapisBlue, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.14 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: lapisBlue,
              size: isMobile ? 17 : 20,
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Text(
              tr("إظهار $rowsPerPage", "Show $rowsPerPage"),
              style: TextStyle(
                color: _textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12.5 : 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}