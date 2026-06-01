import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../../../core/layout/custom_layout.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../services/materials_service.dart';
import '../utils/materials_utils.dart';
import '../widgets/materials_top_bar.dart';
import '../widgets/materials_pagination.dart';
import '../widgets/material_form_dialog.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../widgets/materials_stats_cards.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart' show kIsWeb;

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class MaterialsScreen extends StatefulWidget {
  final String username;
  final bool initialArabic;

  const MaterialsScreen({
    super.key,
    required this.username,
    required this.initialArabic,
  });

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late bool isArabic;
  bool isAdding = false;
  bool isEditMode = false;
  String? editingDocId;
  String searchQuery = "";
  String? formError;

  String sortColumn = 'name';
  bool isAscending = true;
  String? hoveredMaterialRowId;
  int _rowsPerPage = 10;
  int _currentPage = 0;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController fName = TextEditingController();
  final TextEditingController fCategory = TextEditingController();
  final TextEditingController fQuantity = TextEditingController();
  final TextEditingController fMinQty = TextEditingController();
  final TextEditingController fUnit = TextEditingController();
  final TextEditingController fPrice = TextEditingController();

  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, double> _draftQuantities = {};
  final Map<String, double> _draftPrices = {};
  final Set<String> _outOfStockAlertedDocs = {};
  final Set<String> _cleanedInvalidNumberDocs = {};
  String? _activeInlineFieldKey;

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : Colors.grey.shade50;

  Future<void> _exportMaterialsToPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          pw.Header(
            level: 0,
            child:
                pw.Text(tr("تقرير مخزون المواد", "Materials Inventory Report")),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: [
              tr("الرقم", "No."),
              tr("اسم المادة", "Material Name"),
              tr("التصنيف", "Category"),
              tr("الكمية", "Qty"),
              tr("الوحدة", "Unit"),
              tr("السعر", "Price"),
              tr("القيمة", "Value"),
              tr("الحالة", "Status"),
            ],
            data: docs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final qty = _effectiveQuantity(doc.id, data);
              final price = _effectivePrice(doc.id, data);
              final value = _effectiveValue(doc.id, data);
              return [
                '${index + 1}',
                (data['name'] ?? '').toString(),
                (data['category'] ?? '').toString(),
                _formatNumber(qty),
                (data['unit'] ?? '').toString(),
                '${price.toStringAsFixed(2)} JD',
                '${value.toStringAsFixed(2)} JD',
                _statusLabel(doc.id, data),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _exportMaterialsToExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['MaterialsInventory'];

    sheet.appendRow([
      TextCellValue(tr("الرقم", "No.")),
      TextCellValue(tr("اسم المادة", "Material Name")),
      TextCellValue(tr("التصنيف", "Category")),
      TextCellValue(tr("الكمية", "Qty")),
      TextCellValue(tr("الوحدة", "Unit")),
      TextCellValue(tr("السعر", "Price")),
      TextCellValue(tr("القيمة", "Value")),
      TextCellValue(tr("الحالة", "Status")),
    ]);

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final data = doc.data() as Map<String, dynamic>;
      final qty = _effectiveQuantity(doc.id, data);
      final price = _effectivePrice(doc.id, data);
      final value = _effectiveValue(doc.id, data);
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue((data['name'] ?? '').toString()),
        TextCellValue((data['category'] ?? '').toString()),
        TextCellValue(_formatNumber(qty)),
        TextCellValue((data['unit'] ?? '').toString()),
        TextCellValue('${price.toStringAsFixed(2)} JD'),
        TextCellValue('${value.toStringAsFixed(2)} JD'),
        TextCellValue(_statusLabel(doc.id, data)),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null && kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([fileBytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'Materials_Inventory.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
  }

  @override
  void dispose() {
    searchController.dispose();
    fName.dispose();
    fCategory.dispose();
    fQuantity.dispose();
    fMinQty.dispose();
    fUnit.dispose();
    fPrice.dispose();

    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final t in _debounceTimers.values) {
      t.cancel();
    }

    super.dispose();
  }

  void _showOutOfStockAlert({
    required String docId,
    required String name,
    required double quantity,
  }) {
    if (quantity > 0) {
      _outOfStockAlertedDocs.remove(docId);
      return;
    }

    if (quantity == 0 && !_outOfStockAlertedDocs.contains(docId)) {
      _outOfStockAlertedDocs.add(docId);
      return;
    }
  }

  void _setSort(String column) {
    setState(() {
      if (sortColumn == column) {
        isAscending = !isAscending;
      } else {
        sortColumn = column;
        isAscending = true;
      }
    });
  }

  void _openAddForm() {
    setState(() {
      isAdding = true;
      isEditMode = false;
      editingDocId = null;
      formError = null;
      fName.clear();
      fCategory.clear();
      fQuantity.clear();
      fMinQty.clear();
      fUnit.clear();
      fPrice.clear();
    });
  }

  void _openEditForm(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    setState(() {
      editingDocId = doc.id;
      isEditMode = true;
      isAdding = true;
      formError = null;
      fName.text = (d['name'] ?? '').toString();
      fCategory.text = (d['category'] ?? '').toString();
      fQuantity.text = _formatNumber(_safeDouble(d['quantity']));
      fMinQty.text = _formatNumber(_safeDouble(d['min_quantity']));
      fUnit.text = (d['unit'] ?? '').toString();
      fPrice.text = _safeDouble(d['price']).toStringAsFixed(2);
    });
  }

  void _closeForm() {
    setState(() {
      isAdding = false;
      isEditMode = false;
      editingDocId = null;
      formError = null;
      fName.clear();
      fCategory.clear();
      fQuantity.clear();
      fMinQty.clear();
      fUnit.clear();
      fPrice.clear();
    });
  }

  Future<void> _saveMaterial() async {
    final name = fName.text.trim();
    final category = fCategory.text.trim();
    final unit = fUnit.text.trim();
    final quantity = double.tryParse(fQuantity.text.trim());
    final minQty = double.tryParse(fMinQty.text.trim());
    final price = double.tryParse(fPrice.text.trim());

    if (name.isEmpty) {
      setState(() => formError = tr("أدخل اسم المادة", "Enter material name"));
      return;
    }
    if (category.isEmpty) {
      setState(() => formError = tr("أدخل التصنيف", "Enter category"));
      return;
    }
    if (unit.isEmpty) {
      setState(() => formError = tr("أدخل الوحدة", "Enter unit"));
      return;
    }
    if (quantity == null || quantity.isNaN || quantity.isInfinite || quantity < 0) {
      setState(() => formError = tr("أدخل كمية صحيحة", "Enter valid quantity"));
      return;
    }
    if (minQty == null || minQty.isNaN || minQty.isInfinite || minQty < 0) {
      setState(
        () => formError = tr("أدخل حد أدنى صحيح", "Enter valid minimum quantity"),
      );
      return;
    }
    if (price == null || price.isNaN || price.isInfinite || price < 0) {
      setState(() => formError = tr("أدخل سعرًا صحيحًا", "Enter valid price"));
      return;
    }

    final data = {
      'name': name,
      'category': category,
      'quantity': quantity,
      'min_quantity': minQty,
      'unit': unit,
      'price': price,
      'last_updated': Timestamp.now(),
    };

    String savedDocId;

    if (isEditMode && editingDocId != null) {
      savedDocId = editingDocId!;
      await MaterialsService.updateMaterial(editingDocId!, data);
    } else {
      final docRef = await MaterialsService.addMaterial(data);
      savedDocId = docRef.id;
    }

    _closeForm();

    _showOutOfStockAlert(
      docId: savedDocId,
      name: name,
      quantity: quantity,
    );
  }

  Future<void> _confirmDelete(String docId, String name) async {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _surface(context),
          title: Text(
            tr("تأكيد الحذف", "Confirm Delete"),
            style: TextStyle(color: _textPrimary(context)),
          ),
          content: Text(
            isArabic
                ? "هل أنت متأكد من حذف المادة: $name ؟"
                : "Are you sure you want to delete: $name ?",
            style: TextStyle(color: _textPrimary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr("إلغاء", "Cancel")),
            ),
            ElevatedButton(
              onPressed: () async {
                await MaterialsService.deleteMaterial(docId);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(
                tr("حذف", "Delete"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _safeDouble(dynamic value, [double fallback = 0]) {
    return MaterialsUtils.safeDouble(value, fallback);
  }

  double _safePositiveDimension(dynamic value, double fallback) {
    return MaterialsUtils.safePositiveDimension(value, fallback);
  }

  String _safeMoney(dynamic value, {int decimals = 2}) {
    return MaterialsUtils.safeMoney(value, decimals: decimals);
  }

  bool _isBadNumber(dynamic value) {
    return MaterialsUtils.isBadNumber(value);
  }

  Future<void> _cleanInvalidMaterialNumbers(
    List<QueryDocumentSnapshot> docs,
  ) async {
    for (final doc in docs) {
      if (_cleanedInvalidNumberDocs.contains(doc.id)) continue;

      final data = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> fixes = {};

      if (_isBadNumber(data['quantity'])) fixes['quantity'] = 0.0;
      if (_isBadNumber(data['min_quantity'])) fixes['min_quantity'] = 0.0;
      if (_isBadNumber(data['price'])) fixes['price'] = 0.0;

      _cleanedInvalidNumberDocs.add(doc.id);

      if (fixes.isNotEmpty) {
        await MaterialsService.fixInvalidMaterialNumbers(
          docId: doc.id,
          fixes: fixes,
        );
      }
    }
  }

  double _serverQuantity(Map<String, dynamic> data) =>
      _safeDouble(data['quantity']);

  double _serverPrice(Map<String, dynamic> data) => _safeDouble(data['price']);

  double _serverMinQty(Map<String, dynamic> data) =>
      _safeDouble(data['min_quantity']);

  double _effectiveQuantity(String docId, Map<String, dynamic> data) =>
      _safeDouble(_draftQuantities[docId], _serverQuantity(data));

  double _effectivePrice(String docId, Map<String, dynamic> data) =>
      _safeDouble(_draftPrices[docId], _serverPrice(data));

  double _effectiveValue(String docId, Map<String, dynamic> data) {
    final value = _effectiveQuantity(docId, data) * _effectivePrice(docId, data);
    return _safeDouble(value);
  }

  bool _isLowStock(String docId, Map<String, dynamic> data) =>
      _effectiveQuantity(docId, data) <= _serverMinQty(data);

  bool _isOutOfStock(String docId, Map<String, dynamic> data) =>
      _effectiveQuantity(docId, data) == 0;

  String _statusLabel(String docId, Map<String, dynamic> data) {
    if (_isOutOfStock(docId, data)) {
      return tr("الكمية نفذت", "Out of stock");
    }
    if (_isLowStock(docId, data)) {
      return tr("شارف على الانتهاء", "Almost Out");
    }
    return tr("متوفر", "Available");
  }

  String _statusLabelCompact(String docId, Map<String, dynamic> data) {
    if (_isOutOfStock(docId, data)) {
      return tr("نفذت", "Out");
    }
    if (_isLowStock(docId, data)) {
      return tr("ناقص", "Low");
    }
    return tr("متوفر", "OK");
  }

  String _formatNumber(double value) {
    return MaterialsUtils.formatNumber(value);
  }

  TextEditingController _getInlineController({
    required String docId,
    required String field,
    required double value,
  }) {
    final key = '$docId|$field';
    final targetMap =
        field == 'quantity' ? _quantityControllers : _priceControllers;

    final safeValue = _safeDouble(value);
    final displayText =
        field == 'price' ? safeValue.toStringAsFixed(2) : _formatNumber(safeValue);

    final controller = targetMap.putIfAbsent(
      key,
      () => TextEditingController(text: displayText),
    );

    if (_activeInlineFieldKey != key && controller.text != displayText) {
      controller.text = displayText;
    }

    return controller;
  }

  void _onInlineChanged({
    required String docId,
    required String field,
    required String rawValue,
    required Map<String, dynamic> data,
  }) {
    final parsed = double.tryParse(rawValue.trim());

    setState(() {
      if (field == 'quantity') {
        if (parsed != null && parsed.isFinite && parsed >= 0) {
          _draftQuantities[docId] = parsed;
        }
      } else {
        if (parsed != null && parsed.isFinite && parsed >= 0) {
          _draftPrices[docId] = parsed;
        }
      }
    });

    final timerKey = '$docId|$field';
    _debounceTimers[timerKey]?.cancel();

    _debounceTimers[timerKey] =
        Timer(const Duration(milliseconds: 500), () async {
      if (parsed == null || !parsed.isFinite || parsed < 0) return;

      await MaterialsService.updateMaterialField(
        docId: docId,
        field: field,
        value: parsed,
      );

      if (field == 'quantity') {
        _showOutOfStockAlert(
          docId: docId,
          name: (data['name'] ?? '').toString(),
          quantity: parsed,
        );
      }
    });
  }

  void _finalizeInlineField({
    required String docId,
    required String field,
    required Map<String, dynamic> data,
  }) {
    final key = '$docId|$field';
    final controller = field == 'quantity'
        ? _quantityControllers[key]
        : _priceControllers[key];

    final parsed = double.tryParse(controller?.text.trim() ?? '');

    setState(() {
      _activeInlineFieldKey = null;

      if (parsed == null || !parsed.isFinite || parsed < 0) {
        if (field == 'quantity') {
          _draftQuantities.remove(docId);
          controller?.text = _formatNumber(_serverQuantity(data));
        } else {
          _draftPrices.remove(docId);
          controller?.text = _serverPrice(data).toStringAsFixed(2);
        }
      } else {
        if (field == 'quantity') {
          _draftQuantities[docId] = parsed;
        } else {
          _draftPrices[docId] = parsed;
        }
      }
    });
  }

  Future<void> _stepInlineValue({
    required String docId,
    required String field,
    required Map<String, dynamic> data,
    double step = 1,
    bool increment = true,
  }) async {
    final current = _safeDouble(
      field == 'quantity'
          ? _effectiveQuantity(docId, data)
          : _effectivePrice(docId, data),
    );
    final safeStep = _safeDouble(step, 1);

    double next = increment ? current + safeStep : current - safeStep;
    next = _safeDouble(next);
    if (next < 0) next = 0;

    if (field == 'price') {
      next = _safeDouble(double.parse(next.toStringAsFixed(2)));
    }

    final key = '$docId|$field';

    setState(() {
      _activeInlineFieldKey = key;
      if (field == 'quantity') {
        _draftQuantities[docId] = next;
      } else {
        _draftPrices[docId] = next;
      }
    });

    final controller = _getInlineController(
      docId: docId,
      field: field,
      value: next,
    );

    controller.text =
        field == 'price' ? next.toStringAsFixed(2) : _formatNumber(next);

    await MaterialsService.updateMaterialField(
      docId: docId,
      field: field,
      value: next,
    );

    if (field == 'quantity') {
      _showOutOfStockAlert(
        docId: docId,
        name: (data['name'] ?? '').toString(),
        quantity: next,
      );
    }

    if (mounted) {
      setState(() {
        _activeInlineFieldKey = null;
      });
    }
  }

  List<QueryDocumentSnapshot> _prepareDocs(List<QueryDocumentSnapshot> input) {
    final docs = input.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) || category.contains(searchQuery);
    }).toList();

    docs.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;

      late dynamic va;
      late dynamic vb;

      switch (sortColumn) {
        case 'name':
          va = (da['name'] ?? '').toString().toLowerCase();
          vb = (db['name'] ?? '').toString().toLowerCase();
          break;
        case 'category':
          va = (da['category'] ?? '').toString().toLowerCase();
          vb = (db['category'] ?? '').toString().toLowerCase();
          break;
        case 'quantity':
          va = _effectiveQuantity(a.id, da);
          vb = _effectiveQuantity(b.id, db);
          break;
        case 'price':
          va = _effectivePrice(a.id, da);
          vb = _effectivePrice(b.id, db);
          break;
        case 'value':
          va = _effectiveValue(a.id, da);
          vb = _effectiveValue(b.id, db);
          break;
        case 'status':
          va = _isLowStock(a.id, da) ? 0 : 1;
          vb = _isLowStock(b.id, db) ? 0 : 1;
          break;
        default:
          va = (da['name'] ?? '').toString().toLowerCase();
          vb = (db['name'] ?? '').toString().toLowerCase();
      }

      final result = va is num && vb is num
          ? _safeDouble(va).compareTo(_safeDouble(vb))
          : va.toString().compareTo(vb.toString());

      return isAscending ? result : -result;
    });

    return docs;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 3,
      searchController: searchController,
      onSearchChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
      onLanguageChanged: (val) => setState(() => isArabic = val),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = _safePositiveDimension(
            constraints.maxWidth,
            MediaQuery.of(context).size.width,
          );
          final bool showTable = screenWidth >= 1100;
          final bool isMobile = screenWidth < 700;
          final double pagePadding = isMobile ? 10 : 24;
          final double topPadding = isMobile ? 8 : pagePadding;
          final double sectionGap = isMobile ? 8 : 20;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pagePadding,
                  topPadding,
                  pagePadding,
                  pagePadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1750),
                    child: Column(
                      children: [
                        _buildHeader(screenWidth),
                        SizedBox(height: sectionGap),
                        _buildStatsCards(),
                        SizedBox(height: sectionGap),
                        Expanded(
                          child: _buildMaterialsContent(showTable),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isAdding) _buildAddOverlay(BoxConstraints(maxWidth: screenWidth)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(double width) {
    final double safeWidth =
        _safePositiveDimension(width, MediaQuery.of(context).size.width);
    final bool stack = safeWidth < 760;
    final bool isMobile = safeWidth < 700;

    return stack
        ? SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr("إدارة مخزون المواد", "Inventory Management"),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.bold,
                      color: lapisBlue,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr("إدارة مخزون المواد", "Inventory Management"),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: lapisBlue,
                ),
              ),
            ],
          );
  }
Widget _buildStatsCards() {
  return MaterialsStatsCards(isArabic: isArabic);
}

  Widget _buildMaterialsContent(bool showTable) {
    return LayoutBuilder(
      builder: (context, contentConstraints) {
        final double contentWidth = _safePositiveDimension(
          contentConstraints.maxWidth,
          MediaQuery.of(context).size.width,
        );
        final bool isMobile = contentWidth < 700;

        return StreamBuilder<QuerySnapshot>(
          stream: MaterialsService.watchMaterials(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _cleanInvalidMaterialNumbers(snapshot.data!.docs);
              }
            });

            final docs = _prepareDocs(snapshot.data!.docs);

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  tr("لا توجد مواد", "No materials found"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary(context),
                  ),
                ),
              );
            }

            final int safeRowsPerPage = _rowsPerPage <= 0 ? 10 : _rowsPerPage;
            final int totalPages = docs.isEmpty
                ? 1
                : ((docs.length + safeRowsPerPage - 1) ~/ safeRowsPerPage);
            if (_currentPage >= totalPages) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _currentPage = totalPages - 1);
                }
              });
            }

            final int safePage = _currentPage < 0
                ? 0
                : (_currentPage > totalPages - 1 ? totalPages - 1 : _currentPage);
            final int startIndex = safePage * safeRowsPerPage;
            final int endIndex = startIndex + safeRowsPerPage > docs.length
                ? docs.length
                : startIndex + safeRowsPerPage;
            final List<QueryDocumentSnapshot> pagedDocs =
                docs.sublist(startIndex, endIndex);

            return Column(
              children: [
                _buildTableTopBar(isMobile: isMobile, docs: docs),
                SizedBox(height: isMobile ? 8 : 12),
                Expanded(
                  child: _buildDesktopTable(
                    pagedDocs,
                    startIndex: startIndex,
                    showAddButton: false,
                  ),
                ),
                if (totalPages > 1) _buildPagination(totalPages, isMobile: isMobile),
              ],
            );
          },
        );
      },
    );
  }

