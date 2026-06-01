import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_theme_controller.dart';
import '../../dental_chart/screens/dental_chart_screen.dart';
import '../../auth/screens/setup_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/layout/custom_layout.dart';
import '../../../core/preferences/app_preferences.dart' as prefs;
import 'patients_screen.dart' as patients;
import '../services/patient_ai_analysis_service.dart';
import '../widgets/patient_ai_analysis_dialog.dart';
import '../services/patient_account_export_service.dart';
import '../utils/patient_account_ai_utils.dart';
import '../utils/patient_account_utils.dart';

// ══════════════════════════════════════════════════════════
//  PatientAccountScreen
// ══════════════════════════════════════════════════════════
class PatientAccountScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String username;
  final bool isArabic;

  const PatientAccountScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.username,
    required this.isArabic,
  });

  @override
  State<PatientAccountScreen> createState() => _PatientAccountScreenState();
}

class _PatientAccountScreenState extends State<PatientAccountScreen> {
  // ── State ────────────────────────────────────────────────
  late bool isArabic;
  int _selectedTreatmentIndex = -1;
  int _selectedPaymentIndex = -1;

  // ── Cached Firestore streams ────────────────────────────
  // مهم: لا ننشئ snapshots داخل build حتى لا يظهر reload/loading عند تغيير الحجم.
  late final Stream<DocumentSnapshot> _patientStream;
  late final Stream<QuerySnapshot> _treatmentsStream;
  late final Stream<QuerySnapshot> _paymentsStream;

  // نخزن آخر بيانات وصلت من Firebase داخل State.
  // هيك لما يتغير حجم المتصفح ويتغير شكل الواجهة من Desktop إلى Mobile
  // ما ترجع StreamBuilder لحالة waiting وما تختفي معلومات المريض.
  StreamSubscription<DocumentSnapshot>? _patientSubscription;
  StreamSubscription<QuerySnapshot>? _treatmentsSubscription;
  StreamSubscription<QuerySnapshot>? _paymentsSubscription;

  Map<String, dynamic> _patientData = <String, dynamic>{};
  bool _patientLoaded = false;
  bool _treatmentsLoaded = false;
  bool _paymentsLoaded = false;
  Object? _patientError;
  Object? _treatmentsError;
  Object? _paymentsError;

  // ── Controllers ─────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _paymentDiscountController = TextEditingController();
  final TextEditingController _paymentNoteController = TextEditingController();
  final ScrollController _treatmentsScrollController = ScrollController();
  final ScrollController _paymentsScrollController = ScrollController();

  // ── Focus ────────────────────────────────────────────────
  final FocusNode _treatmentsFocus = FocusNode(debugLabel: 'treatments');
  final FocusNode _paymentsFocus = FocusNode(debugLabel: 'payments');

  // ── Payments ─────────────────────────────────────────────
  String _paymentMethod = 'كاش';

  String _currentUserRole = '';
  Map<String, dynamic> _currentUserPermissions = {};
  bool _currentUserLoaded = false;

  // ── AI Analysis ─────────────────────────────────────────
  bool isAiAnalyzing = false;
  String? patientAiResult;
  String? patientAiConfidenceLevel;
  String? patientAiTitle;
  String? openedPatientAiAnalysisId;

  // Gemini API Key من Google AI Studio.
  // ملاحظة: مفاتيح Google AI Studio الجديدة قد تبدأ بـ AQ. بدل AIza.
  // للتجربة الجامعية يعمل هنا، لكن للإنتاج الأفضل نقله إلى Cloud Functions.
static const String patientAiApiKey = String.fromEnvironment(
  'PATIENT_GEMINI_API_KEY',
  defaultValue: '',
);
  bool get _isAdminUser => _currentUserRole == 'admin';

  bool _hasPermission(String key) {
    if (_isAdminUser) return true;
    if (!_currentUserLoaded) return false;
    return _currentUserPermissions[key] == true;
  }

  bool get _canEditPatientTreatment => _hasPermission('canEditPatientTreatment');

  bool get _canAccessTreatmentSettings => _hasPermission('canAccessTreatmentSettings');

  // ── Cached lists ─────────────────────────────────────────
  List<QueryDocumentSnapshot> _treatmentDocs = [];
  List<QueryDocumentSnapshot> _paymentDocs = [];

  static const double _rowH = 70.0;
  static const double _payH = 96.0;

  @override
  void initState() {
    super.initState();
    isArabic = widget.isArabic;
    _paymentMethod = isArabic ? 'كاش' : 'Cash';
    _loadSavedLanguagePreference();

    _patientStream = FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.patientId)
        .snapshots();

    _treatmentsStream = FirebaseFirestore.instance
        .collection('patient_treatments')
        .where('patientId', isEqualTo: widget.patientId)
        .snapshots();

    _paymentsStream = FirebaseFirestore.instance
        .collection('patient_payments')
        .where('patientId', isEqualTo: widget.patientId)
        .snapshots();

