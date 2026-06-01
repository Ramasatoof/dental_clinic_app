import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/xray_analysis_service.dart';
import '../../../core/layout/custom_layout.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../utils/xray_analysis_utils.dart';
import '../widgets/xray_confidence_chip.dart';
import '../widgets/xray_status_chip.dart';
import '../widgets/xray_image_action_button.dart';
import '../widgets/xray_history_date_button.dart';
import '../widgets/xray_adjustment_slider.dart';
import '../widgets/xray_findings_overlay.dart';
import '../widgets/xray_new_analysis_button.dart';
const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class XRayAnalysisScreen extends StatefulWidget {
  final String username;
  final bool initialArabic;

  const XRayAnalysisScreen({
    super.key,
    required this.username,
    required this.initialArabic,
  });

  @override
  State<XRayAnalysisScreen> createState() => _XRayAnalysisScreenState();
}

class _XRayAnalysisScreenState extends State<XRayAnalysisScreen> {
  late bool isArabic;
  bool isAnalyzing = false;
  bool isSavingAnalysis = false;
  bool isHistoryOpen = true;

  XFile? selectedImage;
  Uint8List? previewBytes;
  Size? previewImageSize;

  String? aiResult;
  String? aiConfidenceLevel;
  String? currentAnalysisTitle;
  String? openedHistoryId;

  List<Map<String, dynamic>> analysisFindings = [];

  double imageBrightness = 0.0;
  double imageContrast = 1.0;
  bool isImageFlipped = false;

  DateTime? historyStartDate;
  DateTime? historyEndDate;
  String historySearchQuery = '';

  final TextEditingController searchController = TextEditingController();
  final TextEditingController historySearchController = TextEditingController();
  TransformationController? previewTransformationController;

  final String apiKey = "AIzaSyBwM9a_aFMNTJomIaMZVwezefv2VTSsbr0";

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    previewTransformationController = TransformationController();
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  TextDirection get _contentDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  TextAlign get _contentAlign =>
      isArabic ? TextAlign.right : TextAlign.left;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : lightGray.withOpacity(0.55);

  Color _panelFill(BuildContext context) =>
      _isDark ? const Color(0xFF111827) : Colors.white;

  Color _previewFill(BuildContext context) =>
      _isDark ? const Color(0xFF0F172A) : lightGray.withOpacity(0.75);

  @override
  void dispose() {
    searchController.dispose();
    historySearchController.dispose();
    previewTransformationController?.dispose();
    super.dispose();
  }

String _safeString(dynamic value, {String fallback = ''}) {
  return XRayAnalysisUtils.safeString(value, fallback: fallback);
}

String _safeTrimmedString(dynamic value, {String fallback = ''}) {
  return XRayAnalysisUtils.safeTrimmedString(value, fallback: fallback);
}

  TransformationController _previewController() {
    previewTransformationController ??= TransformationController();
    return previewTransformationController!;
  }

  Future<Size?> _readImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  void _resetPreviewView() {
    final oldController = previewTransformationController;
    previewTransformationController = TransformationController();

    try {
      oldController?.dispose();
    } catch (_) {}
  }

  void _resetImageAdjustments() {
    setState(() {
      imageBrightness = 0.0;
      imageContrast = 1.0;
      isImageFlipped = false;
      _resetPreviewView();
    });
  }

  void _openNewBlankAnalysis() {
    setState(() {
      _resetPreviewView();
      selectedImage = null;
      previewBytes = null;
      previewImageSize = null;
      aiResult = null;
      aiConfidenceLevel = null;
      currentAnalysisTitle = null;
      openedHistoryId = null;
      analysisFindings = [];
      imageBrightness = 0.0;
      imageContrast = 1.0;
      isImageFlipped = false;
    });
  }

Widget _buildNewAnalysisButton({bool compact = false}) {
  return XRayNewAnalysisButton(
    onPressed: _openNewBlankAnalysis,
    label: tr("فتح تحليل جديد", "Open New Analysis"),
    compact: compact,
  );
}
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    final size = await _readImageSize(bytes);

    if (!mounted) return;

    setState(() {
      _resetPreviewView();
      selectedImage = image;
      previewBytes = bytes;
      previewImageSize = size;
      aiResult = null;
      aiConfidenceLevel = null;
      currentAnalysisTitle = null;
      openedHistoryId = null;
      analysisFindings = [];
      imageBrightness = 0.0;
      imageContrast = 1.0;
      isImageFlipped = false;
    });
  }

