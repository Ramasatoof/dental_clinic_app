import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientAccountUtils {
  const PatientAccountUtils._();

  static String tr(bool isArabic, String ar, String en) => isArabic ? ar : en;

  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static String formatDate(dynamic raw, {String pattern = 'yyyy/MM/dd'}) {
    if (raw is Timestamp) return DateFormat(pattern).format(raw.toDate());
    if (raw is DateTime) return DateFormat(pattern).format(raw);
    return raw?.toString() ?? '';
  }

  static String genderSymbol(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final value = raw.trim().toLowerCase();
    if (value == 'ذكر' || value == 'male' || value == 'm') return 'M';
    if (value == 'أنثى' || value == 'انثى' || value == 'female' || value == 'f') return 'F';
    return raw.toUpperCase().substring(0, 1);
  }

  static int calculateAge(dynamic raw) {
    DateTime? birthDate;
    if (raw is Timestamp) birthDate = raw.toDate();
    if (raw is DateTime) birthDate = raw;
    if (birthDate == null) return 0;

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static List<QueryDocumentSnapshot> sortedDocs(List<QueryDocumentSnapshot> docs) {
    return List<QueryDocumentSnapshot>.from(docs)
      ..sort((a, b) {
        final tA = (a.data() as Map)['date'];
        final tB = (b.data() as Map)['date'];
        if (tA is! Timestamp) return -1;
        if (tB is! Timestamp) return 1;
        return tB.compareTo(tA);
      });
  }

  static String paymentMethodLabel({required bool isArabic, required String method}) {
    if (method == 'كاش') return tr(isArabic, 'كاش', 'Cash');
    if (method == 'بطاقة') return tr(isArabic, 'بطاقة', 'Card');
    if (method == 'Cash') return tr(isArabic, 'كاش', 'Cash');
    if (method == 'Card') return tr(isArabic, 'بطاقة', 'Card');
    return method;
  }

  static String safeFilePart(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  static String exportFileName({
    required String patientName,
    required String extension,
  }) {
    final safeName = safeFilePart(patientName.isEmpty ? 'patient' : patientName);
    final date = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${safeName}_patient_account_$date.$extension';
  }
}