    _startRealtimeListeners();
    _loadCurrentUserAccess();
  }

  void _startRealtimeListeners() {
    _patientSubscription = _patientStream.listen(
      (snap) {
        if (!mounted) return;
        final data = snap.exists ? snap.data() : null;
        setState(() {
          _patientData = data is Map<String, dynamic> ? data : <String, dynamic>{};
          _patientLoaded = true;
          _patientError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _patientLoaded = true;
          _patientError = error;
        });
      },
    );

    _treatmentsSubscription = _treatmentsStream.listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _treatmentDocs = _sortedDocs(snap.docs);
          _treatmentsLoaded = true;
          _treatmentsError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _treatmentsLoaded = true;
          _treatmentsError = error;
        });
      },
    );

    _paymentsSubscription = _paymentsStream.listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _paymentDocs = _sortedDocs(snap.docs);
          _paymentsLoaded = true;
          _paymentsError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _paymentsLoaded = true;
          _paymentsError = error;
        });
      },
    );
  }

  @override
  void dispose() {
    _patientSubscription?.cancel();
    _treatmentsSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _searchController.dispose();
    _paymentAmountController.dispose();
    _paymentDiscountController.dispose();
    _paymentNoteController.dispose();
    _treatmentsScrollController.dispose();
    _paymentsScrollController.dispose();
    _treatmentsFocus.dispose();
    _paymentsFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAccess() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        setState(() {
          _currentUserRole = 'admin';
          _currentUserPermissions = <String, dynamic>{};
          _currentUserLoaded = true;
        });
        return;
      }

      final data = query.docs.first.data();
      final rawPermissions = data['permissions'];

      setState(() {
        _currentUserRole = (data['role'] ?? '').toString();
        _currentUserPermissions = rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : <String, dynamic>{};
        _currentUserLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentUserLoaded = true);
    }
  }

  void _goBackToPatients() {
    prefs.AppPreferences.saveLastRoute('/patients');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => patients.PatientsScreen(
          username: widget.username,
          initialArabic: isArabic,
        ),
      ),
    );
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;
  Color get _pageBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F9FC);
  Color get _surface => AppThemeColors.surface(context);
  Color get _border => AppThemeColors.border(context);
  Color get _textPrimary => AppThemeColors.textPrimary(context);
  Color get _textSecondary => AppThemeColors.textSecondary(context);
  Color get _softFill => _isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.06);

  Future<void> _loadSavedLanguagePreference() async {
    try {
      final saved = await Future.value(prefs.AppPreferences.getSavedIsArabic());
      if (!mounted || saved == isArabic) return;
      setState(() {
        isArabic = saved;
        _paymentMethod = isArabic ? 'كاش' : 'Cash';
      });
    } catch (_) {}
  }

  void _setLanguage(bool value) {
    if (isArabic != value) {
      setState(() {
        isArabic = value;
        _paymentMethod = isArabic ? 'كاش' : 'Cash';
      });
    }
    try {
      prefs.AppPreferences.saveLanguage(value);
    } catch (_) {}
  }

  static double _toDouble(dynamic value) {
    return PatientAccountUtils.toDouble(value);
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(
          'لا تملك صلاحية لتنفيذ هذا الإجراء',
          'You do not have permission to perform this action',
        )),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _ensureVisible(ScrollController ctrl, int index, double rowHeight) {
    if (!ctrl.hasClients) return;
    final viewportHeight = ctrl.position.viewportDimension;
    final itemTop = index * rowHeight;
    final itemBottom = itemTop + rowHeight;
    final scrollOffset = ctrl.offset;

    if (itemBottom > scrollOffset + viewportHeight) {
      ctrl.animateTo(
        itemBottom - viewportHeight,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (itemTop < scrollOffset) {
      ctrl.animateTo(
        itemTop,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('لا يمكن فتح الرابط', 'Could not launch URL'))),
      );
    }
  }


  Future<void> _analyzePatientFileWithAi() async {
    if (isAiAnalyzing) return;

    if (!PatientAccountAiUtils.isGeminiApiKeyLooksValid(patientAiApiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
            'Gemini API Key غير صحيح أو ناقص. انسخه من Google AI Studio كما هو.',
            'Invalid or incomplete Gemini API Key. Copy it exactly from Google AI Studio.',
          )),
          backgroundColor: Colors.deepPurple,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    setState(() {
      isAiAnalyzing = true;
      patientAiResult = null;
      patientAiConfidenceLevel = null;
      patientAiTitle = null;
      openedPatientAiAnalysisId = null;
    });

    try {
      final payload = PatientAccountAiUtils.buildPayload(
        isArabic: isArabic,
        patientId: widget.patientId,
        patientName: widget.patientName,
        patientData: _patientData,
        treatmentDocs: _treatmentDocs,
        paymentDocs: _paymentDocs,
      );

      final responseText = await PatientAiAnalysisService.analyzePatientFileWithGemini(
        apiKey: patientAiApiKey,
        prompt: PatientAccountAiUtils.analysisPrompt(isArabic),
        patientPayload: payload,
      );

      final rawText = responseText.trim().isNotEmpty
          ? responseText.trim()
          : tr('لم يتم إرجاع نتيجة واضحة من التحليل.', 'No clear analysis result was returned.');

      final structured = PatientAccountAiUtils.parseJson(rawText);
      final title = PatientAccountAiUtils.safeText(
        structured?['title'],
        fallback: tr('تحليل ملف المريض', 'Patient File Analysis'),
      );
      final confidence = PatientAccountAiUtils.normalizeConfidence(structured?['confidence']);
      final report = PatientAccountAiUtils.safeText(structured?['report'], fallback: rawText);

      final docId = await PatientAiAnalysisService.saveAnalysis(
        patientId: widget.patientId,
        patientName: widget.patientName,
        title: title,
        resultText: report,
        confidenceLevel: confidence,
        structuredResult: structured,
        payload: payload,
        username: widget.username,
        language: isArabic ? 'ar' : 'en',
      );

      if (!mounted) return;

      setState(() {
        patientAiTitle = title;
        patientAiResult = report;
        patientAiConfidenceLevel = confidence;
        openedPatientAiAnalysisId = docId;
        isAiAnalyzing = false;
      });

      _showPatientAiAnalysisDialog(
        title: title,
        report: report,
        confidence: confidence,
        structuredResult: structured,
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      debugPrint('PATIENT AI ERROR: $e');
      debugPrint('PATIENT AI STACK: $stackTrace');

      setState(() => isAiAnalyzing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PatientAccountAiUtils.friendlyErrorMessage(error: e, isArabic: isArabic)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  void _showPatientAiAnalysisDialog({
    required String title,
    required String report,
    required String? confidence,
    required Map<String, dynamic>? structuredResult,
  }) {
    showDialog(
      context: context,
      builder: (_) => PatientAiAnalysisDialog(
        isArabic: isArabic,
        title: title,
        report: report,
        confidence: confidence,
        structuredResult: structuredResult,
      ),
    );
  }

  Future<void> _syncPatientFinancials() async {
    final db = FirebaseFirestore.instance;

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
  }

  void _onTreatmentKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return;
    final max = _treatmentDocs.length;
    if (max == 0) return;

    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedTreatmentIndex = (_selectedTreatmentIndex + 1).clamp(0, max - 1));
      _ensureVisible(_treatmentsScrollController, _selectedTreatmentIndex, _rowH);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedTreatmentIndex = (_selectedTreatmentIndex - 1).clamp(0, max - 1));
      _ensureVisible(_treatmentsScrollController, _selectedTreatmentIndex, _rowH);
    } else if (e.logicalKey == LogicalKeyboardKey.delete ||
        e.logicalKey == LogicalKeyboardKey.backspace) {
      if (!_canEditPatientTreatment) {
        _showPermissionDenied();
        return;
      }
      if (_selectedTreatmentIndex >= 0 && _selectedTreatmentIndex < max) {
        _confirmDeleteTreatment(_treatmentDocs[_selectedTreatmentIndex].id);
      }
    }
  }

  void _onPaymentKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return;
    final max = _paymentDocs.length;
    if (max == 0) return;

    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedPaymentIndex = (_selectedPaymentIndex + 1).clamp(0, max - 1));
      _ensureVisible(_paymentsScrollController, _selectedPaymentIndex, _payH);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedPaymentIndex = (_selectedPaymentIndex - 1).clamp(0, max - 1));
      _ensureVisible(_paymentsScrollController, _selectedPaymentIndex, _payH);
    } else if (e.logicalKey == LogicalKeyboardKey.delete ||
        e.logicalKey == LogicalKeyboardKey.backspace) {
      if (!_canEditPatientTreatment) {
        _showPermissionDenied();
        return;
      }
      if (_selectedPaymentIndex >= 0 && _selectedPaymentIndex < max) {
        _confirmDeletePayment(_paymentDocs[_selectedPaymentIndex].id);
      }
    }
  }

  Future<void> _confirmDeleteTreatment(String docId) async {
    if (!_canEditPatientTreatment) {
      _showPermissionDenied();
      return;
    }

    final ok = await _showConfirmDialog(tr('حذف المعالجة؟', 'Delete treatment?'));
    if (!ok || !mounted) return;
    await FirebaseFirestore.instance.collection('patient_treatments').doc(docId).delete();
    await _syncPatientFinancials();
    setState(() => _selectedTreatmentIndex = -1);
  }

  Future<void> _confirmDeletePayment(String docId) async {
    if (!_canEditPatientTreatment) {
      _showPermissionDenied();
      return;
    }

    final ok = await _showConfirmDialog(tr('حذف الدفعة؟', 'Delete payment?'));
    if (!ok || !mounted) return;
    await FirebaseFirestore.instance.collection('patient_payments').doc(docId).delete();
    await _syncPatientFinancials();
    setState(() => _selectedPaymentIndex = -1);
  }

  Future<bool> _showConfirmDialog(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            title: Text(message, style: TextStyle(color: _textPrimary, fontSize: 20)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('حذف', 'Delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAddAlertDialog(String currentAlert) {
    final alertCtrl = TextEditingController(text: currentAlert);
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _surface,
          title: Text(tr('تعديل تنبيهات المريض', 'Edit Patient Alerts'), style: TextStyle(color: _textPrimary)),
          content: TextField(
            controller: alertCtrl,
            style: TextStyle(color: _textPrimary),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: tr(
                'مثال: حساسية بنسلين، مريض سكري، ضغط دم مرتفع...',
                'e.g., Penicillin allergy, diabetic...',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('patients').doc(widget.patientId).update({
                  'alert': alertCtrl.text.trim(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr('تم حفظ التنبيه بنجاح', 'Alert saved successfully')),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text(tr('حفظ', 'Save')),
            )
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 5,
      searchController: _searchController,
      onSearchChanged: (_) {},
      onLanguageChanged: _setLanguage,
      body: LayoutBuilder(
        builder: (context, pageConstraints) {
          final pageWidth = pageConstraints.maxWidth;
          final isSmall = pageWidth < 900;
          final isMobile = pageWidth < 620;

          return ColoredBox(
            color: _pageBg,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 20),
              child: isSmall
                ? ListView(
                    children: [
                      _buildHeaderCard(),
                      SizedBox(height: isMobile ? 12 : 16),
                      _buildFinancialSummaryCards(),
                      SizedBox(height: isMobile ? 12 : 16),
                      _buildTreatmentsMobileCards(),
                      SizedBox(height: isMobile ? 12 : 16),
                      SizedBox(
                        height: isMobile ? 420 : 460,
                        child: _buildPaymentsSection(),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildFinancialSummaryCards(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: _buildTreatmentsTable()),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: _buildPaymentsSection()),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Header Card
  // ─────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    if (_patientError != null && !_patientLoaded) {
      return _headerMessage('Error: $_patientError');
    }

    final d = _patientData;
    final fileNumber = d['file_number']?.toString() ?? widget.patientId;
    final phone = d['phone']?.toString() ?? '';
    final genderSym = _genderSymbol(d['gender']?.toString());
    final birthRaw = d['birth_date'];
    final age = _calcAge(birthRaw);
    final alertText = d['alert']?.toString() ?? '';

    String birthStr = '—';
    if (birthRaw is Timestamp) {
      birthStr = DateFormat('MM/dd/yyyy').format(birthRaw.toDate());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 620) {
          return _buildMobileHeaderCard(
            fileNumber: fileNumber,
            phone: phone,
            genderSym: genderSym,
            birthStr: birthStr,
            age: age,
            alertText: alertText,
          );
        }

        if (width < 1000) {
          return _buildCompactHeaderCard(
            fileNumber: fileNumber,
            phone: phone,
            genderSym: genderSym,
            birthStr: birthStr,
            age: age,
            alertText: alertText,
          );
        }

        return _buildDesktopHeaderCard(
          fileNumber: fileNumber,
          phone: phone,
          genderSym: genderSym,
          birthStr: birthStr,
          age: age,
          alertText: alertText,
        );
      },
    );
  }

  Widget _headerMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _headerDecoration(),
      child: Text(message, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildDesktopHeaderCard({
    required String fileNumber,
    required String phone,
    required String genderSym,
    required String birthStr,
    required int age,
    required String alertText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _headerDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _iconActionBtn(
            icon: isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
            tooltip: tr('العودة إلى المرضى', 'Back to Patients'),
            color: Colors.blueGrey.shade700,
            onTap: _goBackToPatients,
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade400,
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _patientTitleBlock(
              fileNumber: fileNumber,
              genderSym: genderSym,
              birthStr: birthStr,
              age: age,
              titleFontSize: 18,
            ),
          ),
          _verticalDivider(),
          Expanded(
            flex: 2,
            child: phone.isNotEmpty
                ? _buildPhoneDropdown(phone)
                : Text(
                    tr('لا يوجد هاتف', 'No Phone'),
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          _verticalDivider(),
          Expanded(flex: 2, child: _alertBlock(alertText)),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Align(
              alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _headerActions(useChartText: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderCard({
    required String fileNumber,
    required String phone,
    required String genderSym,
    required String birthStr,
    required int age,
    required String alertText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _headerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconActionBtn(
                icon: isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                tooltip: tr('العودة إلى المرضى', 'Back to Patients'),
                color: Colors.blueGrey.shade700,
                onTap: _goBackToPatients,
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade400,
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _patientTitleBlock(
                  fileNumber: fileNumber,
                  genderSym: genderSym,
                  birthStr: birthStr,
                  age: age,
                  titleFontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              _headerActions(useChartText: false),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: phone.isNotEmpty
                    ? _infoChip(Icons.phone, phone, onTap: () => _showPhoneMenu(phone))
                    : _infoChip(Icons.phone_disabled, tr('لا يوجد هاتف', 'No Phone')),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _alertChip(alertText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeaderCard({
    required String fileNumber,
    required String phone,
    required String genderSym,
    required String birthStr,
    required int age,
    required String alertText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _headerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconActionBtn(
                icon: isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                tooltip: tr('العودة إلى المرضى', 'Back to Patients'),
                color: Colors.blueGrey.shade700,
                onTap: _goBackToPatients,
                padding: 7,
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.grey.shade400,
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.patientName,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _headerActions(useChartText: false, compactIcons: true),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(Icons.folder_open, '#$fileNumber'),
              if (phone.isNotEmpty)
                _infoChip(Icons.phone, phone, onTap: () => _showPhoneMenu(phone))
              else
                _infoChip(Icons.phone_disabled, tr('لا يوجد هاتف', 'No Phone')),
              _infoChip(Icons.cake_outlined, '$birthStr ($age)'),
              _infoChip(Icons.person_outline, genderSym),
            ],
          ),
          const SizedBox(height: 10),
          _alertChip(alertText),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: _actionBtn(
              icon: Icons.monitor_heart_rounded,
              label: tr('المخطط', 'Chart'),
              color: _canEditPatientTreatment ? Colors.teal.shade600 : Colors.grey,
              onTap: _canEditPatientTreatment ? _openChart : _showPermissionDenied,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _headerDecoration() {
    return BoxDecoration(
      color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F5F7),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    );
  }

  Widget _patientTitleBlock({
    required String fileNumber,
    required String genderSym,
    required String birthStr,
    required int age,
    required double titleFontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.patientName,
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold, color: _textPrimary),
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
        Text(
          '$birthStr ($age) $genderSym',
          style: TextStyle(fontSize: 13, color: _textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _alertBlock(String alertText) {
    return InkWell(
      onTap: () => _showAddAlertDialog(alertText),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    tr('التنبيهات', 'Alerts'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              alertText.isNotEmpty ? alertText : tr('لا يوجد تنبيهات', 'None'),
              style: TextStyle(
                fontSize: 13,
                color: alertText.isNotEmpty ? Colors.redAccent : _textSecondary,
                fontWeight: alertText.isNotEmpty ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertChip(String alertText) {
    return InkWell(
      onTap: () => _showAddAlertDialog(alertText),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: alertText.isNotEmpty ? Colors.red.withOpacity(0.08) : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: alertText.isNotEmpty ? Colors.red.shade200 : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: alertText.isNotEmpty ? Colors.redAccent : Colors.grey,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                alertText.isNotEmpty ? alertText : tr('لا يوجد تنبيهات', 'No alerts'),
                style: TextStyle(
                  color: alertText.isNotEmpty ? Colors.redAccent : _textSecondary,
                  fontWeight: alertText.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.blueGrey.shade600),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: _textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerActions({required bool useChartText, bool compactIcons = false}) {
    final iconPadding = compactIcons ? 7.0 : 8.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconActionBtn(
          icon: isAiAnalyzing ? Icons.hourglass_top_rounded : Icons.psychology_alt_outlined,
          tooltip: tr('تحليل ملف المريض بالذكاء الاصطناعي', 'AI Patient Analysis'),
          color: isAiAnalyzing ? Colors.grey : Colors.deepPurple,
          onTap: isAiAnalyzing ? () {} : _analyzePatientFileWithAi,
          padding: iconPadding,
        ),
        SizedBox(width: compactIcons ? 5 : 8),
        _iconActionBtn(
          icon: Icons.settings_rounded,
          tooltip: tr('إعداد', 'Setup'),
          color: _canAccessTreatmentSettings ? Colors.blueGrey.shade700 : Colors.grey,
          onTap: _canAccessTreatmentSettings
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TreatmentsSetupScreen(username: widget.username, initialArabic: isArabic),
                    ),
                  )
              : _showPermissionDenied,
          padding: iconPadding,
        ),
        SizedBox(width: compactIcons ? 5 : 8),
        _exportPopupButton(padding: iconPadding),
        if (useChartText) ...[
          const SizedBox(width: 8),
          _actionBtn(
            icon: Icons.monitor_heart_rounded,
            label: tr('المخطط', 'Chart'),
            color: _canEditPatientTreatment ? Colors.teal.shade600 : Colors.grey,
            onTap: _canEditPatientTreatment ? _openChart : _showPermissionDenied,
          ),
        ],
      ],
    );
  }


  Widget _exportPopupButton({double padding = 8}) {
    return Tooltip(
      message: tr('طباعة وتصدير', 'Print & Export'),
      child: PopupMenuButton<String>(
        tooltip: tr('طباعة وتصدير', 'Print & Export'),
        color: _surface,
        elevation: 8,
        offset: const Offset(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (value) {
          if (value == 'pdf') {
            _exportPatientPdf();
          } else if (value == 'excel') {
            _exportPatientExcel();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'pdf',
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 22),
                const SizedBox(width: 12),
                Text(
                  tr('تصدير PDF', 'Export PDF'),
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'excel',
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, color: Colors.green, size: 22),
                const SizedBox(width: 12),
                Text(
                  tr('تصدير Excel', 'Export Excel'),
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
            color: _surface,
          ),
          child: Icon(Icons.print_rounded, size: 20, color: Colors.blueGrey.shade700),
        ),
      ),
    );
  }

  Future<void> _exportPatientPdf() async {
    try {
      await PatientAccountExportService.exportPdf(
        isArabic: isArabic,
        patientId: widget.patientId,
        patientName: widget.patientName,
        patientData: _patientData,
        treatmentDocs: _treatmentDocs,
        paymentDocs: _paymentDocs,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم تصدير ملف PDF بنجاح', 'PDF exported successfully')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تعذر تصدير PDF: $e', 'Could not export PDF: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportPatientExcel() async {
    try {
      await PatientAccountExportService.exportExcel(
        isArabic: isArabic,
        patientId: widget.patientId,
        patientName: widget.patientName,
        patientData: _patientData,
        treatmentDocs: _treatmentDocs,
        paymentDocs: _paymentDocs,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم تصدير Excel بنجاح', 'Excel exported successfully')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تعذر تصدير Excel: $e', 'Could not export Excel: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openChart() {
    Navigator.pushReplacement(
      context,
      smoothPageRoute(
        MainDashboard(
          patientId: widget.patientId,
          patientName: widget.patientName,
          username: widget.username,
          isArabic: isArabic,
        ),
      ),
    );
  }

  Widget _buildPhoneDropdown(String phone) {
    return PopupMenuButton<String>(
      tooltip: tr('خيارات التواصل', 'Contact Options'),
      offset: const Offset(0, 40),
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) => _handlePhoneAction(value, phone),
      itemBuilder: (BuildContext context) => _phoneMenuItems(),
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

  List<PopupMenuEntry<String>> _phoneMenuItems() {
    return [
      PopupMenuItem(
        value: 'call',
        child: Row(
          children: [
            const Icon(Icons.phone, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Text(tr('مكالمة هاتفية', 'Call Phone')),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'wa',
        child: Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 10),
            Text('WhatsApp'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'sms',
        child: Row(
          children: [
            Icon(Icons.sms, color: Colors.blueGrey, size: 20),
            SizedBox(width: 10),
            Text('SMS Message'),
          ],
        ),
      ),
    ];
  }

  void _handlePhoneAction(String value, String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    switch (value) {
      case 'call':
        _launchUrl('tel:$cleanPhone');
        break;
      case 'wa':
        _launchUrl('https://wa.me/$cleanPhone');
        break;
      case 'sms':
        _launchUrl('sms:$cleanPhone');
        break;
    }
  }

  void _showPhoneMenu(String phone) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 120, 20, 0),
      color: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: _phoneMenuItems(),
    ).then((value) {
      if (value != null) _handlePhoneAction(value, phone);
    });
  }

  Widget _verticalDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: VerticalDivider(color: _border, thickness: 1, width: 1),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    double padding = 8,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
            color: _surface,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  String _genderSymbol(String? raw) {
    return PatientAccountUtils.genderSymbol(raw);
  }

  int _calcAge(dynamic raw) {
    return PatientAccountUtils.calculateAge(raw);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 17, color: color), overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 16),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 17), overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Financial Summary Cards
  // ─────────────────────────────────────────────────────────
  Widget _buildFinancialSummaryCards() {
    final d = _patientData;
    final req = _toDouble(d['required_amount']);
    final disc = _toDouble(d['discount']);
    final paid = _toDouble(d['paid_amount']);
    final balance = _toDouble(d['remaining_amount']);

    return LayoutBuilder(
      builder: (context, c) {
        final isTiny = c.maxWidth < 480;
        final width = isTiny
            ? c.maxWidth
            : c.maxWidth < 800
                ? (c.maxWidth / 2) - 10
                : (c.maxWidth / 4) - 12;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _summaryCard(tr('إجمالي المعالجات', 'Treatments'), req, Icons.medical_services, Colors.blue, width),
            _summaryCard(tr('إجمالي الخصم', 'Discount'), disc, Icons.discount, Colors.orange, width),
            _summaryCard(tr('إجمالي المدفوع', 'Paid'), paid, Icons.payments, Colors.green, width),
            _summaryCard(
              tr('الرصيد المتبقي', 'Remaining'),
              balance,
              Icons.account_balance_wallet,
              balance > 0 ? Colors.red : Colors.teal,
              width,
              isBalance: true,
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, double amount, IconData icon, Color color, double width, {bool isBalance = false}) {
    return Container(
      width: width < 0 ? double.infinity : width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isBalance ? color.withOpacity(0.45) : _border, width: isBalance ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppThemeColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${amount.toStringAsFixed(2)} JD',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isBalance ? color : _textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Treatments Table - Desktop
  // ─────────────────────────────────────────────────────────
  Widget _buildTreatmentsTable() {
    return Container(
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            title: tr('سجل المعالجات السريرية', 'Clinical Treatments Record'),
            color: AppThemeColors.lapisBlue,
            trailing: _countChip(_treatmentDocs.length, AppThemeColors.lapisBlue),
          ),
          _treatmentColumnHeaders(),
          Expanded(
            child: _buildTreatmentsListBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentsListBody() {
    if (_treatmentsError != null && !_treatmentsLoaded) {
      return Center(child: Text('Error: $_treatmentsError'));
    }

    if (!_treatmentsLoaded && _treatmentDocs.isEmpty) {
      return Center(child: Text(tr('جاري تحميل المعالجات...', 'Loading treatments...'), style: const TextStyle(color: Colors.grey)));
    }

    if (_treatmentDocs.isEmpty) {
      return Center(child: Text(tr('لا توجد معالجات', 'No treatments'), style: const TextStyle(color: Colors.grey)));
    }

    return KeyboardListener(
      focusNode: _treatmentsFocus,
      autofocus: false,
      onKeyEvent: _onTreatmentKey,
      child: GestureDetector(
        onTap: () => _treatmentsFocus.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: Scrollbar(
          controller: _treatmentsScrollController,
          thumbVisibility: true,
          thickness: 7,
          radius: const Radius.circular(8),
          child: ListView.builder(
            controller: _treatmentsScrollController,
            itemCount: _treatmentDocs.length,
            itemExtent: _rowH,
            itemBuilder: (context, index) => _buildTreatmentRow(index, _treatmentDocs[index]),
          ),
        ),
      ),
    );
  }

  Widget _countChip(int count, Color color) {
    return Chip(
      label: Text('$count', style: const TextStyle(fontSize: 15, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  List<QueryDocumentSnapshot> _sortedDocs(List<QueryDocumentSnapshot> docs) {
    return PatientAccountUtils.sortedDocs(docs);
  }

  Widget _treatmentColumnHeaders() {
    const style = TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white);
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color.fromRGBO(38, 97, 156, 1), Color.fromRGBO(38, 97, 156, 1)]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _colHeader(tr('التاريخ', 'Date'), flex: 2, style: style),
          _colHeader(tr('التصنيف', 'Category'), flex: 4, style: style),
          _colHeader(tr('المعالجة', 'Treatment'), flex: 4, style: style),
          _colHeader(tr('السن', 'Tooth'), flex: 2, style: style, center: true),
          _colHeader(tr('العدد', 'Qty'), flex: 2, style: style, center: true),
          _colHeader(tr('السعر', 'Price'), flex: 2, style: style),
          _colHeader(tr('الخصم', 'Disc.'), flex: 2, style: style),
          _colHeader(tr('الإجمالي', 'Total'), flex: 2, style: style),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _colHeader(String text, {required int flex, required TextStyle style, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: center ? TextAlign.center : null, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildTreatmentRow(int index, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now();
    final category = data['category'] ?? tr('غير محدد', 'N/A');
    final tName = data['treatmentName'] ?? '';
    final detail = data['detail'] ?? '';
    final toothId = data['toothId'] ?? 0;
    final qty = data['quantity'] ?? 1;
    final price = _toDouble(data['price']);
    final discount = _toDouble(data['discount']);
    final total = (price * qty) - discount;
    final isSelected = index == _selectedTreatmentIndex;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTreatmentIndex = index);
        _treatmentsFocus.requestFocus();
      },
      child: Container(
        height: _rowH,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.13)
              : index.isEven
                  ? Colors.transparent
                  : Colors.grey.withOpacity(0.04),
          border: Border(
            bottom: BorderSide(color: _border.withOpacity(0.5)),
            left: isSelected ? const BorderSide(color: Colors.blue, width: 3) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(DateFormat('yyyy/MM/dd').format(date), style: const TextStyle(fontSize: 12))),
            Expanded(
              flex: 4,
              child: Text(
                category.toString(),
                style: TextStyle(fontSize: 16, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                detail.toString().isEmpty ? tName.toString() : '$tName - $detail',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  toothId == 0 ? tr('عام', 'Gen') : '$toothId',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(flex: 2, child: Center(child: Text('$qty', style: const TextStyle(fontSize: 16)))),
            Expanded(
              flex: 2,
              child: _editableMoneyText(
                price,
                _textPrimary,
                () => _canEditPatientTreatment ? _editFinancialValue(doc.id, 'price', price) : _showPermissionDenied(),
              ),
            ),
            Expanded(
              flex: 2,
              child: _editableMoneyText(
                discount,
                Colors.orange,
                () => _canEditPatientTreatment ? _editFinancialValue(doc.id, 'discount', discount) : _showPermissionDenied(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${total.toStringAsFixed(2)} JD',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: _canEditPatientTreatment ? Colors.red : Colors.grey, size: 18),
                padding: EdgeInsets.zero,
                tooltip: tr('حذف المعالجة', 'Delete'),
                onPressed: () => _confirmDeleteTreatment(doc.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableMoneyText(double value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(value.toStringAsFixed(2), style: TextStyle(fontSize: 16, color: color), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 3),
            Icon(Icons.edit, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  void _editFinancialValue(String docId, String field, double current) {
    if (!_canEditPatientTreatment) {
      _showPermissionDenied();
      return;
    }

    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    final title = field == 'price' ? tr('تعديل السعر', 'Edit Price') : tr('تعديل الخصم', 'Edit Discount');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: Text(title, style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('القيمة الجديدة (JD)', 'New Value (JD)'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('إلغاء', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              final v = double.tryParse(ctrl.text);
              if (v == null) return;
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('patient_treatments').doc(docId).update({field: v});
              await _syncPatientFinancials();
            },
            child: Text(tr('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Treatments Cards - Mobile / Small
  // ─────────────────────────────────────────────────────────
  Widget _buildTreatmentsMobileCards() {
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            title: tr('سجل المعالجات السريرية', 'Clinical Treatments Record'),
            color: AppThemeColors.lapisBlue,
            trailing: _countChip(_treatmentDocs.length, AppThemeColors.lapisBlue),
          ),
          if (_treatmentsError != null && !_treatmentsLoaded)
            Padding(padding: const EdgeInsets.all(18), child: Center(child: Text('Error: $_treatmentsError')))
          else if (!_treatmentsLoaded && _treatmentDocs.isEmpty)
            SizedBox(
              height: 180,
              child: Center(child: Text(tr('جاري تحميل المعالجات...', 'Loading treatments...'), style: const TextStyle(color: Colors.grey))),
            )
          else if (_treatmentDocs.isEmpty)
            SizedBox(
              height: 180,
              child: Center(child: Text(tr('لا توجد معالجات', 'No treatments'), style: const TextStyle(color: Colors.grey))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: _treatmentDocs.length,
              itemBuilder: (context, index) => _buildTreatmentMobileCard(index, _treatmentDocs[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTreatmentMobileCard(int index, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now();
    final category = data['category'] ?? tr('غير محدد', 'N/A');
    final tName = data['treatmentName'] ?? '';
    final detail = data['detail'] ?? '';
    final toothId = data['toothId'] ?? 0;
    final qty = data['quantity'] ?? 1;
    final price = _toDouble(data['price']);
    final discount = _toDouble(data['discount']);
    final total = (price * qty) - discount;
    final isSelected = index == _selectedTreatmentIndex;

    return GestureDetector(
      onTap: () => setState(() => _selectedTreatmentIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.10) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.blue : _border, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.toString().isEmpty ? tName.toString() : '$tName - $detail',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _canEditPatientTreatment ? Colors.red : Colors.grey, size: 21),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: tr('حذف المعالجة', 'Delete'),
                  onPressed: () => _confirmDeleteTreatment(doc.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mobileInfoTile(tr('التاريخ', 'Date'), DateFormat('yyyy/MM/dd').format(date)),
                _mobileInfoTile(tr('التصنيف', 'Category'), category.toString(), valueColor: Colors.blue.shade800),
                _mobileInfoTile(tr('السن / المجال', 'Tooth'), toothId == 0 ? tr('عام', 'Gen') : '$toothId'),
                _mobileInfoTile(tr('العدد', 'Qty'), '$qty'),
                _mobileEditableMoneyTile(tr('السعر', 'Price'), price, _textPrimary, () {
                  _canEditPatientTreatment ? _editFinancialValue(doc.id, 'price', price) : _showPermissionDenied();
                }),
                _mobileEditableMoneyTile(tr('الخصم', 'Discount'), discount, Colors.orange, () {
                  _canEditPatientTreatment ? _editFinancialValue(doc.id, 'discount', discount) : _showPermissionDenied();
                }),
                _mobileInfoTile(tr('الإجمالي', 'Total'), '${total.toStringAsFixed(2)} JD', valueColor: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileInfoTile(String label, String value, {Color? valueColor}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _softFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? _textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _mobileEditableMoneyTile(String label, double value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 116, maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: _textSecondary)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value.toStringAsFixed(2),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Payments Section
  // ─────────────────────────────────────────────────────────
  Widget _buildPaymentsSection() {
    return Container(
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        children: [
          _sectionHeader(
            title: tr('سجل الدفعات', 'Payments'),
            color: Colors.green,
            trailing: IconButton(
              icon: Icon(Icons.add_circle, color: _canEditPatientTreatment ? Colors.green : Colors.grey),
              tooltip: tr('إضافة دفعة', 'Add payment'),
              onPressed: _showAddPaymentDialog,
            ),
          ),
          Expanded(child: _buildPaymentsListBody()),
        ],
      ),
    );
  }

  Widget _buildPaymentsListBody() {
    if (_paymentsError != null && !_paymentsLoaded) {
      return Center(child: Text('Error: $_paymentsError'));
    }

    if (!_paymentsLoaded && _paymentDocs.isEmpty) {
      return Center(child: Text(tr('جاري تحميل الدفعات...', 'Loading payments...'), style: const TextStyle(color: Colors.grey)));
    }

    if (_paymentDocs.isEmpty) {
      return Center(child: Text(tr('لا توجد دفعات', 'No payments'), style: const TextStyle(color: Colors.grey)));
    }

    return KeyboardListener(
      focusNode: _paymentsFocus,
      autofocus: false,
      onKeyEvent: _onPaymentKey,
      child: GestureDetector(
        onTap: () => _paymentsFocus.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: Scrollbar(
          controller: _paymentsScrollController,
          thumbVisibility: true,
          thickness: 6,
          radius: const Radius.circular(8),
          child: ListView.builder(
            controller: _paymentsScrollController,
            padding: const EdgeInsets.all(10),
            itemCount: _paymentDocs.length,
            itemBuilder: (context, index) => _buildPaymentCard(index, _paymentDocs[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(int index, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now();
    final amount = _toDouble(data['amount']);
    final discount = _toDouble(data['discount']);
    final note = data['note'] as String? ?? '';
    final method = data['method'] as String? ?? '';
    final isCash = method == 'كاش' || method == 'Cash';
    final isSelected = index == _selectedPaymentIndex;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPaymentIndex = index);
        _paymentsFocus.requestFocus();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.12) : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.green : Colors.green.shade100, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isCash ? Icons.money : Icons.credit_card, color: Colors.green, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${amount.toStringAsFixed(2)} JD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$method  •  ${DateFormat('yyyy/MM/dd').format(date)}',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (discount > 0)
                    Text(
                      tr('خصم: ${discount.toStringAsFixed(2)} JD', 'Disc: ${discount.toStringAsFixed(2)} JD'),
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (note.isNotEmpty)
                    Text(note, style: TextStyle(color: _textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: _canEditPatientTreatment ? Colors.red : Colors.grey, size: 20),
              tooltip: tr('حذف الدفعة', 'Delete payment'),
              onPressed: () => _confirmDeletePayment(doc.id),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Add Payment Dialog
  // ─────────────────────────────────────────────────────────
  void _showAddPaymentDialog() {
    if (!_canEditPatientTreatment) {
      _showPermissionDenied();
      return;
    }

    _paymentAmountController.clear();
    _paymentDiscountController.clear();
    _paymentNoteController.clear();
    _paymentMethod = isArabic ? 'كاش' : 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: _surface,
          title: Text(tr('إضافة دفعة', 'Add Payment'), style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _paymentAmountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('المبلغ المدفوع (JD)', 'Amount (JD)'),
                    prefixIcon: const Icon(Icons.attach_money),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _paymentDiscountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: tr('خصم إضافي (JD)', 'Extra Discount (JD)'),
                    prefixIcon: const Icon(Icons.money_off, color: Colors.orange),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _paymentNoteController,
                  decoration: InputDecoration(
                    labelText: tr('ملاحظة (اختياري)', 'Note (optional)'),
                    prefixIcon: const Icon(Icons.note),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  dropdownColor: _surface,
                  decoration: InputDecoration(labelText: tr('طريقة الدفع', 'Payment Method'), border: const OutlineInputBorder()),
                  items: [tr('كاش', 'Cash'), tr('بطاقة', 'Card')]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setDlgState(() => _paymentMethod = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('إلغاء', 'Cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(_paymentAmountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);

                await FirebaseFirestore.instance.collection('patient_payments').add({
                  'patientId': widget.patientId,
                  'amount': amount,
                  'discount': double.tryParse(_paymentDiscountController.text) ?? 0.0,
                  'note': _paymentNoteController.text.trim(),
                  'method': _paymentMethod,
                  'date': Timestamp.now(),
                });
                await _syncPatientFinancials();
              },
              child: Text(tr('حفظ الدفعة', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Shared Widgets
  // ─────────────────────────────────────────────────────────
  Widget _sectionHeader({required String title, required Color color, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
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
}

Route smoothPageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 150),
  );
}