String _generateSuggestedTitle(String resultText) {
  return XRayAnalysisUtils.generateSuggestedTitle(
    resultText: resultText,
    isArabic: isArabic,
  );
}

String _formatDate(dynamic ts) {
  return XRayAnalysisUtils.formatDate(ts);
}

String _formatShortDate(DateTime? date) {
  return XRayAnalysisUtils.formatShortDate(
    date: date,
    fallback: tr("اختر تاريخ", "Pick date"),
  );
}

int _timestampValue(DocumentSnapshot doc) {
  return XRayAnalysisUtils.timestampValue(doc);
}

  String _friendlyAnalysisErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains("503") ||
        message.contains("unavailable") ||
        message.contains("high demand") ||
        message.contains("overloaded") ||
        message.contains("temporar")) {
      return tr(
        "تعذر إكمال التحليل الآن لأن خدمة الذكاء الاصطناعي مشغولة حاليًا. يرجى إعادة المحاولة بعد قليل.",
        "The analysis could not be completed right now because the AI service is currently busy. Please try again shortly.",
      );
    }

    if (message.contains("api key") ||
        message.contains("permission") ||
        message.contains("unauthorized") ||
        message.contains("forbidden") ||
        message.contains("403")) {
      return tr(
        "تعذر الاتصال بخدمة التحليل حاليًا. يرجى التحقق من إعدادات الخدمة أو المحاولة لاحقًا.",
        "The analysis service could not be reached right now. Please check the service settings or try again later.",
      );
    }

    if (message.contains("network") ||
        message.contains("socket") ||
        message.contains("timeout") ||
        message.contains("connection")) {
      return tr(
        "يوجد مشكلة في الاتصال أثناء إرسال صورة الأشعة للتحليل. يرجى التحقق من الإنترنت ثم إعادة المحاولة.",
        "There was a connection problem while sending the X-ray for analysis. Please check the internet connection and try again.",
      );
    }

    if (message.contains("mime") ||
        message.contains("format") ||
        message.contains("invalid image") ||
        message.contains("unsupported")) {
      return tr(
        "تعذر قراءة صورة الأشعة المرفوعة. يرجى اختيار صورة واضحة وبصيغة مدعومة ثم إعادة المحاولة.",
        "The uploaded X-ray image could not be read. Please choose a clear image in a supported format and try again.",
      );
    }

    return tr(
      "حدث خطأ أثناء تحليل صورة الأشعة. يرجى إعادة المحاولة، وإذا استمرت المشكلة تحقق من إعدادات الخدمة.",
      "An error occurred while analyzing the X-ray image. Please try again, and if the issue continues, check the service settings.",
    );
  }

  List<double> _imageAdjustmentMatrix() {
    final double c = imageContrast;
    final double t = (1 - c) * 128 + (imageBrightness * 255);

    return <double>[
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  Future<Uint8List> _buildAdjustedImageBytes(Uint8List sourceBytes) async {
    if (imageBrightness == 0.0 && imageContrast == 1.0) {
      return sourceBytes;
    }

    try {
      final codec = await ui.instantiateImageCodec(sourceBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final width = image.width.toDouble();
      final height = image.height.toDouble();

      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.matrix(_imageAdjustmentMatrix());

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, width, height),
        Rect.fromLTWH(0, 0, width, height),
        paint,
      );

      final picture = recorder.endRecording();
      final rendered = await picture.toImage(image.width, image.height);
      final byteData = await rendered.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return sourceBytes;

      return byteData.buffer.asUint8List();
    } catch (_) {
      return sourceBytes;
    }
  }

  String _analysisPrompt() {
    return isArabic
        ? '''
أنت مساعد خبير لطبيب أسنان.
حلل صورة الأشعة السنية بدقة، ثم أعد النتيجة بصيغة JSON فقط وبدون markdown أو أي نص إضافي.
يجب أن يكون الرد بهذا الشكل بالضبط:

{
  "title": "عنوان قصير جدًا",
  "confidence": "high",
  "report": "تقرير واضح ومنظم باللغة العربية.",
  "findings": [
    {
      "label": "وصف قصير",
      "x": 120,
      "y": 220,
      "width": 180,
      "height": 140
    }
  ]
}

القواعد:
- confidence يجب أن تكون واحدة فقط من: high أو mid أو low
- report يجب أن يكون عربيًا وواضحًا للطبيب ومختصرًا ومنظمًا
- findings يجب أن تحتوي على أماكن تقريبية للمشكلات الظاهرة فقط
- استخدم إحداثيات تقريبية normalized من 0 إلى 1000
- إذا لم توجد منطقة واضحة، أعد findings كمصفوفة فارغة []
- لا تضف أي نص خارج JSON
- أختم report بجملة قصيرة توضح أن النتيجة استرشادية وليست تشخيصًا نهائيًا
'''
        : '''
You are an expert dental assistant.
Analyze this dental X-ray carefully, then return the result as JSON only with no markdown and no extra text.
The response must follow this exact structure:

{
  "title": "Very short title",
  "confidence": "high",
  "report": "Clear and structured English report.",
  "findings": [
    {
      "label": "Short label",
      "x": 120,
      "y": 220,
      "width": 180,
      "height": 140
    }
  ]
}

Rules:
- confidence must be exactly one of: high, mid, low
- report must be in clear English and useful to the dentist
- findings should contain approximate locations only for visible suspicious areas
- use normalized coordinates from 0 to 1000
- if there is no clear localized finding, return an empty findings array []
- do not include any text outside the JSON
- end the report with a short sentence that says this is guidance only and not a final diagnosis
''';
  }

String _formatAnalysisReportForDisplay(String text) {
  return XRayAnalysisUtils.formatAnalysisReportForDisplay(
    text: text,
    isArabic: isArabic,
  );
}


String? _normalizeConfidence(dynamic value) {
  return XRayAnalysisUtils.normalizeConfidence(value);
}

String? _extractConfidenceFromText(String text) {
  return XRayAnalysisUtils.extractConfidenceFromText(text);
}

 List<Map<String, dynamic>> _normalizeFindings(dynamic rawFindings) {
  return XRayAnalysisUtils.normalizeFindings(rawFindings);
}

Map<String, dynamic>? _parseStructuredAnalysis(String rawText) {
  return XRayAnalysisUtils.parseStructuredAnalysis(rawText);
}

Future<String> _saveAnalysisToFirestore({
  required String resultText,
  required String suggestedTitle,
  required String? confidenceLevel,
  required List<Map<String, dynamic>> findings,
}) {
  return XRayAnalysisService.saveAnalysis(
    title: suggestedTitle,
    resultText: resultText,
    confidenceLevel: confidenceLevel,
    findings: findings,
    username: widget.username,
    language: isArabic ? "ar" : "en",
  );
}

  Future<void> _deleteAnalysis(String docId) async {
await XRayAnalysisService.deleteAnalysis(docId);
    if (!mounted) return;

    setState(() {
      if (openedHistoryId == docId) {
        openedHistoryId = null;
        aiResult = null;
        aiConfidenceLevel = null;
        currentAnalysisTitle = null;
        selectedImage = null;
        previewBytes = null;
        previewImageSize = null;
        analysisFindings = [];
      }
    });
  }

  Future<void> _confirmDeleteAnalysis(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: _contentDirection,
        child: AlertDialog(
          backgroundColor: _surface(context),
          title: Text(
            tr("حذف التحليل", "Delete Analysis"),
            style: TextStyle(color: _textPrimary(context)),
          ),
          content: Text(
            tr(
              "هل أنت متأكد من حذف هذا التحليل من السجل؟",
              "Are you sure you want to delete this analysis from history?",
            ),
            style: TextStyle(color: _textPrimary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr("إلغاء", "Cancel")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: Text(
                tr("حذف", "Delete"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _deleteAnalysis(docId);
    }
  }

  Future<void> _analyzeXRay() async {
    if (selectedImage == null || previewBytes == null) return;

    setState(() {
      isAnalyzing = true;
      isSavingAnalysis = false;
      aiResult = null;
      aiConfidenceLevel = null;
      currentAnalysisTitle = null;
      analysisFindings = [];
    });

    try {
final imageBytes = await _buildAdjustedImageBytes(previewBytes!);

final responseText = _safeString(
  await XRayAnalysisService.analyzeImageWithGemini(
    apiKey: apiKey,
    prompt: _analysisPrompt(),
    imageBytes: imageBytes,
    imagePath: selectedImage!.path,
  ),
);
      final rawText = responseText.trim().isNotEmpty
          ? responseText.trim()
          : (isArabic
              ? "لم يتم إرجاع نتيجة واضحة من التحليل. يرجى إعادة المحاولة بصورة أوضح."
              : "No clear analysis result was returned. Please try again with a clearer image.");

      final structured = _parseStructuredAnalysis(rawText);

      final reportCandidate = structured == null
          ? ""
          : _safeTrimmedString(structured["report"]);
final reportText = _formatAnalysisReportForDisplay(
  reportCandidate.isNotEmpty ? reportCandidate : rawText,
);
      final confidenceLevel = structured == null
          ? _extractConfidenceFromText(rawText)
          : _safeString(structured["confidence"]).isNotEmpty
              ? _safeString(structured["confidence"])
              : _extractConfidenceFromText(rawText);

      final findings = structured == null
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (structured["findings"] as List?) ?? const [],
            );

      final structuredTitle = structured == null
          ? ""
          : _safeTrimmedString(structured["title"]);
      final title = structuredTitle.isNotEmpty
          ? structuredTitle
          : _generateSuggestedTitle(reportText);

      if (!mounted) return;

      setState(() {
        aiResult = reportText;
        aiConfidenceLevel = _normalizeConfidence(confidenceLevel);
        analysisFindings = findings;
        currentAnalysisTitle = title;
        isAnalyzing = false;
        isSavingAnalysis = true;
      });

      final docId = await _saveAnalysisToFirestore(
        resultText: reportText,
        suggestedTitle: title,
        confidenceLevel: _normalizeConfidence(confidenceLevel),
        findings: findings,
      );

      if (!mounted) return;

      setState(() {
        openedHistoryId = docId;
        isSavingAnalysis = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        currentAnalysisTitle =
            tr("تعذر إكمال التحليل", "Analysis Could Not Be Completed");
        aiResult = _friendlyAnalysisErrorMessage(e);
        aiConfidenceLevel = null;
        analysisFindings = [];
        isAnalyzing = false;
        isSavingAnalysis = false;
      });
    }
  }

  void _openSavedAnalysis(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    setState(() {
      _resetPreviewView();
      openedHistoryId = doc.id;
      currentAnalysisTitle = _safeString(data["title"]);
aiResult = _formatAnalysisReportForDisplay(_safeString(data["result"]));
      aiConfidenceLevel = _normalizeConfidence(data["confidence"]) ??
          _extractConfidenceFromText(_safeString(data["result"]));
      analysisFindings = _normalizeFindings(data["findings"]);
      selectedImage = null;
      previewBytes = null;
      previewImageSize = null;
      imageBrightness = 0.0;
      imageContrast = 1.0;
      isImageFlipped = false;
    });
  }

  Future<void> _pickHistoryDate({required bool isStart}) async {
    final initialDate =
        (isStart ? historyStartDate : historyEndDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart
          ? tr("اختر تاريخ البداية", "Select start date")
          : tr("اختر تاريخ النهاية", "Select end date"),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        historyStartDate = picked;
        if (historyEndDate != null &&
            historyEndDate!.isBefore(historyStartDate!)) {
          historyEndDate = historyStartDate;
        }
      } else {
        historyEndDate = picked;
        if (historyStartDate != null &&
            historyEndDate!.isBefore(historyStartDate!)) {
          historyStartDate = historyEndDate;
        }
      }
    });
  }

bool _matchesHistoryFilters(QueryDocumentSnapshot doc) {
  return XRayAnalysisUtils.matchesHistoryFilters(
    doc: doc,
    searchQuery: historySearchQuery,
    startDate: historyStartDate,
    endDate: historyEndDate,
  );
}

  Color _confidenceColor(String level) {
    switch (level) {
      case "high":
        return Colors.green.shade700;
      case "mid":
        return Colors.orange.shade700;
      case "low":
      default:
        return Colors.red.shade700;
    }
  }

  String _confidenceLabel(String level) {
    switch (level) {
      case "high":
        return tr("ثقة عالية", "High");
      case "mid":
        return tr("ثقة متوسطة", "Mid");
      case "low":
      default:
        return tr("ثقة منخفضة", "Low");
    }
  }

  IconData _confidenceIcon(String level) {
    switch (level) {
      case "high":
        return Icons.verified_rounded;
      case "mid":
        return Icons.rule_folder_outlined;
      case "low":
      default:
        return Icons.error_outline_rounded;
    }
  }

Widget _buildStatusChip(String text, IconData icon) {
  return XRayStatusChip(
    text: text,
    icon: icon,
  );
}

Widget _buildConfidenceChip(String level) {
  return XRayConfidenceChip(
    level: level,
    color: _confidenceColor(level),
    label: _confidenceLabel(level),
    icon: _confidenceIcon(level),
  );
}

  Widget _buildTopHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 700;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _panelFill(context),
                lapisBlue.withOpacity(_isDark ? 0.12 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: lapisBlue.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: lapisBlue.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Directionality(
            textDirection: _contentDirection,
            child: isCompact
                ? Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: lapisBlue,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.radar,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              tr(
                                "تحليل الأشعة بالذكاء الاصطناعي",
                                "AI X-Ray Analysis",
                              ),
                              textAlign: _contentAlign,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: lapisBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: isArabic
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: isArabic
                              ? WrapAlignment.start
                              : WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isSavingAnalysis)
                              _buildStatusChip(
                                tr("جارٍ الحفظ", "Saving"),
                                Icons.save_outlined,
                              ),
                            _buildNewAnalysisButton(compact: true),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: lapisBlue,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.radar,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          tr(
                            "تحليل الأشعة بالذكاء الاصطناعي",
                            "AI X-Ray Analysis",
                          ),
                          textAlign: _contentAlign,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: lapisBlue,
                          ),
                        ),
                      ),
                      if (isSavingAnalysis) ...[
                        _buildStatusChip(
                          tr("جارٍ الحفظ", "Saving"),
                          Icons.save_outlined,
                        ),
                        const SizedBox(width: 10),
                      ],
                      _buildNewAnalysisButton(),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryPanel({bool expandToWidth = false}) {
    final double width =
        expandToWidth ? double.infinity : (isHistoryOpen ? 340.0 : 72.0);

    return Container(
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _panelFill(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isHistoryOpen
          ? _buildOpenedHistory()
          : _buildClosedHistory(isCompact: expandToWidth),
    );
  }

  Widget _buildClosedHistory({bool isCompact = false}) {
    if (isCompact) {
      return Center(
        child: IconButton(
          onPressed: () => setState(() => isHistoryOpen = true),
          tooltip: tr("فتح السجل", "Open history"),
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: lapisBlue,
            size: 24,
          ),
          style: IconButton.styleFrom(
            backgroundColor: lapisBlue.withOpacity(0.08),
            padding: const EdgeInsets.all(16),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        IconButton(
          onPressed: () => setState(() => isHistoryOpen = true),
          icon: const Icon(Icons.chevron_right_rounded, color: lapisBlue),
          style: IconButton.styleFrom(
            backgroundColor: lapisBlue.withOpacity(0.08),
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: lapisBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.history_edu_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }

Widget _buildHistoryDateButton({
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
}) {
  return XRayHistoryDateButton(
    label: label,
    icon: icon,
    onPressed: onPressed,
  );
}

  Widget _buildOpenedHistory() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
          decoration: BoxDecoration(
            color: lapisBlue.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: lapisBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.history_edu_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr("سجل التحليلات", "Analysis History"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: lapisBlue,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  onPressed: () => setState(() => isHistoryOpen = false),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: lapisBlue,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Directionality(
            textDirection: _contentDirection,
            child: Column(
              children: [
                TextField(
                  controller: historySearchController,
                  onChanged: (value) {
                    setState(() {
                      historySearchQuery = value;
                    });
                  },
                  textDirection: _contentDirection,
                  style: TextStyle(color: _textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: tr("ابحث داخل السجل", "Search history"),
                    hintStyle: TextStyle(color: _textSecondary(context)),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: _softFill(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: lapisBlue.withOpacity(0.24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment:
                      isArabic ? WrapAlignment.end : WrapAlignment.start,
                  children: [
                    _buildHistoryDateButton(
                      label:
                          "${tr("من", "From")}: ${_formatShortDate(historyStartDate)}",
                      icon: Icons.date_range_rounded,
                      onPressed: () => _pickHistoryDate(isStart: true),
                    ),
                    _buildHistoryDateButton(
                      label:
                          "${tr("إلى", "To")}: ${_formatShortDate(historyEndDate)}",
                      icon: Icons.event_available_rounded,
                      onPressed: () => _pickHistoryDate(isStart: false),
                    ),
                    if (historyStartDate != null || historyEndDate != null)
                      _buildHistoryDateButton(
                        label: tr("مسح الفلتر", "Clear filter"),
                        icon: Icons.filter_alt_off_rounded,
                        onPressed: () {
                          setState(() {
                            historyStartDate = null;
                            historyEndDate = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
          stream: XRayAnalysisService.watchUserAnalyses(
  username: widget.username,
),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      tr(
                        "تعذر تحميل سجل التحليلات.",
                        "Could not load history.",
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary(context),
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              }

              final docs = List<QueryDocumentSnapshot>.from(
                snapshot.data?.docs ?? const [],
              );

              docs.sort(
                (a, b) => _timestampValue(b).compareTo(_timestampValue(a)),
              );

              final filteredDocs =
                  docs.where(_matchesHistoryFilters).toList(growable: false);

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 52,
                          color: _textSecondary(context),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(
                            "لا يوجد تحليلات محفوظة بعد",
                            "No saved analyses yet",
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 52,
                          color: _textSecondary(context),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(
                            "لا توجد نتائج مطابقة للبحث أو الفلتر",
                            "No matching results for the search or date filter",
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final title =
                      _safeString(data["title"], fallback: "New Analysis");
                  final result = _safeString(data["result"]);
                  final createdAt = _formatDate(data["created_at"]);
                  final isActive = openedHistoryId == doc.id;

                  return InkWell(
                    onTap: () => _openSavedAnalysis(doc),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? lapisBlue.withOpacity(0.08)
                            : _softFill(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive
                              ? lapisBlue.withOpacity(0.45)
                              : _border(context),
                        ),
                      ),
                      child: Directionality(
                        textDirection: _contentDirection,
                        child: Column(
                          crossAxisAlignment: isArabic
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? lapisBlue
                                        : lapisBlue.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: isActive ? Colors.white : lapisBlue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: lapisBlue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: IconButton(
                                    onPressed: () =>
                                        _confirmDeleteAnalysis(doc.id),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    tooltip: tr("حذف", "Delete"),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              result,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: _contentAlign,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _textPrimary(context),
                                height: 1.5,
                              ),
                            ),
                            if (createdAt.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                createdAt,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _textSecondary(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
Widget _buildImageActionButton({
  required VoidCallback? onPressed,
  required IconData icon,
  required String label,
}) {
  return XRayImageActionButton(
    onPressed: onPressed,
    icon: icon,
    label: label,
  );
}
Widget _buildAdjustmentSlider({
  required String label,
  required IconData icon,
  required dynamic value,
  required double min,
  required double max,
  required int divisions,
  required ValueChanged<double> onChanged,
}) {
  return XRayAdjustmentSlider(
    label: label,
    icon: icon,
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    onChanged: onChanged,
    isArabic: isArabic,
    softFill: _softFill(context),
    borderColor: _border(context),
    textSecondary: _textSecondary(context),
  );
}

Widget _buildFindingsOverlay({
  required double imageWidth,
  required double imageHeight,
}) {
  return XRayFindingsOverlay(
    findings: analysisFindings,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

  Widget _buildPreviewImageArea({
    required bool hasImage,
    required double previewHeight,
  }) {
    if (!hasImage) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _pickImage,
        child: Container(
          height: previewHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _previewFill(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 76,
                color: _textSecondary(context),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  tr(
                    "اضغط هنا لاختيار صورة الأشعة",
                    "Click here to select an X-ray image",
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: lapisBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: previewHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _previewFill(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size rawSize = previewImageSize ??
                Size(constraints.maxWidth, constraints.maxHeight);

            final FittedSizes fittedSizes = applyBoxFit(
              BoxFit.contain,
              rawSize,
              Size(constraints.maxWidth, constraints.maxHeight),
            );

            final double renderedWidth = fittedSizes.destination.width;
            final double renderedHeight = fittedSizes.destination.height;

            return InteractiveViewer(
              transformationController: _previewController(),
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Center(
                  child: SizedBox(
                    width: renderedWidth,
                    height: renderedHeight,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        isImageFlipped ? -1 : 1,
                        1,
                        1,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ColorFiltered(
                              colorFilter:
                                  ColorFilter.matrix(_imageAdjustmentMatrix()),
                              child: Image.memory(
                                previewBytes!,
                                fit: BoxFit.fill,
                                width: renderedWidth,
                                height: renderedHeight,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: _buildFindingsOverlay(
                              imageWidth: renderedWidth,
                              imageHeight: renderedHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewControls(bool hasImage, BoxConstraints constraints) {
    final bool isNarrow = constraints.maxWidth < 760;

    if (isNarrow) {
      return Column(
        children: [
          Align(
            alignment:
                isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment:
                  isArabic ? WrapAlignment.end : WrapAlignment.start,
              children: [
                _buildImageActionButton(
                  onPressed: _pickImage,
                  icon: hasImage
                      ? Icons.refresh_rounded
                      : Icons.add_photo_alternate_outlined,
                  label: hasImage
                      ? tr("تغيير الصورة", "Change image")
                      : tr("اختيار صورة", "Choose image"),
                ),
                _buildImageActionButton(
                  onPressed: hasImage
                      ? () {
                          setState(() {
                            isImageFlipped = !isImageFlipped;
                          });
                        }
                      : null,
                  icon: Icons.compare_arrows_rounded,
                  label: tr("عكس الصورة", "Flip image"),
                ),
                _buildImageActionButton(
                  onPressed: hasImage
                      ? () {
                          _resetImageAdjustments();
                        }
                      : null,
                  icon: Icons.restart_alt_rounded,
                  label: tr("إعادة الضبط", "Reset"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildAdjustmentSlider(
            label: tr("الإضاءة", "Brightness"),
            icon: Icons.light_mode_outlined,
            value: imageBrightness,
            min: -0.5,
            max: 0.5,
            divisions: 20,
            onChanged: hasImage
                ? (value) {
                    setState(() {
                      imageBrightness = value;
                    });
                  }
                : (_) {},
          ),
          const SizedBox(height: 10),
          _buildAdjustmentSlider(
            label: tr("التباين", "Contrast"),
            icon: Icons.contrast_rounded,
            value: imageContrast,
            min: 0.6,
            max: 1.8,
            divisions: 24,
            onChanged: hasImage
                ? (value) {
                    setState(() {
                      imageContrast = value;
                    });
                  }
                : (_) {},
          ),
        ],
      );
    }

    return Column(
      children: [
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
            children: [
              _buildImageActionButton(
                onPressed: _pickImage,
                icon: hasImage
                    ? Icons.refresh_rounded
                    : Icons.add_photo_alternate_outlined,
                label: hasImage
                    ? tr("تغيير الصورة", "Change image")
                    : tr("اختيار صورة", "Choose image"),
              ),
              _buildImageActionButton(
                onPressed: hasImage
                    ? () {
                        setState(() {
                          isImageFlipped = !isImageFlipped;
                        });
                      }
                    : null,
                icon: Icons.compare_arrows_rounded,
                label: tr("عكس الصورة", "Flip image"),
              ),
              _buildImageActionButton(
                onPressed: hasImage
                    ? () {
                        _resetImageAdjustments();
                      }
                    : null,
                icon: Icons.restart_alt_rounded,
                label: tr("إعادة الضبط", "Reset"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAdjustmentSlider(
                label: tr("الإضاءة", "Brightness"),
                icon: Icons.light_mode_outlined,
                value: imageBrightness,
                min: -0.5,
                max: 0.5,
                divisions: 20,
                onChanged: hasImage
                    ? (value) {
                        setState(() {
                          imageBrightness = value;
                        });
                      }
                    : (_) {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAdjustmentSlider(
                label: tr("التباين", "Contrast"),
                icon: Icons.contrast_rounded,
                value: imageContrast,
                min: 0.6,
                max: 1.8,
                divisions: 24,
                onChanged: hasImage
                    ? (value) {
                        setState(() {
                          imageContrast = value;
                        });
                      }
                    : (_) {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 560;
        final bool hasImage = previewBytes != null;

        final double previewHeight = constraints.maxWidth < 420
            ? 260
            : constraints.maxWidth < 620
                ? 320
                : constraints.maxHeight < 760
                    ? 300
                    : 420;

        return Container(
          decoration: BoxDecoration(
            color: _panelFill(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Directionality(
                    textDirection: _contentDirection,
                    child: isCompact
                        ? Column(
                            crossAxisAlignment: isArabic
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr("معاينة صورة الأشعة", "X-Ray Preview"),
                                textAlign: _contentAlign,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: lapisBlue,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: isArabic
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: _buildStatusChip(
                                  hasImage
                                      ? tr("تم تحميل صورة", "Image loaded")
                                      : tr("بانتظار صورة", "Waiting for image"),
                                  hasImage
                                      ? Icons.check_circle_outline
                                      : Icons.image_outlined,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr("معاينة صورة الأشعة", "X-Ray Preview"),
                                  textAlign: _contentAlign,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: lapisBlue,
                                  ),
                                ),
                              ),
                              _buildStatusChip(
                                hasImage
                                    ? tr("تم تحميل صورة", "Image loaded")
                                    : tr("بانتظار صورة", "Waiting for image"),
                                hasImage
                                    ? Icons.check_circle_outline
                                    : Icons.image_outlined,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewImageArea(
                    hasImage: hasImage,
                    previewHeight: previewHeight,
                  ),
                  const SizedBox(height: 14),
                  _buildPreviewControls(hasImage, constraints),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (selectedImage != null && !isAnalyzing)
                              ? _analyzeXRay
                              : null,
                          icon: isAnalyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.psychology_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                          label: Text(
                            isAnalyzing
                                ? tr("جاري التحليل...", "Analyzing...")
                                : (selectedImage != null && aiResult != null)
                                    ? tr("إعادة التحليل", "Re-run Analysis")
                                    : tr("بدء التحليل", "Start Analysis"),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultActions() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildStatusChip(
            aiResult == null
                ? tr("لا توجد نتيجة", "No result")
                : tr("تم التحليل", "Analyzed"),
            aiResult == null ? Icons.pending_outlined : Icons.task_alt,
          ),
          if (aiConfidenceLevel != null) _buildConfidenceChip(aiConfidenceLevel!),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 680;

        return Container(
          decoration: BoxDecoration(
            color: _panelFill(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Directionality(
              textDirection: _contentDirection,
              child: Column(
                crossAxisAlignment:
                    isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isCompact)
                    Column(
                      crossAxisAlignment:
                          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment:
                                    isArabic ? Alignment.centerRight : Alignment.centerLeft,
                                child: Text(
                                  currentAnalysisTitle ??
                                      tr("التقرير التشخيصي", "Diagnostic Report"),
                                  textAlign: _contentAlign,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: lapisBlue,
                                  ),
                                ),
                              ),
                            ),
                            if (openedHistoryId != null) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: IconButton(
                                  onPressed: () => _confirmDeleteAnalysis(openedHistoryId!),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  tooltip: tr("حذف", "Delete"),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildResultActions(),
                        ),
                      ],
                    )
                  else
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildResultActions(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentAnalysisTitle ??
                                          tr("التقرير التشخيصي", "Diagnostic Report"),
                                      textAlign: _contentAlign,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: lapisBlue,
                                      ),
                                    ),
                                  ),
                                  if (openedHistoryId != null) ...[
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: IconButton(
                                        onPressed: () =>
                                            _confirmDeleteAnalysis(openedHistoryId!),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        tooltip: tr("حذف", "Delete"),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: _border(context),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: aiResult == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.psychology_alt_outlined,
                                  size: 70,
                                  color: _textSecondary(context),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  tr(
                                    "بانتظار بدء التحليل",
                                    "Waiting for analysis",
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: lapisBlue,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Text(
                              aiResult!,
                              textAlign: _contentAlign,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.9,
                                color: _textPrimary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                  if (aiResult != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withOpacity(0.12)),
                      ),
                      child: Text(
                        tr(
                          "⚠️ هذا التقرير استرشادي فقط، والقرار النهائي للطبيب.",
                          "⚠️ This report is for guidance only. The final decision belongs to the dentist.",
                        ),
                        textAlign: _contentAlign,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryPanel(),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(),
                const SizedBox(height: 22),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPreviewCard()),
                      const SizedBox(width: 22),
                      Expanded(child: _buildResultCard()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    final double historyHeight = isHistoryOpen ? 340 : 90;

    return Column(
      children: [
        _buildTopHeader(),
        const SizedBox(height: 20),
        SizedBox(
          height: historyHeight,
          child: _buildHistoryPanel(expandToWidth: true),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPreviewCard()),
              const SizedBox(width: 20),
              Expanded(child: _buildResultCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final double historyHeight = isHistoryOpen ? 340 : 90;

    return Column(
      children: [
        _buildTopHeader(),
        const SizedBox(height: 20),
        SizedBox(
          height: historyHeight,
          child: _buildHistoryPanel(expandToWidth: true),
        ),
        const SizedBox(height: 20),
        _buildPreviewCard(),
        const SizedBox(height: 20),
        SizedBox(height: 520, child: _buildResultCard()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 2,
      searchController: searchController,
      onSearchChanged: (_) {},
      onLanguageChanged: (val) {
        setState(() {
          isArabic = val;
        });
      },
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double pagePadding = constraints.maxWidth < 700 ? 16 : 24;

          return Padding(
            padding: EdgeInsets.all(pagePadding),
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                if (innerConstraints.maxWidth >= 1500) {
                  return _buildDesktopLayout();
                }

                if (innerConstraints.maxWidth >= 1050) {
                  return _buildTabletLayout();
                }

                return SingleChildScrollView(
                  child: _buildMobileLayout(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
