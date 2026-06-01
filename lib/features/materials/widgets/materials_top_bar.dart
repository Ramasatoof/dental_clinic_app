import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class MaterialsTopBar extends StatelessWidget {
  final bool isArabic;
  final bool isMobile;
  final int rowsPerPage;
  final List<QueryDocumentSnapshot> docs;
  final VoidCallback onAddMaterial;
  final ValueChanged<int> onRowsPerPageChanged;
  final Future<void> Function(List<QueryDocumentSnapshot> docs) onExportPdf;
  final Future<void> Function(List<QueryDocumentSnapshot> docs) onExportExcel;

  const MaterialsTopBar({
    super.key,
    required this.isArabic,
    required this.isMobile,
    required this.rowsPerPage,
    required this.docs,
    required this.onAddMaterial,
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPrintButton(context),
          const Spacer(),
          _buildRowsButton(context),
          SizedBox(width: isMobile ? 8 : 10),
          _buildAddMaterialButton(),
        ],
      ),
    );
  }

  Widget _buildAddMaterialButton() {
    return ElevatedButton.icon(
      onPressed: onAddMaterial,
      icon: Icon(
        Icons.add,
        color: Colors.white,
        size: isMobile ? 18 : 22,
      ),
      label: Text(
        tr("إضافة مادة", "Add Material"),
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 13 : 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: lapisBlue,
        elevation: 0,
        minimumSize: Size(0, isMobile ? 42 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 22,
          vertical: isMobile ? 10 : 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 9),
        ),
      ),
    );
  }

  Widget _buildRowsButton(BuildContext context) {
    final double buttonHeight = isMobile ? 32 : 40;
    final double menuWidth = isMobile ? 96 : 128;

    return PopupMenuButton<int>(
      tooltip: '',
      initialValue: rowsPerPage,
      offset: Offset(0, isMobile ? 38 : 50),
      color: _surface(context),
      elevation: 8,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth + 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        side: BorderSide(color: _border(context)),
      ),
      onSelected: onRowsPerPageChanged,
      itemBuilder: (context) => [10, 50, 100].map((value) {
        final bool selected = rowsPerPage == value;
        return PopupMenuItem<int>(
          value: value,
          height: isMobile ? 28 : 36,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 5 : 8,
              vertical: isMobile ? 4 : 6,
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
                  size: isMobile ? 12 : 15,
                  color: selected ? lapisBlue : _textSecondary(context),
                ),
                SizedBox(width: isMobile ? 4 : 7),
                Text(
                  tr('إظهار $value', 'Show $value'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? lapisBlue : _textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 10.5 : 12.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: buttonHeight,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 11),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(isMobile ? 7 : 8),
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
              size: isMobile ? 14 : 18,
            ),
            SizedBox(width: isMobile ? 4 : 7),
            Text(
              tr('إظهار $rowsPerPage', 'Show $rowsPerPage'),
              style: TextStyle(
                color: _textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 10.5 : 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintButton(BuildContext context) {
    return PopupMenuButton<int>(
      offset: Offset(0, isMobile ? 38 : 50),
      color: _surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 15),
      ),
      elevation: 8,
      onSelected: (value) async {
        if (docs.isEmpty) return;
        if (value == 1) await onExportPdf(docs);
        if (value == 2) await onExportExcel(docs);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          height: isMobile ? 32 : 42,
          value: 1,
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
                size: isMobile ? 14 : 18,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                tr('تصدير PDF', 'Export PDF'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: isMobile ? 32 : 42,
          value: 2,
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                color: Colors.green,
                size: isMobile ? 14 : 18,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                tr('تصدير Excel', 'Export Excel'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                  fontSize: isMobile ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: isMobile ? 32 : 40,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 14,
          vertical: isMobile ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: lapisBlue,
          borderRadius: BorderRadius.circular(isMobile ? 7 : 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print, size: isMobile ? 12 : 15, color: Colors.white),
            SizedBox(width: isMobile ? 4 : 4),
            Text(
              tr('طباعة', 'Print'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 10.5 : 12.5,
              ),
            ),
            SizedBox(width: isMobile ? 4 : 5),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
              size: isMobile ? 12 : 15,
            ),
          ],
        ),
      ),
    );
  }
}