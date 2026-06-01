import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/custom_layout.dart';
import '../../../core/preferences/app_preferences.dart' as prefs;
import '../../../core/theme/app_theme_controller.dart';

class SubDetail {
  String id;
  String name;
  String nameEn;
  Color color;
  int order;

  SubDetail({
    required this.id,
    required this.name,
    this.nameEn = '',
    required this.color,
    required this.order,
  });

  String getDisplayName(bool isArabic) {
    if (isArabic) return name;
    return nameEn.isNotEmpty ? nameEn : name;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'order': order,
      'color': color.value,
    };
  }
}

class TreatmentItem {
  String id;
  String category;
  String name;
  String nameEn;
  Color color;
  double price;
  String textCode;
  String imageCode;
  bool hasLab;
  String actionType;
  List<SubDetail> details;

  TreatmentItem({
    required this.id,
    required this.category,
    required this.name,
    this.nameEn = '',
    this.color = Colors.blue,
    this.price = 0.0,
    this.textCode = '',
    this.imageCode = '',
    this.hasLab = false,
    this.actionType = 'general_consultation',
    this.details = const [],
  });

  String getDisplayName(bool isArabic) {
    if (isArabic) return name;
    return nameEn.isNotEmpty ? nameEn : name;
  }
}

class CategoryItem {
  String id;
  String name;
  String nameEn;

  CategoryItem({
    required this.id,
    required this.name,
    this.nameEn = '',
  });

  String getDisplayName(bool isArabic) {
    if (isArabic) return name;
    return nameEn.isNotEmpty ? nameEn : name;
  }
}

enum ActiveSection { category, treatment, detail }

class TreatmentsSetupScreen extends StatefulWidget {
  final String username;
  final bool initialArabic;

  const TreatmentsSetupScreen({
    super.key,
    required this.username,
    required this.initialArabic,
  });

  @override
  State<TreatmentsSetupScreen> createState() => _TreatmentsSetupScreenState();
}

class _TreatmentsSetupScreenState extends State<TreatmentsSetupScreen> {
  late bool isArabic;

  final FocusNode _focusNode = FocusNode();
  final TextEditingController searchController = TextEditingController();
  final ScrollController _desktopHorizontalController = ScrollController();
  final ScrollController _treatmentsHorizontalController = ScrollController();

  List<CategoryItem> _categories = [];
  List<TreatmentItem> _allTreatments = [];

  CategoryItem? _selectedCategory;
  TreatmentItem? _selectedTreatment;
  SubDetail? _selectedDetail;
  ActiveSection _activeSection = ActiveSection.category;

  bool _isLoading = true;
  bool _isBlockingLoaderVisible = false;

  static const double _mobileBreakpoint = 760;
  static const double _desktopDesignWidth = 1060;
  static const double _mobileCategoriesHeight = 260;
  static const double _mobileTreatmentsHeight = 520;
  static const double _mobileDetailsHeight = 380;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.teal,
    Colors.brown,
    Colors.grey,
    Colors.black,
    Colors.pink,
    Colors.indigo,
    Colors.lime,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    _loadSavedLanguage();
    _fetchDataFromFirebase();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    searchController.dispose();
    _desktopHorizontalController.dispose();
    _treatmentsHorizontalController.dispose();
    super.dispose();
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;
  Color get _pageBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => AppThemeColors.surface(context);
  Color get _textPrimary => AppThemeColors.textPrimary(context);
  Color get _tableHeaderBg =>
      _isDark ? const Color(0xFF334155) : Colors.grey.shade100;
  Color get _mutedTileBg =>
      _isDark ? const Color(0xFF111827) : Colors.grey.withOpacity(0.07);

  Future<void> _loadSavedLanguage() async {
    try {
      final bool saved = prefs.AppPreferences.getSavedIsArabic();
      if (!mounted) return;
      if (saved != isArabic) setState(() => isArabic = saved);
    } catch (_) {}
  }

  Future<void> _setLanguage(bool value) async {
    if (isArabic != value) setState(() => isArabic = value);
    try {
      prefs.AppPreferences.saveLanguage(value);
    } catch (_) {}
  }

  List<TreatmentItem> get _currentTreatments {
    return _allTreatments
        .where((t) => t.category == _selectedCategory?.name)
        .toList(growable: false);
  }