Widget _buildTableTopBar({
  required bool isMobile,
  required List<QueryDocumentSnapshot> docs,
}) {
  return MaterialsTopBar(
    isArabic: isArabic,
    isMobile: isMobile,
    rowsPerPage: _rowsPerPage,
    docs: docs,
    onAddMaterial: _openAddForm,
    onRowsPerPageChanged: (value) {
      setState(() {
        _rowsPerPage = value;
        _currentPage = 0;
      });
    },
    onExportPdf: _exportMaterialsToPDF,
    onExportExcel: _exportMaterialsToExcel,
  );
}
Widget _buildPagination(int totalPages, {required bool isMobile}) {
  return MaterialsPagination(
    totalPages: totalPages,
    currentPage: _currentPage,
    isMobile: isMobile,
    onPageChanged: (page) {
      setState(() => _currentPage = page);
    },
  );
}

  Widget _buildDesktopTable(
    List<QueryDocumentSnapshot> docs, {
    required int startIndex,
    bool showAddButton = true,
  }) {
    const double desktopMinTableWidth = 1600;
    const double mobileFitTableWidth = 720;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double safeMaxWidth = _safePositiveDimension(
          constraints.maxWidth,
          MediaQuery.of(context).size.width,
        );
        final bool isMobileTable = safeMaxWidth < 700;
        final double tableWidth = safeMaxWidth > desktopMinTableWidth
            ? safeMaxWidth
            : desktopMinTableWidth;

        final Map<int, TableColumnWidth> columnWidths = isMobileTable
            ? const {
                0: FlexColumnWidth(0.55),
                1: FlexColumnWidth(1.55),
                2: FlexColumnWidth(1.00),
                3: FlexColumnWidth(1.75),
                4: FlexColumnWidth(1.70),
                5: FlexColumnWidth(1.25),
                6: FlexColumnWidth(1.45),
                7: FlexColumnWidth(0.75),
              }
            : const {
                0: FlexColumnWidth(0.8),
                1: FlexColumnWidth(2.4),
                2: FlexColumnWidth(1.8),
                3: FlexColumnWidth(2.3),
                4: FlexColumnWidth(2.3),
                5: FlexColumnWidth(1.6),
                6: FlexColumnWidth(1.1),
                7: FlexColumnWidth(1.4),
              };

        Widget buildTableHeader() {
          return Table(
            columnWidths: columnWidths,
            border: TableBorder(
              top: BorderSide(color: lapisBlue, width: 1),
              bottom: BorderSide(color: _border(context), width: 1),
              left: BorderSide(color: _border(context), width: 1),
              right: BorderSide(color: _border(context), width: 1),
              horizontalInside: BorderSide(color: _border(context), width: 1),
              verticalInside: BorderSide(color: _border(context), width: 1),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: lapisBlue),
                children: [
                  _tableStaticHeaderCell(tr("الرقم", "No.")),
                  _tableHeaderCell(tr("اسم المادة", "Material Name"), 'name'),
                  _tableHeaderCell(tr("التصنيف", "Category"), 'category'),
                  _tableHeaderCell(tr("الكمية", "Qty"), 'quantity'),
                  _tableHeaderCell(tr("السعر", "Price"), 'price'),
                  _tableHeaderCell(tr("القيمة", "Value"), 'value'),
                  _tableHeaderCell(tr("الحالة", "Status"), 'status'),
                  _tableStaticHeaderCell(tr("إجراءات", "Actions")),
                ],
              ),
            ],
          );
        }

        Widget buildTableBody() {
          return Table(
            columnWidths: columnWidths,
            border: TableBorder(
              bottom: BorderSide(color: _border(context), width: 1),
              left: BorderSide(color: _border(context), width: 1),
              right: BorderSide(color: _border(context), width: 1),
              horizontalInside: BorderSide(color: _border(context), width: 1),
              verticalInside: BorderSide(color: _border(context), width: 1),
            ),
            children: [
              ...docs.asMap().entries.map((entry) {
                final index = entry.key;
                final doc = entry.value;
                final d = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final qty = _effectiveQuantity(docId, d);
                final price = _effectivePrice(docId, d);
                final value = _effectiveValue(docId, d);
                final isLow = _isLowStock(docId, d);
                final isOut = _isOutOfStock(docId, d);
                final name = (d['name'] ?? '').toString();
                final unit = (d['unit'] ?? '').toString();
                final bool isHovered = hoveredMaterialRowId == docId;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isLow
                        ? Colors.red.withOpacity(_isDark ? 0.18 : 0.08)
                        : isHovered
                            ? lapisBlue.withOpacity(0.08)
                            : index.isEven
                                ? _surface(context)
                                : _softFill(context),
                  ),
                  children: [
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        Center(
                          child: Text(
                            '${startIndex + index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: lapisBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        Center(
                          child: Text(
                            (d['category'] ?? '').toString(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        _editableStepperCell(
                          docId: docId,
                          field: 'quantity',
                          value: qty,
                          data: d,
                          suffix: unit,
                          step: 1,
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        _editableStepperCell(
                          docId: docId,
                          field: 'price',
                          value: price,
                          data: d,
                          step: 1,
                          suffix: 'JD',
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        Center(
                          child: Text(
                            "${_safeMoney(value)} JD",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLow ? Icons.error : Icons.check_circle,
                                  color: isLow ? Colors.red : Colors.green,
                                  size: isMobileTable ? 14 : 22,
                                ),
                                SizedBox(width: isMobileTable ? 3 : 6),
                                Text(
                                  isMobileTable
                                      ? _statusLabelCompact(docId, d)
                                      : _statusLabel(docId, d),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLow ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobileTable ? 9.5 : (isOut ? 12 : 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _hoverableMaterialRowCell(
                      docId,
                      _tableBodyCell(
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: BoxConstraints(
                                  minWidth: isMobileTable ? 22 : 40,
                                  minHeight: isMobileTable ? 26 : 40,
                                ),
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.green,
                                  size: isMobileTable ? 15 : 24,
                                ),
                                onPressed: () => _openEditForm(doc),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: BoxConstraints(
                                  minWidth: isMobileTable ? 22 : 40,
                                  minHeight: isMobileTable ? 26 : 40,
                                ),
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: isMobileTable ? 15 : 24,
                                ),
                                onPressed: () => _confirmDelete(docId, name),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        }

        return Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showAddButton)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isMobileTable ? 8 : 12),
                  child: ElevatedButton.icon(
                    onPressed: _openAddForm,
                    icon: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: isMobileTable ? 18 : 22,
                    ),
                    label: Text(
                      tr("إضافة مادة", "Add Material"),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobileTable ? 13 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lapisBlue,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobileTable ? 16 : 22,
                        vertical: isMobileTable ? 10 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobileTable ? 8 : 9),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(isMobileTable ? 12 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: isMobileTable ? 9 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isMobileTable ? 12 : 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: isMobileTable ? mobileFitTableWidth : tableWidth,
                      child: Column(
                        children: [
                          buildTableHeader(),
                          Expanded(
                            child: SingleChildScrollView(
                              child: buildTableBody(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

Widget _buildAddOverlay(BoxConstraints constraints) {
  return MaterialFormDialog(
    constraints: constraints,
    isArabic: isArabic,
    isEditMode: isEditMode,
    formError: formError,
    nameController: fName,
    categoryController: fCategory,
    quantityController: fQuantity,
    minQtyController: fMinQty,
    unitController: fUnit,
    priceController: fPrice,
    onClose: _closeForm,
    onSave: _saveMaterial,
  );
}
  Widget _tableHeaderCell(String title, String column) {
    final bool active = sortColumn == column;
    final bool compact = MediaQuery.of(context).size.width < 700;

    return InkWell(
      onTap: () => _setSort(column),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 10,
          vertical: compact ? 8 : 14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 8.5 : 15,
                ),
              ),
            ),
            SizedBox(width: compact ? 1 : 4),
            Icon(
              active
                  ? (isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
                  : Icons.unfold_more,
              color: Colors.white,
              size: compact ? 10 : 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableStaticHeaderCell(String title) {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 10,
        vertical: compact ? 8 : 14,
      ),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 8.5 : 15,
          ),
        ),
      ),
    );
  }

  Widget _tableBodyCell(Widget child) {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 10,
        vertical: compact ? 6 : 10,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: compact ? 11.5 : 14),
        child: child,
      ),
    );
  }

  Widget _hoverableMaterialRowCell(String rowId, Widget child) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hoveredMaterialRowId = rowId),
      onExit: (_) {
        if (hoveredMaterialRowId == rowId) {
          setState(() => hoveredMaterialRowId = null);
        }
      },
      child: child,
    );
  }

  Widget _editableStepperCell({
    required String docId,
    required String field,
    required double value,
    required Map<String, dynamic> data,
    String suffix = '',
    double step = 1,
  }) {
    final key = '$docId|$field';

    final controller = _getInlineController(
      docId: docId,
      field: field,
      value: value,
    );

    final bool compact = MediaQuery.of(context).size.width < 700;

    return Container(
      height: compact ? 32 : 38,
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border(context)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _stepInlineValue(
              docId: docId,
              field: field,
              data: data,
              step: step,
              increment: false,
            ),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: compact ? 20 : 30,
              height: compact ? 32 : 38,
              child: Center(
                child: Icon(
                  Icons.remove,
                  size: compact ? 13 : 16,
                  color: lapisBlue,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onTap: () => setState(() => _activeInlineFieldKey = key),
              onChanged: (v) => _onInlineChanged(
                docId: docId,
                field: field,
                rawValue: v,
                data: data,
              ),
              onSubmitted: (_) => _finalizeInlineField(
                docId: docId,
                field: field,
                data: data,
              ),
              onTapOutside: (_) => _finalizeInlineField(
                docId: docId,
                field: field,
                data: data,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 11.5 : 14,
                color: _textPrimary(context),
              ),
            ),
          ),
          if (suffix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                suffix,
                style: TextStyle(
                  fontSize: compact ? 9.5 : 12,
                  color: _textSecondary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          InkWell(
            onTap: () => _stepInlineValue(
              docId: docId,
              field: field,
              data: data,
              step: step,
              increment: true,
            ),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: compact ? 20 : 30,
              height: compact ? 32 : 38,
              child: Center(
                child: Icon(
                  Icons.add,
                  size: compact ? 13 : 16,
                  color: lapisBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
