import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/layout/custom_layout.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../../auth/screens/setup_screen.dart';
import '../../patients/screens/patient_account_screen.dart' hide smoothPageRoute;
import '../utils/dental_chart_models.dart';
import '../widgets/dental_surface_painter.dart';
import '../services/dental_chart_service.dart';
import '../utils/dental_chart_route.dart';

class MainDashboard extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String username;
  final bool isArabic;

  const MainDashboard({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.username,
    required this.isArabic,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final TextEditingController searchController = TextEditingController();
  late bool isArabic;
  late List<ToothModel> upperTeeth;
  late List<ToothModel> lowerTeeth;

  final List<Map<String, dynamic>> _pendingTreatments = [];
  bool _isAddingMode = false;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  List<DocumentSnapshot> _treatmentsList = [];
  List<Map<String, dynamic>> _detailsList = [];

  final List<List<ToothModel>> _undoHistoryUpper = [];
  final List<List<ToothModel>> _undoHistoryLower = [];
  String _selectedTreatmentName = '';
  String _selectedSubDetailName = '';

  Map<String, dynamic>? _selectedTreatmentData;
  String _selectedDoctor = 'Dr. Ahmed';
  String _selectedColorField = 'A1';
  String _currentTreatmentStatus = 'planned';
  String? _selectedCategory;
  final bool _noPriceChecked = false;

  bool isLoadingData = true;

  final List<StatusItem> _statusItems = [
    StatusItem(ar: 'عملي (مكتمل)', en: 'My Work (Done)', color: Colors.green, square: true, statusCode: 'completed'),
    StatusItem(ar: 'عمل الغير', en: 'Other Work', color: Colors.blue, square: false, statusCode: 'other'),
    StatusItem(ar: 'أعمال قديمة', en: 'Existing Work', color: Colors.brown, square: true, statusCode: 'existing'),
    StatusItem(ar: 'المستقبلية (مخطط)', en: 'Planned (Future)', color: Colors.red, square: false, statusCode: 'planned'),
    StatusItem(ar: 'تشخيص', en: 'Diagnosis', color: Colors.lightGreenAccent, square: true, statusCode: 'diagnosed'),
  ];

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    _priceController.text = '0.00';
    _dateController.text = DateFormat('yyyy/MM/dd').format(DateTime.now());
    upperTeeth = List.generate(16, (i) => ToothModel(id: i + 1));
    lowerTeeth = List.generate(16, (i) => ToothModel(id: 32 - i));
    
    // 🎨 استمع لتغييرات الـ Theme
    AppThemeController.themeMode.addListener(_onThemeChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPatientDentalChart();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    // 🎨 إلغاء الـ Listener
    AppThemeController.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  // 🎨 تحديث الواجهة عند تغيير الـ Theme
  void _onThemeChanged() {
    setState(() {});
  }

  bool get _isDark => AppThemeController.isDark;
  Color get _pageBg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _headerBg => _isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F5F7);
  Color get _borderColor => _isDark ? const Color(0xFF334155) : const Color(0xFFD2D6DC);
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary => _isDark ? Colors.white70 : Colors.grey.shade700;
  Color get _bottomPanelBg => _isDark ? const Color(0xFF111827) : const Color(0xFFFBF4E9);

  String tr(String ar, String en) => isArabic ? ar : en;

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Future<void> _fetchPatientDentalChart() async {
    setState(() => isLoadingData = true);
    try {
      final dbService = DatabaseService();
      final savedTeeth = await dbService.getPatientDentalChart(widget.patientId);

      setState(() {
        for (final savedTooth in savedTeeth) {
          final int? tId = savedTooth['id'] is num ? (savedTooth['id'] as num).toInt() : null;
          if (tId == null) continue;
          ToothModel? targetTooth;
          if (tId >= 1 && tId <= 16) {
            targetTooth = upperTeeth.firstWhere((t) => t.id == tId);
          } else if (tId >= 17 && tId <= 32) {
            targetTooth = lowerTeeth.firstWhere((t) => t.id == tId);
          }
          targetTooth?.fromMap(savedTooth);
        }
        isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error fetching chart: $e');
      if (mounted) setState(() => isLoadingData = false);
    }
  }

  Future<void> _syncPatientFinancials() async {
    final db = FirebaseFirestore.instance;
    try {
      final treatments = await db
          .collection('patient_treatments')
          .where('patientId', isEqualTo: widget.patientId)
          .get();

      double reqAmount = 0, discount = 0;
      for (final doc in treatments.docs) {
        final d = doc.data();
        reqAmount += _toDouble(d['price']);
        discount += _toDouble(d['discount']);
      }

      final payments = await db
          .collection('patient_payments')
          .where('patientId', isEqualTo: widget.patientId)
          .get();

      double paidAmount = 0;
      for (final doc in payments.docs) {
        paidAmount += _toDouble(doc.data()['amount']);
      }

      await db.collection('patients').doc(widget.patientId).update({
        'required_amount': reqAmount,
        'discount': discount,
        'paid_amount': paidAmount,
        'remaining_amount': (reqAmount - discount) - paidAmount,
      });
    } catch (e) {
      debugPrint('Error syncing financials: $e');
    }
  }

  void _toggleAddingMode() {
    setState(() => _isAddingMode = !_isAddingMode);
  }

  void _queueCurrentTreatment() {
    if (_selectedTreatmentName.isEmpty) return;

    final price = _noPriceChecked ? 0.0 : (double.tryParse(_priceController.text) ?? 0.0);
    final selectedTeeth = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();

    setState(() {
      if (selectedTeeth.isEmpty) {
        _pendingTreatments.add({
          'toothId': 0,
          'category': _selectedCategory ?? '',
          'treatmentName': _selectedTreatmentName,
          'detail': _selectedSubDetailName,
          'doctorName': _selectedDoctor,
          'price': price,
          'status': _currentTreatmentStatus,
        });
      } else {
        for (final tooth in selectedTeeth) {
          _pendingTreatments.add({
            'toothId': tooth.id,
            'category': _selectedCategory ?? '',
            'treatmentName': _selectedTreatmentName,
            'detail': _selectedSubDetailName,
            'doctorName': _selectedDoctor,
            'price': price,
            'status': _currentTreatmentStatus,
          });
        }
      }
    });
  }

  Future<void> _clearToothTreatmentsFromDatabase() async {
    final selected = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('الرجاء تحديد سن أولاً لتتمكن من مسح سجلاته', 'Please select a tooth first to clear its records')),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _cardBg,
          title: Text(tr('تأكيد مسح السجلات والرسوم', 'Confirm Clearing'), style: TextStyle(color: _textPrimary)),
          content: Text(
            tr(
              'هل أنت متأكد من حذف جميع المعالجات المسجلة لـ ${selected.length} أسنان نهائياً؟',
              'Are you sure you want to permanently delete all treatments registered for ${selected.length} teeth?',
            ),
            style: TextStyle(color: _textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('مسح نهائي', 'Permanently Clear')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final dbService = DatabaseService();

      for (final tooth in selected) {
        final treatmentsQuery = await db
            .collection('patient_treatments')
            .where('patientId', isEqualTo: widget.patientId)
            .where('toothId', isEqualTo: tooth.id)
            .get();

        final batch = db.batch();
        for (final doc in treatmentsQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        setState(() {
          tooth.hasCrown = false;
          tooth.hasAppliance = false;
          tooth.hasRCT = false;
          tooth.hasImplant = false;
          tooth.isMissing = false;
          tooth.hasCaries = false;
          tooth.hasVeneer = false;
          tooth.hasBraces = false;
          tooth.hasAbscess = false;
          tooth.isImpacted = false;
          tooth.hasScaling = false;
          tooth.condition = 'healthy';
          tooth.statusColor = Colors.transparent;
          tooth.note = null;
          tooth.treatmentsHistory.clear();
          tooth.surfaces.updateAll((k, v) => false);
        });

        final clearedMap = tooth.toMap();
        clearedMap['id'] = tooth.id;
        await dbService.saveToothVisualState(widget.patientId, tooth.id, clearedMap);
      }

      await _syncPatientFinancials();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('تم مسح السجلات والرسوم البصرية بنجاح', 'Visuals & financial records cleared successfully')),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveDentalChartToFirebase() async {
    if (_pendingTreatments.isEmpty && _selectedTreatmentName.isNotEmpty) {
      _queueCurrentTreatment();
    }

    if (_pendingTreatments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('لا توجد معالجات مضافة للحفظ', 'No treatments added to save')),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final dbService = DatabaseService();
      final batch = db.batch();

      for (final treat in _pendingTreatments) {
        final docRef = db.collection('patient_treatments').doc();
        batch.set(docRef, {
          'patientId': widget.patientId,
          'toothId': treat['toothId'],
          'category': treat['category'],
          'treatmentName': treat['treatmentName'],
          'detail': treat['detail'],
          'doctorName': treat['doctorName'],
          'price': treat['price'],
          'discount': 0.0,
          'quantity': 1,
          'status': treat['status'],
          'date': Timestamp.now(),
        });

        final int tId = treat['toothId'];
        if (tId > 0) {
          final tooth = [...upperTeeth, ...lowerTeeth].firstWhere((t) => t.id == tId);
          setState(() {
            tooth.statusColor = treat['status'] == 'completed'
                ? Colors.green
                : (treat['status'] == 'planned' ? Colors.red : Colors.blue);
            tooth.lastTreatmentDate = DateTime.now();
            final label = treat['treatmentName'] +
                (treat['detail'].toString().isNotEmpty ? ' (${treat['detail']})' : '');
            if (!tooth.treatmentsHistory.contains(label)) {
              tooth.treatmentsHistory.add(label);
            }
          });

          final toothMap = tooth.toMap();
          toothMap['id'] = tooth.id;
          await dbService.saveToothVisualState(widget.patientId, tooth.id, toothMap);
        }
      }

      await batch.commit();
      await _syncPatientFinancials();

      setState(() {
        _pendingTreatments.clear();
        _isAddingMode = false;
        _deselectAll();
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('تم حفظ جميع المعالجات وتحديث الحساب المالي بنجاح', 'All treatments saved successfully')),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ أثناء الحفظ: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _fetchTreatmentsForCategory(String categoryName) async {
    if (categoryName.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('treatments_setup')
          .where('category', isEqualTo: categoryName)
          .get();

      setState(() {
        _treatmentsList = snap.docs;
        _selectedTreatmentName = '';
        _selectedSubDetailName = '';
        _detailsList = [];
      });
    } catch (e) {
      debugPrint('Error fetching treatments: $e');
    }
  }

  void _deselectAll() {
    setState(() {
      for (final t in [...upperTeeth, ...lowerTeeth]) {
        t.isSelected = false;
      }
      _selectedCategory = null;
      _selectedTreatmentName = '';
      _selectedSubDetailName = '';
      _treatmentsList = [];
      _detailsList = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: CustomScaffold(
        username: widget.username,
        isArabic: isArabic,
        selectedIndex: 1,
        searchController: searchController,
        onSearchChanged: (val) {},
        onLanguageChanged: (val) => setState(() => isArabic = val),
        body: LayoutBuilder(
          builder: (context, constraints) {
            const double minWidth = 1100.0;
            final needsScroll = constraints.maxWidth < minWidth;

            final content = Column(
              children: [
                _buildPatientHeader(),
                Expanded(child: _buildDentalChartArea()),
              ],
            );

            if (needsScroll) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minWidth, child: content),
              );
            }
            return content;
          },
        ),
      ),
    );
  }

  Widget _buildPatientHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 1250;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').doc(widget.patientId).snapshots(),
      builder: (context, snap) {
        Map<String, dynamic> d = {};
        if (snap.hasData && snap.data!.exists) {
          d = snap.data!.data() as Map<String, dynamic>;
        }

        final name = d['full_name'] ?? d['name'] ?? widget.patientName;
        final fileNumber = d['file_number']?.toString() ?? widget.patientId;
        final phone = d['phone']?.toString() ?? '';
        final genderSym = _genderSymbol(d['gender']?.toString());
        final birthRaw = d['birth_date'];
        final age = _calcAge(birthRaw);
        String birthStr = '—';
        if (birthRaw is Timestamp) birthStr = DateFormat('MM/dd/yyyy').format(birthRaw.toDate());
        final hasPhone = phone.isNotEmpty;
        final alertText = d['alert']?.toString() ?? '';
        final remainingAmount = _toDouble(d['remaining_amount'] ?? 0.0);

        if (isNarrow) {
          return _buildCompactPatientHeader(
            name: name.toString(),
            fileNumber: fileNumber,
            phone: phone,
            genderSym: genderSym,
            birthStr: birthStr,
            age: age,
            alertText: alertText,
            remainingAmount: remainingAmount,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _headerBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade400,
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.toString(),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'File: #$fileNumber',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$birthStr ($age) $genderSym', style: TextStyle(fontSize: 13, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _verticalDividerHeader(),
              Expanded(
                flex: 2,
                child: hasPhone
                    ? _buildPhoneDropdown(phone)
                    : Text(tr('لا يوجد رقم هاتف', 'No Phone'), style: TextStyle(color: _textSecondary), overflow: TextOverflow.ellipsis),
              ),
              _verticalDividerHeader(),
              Expanded(flex: 2, child: _buildAlertHeaderBlock(alertText)),
              _verticalDividerHeader(),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('المتبقي مالياً', 'Remaining Bal.'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${remainingAmount.toStringAsFixed(2)} JD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: remainingAmount > 0 ? Colors.red.shade700 : Colors.teal.shade700), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _headerActions(accountLabel: tr('الحساب المالي', 'Account')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactPatientHeader({
    required String name,
    required String fileNumber,
    required String phone,
    required String genderSym,
    required String birthStr,
    required int age,
    required String alertText,
    required double remainingAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade400,
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('File: #$fileNumber | $birthStr ($age) $genderSym', style: TextStyle(fontSize: 12, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _headerActions(accountLabel: tr('الحساب', 'Account'), compact: true),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: phone.isNotEmpty ? _buildPhoneDropdown(phone) : Text(tr('لا يوجد رقم هاتف', 'No Phone'), style: TextStyle(color: _textSecondary), overflow: TextOverflow.ellipsis),
              ),
              InkWell(
                onTap: () => _showAddAlertDialog(alertText),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('التنبيهات', 'Alerts'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        alertText.isNotEmpty ? alertText : tr('لا يوجد', 'None'),
                        style: TextStyle(fontSize: 12, color: alertText.isNotEmpty ? Colors.redAccent : _textSecondary, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('المتبقي مالياً', 'Remaining Bal.'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                  Text('${remainingAmount.toStringAsFixed(2)} JD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: remainingAmount > 0 ? Colors.red.shade700 : Colors.teal.shade700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerActions({required String accountLabel, bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconActionBtn(
          icon: Icons.settings_rounded,
          tooltip: tr('إعدادات المعالجة', 'Setup'),
          color: Colors.blueGrey.shade700,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TreatmentsSetupScreen(username: widget.username, initialArabic: isArabic),
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 8),
        _actionBtnHeader(
          icon: Icons.account_balance_wallet_rounded,
          label: accountLabel,
          color: Colors.teal.shade600,
          onTap: () => Navigator.pushReplacement(
            context,
            smoothPageRoute(
              PatientAccountScreen(
                patientId: widget.patientId,
                patientName: widget.patientName,
                username: widget.username,
                isArabic: isArabic,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertHeaderBlock(String alertText) {
    return InkWell(
      onTap: () => _showAddAlertDialog(alertText),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(child: Text(tr('التنبيهات', 'Alerts'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              alertText.isNotEmpty ? alertText : tr('لا يوجد تنبيهات', 'None'),
              style: TextStyle(fontSize: 13, color: alertText.isNotEmpty ? Colors.redAccent : _textSecondary, fontWeight: alertText.isNotEmpty ? FontWeight.bold : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAlertDialog(String currentAlert) {
    final alertCtrl = TextEditingController(text: currentAlert);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _cardBg,
          title: Text(tr('تعديل تنبيهات المريض', 'Edit Patient Alerts'), style: TextStyle(color: _textPrimary)),
          content: TextField(
            controller: alertCtrl,
            maxLines: 2,
            style: TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: tr('مثال: حساسية بنسلين، مريض سكري، ضغط دم مرتفع...', 'e.g., Penicillin allergy, diabetic...'),
              hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).update({'alert': alertCtrl.text.trim()});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('تم حفظ التنبيه بنجاح', 'Alert saved successfully')),
                  backgroundColor: Colors.green,
                ));
              },
              child: Text(tr('حفظ', 'Save')),
            )
          ],
        ),
      ),
    );
  }

  String _genderSymbol(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final v = raw.trim().toLowerCase();
    if (v == 'ذكر' || v == 'male' || v == 'm') return 'M';
    if (v == 'أنثى' || v == 'انثى' || v == 'female' || v == 'f') return 'F';
    return raw.toUpperCase().substring(0, 1);
  }

  int _calcAge(dynamic raw) {
    DateTime? bd;
    if (raw is Timestamp) bd = raw.toDate();
    if (bd == null) return 0;
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
    return age;
  }

  Widget _verticalDividerHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: VerticalDivider(color: _borderColor, thickness: 1, width: 1),
    );
  }

  Widget _buildPhoneDropdown(String phone) {
    return PopupMenuButton<String>(
      tooltip: tr('خيارات التواصل', 'Contact Options'),
      offset: const Offset(0, 40),
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) async {
        final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
        final Uri url = Uri.parse(value == 'call'
            ? 'tel:$cleanPhone'
            : (value == 'wa' ? 'https://wa.me/$cleanPhone' : 'sms:$cleanPhone'));
        if (await canLaunchUrl(url)) await launchUrl(url);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'call',
          child: Row(children: [
            const Icon(Icons.phone, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Text(tr('مكالمة هاتفية', 'Call Phone'), style: TextStyle(color: _textPrimary))
          ]),
        ),
        PopupMenuItem(
          value: 'wa',
          child: Row(children: [
            const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
            const SizedBox(width: 10),
            Text('WhatsApp', style: TextStyle(color: _textPrimary))
          ]),
        ),
        PopupMenuItem(
          value: 'sms',
          child: Row(children: [
            const Icon(Icons.sms, color: Colors.blueGrey, size: 20),
            const SizedBox(width: 10),
            Text('SMS', style: TextStyle(color: _textPrimary))
          ]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              phone,
              style: const TextStyle(color: Colors.blue, fontSize: 15, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
            color: _cardBg,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _actionBtnHeader({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDentalChartArea() {
    return Column(
      children: [
        Container(
          color: _isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleAddingMode,
                icon: Icon(_isAddingMode ? Icons.check_circle : Icons.add_circle, color: Colors.white, size: 18),
                label: Text(
                  _isAddingMode ? tr('وضع الإضافة نشط', 'Adding Active') : tr('إضافة معالجة', 'Add Treatment'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAddingMode ? Colors.green.shade600 : const Color(0xFF26619C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            color: _pageBg,
            child: GestureDetector(
              onTap: _deselectAll,
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        _buildTeethRow(upperTeeth, true),
                        SizedBox(
                          height: 24,
                          child: Divider(thickness: 1, indent: 30, endIndent: 150, color: _borderColor),
                        ),
                        _buildTeethRow(lowerTeeth, false),
                      ],
                    ),
                    Positioned(right: 20, child: _buildFloatingControlPanel()),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildBottomProcedurePanel(),
      ],
    );
  }

  Widget _buildBottomProcedurePanel() {
    return Container(
      height: 215,
      decoration: BoxDecoration(
        color: _bottomPanelBg,
        border: Border(top: BorderSide(color: _borderColor, width: 1.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 1, child: _buildLeftVerticalStatusArea()),
                VerticalDivider(width: 1, thickness: 1, color: _borderColor),
                Expanded(flex: 8, child: _buildCenterCategoriesGridArea()),
                VerticalDivider(width: 1, thickness: 1, color: _borderColor),
                Expanded(flex: 2, child: _buildRightFormsInputArea()),
              ],
            ),
          ),
          _buildActionFooterRow(),
        ],
      ),
    );
  }

  Widget _buildActionFooterRow() {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      color: _cardBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _actionBtnImg(Icons.edit_note, tr('ملاحظة', 'Note'), _textPrimary, _borderColor, _showNoteDialog),
          const SizedBox(width: 8),
          _actionBtnImg(Icons.cleaning_services_outlined, tr('مسح', 'Clear'), _textPrimary, _borderColor, () {
            _clearToothTreatmentsFromDatabase();
            setState(() => _selectedTreatmentName = '');
            _applyProcedure({'action': 'clear'}, 0.0);
          }),
          const SizedBox(width: 8),
          _actionBtnImg(Icons.undo, tr('تراجع', 'Undo'), _textPrimary, _borderColor, _undoLastAction),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saveDentalChartToFirebase,
            icon: const Icon(Icons.save, size: 14, color: Colors.white),
            label: Text(tr('حفظ', 'Save'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26619C),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtnImg(IconData icon, String label, Color textColor, Color borderColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: borderColor)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog() {
    final selectedTeeth = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();
    if (selectedTeeth.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد سن أولاً لإضافة ملاحظة'), backgroundColor: Colors.orange));
      return;
    }

    final noteController = TextEditingController();
    if (selectedTeeth.length == 1 && selectedTeeth.first.note != null) {
      noteController.text = selectedTeeth.first.note!;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('ملاحظة سريرية لـ ${selectedTeeth.length} سن', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          style: TextStyle(color: _textPrimary),
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظتك هنا (مثال: السن يحتاج مراقبة، المريض يشعر بألم...)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (final t in selectedTeeth) {
                  t.note = noteController.text.trim();
                  t.isSelected = false;
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظة بنجاح'), backgroundColor: Colors.green));
            },
            child: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    );
  }

  void _undoLastAction() {
    if (_undoHistoryUpper.isNotEmpty && _undoHistoryLower.isNotEmpty) {
      setState(() {
        upperTeeth = _undoHistoryUpper.removeLast();
        lowerTeeth = _undoHistoryLower.removeLast();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('تم التراجع عن الإجراء البصري الأخير بنجاح', 'Last visual state successfully undone')),
        backgroundColor: Colors.blueGrey,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('لا توجد إجراءات للتراجع عنها في هذه الجلسة', 'Nothing to undo in this session')),
        backgroundColor: Colors.orange,
      ));
    }
  }

  Widget _buildLeftVerticalStatusArea() {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _statusItems.map((st) {
          final isSelected = _currentTreatmentStatus == st.statusCode;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: InkWell(
              onTap: () => setState(() => _currentTreatmentStatus = st.statusCode),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? st.color.withOpacity(0.15) : Colors.transparent,
                  border: Border.all(color: isSelected ? st.color : Colors.transparent, width: 1.0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: st.color,
                        shape: st.square ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: st.square ? BorderRadius.circular(2) : null,
                        border: Border.all(color: _isDark ? Colors.white24 : Colors.black26, width: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr(st.ar, st.en),
                        style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? st.color : _textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCenterCategoriesGridArea() {
    final List<Map<String, dynamic>> clinicalButtons = [
      {'labelAr': 'الحشوات', 'labelEn': 'Fillings', 'icon': Icons.opacity, 'color': Colors.blue},
      {'labelAr': 'التيجان', 'labelEn': 'Crowns', 'icon': Icons.brightness_5, 'color': Colors.amber},
      {'labelAr': 'الجسور', 'labelEn': 'Bridges', 'icon': Icons.linear_scale, 'color': Colors.purple},
      {'labelAr': 'الجزئية', 'labelEn': 'Partials', 'icon': Icons.grid_on, 'color': Colors.deepOrange},
      {'labelAr': 'لبية', 'labelEn': 'Endodontics', 'icon': Icons.healing, 'color': Colors.red},
      {'labelAr': 'الأجهزة', 'labelEn': 'Appliances', 'icon': Icons.album, 'color': Colors.teal},
      {'labelAr': 'قلع', 'labelEn': 'Extractions', 'icon': Icons.delete_sweep, 'color': Colors.brown},
      {'labelAr': 'معالجات لثوية', 'labelEn': 'Periodontics', 'icon': Icons.bubble_chart, 'color': Colors.green},
      {'labelAr': 'معالجة جراحية صغرى', 'labelEn': 'Minor Surgery', 'icon': Icons.content_cut, 'color': Colors.blueGrey},
      {'labelAr': 'معالجات أخرى', 'labelEn': 'Other Treatments', 'icon': Icons.more_horiz, 'color': Colors.grey},
      {'labelAr': 'معالجة أسنان مؤقتة', 'labelEn': 'Pedodontics', 'icon': Icons.child_care, 'color': Colors.indigo},
      {'labelAr': 'معالجات لثوية ٢', 'labelEn': 'Gum Treatments', 'icon': Icons.layers, 'color': Colors.pink},
      {'labelAr': 'براغي وأوتاد', 'labelEn': 'Screws & Posts', 'icon': Icons.build, 'color': Colors.cyan},
      {'labelAr': 'الصور الخاصة', 'labelEn': 'Imaging', 'icon': Icons.image, 'color': Colors.black},
      {'labelAr': 'وقائية', 'labelEn': 'Preventive', 'icon': Icons.security, 'color': Colors.orange},
      {'labelAr': 'صفة الاسنان', 'labelEn': 'Tooth Align', 'icon': Icons.format_align_center, 'color': Colors.lightGreen},
      {'labelAr': 'ملاحظات', 'labelEn': 'Notes', 'icon': Icons.note, 'color': Colors.blueGrey},
      {'labelAr': 'زرعات', 'labelEn': 'Implants', 'icon': Icons.vertical_align_bottom, 'color': Colors.deepPurple},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 4.5,
        ),
        itemCount: clinicalButtons.length,
        itemBuilder: (context, index) {
          final btn = clinicalButtons[index];
          final categoryName = tr(btn['labelAr'], btn['labelEn'] ?? btn['labelAr']);
          final isSelected = _selectedCategory == btn['labelAr'];
          return InkWell(
            onTap: () {
              setState(() => _selectedCategory = btn['labelAr']);
              _fetchTreatmentsForCategory(btn['labelAr']);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? (_isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100) : _cardBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isSelected ? Colors.blue.shade700 : _borderColor, width: isSelected ? 1.5 : 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btn['icon'], size: 13, color: btn['color']),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(categoryName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightFormsInputArea() {
    return Container(
      padding: const EdgeInsets.all(6.0),
      color: _cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_pendingTreatments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(4)),
                  child: Text('${_pendingTreatments.length} ${tr('بانتظار الحفظ', 'Pending')}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _buildDoctorDateRow(),
          const SizedBox(height: 4),
          _buildTreatmentShadeRow(),
          const SizedBox(height: 4),
          _buildDetailPriceRow(),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: _selectedTreatmentName.isEmpty
                ? null
                : () {
                    _queueCurrentTreatment();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('تمت إضافة المعالجة إلى قائمة الحفظ المؤقتة', 'Treatment added to temporary save queue')),
                      backgroundColor: Colors.teal,
                      duration: const Duration(seconds: 1),
                    ));
                  },
            icon: const Icon(Icons.add_shopping_cart, size: 14),
            label: Text(tr('إدراج المعالجة الحالية', 'Queue Current Treatment'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorDateRow() {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(tr('الطبيب', 'Doctor'), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Expanded(child: _smallDropdown<String>(value: _selectedDoctor, items: ['Dr. Ahmed', 'Dr. Sarah', 'Dr. Ali'], onChanged: (val) => setState(() => _selectedDoctor = val!))),
        const SizedBox(width: 6),
        SizedBox(width: 30, child: Text(tr('التاريخ', 'Date'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Expanded(child: _smallTextField(_dateController)),
      ],
    );
  }

  Widget _buildTreatmentShadeRow() {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(tr('المعالجة', 'Treatment'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Expanded(
          child: _smallDropdown<String>(
            value: _selectedTreatmentName.isEmpty ? null : _selectedTreatmentName,
            hint: tr('اختر المعالجة', 'Select Treatment'),
            items: _treatmentsList.map((doc) => doc['name'] as String).toList(),
            onChanged: (val) {
              if (val == null) return;
              final matchedDoc = _treatmentsList.firstWhere((element) => element['name'] == val);
              final details = matchedDoc.data() as Map<String, dynamic>;
              final detailsRaw = details['details'] as List<dynamic>? ?? [];
              setState(() {
                _selectedTreatmentName = val;
                _selectedTreatmentData = details;
                _detailsList = detailsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
                _selectedSubDetailName = '';
                _priceController.text = (details['price'] as num? ?? 0.0).toStringAsFixed(2);
              });
              _applyProcedure({'action': details['actionType'] ?? 'general_consultation', 'label': val}, (details['price'] as num? ?? 0.0).toDouble());
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: _smallDropdown<String>(value: _selectedColorField, items: ['A1', 'A2', 'A3', 'B1', 'B2', 'Bleach'], onChanged: (val) => setState(() => _selectedColorField = val!))),
      ],
    );
  }

  Widget _buildDetailPriceRow() {
    return Row(
      children: [
        SizedBox(width: 35, child: Text(tr('تفاصيل', 'Details'), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Expanded(
          child: _smallDropdown<String>(
            value: _selectedSubDetailName.isEmpty ? null : _selectedSubDetailName,
            hint: tr('تفصيل المعالجة', 'Treatment detail'),
            items: _detailsList.map((m) => m['name'] as String).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() => _selectedSubDetailName = val);
              if (_selectedTreatmentData != null) {
                final price = (_selectedTreatmentData!['price'] as num? ?? 0.0).toDouble();
                _applyProcedure({'action': _selectedTreatmentData!['actionType'] ?? 'general_consultation', 'label': '$_selectedTreatmentName ($val)'}, price);
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 30, child: Text(tr('سعر', 'Price'), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _textPrimary), textAlign: TextAlign.right)),
        const SizedBox(width: 4),
        Expanded(child: _smallTextField(_priceController)),
      ],
    );
  }

  Widget _smallDropdown<T>({T? value, required List<T> items, String? hint, required ValueChanged<T?> onChanged}) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(border: Border.all(color: _borderColor), borderRadius: BorderRadius.circular(3)),
      child: DropdownButton<T>(
        value: value,
        dropdownColor: _cardBg,
        isExpanded: true,
        underline: const SizedBox(),
        hint: hint == null ? null : Text(hint, style: TextStyle(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
        style: TextStyle(fontSize: 10, color: _textPrimary),
        items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString(), style: TextStyle(color: _textPrimary), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _smallTextField(TextEditingController controller) {
    return SizedBox(
      height: 22,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 10, color: _textPrimary),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _borderColor)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        ),
      ),
    );
  }

  Widget _buildInteractiveGlobalGrid(List<ToothModel> selectedTeeth) {
    const size = 80.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(size: const Size(size, size), painter: DentalSurfacePainter(selectedTeeth.isNotEmpty ? selectedTeeth.first.surfaces : {}, isDark: _isDark)),
          _globalSurfaceClickArea(selectedTeeth, 'top', size, 20.5),
          _globalSurfaceClickArea(selectedTeeth, 'bottom', size, 20.5),
          _globalSurfaceClickArea(selectedTeeth, 'left', 20, size),
          _globalSurfaceClickArea(selectedTeeth, 'right', 20.5, size),
          _globalSurfaceClickArea(selectedTeeth, 'center', 25, 25),
        ],
      ),
    );
  }

  Widget _globalSurfaceClickArea(List<ToothModel> selectedTeeth, String part, double w, double h) {
    return Align(
      alignment: part == 'top'
          ? Alignment.topCenter
          : part == 'bottom'
              ? Alignment.bottomCenter
              : part == 'left'
                  ? Alignment.centerLeft
                  : part == 'right'
                      ? Alignment.centerRight
                      : Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selectedTeeth.isEmpty) return;
          setState(() {
            final currentStatus = selectedTeeth.first.surfaces[part] ?? false;
            for (final t in selectedTeeth) {
              t.surfaces[part] = !currentStatus;
            }
          });
        },
        child: SizedBox(width: w, height: h),
      ),
    );
  }

  Widget _buildToothWidget(ToothModel tooth, bool isUpper) {
    final imagePath = _getToothImagePath(tooth.id);
    final hasFilling = tooth.surfaces.values.any((v) => v == true);
    final hasNote = tooth.note != null && tooth.note!.isNotEmpty;

    String hoverMessage = '${isArabic ? 'السن رقم' : 'Tooth'} ${tooth.id}';
    if (hasNote) hoverMessage += '\n${isArabic ? 'ملاحظة:' : 'Note:'} ${tooth.note}';
    if (tooth.treatmentsHistory.isNotEmpty) hoverMessage += '\n${isArabic ? 'سجل العلاج:' : 'History:'}\n• ${tooth.treatmentsHistory.join('\n• ')}';

    return Tooltip(
      message: hoverMessage,
      preferBelow: !isUpper,
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(6)),
      child: GestureDetector(
        onTap: () => setState(() => tooth.isSelected = !tooth.isSelected),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUpper) ...[
              SizedBox(height: 24, child: hasNote ? const Icon(Icons.speaker_notes, color: Colors.amber, size: 22) : const SizedBox.shrink()),
              Text('${tooth.id}', style: TextStyle(fontSize: 15, fontWeight: tooth.isSelected ? FontWeight.bold : FontWeight.normal, color: tooth.isSelected ? Colors.blue : _textPrimary)),
              _buildToothImageOnly(tooth, isUpper, imagePath, (tooth.id >= 9 && tooth.id <= 24)),
              const SizedBox(height: 15),
            ],
            SizedBox(
              height: 35,
              child: Visibility(
                visible: hasFilling,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Center(child: _buildSurfaceGrid(tooth)),
              ),
            ),
            if (!isUpper) ...[
              const SizedBox(height: 15),
              _buildToothImageOnly(tooth, isUpper, imagePath, (tooth.id >= 9 && tooth.id <= 24)),
              Text('${tooth.id}', style: TextStyle(fontSize: 15, fontWeight: tooth.isSelected ? FontWeight.bold : FontWeight.normal, color: tooth.isSelected ? Colors.blue : _textPrimary)),
              SizedBox(height: 24, child: hasNote ? const Icon(Icons.speaker_notes, color: Colors.amber, size: 22) : const SizedBox.shrink()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControlPanel() {
    final selectedTeeth = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Surface', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 5),
          _buildInteractiveGlobalGrid(selectedTeeth),
          SizedBox(
            height: 20,
            child: Visibility(
              visible: selectedTeeth.isNotEmpty,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Center(child: Text('${selectedTeeth.length} Selected', style: const TextStyle(fontSize: 9, color: Colors.blue))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToothImageOnly(ToothModel tooth, bool isUpper, String imagePath, bool isLeftSide) {
    double finalScaleX = isLeftSide ? -1.0 : 1.0;
    double finalScaleY = isUpper ? 1.0 : -1.0;
    if ([17, 18, 19, 30, 31, 32].contains(tooth.id)) finalScaleY = finalScaleY * -1.0;
    final isLargeMolar = [1, 16, 2, 15, 3, 14].contains(tooth.id);
    final img = _getToothImagePath(tooth.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 75,
      height: 118,
      decoration: BoxDecoration(
        color: tooth.isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: tooth.isSelected ? Border.all(color: Colors.blue, width: 1) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(scaleY: finalScaleY, child: Image.asset(img, fit: BoxFit.contain)),
          if (tooth.hasCrown)
            Transform.scale(
              scale: 1.1,
              child: Transform.scale(scaleY: isUpper ? 1.0 : -1.0, scaleX: finalScaleX, child: Image.asset('assets/crown.png', fit: BoxFit.contain)),
            ),
          if (tooth.hasImplant)
            Transform.scale(
              scale: 0.8,
              child: Container(
                decoration: BoxDecoration(color: _cardBg.withOpacity(0.8), shape: BoxShape.circle),
                child: const Icon(Icons.build, color: Colors.blueGrey, size: 40),
              ),
            ),
          if (tooth.condition == 'extraction' || tooth.condition == 'extracted') const Icon(Icons.close, color: Colors.red, size: 50),
          if (tooth.hasCaries) const Positioned(top: 20, child: Icon(Icons.lens, color: Colors.red, size: 15)),
          if (tooth.hasBraces)
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          if (tooth.hasAbscess)
            Positioned(
              bottom: isUpper ? 0 : null,
              top: !isUpper ? 0 : null,
              child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle)),
            ),
          if (tooth.hasVeneer) Icon(Icons.auto_awesome, color: Colors.cyan.shade100, size: 30),
          if (tooth.hasRCT)
            OverflowBox(
              maxWidth: 200,
              maxHeight: 200,
              child: Transform.scale(
                scaleX: isLeftSide ? -1.0 : 1.0,
                scaleY: isUpper ? 1.0 : -1.0,
                child: Transform.translate(
                  offset: (tooth.id == 1)
                      ? const Offset(-4, -10)
                      : (tooth.id == 16)
                          ? const Offset(-5, -10)
                          : (tooth.id == 2)
                              ? const Offset(-3, -10)
                              : (tooth.id == 15)
                                  ? const Offset(-4, -10)
                                  : isLargeMolar
                                      ? const Offset(0, -10)
                                      : const Offset(0, 0),
                  child: Image.asset(isLargeMolar ? 'assets/rct1.png' : 'assets/rct.png', fit: BoxFit.contain, width: isLargeMolar ? 60.0 : 40.0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeethRow(List<ToothModel> teeth, bool isUpper) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: teeth.map((t) {
              return Container(
                width: 60,
                height: 120,
                alignment: Alignment.center,
                child: t.hasAppliance ? Opacity(opacity: 0.8, child: Image.asset('assets/mesh_pink.png', fit: BoxFit.fill, height: 40)) : const SizedBox.shrink(),
              );
            }).toList(),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: teeth.map((t) => _buildToothWidget(t, isUpper)).toList()),
        ],
      ),
    );
  }

  Widget _buildSurfaceGrid(ToothModel tooth) {
    const gridSize = 38.0;
    return SizedBox(width: gridSize, height: gridSize, child: CustomPaint(painter: DentalSurfacePainter(tooth.surfaces, isDark: _isDark)));
  }

  String _getToothImagePath(int id) {
    if (id == 1 || id == 16) return 'assets/tooth8.png';
    if (id == 2 || id == 15) return 'assets/tooth7.png';
    if (id == 3 || id == 14) return 'assets/tooth6.png';
    if (id == 19 || id == 30) return 'assets/tooth9.png';
    if (id == 18 || id == 31) return 'assets/tooth10.png';
    if (id == 17 || id == 32) return 'assets/tooth11.png';

    int shapeIndex = 1;
    if (id >= 1 && id <= 8) {
      shapeIndex = 9 - id;
    } else if (id >= 9 && id <= 16) shapeIndex = id - 8;
    else if (id >= 17 && id <= 24) shapeIndex = 25 - id;
    else if (id >= 25 && id <= 32) shapeIndex = id - 24;
    return 'assets/tooth$shapeIndex.png';
  }

  Future<void> _applyProcedure(Map<String, dynamic> treatmentInfo, double price) async {
    final type = treatmentInfo['action'] ?? 'general';
    final label = treatmentInfo['label'] ?? '';
    var selectedTeeth = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();

    final isSpanTreatment = type == 'crown' || type == 'bridge' || type == 'appliance' || type == 'braces' || type == 'extraction';
    if (isSpanTreatment && selectedTeeth.length == 2) {
      final id1 = selectedTeeth[0].id;
      final id2 = selectedTeeth[1].id;
      final start = math.min(id1, id2);
      final end = math.max(id1, id2);
      setState(() {
        for (final t in [...upperTeeth, ...lowerTeeth]) {
          if (t.id >= start && t.id <= end) t.isSelected = true;
        }
      });
      selectedTeeth = [...upperTeeth, ...lowerTeeth].where((t) => t.isSelected).toList();
    }

    if (selectedTeeth.isEmpty && type != 'clear') return;

    setState(() {
      for (final t in selectedTeeth) {
        if (type == 'clear') {
          t.hasCrown = false;
          t.hasAppliance = false;
          t.hasRCT = false;
          t.hasImplant = false;
          t.isMissing = false;
          t.hasCaries = false;
          t.hasVeneer = false;
          t.hasBraces = false;
          t.hasAbscess = false;
          t.isImpacted = false;
          t.hasScaling = false;
          t.condition = 'healthy';
          t.statusColor = Colors.transparent;
          t.note = null;
          t.treatmentsHistory.clear();
          t.surfaces.updateAll((k, v) => false);
        } else {
          t.statusColor = _currentTreatmentStatus == 'completed'
              ? Colors.green
              : (_currentTreatmentStatus == 'planned' ? Colors.red : Colors.blue);
          t.lastTreatmentDate = DateTime.now();
          if (label.isNotEmpty && !t.treatmentsHistory.contains(label)) t.treatmentsHistory.add(label);
          if (type == 'rct') {
            t.hasRCT = true;
          } else if (type == 'implant') t.hasImplant = true;
          else if (type == 'crown') t.hasCrown = true;
          else if (type == 'extraction') t.condition = 'extracted';
          else if (type == 'filling') t.surfaces['center'] = true;
          else if (type == 'veneer') t.hasVeneer = true;
          else if (type == 'braces') t.hasBraces = true;
        }
      }
    });
  }
}