  Future<void> _fetchDataFromFirebase() async {
    try {
      final catSnapshot = await FirebaseFirestore.instance
          .collection('treatment_categories')
          .orderBy('timestamp')
          .get();

      final fetchedCategories = catSnapshot.docs.map((doc) {
        final data = doc.data();
        return CategoryItem(
          id: doc.id,
          name: data['name']?.toString() ?? '',
          nameEn: data['nameEn']?.toString() ?? '',
        );
      }).toList();

      final treatSnapshot =
          await FirebaseFirestore.instance.collection('treatments_setup').get();

      final fetchedTreatments = treatSnapshot.docs.map((doc) {
        final data = doc.data();

        final rawDetails = data['details'];
        final details = rawDetails is List
            ? rawDetails.map((raw) {
                final d = raw is Map
                    ? Map<String, dynamic>.from(raw)
                    : <String, dynamic>{};

                return SubDetail(
                  id: d['id']?.toString() ?? '',
                  name: d['name']?.toString() ?? '',
                  nameEn: d['nameEn']?.toString() ?? '',
                  order: d['order'] is num
                      ? (d['order'] as num).toInt()
                      : int.tryParse(d['order']?.toString() ?? '') ?? 1,
                  color: Color(
                    d['color'] is int ? d['color'] as int : Colors.black.value,
                  ),
                );
              }).toList()
            : <SubDetail>[];

        details.sort((a, b) => a.order.compareTo(b.order));

        return TreatmentItem(
          id: doc.id,
          category: data['category']?.toString() ?? '',
          name: data['name']?.toString() ?? '',
          nameEn: data['nameEn']?.toString() ?? '',
          price: _toDouble(data['price']),
          color:
              Color(data['color'] is int ? data['color'] as int : Colors.blue.value),
          textCode: data['textCode']?.toString() ?? '',
          imageCode: data['imageCode']?.toString() ?? '',
          hasLab: data['hasLab'] == true,
          actionType: data['actionType']?.toString() ?? 'general_consultation',
          details: details,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _categories = fetchedCategories;
        _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
        _selectedTreatment = null;
        _selectedDetail = null;
        _allTreatments = fetchedTreatments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching treatments setup: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  void _handleArrowKey(int step) {
    setState(() {
      if (_activeSection == ActiveSection.category) {
        if (_selectedCategory == null) return;
        final currentIndex = _categories.indexOf(_selectedCategory!);
        final nextIndex = currentIndex + step;
        if (nextIndex >= 0 && nextIndex < _categories.length) {
          _selectedCategory = _categories[nextIndex];
          _selectedTreatment = null;
          _selectedDetail = null;
        }
        return;
      }

      if (_activeSection == ActiveSection.treatment) {
        final treatments = _currentTreatments;
        if (treatments.isEmpty) return;
        final currentIndex = _selectedTreatment == null
            ? -1
            : treatments.indexWhere((t) => t.id == _selectedTreatment!.id);
        final nextIndex = currentIndex == -1 ? 0 : currentIndex + step;
        if (nextIndex >= 0 && nextIndex < treatments.length) {
          _selectedTreatment = treatments[nextIndex];
          _selectedDetail = null;
        }
        return;
      }

      if (_activeSection == ActiveSection.detail) {
        if (_selectedTreatment == null || _selectedTreatment!.details.isEmpty) {
          return;
        }
        final details = _selectedTreatment!.details;
        final currentIndex = _selectedDetail == null
            ? -1
            : details.indexWhere((d) => d.id == _selectedDetail!.id);
        final nextIndex = currentIndex == -1 ? 0 : currentIndex + step;
        if (nextIndex >= 0 && nextIndex < details.length) {
          _selectedDetail = details[nextIndex];
        }
      }
    });
  }

  Future<Color?> _pickColorDialog(Color currentColor) async {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            tr('اختر لوناً', 'Pick a Color'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableColors.map((c) {
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: currentColor.value == c.value
                            ? Colors.black
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog({CategoryItem? existingCategory}) async {
    final ctrlAr = TextEditingController(text: existingCategory?.name ?? '');
    final ctrlEn = TextEditingController(text: existingCategory?.nameEn ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(
            existingCategory == null
                ? tr('إضافة تصنيف', 'Add Category')
                : tr('تعديل التصنيف', 'Edit Category'),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrlAr,
                  decoration: InputDecoration(
                    labelText: tr('الاسم بالعربية', 'Name in Arabic'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrlEn,
                  decoration: InputDecoration(
                    labelText: tr('الاسم بالإنجليزية', 'Name in English'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final newNameAr = ctrlAr.text.trim();
                final newNameEn = ctrlEn.text.trim();
                if (newNameAr.isEmpty) return;

                Navigator.pop(ctx);
                await _saveCategory(
                  existingCategory: existingCategory,
                  newNameAr: newNameAr,
                  newNameEn: newNameEn,
                );
              },
              child: Text(tr('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCategory({
    required CategoryItem? existingCategory,
    required String newNameAr,
    required String newNameEn,
  }) async {
    _showBlockingLoader();

    try {
      if (existingCategory == null) {
        final docRef =
            await FirebaseFirestore.instance.collection('treatment_categories').add({
          'name': newNameAr,
          'nameEn': newNameEn,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        setState(() {
          final newCat = CategoryItem(
            id: docRef.id,
            name: newNameAr,
            nameEn: newNameEn,
          );
          _categories.add(newCat);
          _selectedCategory = newCat;
          _selectedTreatment = null;
          _selectedDetail = null;
        });
      } else {
        final oldNameAr = existingCategory.name;

        await FirebaseFirestore.instance
            .collection('treatment_categories')
            .doc(existingCategory.id)
            .update({
          'name': newNameAr,
          'nameEn': newNameEn,
        });

        final treatmentsQuery = await FirebaseFirestore.instance
            .collection('treatments_setup')
            .where('category', isEqualTo: oldNameAr)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in treatmentsQuery.docs) {
          batch.update(doc.reference, {'category': newNameAr});
        }
        await batch.commit();

        if (!mounted) return;
        setState(() {
          existingCategory.name = newNameAr;
          existingCategory.nameEn = newNameEn;
          for (final t in _allTreatments) {
            if (t.category == oldNameAr) t.category = newNameAr;
          }
        });
      }

      _hideBlockingLoader();
    } catch (e) {
      _hideBlockingLoader();
      _showError(e);
    }
  }

  Future<void> _deleteCategory(CategoryItem category) async {
    final confirmed = await _confirm(
      title: tr('تأكيد الحذف', 'Confirm Delete'),
      message: tr(
        "هل أنت متأكد من حذف التصنيف '${category.getDisplayName(isArabic)}'؟\nسيؤدي هذا إلى حذف المعالجات المرتبطة به أيضاً.",
        "Are you sure you want to delete '${category.getDisplayName(isArabic)}'?\nThis will also delete its treatments.",
      ),
    );

    if (!confirmed) return;

    _showBlockingLoader();

    try {
      await FirebaseFirestore.instance
          .collection('treatment_categories')
          .doc(category.id)
          .delete();

      final treatmentsQuery = await FirebaseFirestore.instance
          .collection('treatments_setup')
          .where('category', isEqualTo: category.name)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in treatmentsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (!mounted) return;

      setState(() {
        _categories.removeWhere((c) => c.id == category.id);
        _allTreatments.removeWhere((t) => t.category == category.name);

        if (_selectedCategory?.id == category.id) {
          _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
          _selectedTreatment = null;
          _selectedDetail = null;
        }
      });

      _hideBlockingLoader();
    } catch (e) {
      _hideBlockingLoader();
      _showError(e);
    }
  }

  Future<void> _showTreatmentDialog({TreatmentItem? existingItem}) async {
    if (_selectedCategory == null) {
      _showSnack(
        tr('يجب تحديد تصنيف أولاً', 'Please select a category first'),
        Colors.red,
      );
      return;
    }

    final nameArCtrl = TextEditingController(text: existingItem?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existingItem?.nameEn ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem == null ? '0.00' : existingItem.price.toString(),
    );
    final textCodeCtrl =
        TextEditingController(text: existingItem?.textCode ?? '');
    final imageCodeCtrl =
        TextEditingController(text: existingItem?.imageCode ?? '');

    Color selectedColor = existingItem?.color ?? Colors.blue;
    bool hasLab = existingItem?.hasLab ?? false;
    String selectedActionType =
        existingItem?.actionType ?? 'general_consultation';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingItem == null
                    ? '${tr('إضافة معالجة لـ ', 'Add treatment to ')}${_selectedCategory?.getDisplayName(isArabic) ?? ''}'
                    : tr('تعديل المعالجة', 'Edit Treatment'),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogTextField(
                        controller: nameArCtrl,
                        label: tr('الاسم بالعربية', 'Name in Arabic'),
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: nameEnCtrl,
                        label: tr('الاسم بالإنجليزية', 'Name in English'),
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: priceCtrl,
                        label: tr('السعر', 'Price'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedActionType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: tr(
                            'تأثير المعالجة على السن للرسم',
                            'Visual effect on tooth',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'general_consultation',
                            child:
                                Text(tr('كشفية / عامة', 'Consultation / General')),
                          ),
                          DropdownMenuItem(
                            value: 'filling',
                            child: Text(tr('حشوة', 'Filling')),
                          ),
                          DropdownMenuItem(
                            value: 'rct',
                            child: Text(tr('سحب عصب', 'Root Canal')),
                          ),
                          DropdownMenuItem(
                            value: 'crown',
                            child: Text(tr('تاج / تلبيسة', 'Crown')),
                          ),
                          DropdownMenuItem(
                            value: 'extraction',
                            child: Text(tr('خلع', 'Extraction')),
                          ),
                          DropdownMenuItem(
                            value: 'implant',
                            child: Text(tr('زراعة', 'Implant')),
                          ),
                          DropdownMenuItem(
                            value: 'veneer',
                            child: Text(tr('فينير', 'Veneer')),
                          ),
                          DropdownMenuItem(
                            value: 'braces',
                            child: Text(tr('تقويم', 'Braces')),
                          ),
                          DropdownMenuItem(
                            value: 'scaling',
                            child: Text(tr('تنظيف لثة', 'Scaling')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setDialogState(() => selectedActionType = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: textCodeCtrl,
                        label: tr('الرمز نص', 'Text code'),
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: imageCodeCtrl,
                        label: tr('مسار صورة الرمز', 'Icon image path'),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            tr('اللون', 'Color'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final c = await _pickColorDialog(selectedColor);
                              if (c != null) {
                                setDialogState(() => selectedColor = c);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr('يحتاج معمل؟', 'Needs Lab?')),
                              Checkbox(
                                value: hasLab,
                                onChanged: (value) {
                                  setDialogState(() => hasLab = value ?? false);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('إلغاء', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameArCtrl.text.trim().isEmpty) {
                      _showSnack(
                        tr('يرجى إدخال اسم المعالجة',
                            'Please enter treatment name'),
                        Colors.orange,
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    await _saveTreatment(
                      existingItem: existingItem,
                      nameAr: nameArCtrl.text.trim(),
                      nameEn: nameEnCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text) ?? 0.0,
                      textCode: textCodeCtrl.text.trim(),
                      imageCode: imageCodeCtrl.text.trim(),
                      color: selectedColor,
                      hasLab: hasLab,
                      actionType: selectedActionType,
                    );
                  },
                  child: Text(tr('حفظ', 'Save')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _saveTreatment({
    required TreatmentItem? existingItem,
    required String nameAr,
    required String nameEn,
    required double price,
    required String textCode,
    required String imageCode,
    required Color color,
    required bool hasLab,
    required String actionType,
  }) async {
    if (_selectedCategory == null) return;

    _showBlockingLoader();

    try {
      if (existingItem == null) {
        final docRef =
            await FirebaseFirestore.instance.collection('treatments_setup').add({
          'category': _selectedCategory!.name,
          'name': nameAr,
          'nameEn': nameEn,
          'price': price,
          'textCode': textCode,
          'imageCode': imageCode,
          'color': color.value,
          'hasLab': hasLab,
          'actionType': actionType,
        });

        if (!mounted) return;
        setState(() {
          final item = TreatmentItem(
            id: docRef.id,
            category: _selectedCategory!.name,
            name: nameAr,
            nameEn: nameEn,
            price: price,
            color: color,
            textCode: textCode,
            imageCode: imageCode,
            hasLab: hasLab,
            actionType: actionType,
          );
          _allTreatments.add(item);
          _selectedTreatment = item;
          _selectedDetail = null;
        });
      } else {
        await FirebaseFirestore.instance
            .collection('treatments_setup')
            .doc(existingItem.id)
            .update({
          'name': nameAr,
          'nameEn': nameEn,
          'price': price,
          'textCode': textCode,
          'imageCode': imageCode,
          'color': color.value,
          'hasLab': hasLab,
          'actionType': actionType,
        });

        if (!mounted) return;
        setState(() {
          existingItem.name = nameAr;
          existingItem.nameEn = nameEn;
          existingItem.price = price;
          existingItem.textCode = textCode;
          existingItem.imageCode = imageCode;
          existingItem.color = color;
          existingItem.hasLab = hasLab;
          existingItem.actionType = actionType;
          _selectedTreatment = existingItem;
        });
      }

      _hideBlockingLoader();
      _showSnack(tr('تم الحفظ بنجاح', 'Saved successfully'), Colors.green);
    } catch (e) {
      _hideBlockingLoader();
      _showError(e);
    }
  }

  Future<void> _deleteTreatment(TreatmentItem item) async {
    final confirmed = await _confirm(
      title: tr('تأكيد الحذف', 'Confirm Delete'),
      message: tr(
        "هل تريد حذف المعالجة '${item.getDisplayName(isArabic)}'؟",
        "Delete treatment '${item.getDisplayName(isArabic)}'?",
      ),
    );

    if (!confirmed) return;

    _showBlockingLoader();

    try {
      await FirebaseFirestore.instance
          .collection('treatments_setup')
          .doc(item.id)
          .delete();

      if (!mounted) return;
      setState(() {
        _allTreatments.removeWhere((t) => t.id == item.id);
        if (_selectedTreatment?.id == item.id) {
          _selectedTreatment = null;
          _selectedDetail = null;
        }
      });

      _hideBlockingLoader();
    } catch (e) {
      _hideBlockingLoader();
      _showError(e);
    }
  }

  Future<void> _showDetailDialog({SubDetail? existingDetail}) async {
    if (_selectedTreatment == null) return;

    final nameArCtrl = TextEditingController(text: existingDetail?.name ?? '');
    final nameEnCtrl = TextEditingController(text: existingDetail?.nameEn ?? '');
    final orderCtrl = TextEditingController(
      text: existingDetail == null ? '1' : existingDetail.order.toString(),
    );
    Color selectedColor = existingDetail?.color ?? Colors.black;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existingDetail == null
                    ? '${tr('إضافة تفصيل لـ ', 'Add detail to ')}${_selectedTreatment!.getDisplayName(isArabic)}'
                    : tr('تعديل التفصيل', 'Edit Detail'),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dialogTextField(
                        controller: nameArCtrl,
                        label: tr('الاسم بالعربية', 'Name in Arabic'),
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: nameEnCtrl,
                        label: tr('الاسم بالإنجليزية', 'Name in English'),
                      ),
                      const SizedBox(height: 10),
                      _dialogTextField(
                        controller: orderCtrl,
                        label: tr('الترتيب رقم', 'Order number'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            tr('اللون', 'Color'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              final c = await _pickColorDialog(selectedColor);
                              if (c != null) {
                                setDialogState(() => selectedColor = c);
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('إلغاء', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nameAr = nameArCtrl.text.trim();
                    if (nameAr.isEmpty) return;

                    Navigator.pop(ctx);

                    await _saveDetail(
                      existingDetail: existingDetail,
                      nameAr: nameAr,
                      nameEn: nameEnCtrl.text.trim(),
                      order: int.tryParse(orderCtrl.text) ?? 1,
                      color: selectedColor,
                    );
                  },
                  child: Text(tr('حفظ', 'Save')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveDetail({
    required SubDetail? existingDetail,
    required String nameAr,
    required String nameEn,
    required int order,
    required Color color,
  }) async {
    if (_selectedTreatment == null) return;

    setState(() {
      if (existingDetail == null) {
        final newDetail = SubDetail(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: nameAr,
          nameEn: nameEn,
          order: order,
          color: color,
        );
        _selectedTreatment!.details.add(newDetail);
        _selectedDetail = newDetail;
      } else {
        existingDetail.name = nameAr;
        existingDetail.nameEn = nameEn;
        existingDetail.order = order;
        existingDetail.color = color;
        _selectedDetail = existingDetail;
      }

      _selectedTreatment!.details.sort((a, b) => a.order.compareTo(b.order));
    });

    await _persistSelectedTreatmentDetails();
  }

  Future<void> _deleteDetail(SubDetail detail) async {
    if (_selectedTreatment == null) return;

    setState(() {
      _selectedTreatment!.details.removeWhere((d) => d.id == detail.id);
      if (_selectedDetail?.id == detail.id) {
        _selectedDetail = null;
      }
    });

    await _persistSelectedTreatmentDetails();
  }

  Future<void> _persistSelectedTreatmentDetails() async {
    if (_selectedTreatment == null || _selectedTreatment!.id.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('treatments_setup')
          .doc(_selectedTreatment!.id)
          .update({
        'details': _selectedTreatment!.details.map((d) => d.toMap()).toList(),
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('إلغاء', 'Cancel')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    tr('حذف', 'Delete'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showBlockingLoader() {
    if (!mounted || _isBlockingLoaderVisible) return;

    _isBlockingLoaderVisible = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() {
      _isBlockingLoaderVisible = false;
    });
  }

  void _hideBlockingLoader() {
    if (!mounted || !_isBlockingLoaderVisible) return;

    Navigator.of(context, rootNavigator: true).pop();
    _isBlockingLoaderVisible = false;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showError(Object error) {
    _showSnack('Error: $error', Colors.red);
  }

  Widget _buildTopActionRow({required bool isCompact}) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 10 : 15),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.25 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.settings_suggest, color: Colors.blue.shade800, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('إعدادات المعالجات والتسعير', 'Treatments & Pricing Setup'),
              style: TextStyle(
                fontSize: isCompact ? 17 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCard({
    required Widget header,
    required Widget body,
    double? height,
  }) {
    final card = Card(
      color: _cardBg,
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: card);
    }

    return card;
  }

  Widget _panelHeader({
    required String title,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _isDark ? color.withOpacity(0.16) : color.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesPanel({double? height, bool compact = false}) {
    return _panelCard(
      height: height,
      header: _panelHeader(
        title: tr('التصنيفات', 'Categories'),
        color: Colors.blueGrey,
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 26),
          onPressed: () => _showCategoryDialog(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: tr('إضافة تصنيف', 'Add Category'),
        ),
      ),
      body: _categories.isEmpty
          ? Center(child: Text(tr('لا توجد تصنيفات', 'No categories')))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _buildCategoryTile(category, compact: compact);
              },
            ),
    );
  }

  Widget _buildCategoryTile(CategoryItem category, {bool compact = false}) {
    final isSelected = category.id == _selectedCategory?.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _selectedTreatment = null;
          _selectedDetail = null;
          _activeSection = ActiveSection.category;
          FocusScope.of(context).requestFocus(_focusNode);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.blue.shade700
                : _isDark
                    ? const Color(0xFF334155)
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.getDisplayName(isArabic),
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : _textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _miniIconButton(
              icon: Icons.edit,
              color: isSelected ? Colors.white70 : Colors.blueGrey,
              tooltip: tr('تعديل', 'Edit'),
              onTap: () => _showCategoryDialog(existingCategory: category),
            ),
            const SizedBox(width: 4),
            _miniIconButton(
              icon: Icons.delete,
              color: isSelected ? Colors.white70 : Colors.redAccent,
              tooltip: tr('حذف', 'Delete'),
              onTap: () => _deleteCategory(category),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildTreatmentsPanel({
    required List<TreatmentItem> treatments,
    double? height,
    required bool compact,
  }) {
    return _panelCard(
      height: height,
      header: _panelHeader(
        title:
            "${tr('نوع المعالجات:', 'Treatments for:')} ${_selectedCategory?.getDisplayName(isArabic) ?? ''}",
        color: Colors.blue.shade800,
        trailing: compact
            ? Tooltip(
                message: tr('إضافة معالجة', 'Add Treatment'),
                child: IconButton(
                  icon:
                      const Icon(Icons.add_circle, color: Colors.blue, size: 26),
                  onPressed:
                      _selectedCategory == null ? null : () => _showTreatmentDialog(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              )
            : ElevatedButton.icon(
                onPressed:
                    _selectedCategory == null ? null : () => _showTreatmentDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  tr('إضافة معالجة', 'Add Treatment'),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
      ),
      body: treatments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  tr(
                    'لا يوجد معالجات. أضف معالجة جديدة.',
                    'No treatments found. Add a new one.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : compact
              ? _buildTreatmentCards(treatments)
              : _buildTreatmentsTable(treatments),
    );
  }

  Widget _buildTreatmentsTable(List<TreatmentItem> treatments) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _treatmentsHorizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _treatmentsHorizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(_tableHeaderBg),
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 64,
                  headingRowHeight: 46,
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(
                      label: Text(
                        '#',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(label: Text(tr('المعالجة', 'Treatment'))),
                    DataColumn(label: Text(tr('اللون', 'Color'))),
                    DataColumn(label: Text(tr('السعر', 'Price'))),
                    DataColumn(label: Text(tr('الرمز نص', 'Code'))),
                    DataColumn(label: Text(tr('الرمز صورة', 'Icon'))),
                    DataColumn(label: Text(tr('معمل', 'Lab'))),
                    DataColumn(label: Text(tr('إجراء', 'Action'))),
                  ],
                  rows: treatments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final selected = _selectedTreatment?.id == item.id;

                    return DataRow(
                      selected: selected,
                      onSelectChanged: (_) => _selectTreatment(item),
                      color: WidgetStateProperty.resolveWith<Color?>(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.blue.shade50
                            : null,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              item.getDisplayName(isArabic),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_colorBox(item.color)),
                        DataCell(
                          Text(
                            item.price.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              item.textCode.isEmpty ? '-' : item.textCode,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_iconPreview(item.imageCode)),
                        DataCell(
                          Icon(
                            item.hasLab
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: item.hasLab ? Colors.green : Colors.grey,
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showTreatmentDialog(existingItem: item),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deleteTreatment(item),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreatmentCards(List<TreatmentItem> treatments) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: treatments.length,
      itemBuilder: (context, index) {
        final item = treatments[index];
        final selected = _selectedTreatment?.id == item.id;

        return InkWell(
          onTap: () => _selectTreatment(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.blue.withOpacity(_isDark ? 0.20 : 0.08)
                  : _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Colors.blue
                    : _isDark
                        ? const Color(0xFF475569)
                        : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _colorBox(item.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.getDisplayName(isArabic),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _miniIconButton(
                      icon: Icons.edit,
                      color: Colors.blue,
                      tooltip: tr('تعديل', 'Edit'),
                      onTap: () => _showTreatmentDialog(existingItem: item),
                    ),
                    _miniIconButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      tooltip: tr('حذف', 'Delete'),
                      onTap: () => _deleteTreatment(item),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoPill(tr('السعر', 'Price'),
                        '${item.price.toStringAsFixed(2)} JD'),
                    _infoPill(tr('الرمز', 'Code'),
                        item.textCode.isEmpty ? '-' : item.textCode),
                    _infoPill(tr('معمل', 'Lab'),
                        item.hasLab ? tr('نعم', 'Yes') : tr('لا', 'No')),
                    _infoPill(tr('التأثير', 'Action'), item.actionType),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsPanel({double? height, required bool compact}) {
    return _panelCard(
      height: height,
      header: _panelHeader(
        title: _selectedTreatment == null
            ? tr('التفاصيل', 'Details')
            : "${tr('تفاصيل:', 'Details for:')} ${_selectedTreatment!.getDisplayName(isArabic)}",
        color: Colors.blueGrey,
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 26),
          onPressed:
              _selectedTreatment == null ? null : () => _showDetailDialog(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: tr('إضافة تفصيل', 'Add Detail'),
        ),
      ),
      body: _selectedTreatment == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  tr(
                    'الرجاء تحديد معالجة من الجدول',
                    'Please select a treatment from the table',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          : _selectedTreatment!.details.isEmpty
              ? Center(child: Text(tr('لا توجد تفاصيل', 'No details')))
              : compact
                  ? _buildDetailCards(_selectedTreatment!.details)
                  : _buildDetailsTable(_selectedTreatment!.details),
    );
  }

  Widget _buildDetailsTable(List<SubDetail> details) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SingleChildScrollView(
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 18,
                headingRowHeight: 45,
                dataRowMinHeight: 50,
                dataRowMaxHeight: 58,
                headingRowColor: WidgetStateProperty.all(_tableHeaderBg),
                columns: [
                  DataColumn(label: Text(tr('التفصيل', 'Detail'))),
                  DataColumn(label: Text(tr('اللون', 'Color'))),
                  DataColumn(label: Text(tr('إجراء', 'Action'))),
                ],
                rows: details.map((detail) {
                  final selected = _selectedDetail?.id == detail.id;
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (_) => _selectDetail(detail),
                    color: WidgetStateProperty.resolveWith<Color?>(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.blue.shade50
                          : null,
                    ),
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            detail.getDisplayName(isArabic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_colorBox(detail.color, size: 22)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 18,
                              ),
                              onPressed: () =>
                                  _showDetailDialog(existingDetail: detail),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () => _deleteDetail(detail),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCards(List<SubDetail> details) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: details.length,
      itemBuilder: (context, index) {
        final detail = details[index];
        final selected = _selectedDetail?.id == detail.id;

        return InkWell(
          onTap: () => _selectDetail(detail),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.blue.withOpacity(_isDark ? 0.20 : 0.08)
                  : _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Colors.blue
                    : _isDark
                        ? const Color(0xFF475569)
                        : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _colorBox(detail.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    detail.getDisplayName(isArabic),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _miniIconButton(
                  icon: Icons.edit,
                  color: Colors.blue,
                  tooltip: tr('تعديل', 'Edit'),
                  onTap: () => _showDetailDialog(existingDetail: detail),
                ),
                _miniIconButton(
                  icon: Icons.delete,
                  color: Colors.red,
                  tooltip: tr('حذف', 'Delete'),
                  onTap: () => _deleteDetail(detail),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectTreatment(TreatmentItem item) {
    setState(() {
      _selectedTreatment = item;
      _selectedDetail = null;
      _activeSection = ActiveSection.treatment;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _selectDetail(SubDetail detail) {
    setState(() {
      _selectedDetail = detail;
      _activeSection = ActiveSection.detail;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Widget _colorBox(Color color, {double size = 25}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _iconPreview(String imageCode) {
    if (imageCode.trim().isEmpty) return const Text('-');

    return Image.asset(
      imageCode,
      width: 28,
      height: 28,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.broken_image, size: 24, color: Colors.grey);
      },
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _mutedTileBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: _isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: TextStyle(color: _textPrimary, fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(List<TreatmentItem> currentTreatments) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildCategoriesPanel()),
        const SizedBox(width: 12),
        Expanded(
          flex: 7,
          child: _buildTreatmentsPanel(
            treatments: currentTreatments,
            compact: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: _buildDetailsPanel(compact: false)),
      ],
    );
  }

  Widget _buildMobileLayout(List<TreatmentItem> currentTreatments) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCategoriesPanel(
            height: _mobileCategoriesHeight,
            compact: true,
          ),
          const SizedBox(height: 12),
          _buildTreatmentsPanel(
            treatments: currentTreatments,
            height: _mobileTreatmentsHeight,
            compact: true,
          ),
          const SizedBox(height: 12),
          _buildDetailsPanel(
            height: _mobileDetailsHeight,
            compact: true,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTreatments = _currentTreatments;

    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 6,
      searchController: searchController,
      onSearchChanged: (String value) {},
      onLanguageChanged: _setLanguage,
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _handleArrowKey(1);
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _handleArrowKey(-1);
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
        child: Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isMobile = width < _mobileBreakpoint;

              return Container(
                color: _pageBg,
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 10 : 16),
                  child: Column(
                    children: [
                      _buildTopActionRow(isCompact: isMobile),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : isMobile
                                ? _buildMobileLayout(currentTreatments)
                                : width < _desktopDesignWidth
                                    ? Scrollbar(
                                        controller: _desktopHorizontalController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller:
                                              _desktopHorizontalController,
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: _desktopDesignWidth,
                                            child: _buildDesktopLayout(
                                              currentTreatments,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _buildDesktopLayout(currentTreatments),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
