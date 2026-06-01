import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_controller.dart';
import '../services/materials_service.dart';
import '../utils/materials_utils.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class MaterialsStatsCards extends StatelessWidget {
  final bool isArabic;

  const MaterialsStatsCards({
    super.key,
    required this.isArabic,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);

  double _safeDouble(dynamic value, [double fallback = 0]) {
    return MaterialsUtils.safeDouble(value, fallback);
  }

  String _safeMoney(dynamic value, {int decimals = 2}) {
    return MaterialsUtils.safeMoney(value, decimals: decimals);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: MaterialsService.watchMaterials(),
      builder: (context, snapshot) {
        int total = 0;
        int lowStock = 0;
        double inventoryValue = 0;

        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final qty = _safeDouble(data['quantity']);
            final minQty = _safeDouble(data['min_quantity']);
            final price = _safeDouble(data['price']);

            if (qty <= minQty) lowStock++;
            inventoryValue += _safeDouble(qty * price);
            inventoryValue = _safeDouble(inventoryValue);
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1000) {
              return Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      tr("إجمالي المواد", "Total Items"),
                      total.toString(),
                      Icons.inventory_2,
                      lapisBlue,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _statCard(
                      context,
                      tr("نواقص", "Low Stock"),
                      lowStock.toString(),
                      Icons.warning_amber_rounded,
                      lowStock > 0 ? Colors.redAccent : lapisBlue,
                      danger: lowStock > 0,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _statCard(
                      context,
                      tr("قيمة المخزون", "Inventory Value"),
                      "${_safeMoney(inventoryValue, decimals: 0)} JD",
                      Icons.payments_outlined,
                      Colors.green,
                    ),
                  ),
                ],
              );
            }

            if (constraints.maxWidth < 760) {
              return Row(
                children: [
                  Expanded(
                    child: _statCard(
                      context,
                      tr("إجمالي المواد", "Total Items"),
                      total.toString(),
                      Icons.inventory_2,
                      lapisBlue,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      context,
                      tr("نواقص", "Low Stock"),
                      lowStock.toString(),
                      Icons.warning_amber_rounded,
                      lowStock > 0 ? Colors.redAccent : lapisBlue,
                      danger: lowStock > 0,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      context,
                      tr("قيمة المخزون", "Inventory Value"),
                      "${_safeMoney(inventoryValue, decimals: 0)} JD",
                      Icons.payments_outlined,
                      Colors.green,
                      compact: true,
                    ),
                  ),
                ],
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: _statCard(
                    context,
                    tr("إجمالي المواد", "Total Items"),
                    total.toString(),
                    Icons.inventory_2,
                    lapisBlue,
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    context,
                    tr("نواقص", "Low Stock"),
                    lowStock.toString(),
                    Icons.warning_amber_rounded,
                    lowStock > 0 ? Colors.redAccent : lapisBlue,
                    danger: lowStock > 0,
                    compact: true,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: _statCard(
                    context,
                    tr("قيمة المخزون", "Inventory Value"),
                    "${_safeMoney(inventoryValue, decimals: 0)} JD",
                    Icons.payments_outlined,
                    Colors.green,
                    compact: true,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(
    BuildContext context,
    String t,
    String v,
    IconData i,
    Color c, {
    bool danger = false,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 22),
      decoration: BoxDecoration(
        color: danger
            ? Colors.redAccent.withOpacity(_isDark ? 0.18 : 0.10)
            : _surface(context),
        borderRadius: BorderRadius.circular(compact ? 13 : 16),
        border: Border.all(
          color: danger ? Colors.redAccent.withOpacity(0.55) : _border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: compact ? 7 : 10,
            offset: compact ? const Offset(0, 2) : Offset.zero,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, color: c, size: compact ? 22 : 30),
          SizedBox(height: compact ? 5 : 10),
          Text(
            t,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11.5 : 14,
              fontWeight: FontWeight.bold,
              color: danger ? Colors.redAccent : _textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? 2 : 0),
          Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 17 : 20,
              color: c,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}