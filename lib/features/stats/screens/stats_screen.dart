import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:url_launcher/url_launcher.dart'; // تأكدي من وجود هذه المكتبة في المشروع
import '../services/stats_service.dart';
import '../utils/stats_utils.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../../core/layout/custom_layout.dart';
import '../widgets/stats_pagination.dart';
import '../widgets/stats_summary_card.dart';
import '../widgets/stats_chart_card.dart';
import '../widgets/stats_top_bar.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class StatsScreen extends StatefulWidget {
  final String username;
  final int initialView;
  final bool initialArabic;

  const StatsScreen({
    super.key,
    required this.username,
    required this.initialView,
    required this.initialArabic,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late bool isArabic;
  String searchQuery = "";
  final TextEditingController searchController = TextEditingController();

  late int viewType;
  String sortColumn = "full_name";
  bool isAscending = true;
  bool isRefreshing = false;

  int? currentPage;
  int? rowsPerPage;

  int get _currentPage {
    currentPage ??= 1;
    return currentPage!;
  }

  int get _rowsPerPage {
    rowsPerPage ??= 10;
    return rowsPerPage!;
  }

  DateTime startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month - 1,
    1,
  );
  DateTime endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    viewType = widget.initialView;
    currentPage ??= 1;
    rowsPerPage ??= 10;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  TextDirection get _pageDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  bool _isMobileWidth(double width) => width < 700;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : lightGray;

  double _toDouble(dynamic value) {
    return StatsUtils.toDouble(value);
  }

  // دالة لتنظيف رقم الهاتف وفتحه عبر الروابط
  Future<void> _launchPhoneAction(String phone, String type) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;

    Uri url;
    if (type == 'call') {
      url = Uri.parse('tel:$cleanPhone');
    } else if (type == 'wa') {
      url = Uri.parse('https://wa.me/962$cleanPhone'); // تعديل كود الدولة حسب الحاجة
    } else {
      url = Uri.parse('sms:$cleanPhone');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _exportToPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("التقرير الإحصائي المالي للمرضى")),
          pw.SizedBox(height: 10),
          pw.Text(
            "الفترة من: ${startDate.year}-${startDate.month}-${startDate.day}  إلى: ${endDate.year}-${endDate.month}-${endDate.day}",
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["المتبقي", "المدفوع", "الخصم", "المطلوب", "اسم المريض"],
            data: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return [
                "${d['remaining_amount'] ?? 0} JD",
                "${d['paid_amount'] ?? 0} JD",
                "${d['discount'] ?? 0} JD",
                "${d['required_amount'] ?? 0} JD",
                d['full_name'] ?? "-",
              ];
            }).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['FinancialStats'];
    sheetObject.appendRow([
      TextCellValue("اسم المريض"),
      TextCellValue("المبلغ المطلوب (JD)"),
      TextCellValue("الخصم (JD)"),
      TextCellValue("المبلغ المدفوع (JD)"),
      TextCellValue("المبلغ المتبقي (JD)")
    ]);

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      sheetObject.appendRow([
        TextCellValue(d['full_name']?.toString() ?? ""),
        TextCellValue("${d['required_amount'] ?? 0} JD"),
        TextCellValue("${d['discount'] ?? 0} JD"),
        TextCellValue("${d['paid_amount'] ?? 0} JD"),
        TextCellValue("${d['remaining_amount'] ?? 0} JD"),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null && kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([fileBytes]));
      html.AnchorElement(href: url)
        ..setAttribute("download", "Clinic_Financial_Report.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(tr("تم تحديث البيانات بنجاح", "Data updated successfully")),
          backgroundColor: lapisBlue,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.of(context).copyWith(primary: lapisBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
        currentPage = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = _isMobileWidth(screenWidth);

    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 4,
      searchController: searchController,
      onSearchChanged: (v) => setState(() {
        searchQuery = v.toLowerCase();
        currentPage = 1;
      }),
      onLanguageChanged: (val) => setState(() => isArabic = val),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 25,
          vertical: isMobile ? 10 : 25,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                SizedBox(height: isMobile ? 8 : 15),
                if (viewType == 0) _buildExportButton(),
                if (viewType == 0) SizedBox(height: isMobile ? 8 : 15),
                _buildFilterSection(),
                SizedBox(height: isMobile ? 8 : 25),
                Expanded(
                  child: viewType == 0
                      ? _buildFinancialTable()
                      : _buildChartsView(),
                ),
              ],
            ),
            if (isRefreshing)
              Container(
                color: _surface(context).withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: lapisBlue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return StatsTopBar(
      isArabic: isArabic,
      viewType: viewType,
      onViewChanged: (index) {
        setState(() {
          viewType = index;
          currentPage = 1;
        });
      },
    );
  }

  Widget _buildRowsPerPageSelector() {
    final bool isMobile = _isMobileWidth(MediaQuery.of(context).size.width);
    final double buttonHeight = isMobile ? 35 : 40;
    final double menuWidth = isMobile ? 118 : 132;

    return PopupMenuButton<int>(
      tooltip: '',
      color: _surface(context),
      elevation: 8,
      offset: Offset(0, isMobile ? 38 : 43),
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        side: BorderSide(color: _border(context).withOpacity(0.6)),
      ),
      onSelected: (value) {
        setState(() {
          rowsPerPage = value;
          currentPage = 1;
        });
      },
      itemBuilder: (context) => [10, 50, 100].map((value) {
        final bool selected = value == _rowsPerPage;

        return PopupMenuItem<int>(
          value: value,
          height: isMobile ? 34 : 38,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 9 : 11,
            vertical: 0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? lapisBlue.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 7 : 8,
              vertical: isMobile ? 5 : 6,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_rounded : Icons.circle_outlined,
                  size: isMobile ? 14 : 15,
                  color: selected ? lapisBlue : _textSecondary(context),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    tr("إظهار $value", "Show $value"),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? lapisBlue : _textPrimary(context),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: isMobile ? 11.5 : 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: buttonHeight,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 9 : 11),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(isMobile ? 7 : 8),
          border: Border.all(color: lapisBlue, width: isMobile ? 1.1 : 1.25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.14 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: lapisBlue,
                size: isMobile ? 17 : 19,
              ),
              SizedBox(width: isMobile ? 5 : 6),
              Text(
                tr("إظهار $_rowsPerPage", "Show $_rowsPerPage"),
                style: TextStyle(
                  color: _textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: isMobile ? 11.8 : 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: StatsService.watchPatientsByLastVisit(
        startDate: startDate,
        endDate: endDate,
      ),
      builder: (context, snapshot) {
        final bool isMobile = _isMobileWidth(MediaQuery.of(context).size.width);

        return Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Wrap(
            spacing: isMobile ? 8 : 12,
            runSpacing: isMobile ? 8 : 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<int>(
                color: _surface(context),
                offset: Offset(0, isMobile ? 38 : 45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (val) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    if (val == 1) _exportToPDF(snapshot.data!.docs);
                    if (val == 2) _exportToExcel(snapshot.data!.docs);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tr("تصدير PDF", "Export PDF"),
                          style: TextStyle(color: _textPrimary(context)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 2,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.table_chart,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tr("تصدير Excel", "Export Excel"),
                          style: TextStyle(color: _textPrimary(context)),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 13 : 18,
                    vertical: isMobile ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: lapisBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.print_rounded,
                        size: isMobile ? 14 : 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        tr("طباعة", "Print"),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                      SizedBox(width: isMobile ? 3 : 5),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                        size: isMobile ? 14 : 16,
                      ),
                    ],
                  ),
                ),
              ),
              _buildRowsPerPageSelector(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = _isMobileWidth(constraints.maxWidth);

        if (!isMobile) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr("تحديد الفترة:", "Select Period:"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lapisBlue,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 25),
                _dateDisplay(
                  tr("من", "From"),
                  startDate,
                  () => _pickDate(context, true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: _textSecondary(context),
                  ),
                ),
                _dateDisplay(
                  tr("إلى", "To"),
                  endDate,
                  () => _pickDate(context, false),
                ),
                const SizedBox(width: 30),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: _handleRefresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lapisBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      tr("موافق", "OK"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border(context)),
          ),
          child: Directionality(
            textDirection: _pageDirection,
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr("تحديد الفترة:", "Select Period:"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lapisBlue,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _dateDisplayCompact(
                        tr("من", "From"),
                        startDate,
                        () => _pickDate(context, true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: _textSecondary(context),
                      ),
                    ),
                    Expanded(
                      child: _dateDisplayCompact(
                        tr("إلى", "To"),
                        endDate,
                        () => _pickDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleRefresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lapisBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      tr("موافق", "OK"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateDisplay(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: _softFill(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$label: ",
              style: TextStyle(color: _textSecondary(context), fontSize: 12),
            ),
            Text(
              "${date.year}-${date.month}-${date.day}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: lapisBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateDisplayCompact(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _softFill(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$label: ",
                style: TextStyle(color: _textSecondary(context), fontSize: 10),
              ),
              Text(
                "${date.year}-${date.month}-${date.day}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: lapisBlue,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return StatsPagination(
      totalPages: totalPages,
      currentPage: _currentPage,
      isDark: _isDark,
      onPageChanged: (page) {
        setState(() => currentPage = page);
      },
    );
  }

  Widget _buildFinancialTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: StatsService.watchPatientsByLastVisit(
        startDate: startDate,
        endDate: endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((d) {
          final String name = (d['full_name'] ?? "").toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        docs.sort((a, b) {
          final valA = a[sortColumn];
          final valB = b[sortColumn];

          const numericColumns = {
            'required_amount',
            'discount',
            'paid_amount',
            'remaining_amount',
          };

          if (numericColumns.contains(sortColumn)) {
            final numA = (valA is num)
                ? valA.toDouble()
                : double.tryParse(valA.toString()) ?? 0.0;
            final numB = (valB is num)
                ? valB.toDouble()
                : double.tryParse(valB.toString()) ?? 0.0;
            return isAscending ? numA.compareTo(numB) : numB.compareTo(numA);
          }

          return isAscending
              ? valA.toString().compareTo(valB.toString())
              : valB.toString().compareTo(valA.toString());
        });

        final int totalItems = docs.length;
        final bool useMobileSizedTable =
            _isMobileWidth(MediaQuery.of(context).size.width);
        final int effectiveRowsPerPage = _rowsPerPage;
        final int totalPages = totalItems == 0
            ? 0
            : (totalItems / effectiveRowsPerPage).ceil();

        if (totalPages > 0 && _currentPage > totalPages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => currentPage = totalPages);
            }
          });
        }

        final int safePage = totalPages == 0
            ? 1
            : _currentPage > totalPages
                ? totalPages
                : _currentPage;

        final int startIndex = (safePage - 1) * effectiveRowsPerPage;
        int endIndex = startIndex + effectiveRowsPerPage;
        if (endIndex > totalItems) endIndex = totalItems;

        final List<QueryDocumentSnapshot> pagedDocs =
            totalItems > 0 ? docs.sublist(startIndex, endIndex) : [];

        double tReq = 0, tPaid = 0, tDisc = 0, tRem = 0;
        for (final d in docs) {
          tReq += _toDouble(d['required_amount']);
          tPaid += _toDouble(d['paid_amount']);
          tDisc += _toDouble(d['discount']);
          tRem += _toDouble(d['remaining_amount']);
        }

        const Map<int, TableColumnWidth> columnWidths = {
          0: FlexColumnWidth(0.8),
          1: FlexColumnWidth(3.0), // الاسم
          2: FlexColumnWidth(2.6), // التلفون + الأيقونة
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(2.0),
          5: FlexColumnWidth(2.0),
          6: FlexColumnWidth(2.0),
        };

        final double cellHorizontalPadding = useMobileSizedTable ? 3 : 12;
        final double headerVerticalPadding = useMobileSizedTable ? 8 : 15;
        final double bodyVerticalPadding = useMobileSizedTable ? 6 : 12;
        final TextStyle tableHeaderStyle = TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: useMobileSizedTable ? 11 : 14,
        );
        final TextStyle totalStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: lapisBlue,
          fontSize: useMobileSizedTable ? 11.5 : 15,
        );

        final TextStyle nameStyle = TextStyle(
          fontWeight: FontWeight.w600,
          color: _textPrimary(context),
          fontSize: useMobileSizedTable ? 11.5 : 14,
        );

        Widget headerCell(
          Widget child, {
          Alignment alignment = Alignment.center,
        }) {
          return Container(
            alignment: alignment,
            padding: EdgeInsets.symmetric(
              horizontal: cellHorizontalPadding,
              vertical: headerVerticalPadding,
            ),
            child: child,
          );
        }

        Widget bodyCell(
          Widget child, {
          Alignment alignment = Alignment.center,
        }) {
          return Container(
            alignment: alignment,
            padding: EdgeInsets.symmetric(
              horizontal: cellHorizontalPadding,
              vertical: bodyVerticalPadding,
            ),
            child: child,
          );
        }

        Widget sortableHeaderCell(
          String title,
          String col, {
          Alignment alignment = Alignment.center,
          TextAlign textAlign = TextAlign.center,
        }) {
          final bool isActive = sortColumn == col;

          return InkWell(
            onTap: () => setState(() {
              if (sortColumn == col) {
                isAscending = !isAscending;
              } else {
                sortColumn = col;
                isAscending = true;
              }
            }),
            child: Container(
              alignment: alignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: textAlign,
                      style: tableHeaderStyle,
                      maxLines: 1,
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      isActive
                          ? (isAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : Icons.sort,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        Widget buildHeader() {
          return Container(
            decoration: const BoxDecoration(
              color: lapisBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    headerCell(
                      Text("#", style: tableHeaderStyle, textAlign: TextAlign.center),
                    ),
                    headerCell(
                      sortableHeaderCell(
                        tr("اسم المريض", "Patient Name"),
                        "full_name",
                        alignment: isArabic
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        textAlign:
                            isArabic ? TextAlign.right : TextAlign.left,
                      ),
                      alignment:
                          isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    ),
                    headerCell(
                      Text(
                        tr("رقم الهاتف", "Phone"),
                        style: tableHeaderStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    headerCell(
                      sortableHeaderCell(
                        tr("المطلوب", "Required"),
                        "required_amount",
                      ),
                    ),
                    headerCell(
                      sortableHeaderCell(
                        tr("الخصم", "Discount"),
                        "discount",
                      ),
                    ),
                    headerCell(
                      sortableHeaderCell(
                        tr("المدفوع", "Paid"),
                        "paid_amount",
                      ),
                    ),
                    headerCell(
                      sortableHeaderCell(
                        tr("المتبقي", "Remaining"),
                        "remaining_amount",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        Widget buildTotalsRow() {
          return Container(
            decoration: BoxDecoration(
              color: lapisBlue.withOpacity(0.08),
              border: const Border(
                bottom: BorderSide(color: lapisBlue, width: 1),
              ),
            ),
            child: Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    bodyCell(
                      const Icon(Icons.analytics, color: lapisBlue),
                    ),
                    bodyCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: isArabic
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Text(
                            tr("إجمالي نتائج الفترة", "Period Totals"),
                            textAlign:
                                isArabic ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: lapisBlue,
                              fontSize: useMobileSizedTable ? 12 : 16,
                            ),
                          ),
                        ],
                      ),
                      alignment:
                          isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    ),
                    bodyCell(
                      Text(
                        "-",
                        style: totalStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${tReq.toStringAsFixed(0)} JD",
                        textAlign: TextAlign.center,
                        style: totalStyle,
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${tDisc.toStringAsFixed(0)} JD",
                        textAlign: TextAlign.center,
                        style: totalStyle,
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${tPaid.toStringAsFixed(0)} JD",
                        textAlign: TextAlign.center,
                        style: totalStyle,
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${tRem.toStringAsFixed(0)} JD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: useMobileSizedTable ? 11.5 : 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        Widget buildDataRow(Map<String, dynamic> data, int index) {
          final String patientPhone = (data['phone'] ?? "").toString();

          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _border(context)),
              ),
            ),
            child: Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    bodyCell(
                      Text(
                        "${startIndex + index + 1}",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textPrimary(context)),
                      ),
                    ),
                    bodyCell(
                      Text(
                        (data['full_name'] ?? "").toString(),
                        textAlign:
                            isArabic ? TextAlign.right : TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      ),
                      alignment:
                          isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    ),
                    bodyCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              patientPhone,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textPrimary(context),
                                fontWeight: FontWeight.w500,
                                fontSize: useMobileSizedTable ? 11 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (patientPhone.isNotEmpty)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.contact_phone,
                                size: 18,
                                color: lightBlue,
                              ),
                              onSelected: (val) => _launchPhoneAction(patientPhone, val),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'call',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.phone, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text(tr("اتصال", "Call")),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'wa',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.chat, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text(tr("واتساب", "WhatsApp")),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'sms',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.message, color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Text(tr("رسالة", "Message")),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${data['required_amount'] ?? 0} JD",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textPrimary(context)),
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${data['discount'] ?? 0} JD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: lightBlue,
                          fontSize: useMobileSizedTable ? 11 : 14,
                        ),
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${data['paid_amount'] ?? 0} JD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: useMobileSizedTable ? 11 : 14,
                        ),
                      ),
                    ),
                    bodyCell(
                      Text(
                        "${data['remaining_amount'] ?? 0} JD",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: useMobileSizedTable ? 11 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: StatsService.watchMaterials(),
          builder: (context, materialsSnapshot) {
            double inventoryValue = 0;

            if (materialsSnapshot.hasData) {
              inventoryValue = StatsUtils.calculateInventoryValue(
                materialsSnapshot.data!.docs,
              );
            }

            Widget buildRowsList({required bool scrollable}) {
              final rows = List.generate(pagedDocs.length, (index) {
                final data = pagedDocs[index].data() as Map<String, dynamic>;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    hoverColor: _softFill(context),
                    onTap: () {},
                    child: buildDataRow(data, index),
                  ),
                );
              });

              return Container(
                decoration: BoxDecoration(
                  color: _surface(context),
                  border: Border.all(color: _border(context)),
                ),
                child: scrollable
                    ? ListView(
                        padding: EdgeInsets.zero,
                        children: rows,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: rows,
                      ),
              );
            }

            final desktopTableWidget = Column(
              children: [
                _summaryCard(
                  title: tr("قيمة مخزون المواد", "Inventory Value"),
                  value: "${inventoryValue.toStringAsFixed(0)} JD",
                  icon: Icons.inventory_2_outlined,
                  color: lapisBlue,
                  width: double.infinity,
                ),
                SizedBox(height: useMobileSizedTable ? 8 : 14),
                buildHeader(),
                buildTotalsRow(),
                Expanded(child: buildRowsList(scrollable: true)),
                if (totalPages > 1) _buildPaginationBar(totalPages),
              ],
            );

            final mobileTableWidget = Column(
              children: [
                _summaryCard(
                  title: tr("قيمة مخزون المواد", "Inventory Value"),
                  value: "${inventoryValue.toStringAsFixed(0)} JD",
                  icon: Icons.inventory_2_outlined,
                  color: lapisBlue,
                  width: double.infinity,
                ),
                SizedBox(height: useMobileSizedTable ? 8 : 14),
                buildHeader(),
                buildTotalsRow(),
                Expanded(child: buildRowsList(scrollable: true)),
                if (totalPages > 1) _buildPaginationBar(totalPages),
              ],
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = _isMobileWidth(constraints.maxWidth);

                if (!isMobile) {
                  return desktopTableWidget;
                }

                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: mobileTableWidget,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChartsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: StatsService.watchPatientsByLastVisit(
        startDate: startDate,
        endDate: endDate,
      ),
      builder: (context, patientsSnapshot) {
        if (!patientsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: StatsService.watchMaterials(),
          builder: (context, materialsSnapshot) {
            if (!materialsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            double tRequired = 0;
            double tPaid = 0;
            double tDiscount = 0;
            double tDebt = 0;

            List<QueryDocumentSnapshot> patientDocs =
                patientsSnapshot.data!.docs;
            patientDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aDate = aData['last_visit'];
              final bDate = bData['last_visit'];

              if (aDate is Timestamp && bDate is Timestamp) {
                return aDate.toDate().compareTo(bDate.toDate());
              }
              return 0;
            });

            for (final doc in patientDocs) {
              final d = doc.data() as Map<String, dynamic>;
              tRequired += _toDouble(d['required_amount']);
              tPaid += _toDouble(d['paid_amount']);
              tDiscount += _toDouble(d['discount']);
              tDebt += _toDouble(d['remaining_amount']);
            }

            final materialDocs = materialsSnapshot.data!.docs;

            final int totalMaterials = materialDocs.length;
            final int lowStock = StatsUtils.countLowStockMaterials(materialDocs);
            final double inventoryValue = StatsUtils.calculateInventoryValue(materialDocs);

            final totalClinicValue = tPaid + inventoryValue;
            final collectionRate =
                (tPaid + tDebt) > 0 ? (tPaid / (tPaid + tDebt)) * 100 : 0.0;

            final incomeSpots = _buildIncomeSpots(patientDocs);

            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = _isMobileWidth(constraints.maxWidth);

                return ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        _summaryCard(
                          title: tr("إجمالي المدفوع", "Total Paid"),
                          value: "${tPaid.toStringAsFixed(0)} JD",
                          icon: Icons.payments_outlined,
                          color: Colors.green,
                          width: isMobile ? double.infinity : 260,
                        ),
                        _summaryCard(
                          title: tr("إجمالي الديون", "Total Debt"),
                          value: "${tDebt.toStringAsFixed(0)} JD",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          width: isMobile ? double.infinity : 260,
                        ),
                        _summaryCard(
                          title: tr("قيمة مخزون المواد", "Inventory Value"),
                          value: "${inventoryValue.toStringAsFixed(0)} JD",
                          icon: Icons.inventory_2_outlined,
                          color: lapisBlue,
                          width: isMobile ? double.infinity : 260,
                        ),
                        _summaryCard(
                          title: tr("القيمة الكلية", "Total Value"),
                          value: "${totalClinicValue.toStringAsFixed(0)} JD",
                          icon: Icons.account_balance_wallet_outlined,
                          color: lightBlue,
                          width: isMobile ? double.infinity : 260,
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _chartCard(
                      tr("نمو الدخل خلال الفترة", "Income Growth"),
                      _buildProfessionalLineChart(incomeSpots),
                    ),
                    const SizedBox(height: 25),
                    if (isMobile) ...[
                      _chartCard(
                        tr("المؤشرات المالية", "Financial Indicators"),
                        _buildProfessionalBarChart(
                          requiredAmount: tRequired,
                          paid: tPaid,
                          discount: tDiscount,
                          debt: tDebt,
                          inventoryValue: inventoryValue,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _chartCard(
                        tr("نسبة التحصيل", "Collection Rate"),
                        _buildProfessionalDonut(
                          paid: tPaid,
                          debt: tDebt,
                          rate: collectionRate,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _chartCard(
                        tr("حالة المواد", "Materials Status"),
                        _buildMaterialsChart(
                          totalMaterials: totalMaterials,
                          lowStock: lowStock,
                          inventoryValue: inventoryValue,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _chartCard(
                              tr("المؤشرات المالية", "Financial Indicators"),
                              _buildProfessionalBarChart(
                                requiredAmount: tRequired,
                                paid: tPaid,
                                discount: tDiscount,
                                debt: tDebt,
                                inventoryValue: inventoryValue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 25),
                          Expanded(
                            child: _chartCard(
                              tr("نسبة التحصيل", "Collection Rate"),
                              _buildProfessionalDonut(
                                paid: tPaid,
                                debt: tDebt,
                                rate: collectionRate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _chartCard(
                        tr("حالة المواد", "Materials Status"),
                        _buildMaterialsChart(
                          totalMaterials: totalMaterials,
                          lowStock: lowStock,
                          inventoryValue: inventoryValue,
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<FlSpot> _buildIncomeSpots(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];

    final limitedDocs = docs.length > 14 ? docs.sublist(docs.length - 14) : docs;
    final List<FlSpot> spots = [];

    double runningTotal = 0;

    for (int i = 0; i < limitedDocs.length; i++) {
      final data = limitedDocs[i].data() as Map<String, dynamic>;
      runningTotal += _toDouble(data['paid_amount']);
      spots.add(FlSpot(i.toDouble(), runningTotal));
    }

    return spots;
  }

  Widget _chartCard(String title, Widget chart) {
    return StatsChartCard(
      isArabic: isArabic,
      title: title,
      chart: chart,
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return StatsSummaryCard(
      isArabic: isArabic,
      title: title,
      value: value,
      icon: icon,
      color: color,
      width: width,
    );
  }

  Widget _buildProfessionalLineChart(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Text(
          tr("لا توجد بيانات", "No Data"),
          style: TextStyle(color: _textPrimary(context)),
        ),
      );
    }

    double maxY = 0;
    for (final spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    if (maxY <= 0) maxY = 100;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _border(context).withOpacity(0.6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 65, // زيادة المساحة لمحور Y
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value == 0 ? "0" : "${value.toInt()}",
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32, // زيادة المساحة لمحور X
              interval: spots.length <= 6 ? 1 : 2,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= spots.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 10,
            getTooltipItems: (items) {
              return items.map((item) {
                return LineTooltipItem(
                  "${item.y.toStringAsFixed(0)} JD",
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lapisBlue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: _surface(context),
                  strokeWidth: 3,
                  strokeColor: lapisBlue,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lapisBlue.withOpacity(0.22),
                  lapisBlue.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalBarChart({
    required double requiredAmount,
    required double paid,
    required double discount,
    required double debt,
    required double inventoryValue,
  }) {
    final values = [
      requiredAmount,
      paid,
      discount,
      debt,
      inventoryValue,
    ];

    double maxValue = 0;
    for (final v in values) {
      if (v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) maxValue = 100;

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.20,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                "${rod.toY.toStringAsFixed(0)} JD",
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _border(context).withOpacity(0.55),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60, // زيادة المساحة لمحور Y
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value == 0 ? "0" : value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50, // زيادة المساحة لمحور X
              getTitlesWidget: (value, meta) {
                String label = "";
                switch (value.toInt()) {
                  case 0:
                    label = tr("مطلوب", "Req");
                    break;
                  case 1:
                    label = tr("مدفوع", "Paid");
                    break;
                  case 2:
                    label = tr("خصم", "Disc");
                    break;
                  case 3:
                    label = tr("متبقي", "Debt");
                    break;
                  case 4:
                    label = tr("مواد", "Stock");
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _textSecondary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: [
          _barGroup(0, requiredAmount, lapisBlue),
          _barGroup(1, paid, Colors.green),
          _barGroup(2, discount, lightBlue),
          _barGroup(3, debt, Colors.redAccent),
          _barGroup(4, inventoryValue, Colors.deepPurple),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 22,
          color: color,
          borderRadius: BorderRadius.circular(8),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: value == 0 ? 1 : value,
            color: color.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalDonut({
    required double paid,
    required double debt,
    required double rate,
  }) {
    final total = paid + debt;

    if (total <= 0) {
      return Center(
        child: Text(
          tr("لا توجد بيانات", "No Data"),
          style: TextStyle(color: _textPrimary(context)),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 72,
            sectionsSpace: 4,
            startDegreeOffset: -90,
            sections: [
              PieChartSectionData(
                value: paid,
                color: Colors.green,
                radius: 38,
                title: "",
              ),
              PieChartSectionData(
                value: debt,
                color: Colors.redAccent,
                radius: 38,
                title: "",
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${rate.toStringAsFixed(0)}%",
              style: const TextStyle(
                color: lapisBlue,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              tr("تحصيل", "Collected"),
              style: TextStyle(
                color: _textSecondary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendDot(Colors.green, tr("مدفوع", "Paid")),
              const SizedBox(width: 16),
              _legendDot(Colors.redAccent, tr("متبقي", "Debt")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialsChart({
    required int totalMaterials,
    required int lowStock,
    required double inventoryValue,
  }) {
    final available = totalMaterials - lowStock;
    final maxY = totalMaterials <= 0 ? 1.0 : totalMaterials.toDouble();

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.25,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: _border(context).withOpacity(0.55),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 10,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      rod.toY.toStringAsFixed(0),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45, // زيادة المساحة لمحور Y
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45, // زيادة المساحة لمحور X
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          value.toInt() == 0
                              ? tr("متوفر", "Available")
                              : tr("نواقص", "Low"),
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barGroups: [
                _barGroup(0, available.toDouble(), Colors.green),
                _barGroup(
                  1,
                  lowStock.toDouble(),
                  lowStock > 0 ? Colors.redAccent : lapisBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _softFill(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: lapisBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr("قيمة مخزون المواد", "Inventory Value"),
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "${inventoryValue.toStringAsFixed(0)} JD",
                style: const TextStyle(
                  color: lapisBlue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary(context),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}