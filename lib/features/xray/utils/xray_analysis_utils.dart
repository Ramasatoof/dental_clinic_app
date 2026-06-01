import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class XRayAnalysisUtils {
  static String safeString(dynamic value, {String fallback = ''}) {
    try {
      if (value == null) return fallback;
      final text = value.toString();
      if (text == 'null' || text == 'undefined') return fallback;
      return text;
    } catch (_) {
      return fallback;
    }
  }

  static String safeTrimmedString(dynamic value, {String fallback = ''}) {
    return safeString(value, fallback: fallback).trim();
  }

  static String safeFixed(dynamic value, {int fractionDigits = 2}) {
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isNaN || parsed.isInfinite) return "0.00";
      return parsed.toStringAsFixed(fractionDigits);
    }
    return "0.00";
  }

  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(safeString(value)) ?? 0.0;
  }

  static String formatDate(dynamic ts) {
    if (ts is! Timestamp) return "";

    final d = ts.toDate();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');

    return "${d.year}-$month-$day  $hour:$minute";
  }

  static String formatShortDate({
    required DateTime? date,
    required String fallback,
  }) {
    if (date == null) return fallback;

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return "${date.year}-$month-$day";
  }

  static int timestampValue(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data["created_at"];

      if (ts is Timestamp) return ts.millisecondsSinceEpoch;

      return 0;
    } catch (_) {
      return 0;
    }
  }

  static String generateSuggestedTitle({
    required String resultText,
    required bool isArabic,
  }) {
    final text = resultText.toLowerCase();

    if (text.contains("تسوس")) return "اشتباه تسوس";
    if (text.contains("التهاب")) return "اشتباه التهاب";
    if (text.contains("كسر")) return "اشتباه كسر";
    if (text.contains("خراج")) return "اشتباه خراج";
    if (text.contains("عصب")) return "اشتباه مشكلة بالعصب";

    if (text.contains("سليم") ||
        text.contains("سليمة") ||
        text.contains("طبيعية")) {
      return "فحص سليم";
    }

    if (text.contains("caries") || text.contains("decay")) {
      return "Possible Caries";
    }

    if (text.contains("inflammation")) return "Possible Inflammation";
    if (text.contains("fracture")) return "Possible Fracture";
    if (text.contains("abscess")) return "Possible Abscess";
    if (text.contains("root")) return "Possible Root Issue";

    if (text.contains("healthy") || text.contains("normal")) {
      return "Normal Scan";
    }

    return isArabic ? "تحليل أشعة جديد" : "New X-Ray Analysis";
  }

  static String cleanAnalysisReportText(String text) {
    var cleaned = safeString(text).trim();

    cleaned = cleaned
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll(RegExp(r'^\s*[#]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[\*•-]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
        .trim();

    return cleaned;
  }

  static String formatAnalysisReportForDisplay({
    required String text,
    required bool isArabic,
  }) {
    var formatted = cleanAnalysisReportText(text);
    if (formatted.isEmpty) return formatted;

    final hasIntro = isArabic
        ? formatted.contains('يظهر تحليل صورة الأشعة')
        : formatted.toLowerCase().contains('this x-ray analysis');

    if (!hasIntro) {
      final intro = isArabic
          ? 'يظهر تحليل صورة الأشعة وجود ملاحظات سنية تحتاج إلى تقييم سريري من الطبيب، وتم ترتيب النتيجة أدناه لتسهيل قراءة الحالة ومراجعة النقاط المهمة.'
          : 'This X-ray analysis highlights dental observations that should be reviewed clinically by the dentist. The findings are organized below to make the case easier to read and follow.';

      formatted = '$intro\n\n$formatted';
    }

    formatted = formatted
        .replaceAll(r'\n', '\n')
        .replaceAll('مقدمة:', '')
        .replaceAll('Introduction:', '')
        .replaceAll('النتائج:', '\nالنتائج:')
        .replaceAll('الفك العلوي:', '\nالفك العلوي:')
        .replaceAll('الفك السفلي:', '\nالفك السفلي:')
        .replaceAll('التوصية:', '\nالتوصية:')
        .replaceAll('Findings:', '\nFindings:')
        .replaceAll('Upper Jaw:', '\nUpper Jaw:')
        .replaceAll('Lower Jaw:', '\nLower Jaw:')
        .replaceAll('Recommendation:', '\nRecommendation:')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return formatted;
  }

  static String extractJsonPayload(String text) {
    final fencedMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);

    if (fencedMatch != null && fencedMatch.groupCount >= 1) {
      return safeTrimmedString(fencedMatch.group(1));
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');

    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1).trim();
    }

    return text.trim();
  }

  static String? normalizeConfidence(dynamic value) {
    final text = safeTrimmedString(value).toLowerCase();

    if (text.isEmpty) return null;

    if (text.contains("high") ||
        text.contains("مرتفع") ||
        text.contains("عالية")) {
      return "high";
    }

    if (text.contains("mid") ||
        text.contains("medium") ||
        text.contains("متوسط") ||
        text.contains("متوسطة")) {
      return "mid";
    }

    if (text.contains("low") ||
        text.contains("منخفض") ||
        text.contains("منخفضة")) {
      return "low";
    }

    return null;
  }

  static String? extractConfidenceFromText(String text) {
    final lower = text.toLowerCase();

    if (lower.contains("confidence: high") ||
        lower.contains("الثقة: high") ||
        lower.contains("ثقة عالية") ||
        lower.contains("high confidence")) {
      return "high";
    }

    if (lower.contains("confidence: mid") ||
        lower.contains("confidence: medium") ||
        lower.contains("الثقة: mid") ||
        lower.contains("ثقة متوسطة") ||
        lower.contains("medium confidence")) {
      return "mid";
    }

    if (lower.contains("confidence: low") ||
        lower.contains("الثقة: low") ||
        lower.contains("ثقة منخفضة") ||
        lower.contains("low confidence")) {
      return "low";
    }

    return null;
  }

  static List<Map<String, dynamic>> normalizeFindings(dynamic rawFindings) {
    if (rawFindings is! List) return [];

    final List<Map<String, dynamic>> result = [];

    for (final item in rawFindings) {
      if (item is! Map) continue;

      final label = safeTrimmedString(item["label"]);
      final x = toDouble(item["x"]);
      final y = toDouble(item["y"]);
      final width = toDouble(item["width"]);
      final height = toDouble(item["height"]);

      if (width <= 0 || height <= 0) continue;

      result.add({
        "label": label,
        "x": x.clamp(0, 1000),
        "y": y.clamp(0, 1000),
        "width": width.clamp(1, 1000),
        "height": height.clamp(1, 1000),
      });
    }

    return result;
  }

  static Map<String, dynamic>? parseStructuredAnalysis(String rawText) {
    try {
      final payload = extractJsonPayload(rawText);
      final decoded = jsonDecode(payload);

      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);

      return {
        "title": safeTrimmedString(map["title"]),
        "confidence": normalizeConfidence(map["confidence"]),
        "report": safeTrimmedString(map["report"]),
        "findings": normalizeFindings(map["findings"]),
      };
    } catch (_) {
      return null;
    }
  }

  static bool matchesHistoryFilters({
    required QueryDocumentSnapshot doc,
    required String searchQuery,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    final title = safeString(data["title"]).toLowerCase();
    final result = safeString(data["result"]).toLowerCase();
    final query = safeString(searchQuery).trim().toLowerCase();

    if (query.isNotEmpty && !title.contains(query) && !result.contains(query)) {
      return false;
    }

    final createdAt = data["created_at"];

    if (createdAt is Timestamp) {
      final dateOnly = DateTime(
        createdAt.toDate().year,
        createdAt.toDate().month,
        createdAt.toDate().day,
      );

      if (startDate != null) {
        final startOnly = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );

        if (dateOnly.isBefore(startOnly)) return false;
      }

      if (endDate != null) {
        final endOnly = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        );

        if (dateOnly.isAfter(endOnly)) return false;
      }
    }

    return true;
  }
}