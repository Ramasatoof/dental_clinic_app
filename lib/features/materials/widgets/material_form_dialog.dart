import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme_controller.dart';
import '../utils/materials_utils.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;

class MaterialFormDialog extends StatelessWidget {
  final BoxConstraints constraints;
  final bool isArabic;
  final bool isEditMode;
  final String? formError;

  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController quantityController;
  final TextEditingController minQtyController;
  final TextEditingController unitController;
  final TextEditingController priceController;

  final VoidCallback onClose;
  final VoidCallback onSave;

  const MaterialFormDialog({
    super.key,
    required this.constraints,
    required this.isArabic,
    required this.isEditMode,
    required this.formError,
    required this.nameController,
    required this.categoryController,
    required this.quantityController,
    required this.minQtyController,
    required this.unitController,
    required this.priceController,
    required this.onClose,
    required this.onSave,
  });

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  double _safePositiveDimension(dynamic value, double fallback) {
    return MaterialsUtils.safePositiveDimension(value, fallback);
  }

  @override
  Widget build(BuildContext context) {
    final double safeMaxWidth = _safePositiveDimension(
      constraints.maxWidth,
      MediaQuery.of(context).size.width,
    );
    final bool isMobile = safeMaxWidth < 950;
    final bool compactMobile = safeMaxWidth < 700;
    final double dialogWidth = isMobile ? safeMaxWidth * 0.92 : 650;
    final double dialogPadding = compactMobile ? 18 : 30;
    final double fieldGap = compactMobile ? 10 : 15;

    return Container(
      color: Colors.black54,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compactMobile ? 12 : 20),
          child: Container(
            width: dialogWidth,
            padding: EdgeInsets.all(dialogPadding),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(compactMobile ? 12 : 15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditMode
                            ? tr("تعديل مادة", "Edit Item")
                            : tr("إضافة مادة جديدة", "Add Item"),
                        style: TextStyle(
                          fontSize: compactMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: lapisBlue,
                        ),
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close,
                        size: compactMobile ? 20 : 24,
                        color: _textPrimary(context),
                      ),
                    ),
                  ],
                ),
                if (formError != null) ...[
                  SizedBox(height: compactMobile ? 6 : 8),
                  Text(
                    formError!,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: compactMobile ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                Divider(height: compactMobile ? 22 : 30),
                _input(
                  context,
                  nameController,
                  tr("اسم المادة", "Name"),
                  compactMobile: compactMobile,
                ),
                SizedBox(height: fieldGap),
                if (!isMobile)
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          context,
                          categoryController,
                          tr("التصنيف", "Category"),
                          compactMobile: compactMobile,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          context,
                          unitController,
                          tr("الوحدة (مثلاً: علبة)", "Unit"),
                          compactMobile: compactMobile,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _input(
                        context,
                        categoryController,
                        tr("التصنيف", "Category"),
                        compactMobile: compactMobile,
                      ),
                      SizedBox(height: fieldGap),
                      _input(
                        context,
                        unitController,
                        tr("الوحدة (مثلاً: علبة)", "Unit"),
                        compactMobile: compactMobile,
                      ),
                    ],
                  ),
                SizedBox(height: fieldGap),
                if (!isMobile)
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          context,
                          quantityController,
                          tr("الكمية الحالية", "Qty"),
                          isNum: true,
                          compactMobile: compactMobile,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          context,
                          minQtyController,
                          tr("الحد الأدنى للطلب", "Min Qty"),
                          isNum: true,
                          compactMobile: compactMobile,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _input(
                        context,
                        quantityController,
                        tr("الكمية الحالية", "Qty"),
                        isNum: true,
                        compactMobile: compactMobile,
                      ),
                      SizedBox(height: fieldGap),
                      _input(
                        context,
                        minQtyController,
                        tr("الحد الأدنى للطلب", "Min Qty"),
                        isNum: true,
                        compactMobile: compactMobile,
                      ),
                    ],
                  ),
                SizedBox(height: fieldGap),
                _input(
                  context,
                  priceController,
                  tr("السعر", "Price"),
                  isNum: true,
                  compactMobile: compactMobile,
                ),
                SizedBox(height: compactMobile ? 20 : 30),
                if (!isMobile)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lapisBlue,
                        ),
                        child: Text(
                          tr("حفظ", "Save"),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 15),
                      OutlinedButton(
                        onPressed: onClose,
                        child: Text(tr("إلغاء", "Cancel")),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lapisBlue,
                            padding: EdgeInsets.symmetric(
                              vertical: compactMobile ? 12 : 14,
                            ),
                          ),
                          child: Text(
                            tr("حفظ", "Save"),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(height: compactMobile ? 8 : 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onClose,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: compactMobile ? 12 : 14,
                            ),
                          ),
                          child: Text(tr("إلغاء", "Cancel")),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    BuildContext context,
    TextEditingController controller,
    String label, {
    bool isNum = false,
    required bool compactMobile,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNum
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNum
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
          : null,
      textInputAction:
          controller == priceController ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) {
        if (controller == priceController) {
          onSave();
        }
      },
      style: TextStyle(
        color: _textPrimary(context),
        fontSize: compactMobile ? 13 : 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _textSecondary(context),
          fontSize: compactMobile ? 12.5 : 14,
        ),
        border: const OutlineInputBorder(),
        filled: _isDark,
        fillColor: _isDark ? const Color(0xFF1F2937) : null,
        isDense: compactMobile,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compactMobile ? 10 : 15,
        ),
      ),
    );
  }
}