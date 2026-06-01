import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'patient_account_utils.dart';

class PatientAccountAiUtils {
  const PatientAccountAiUtils._();

  static String analysisPrompt(bool isArabic) {
    return isArabic
        ? '''
أنت مساعد خبير لطبيب أسنان داخل نظام إدارة عيادة.
حلل ملف المريض بناءً على البيانات السريرية والمالية الموجودة فقط.

أعد الرد بصيغة JSON فقط بدون markdown وبدون أي نص إضافي.
ممنوع استخدام النجوم * أو التعداد markdown أو أي زخرفة نصية.

الشكل المطلوب:
{
  "title": "عنوان مختصر للتحليل",
  "confidence": "mid",
  "introduction": "مقدمة قصيرة ولطيفة توضح حالة الملف بشكل عام",
  "summary": "ملخص واضح ومنظم لحالة المريض الحالية",
  "clinicalNotes": [
    "ملاحظة سريرية 1",
    "ملاحظة سريرية 2"
  ],
  "futureTreatmentPlan": [
    {
      "phase": "المرحلة الأولى",
      "priority": "high",
      "goal": "هدف المرحلة",
      "steps": [
        "خطوة علاجية 1",
        "خطوة علاجية 2"
      ]
    }
  ],
  "homeCare": [
    "نصيحة منزلية 1",
    "نصيحة منزلية 2"
  ],
  "financialNotes": [
    "ملاحظة مالية 1"
  ],
  "questionsForDentist": [
    "سؤال مهم للطبيب 1"
  ],
  "finalRecommendation": "توصية ختامية واضحة ومهنية"
}

القواعد:
- confidence واحدة فقط من: high أو mid أو low.
- priority واحدة فقط من: high أو mid أو low.
- لا تعطي تشخيصًا نهائيًا.
- لا تخترع معلومات غير موجودة.
- إذا البيانات ناقصة، اذكر أن الخطة تحتاج فحصًا سريريًا وصورًا شعاعية.
- ركز على خطة علاجية مستقبلية واقعية ومنطقية للمريض.
- اجعل الأسلوب مهنيًا وواضحًا وسهل القراءة.
- كل خطوة علاجية تكون جملة قصيرة واضحة.
- لا تستخدم النجوم * ولا markdown.
- أختم بأن التحليل استرشادي فقط وأن القرار النهائي للطبيب بعد الفحص السريري والصور الشعاعية.
'''
        : '''
You are an expert dental assistant inside a dental clinic management system.
Analyze the patient file based only on the provided clinical and financial data.

Return JSON only with no markdown and no extra text.
Do not use asterisks * or markdown bullets.

Required structure:
{
  "title": "Short analysis title",
  "confidence": "mid",
  "introduction": "A short and polished introduction for the dentist",
  "summary": "Clear and organized patient summary",
  "clinicalNotes": [
    "Clinical note 1",
    "Clinical note 2"
  ],
  "futureTreatmentPlan": [
    {
      "phase": "Phase 1",
      "priority": "high",
      "goal": "Goal of this phase",
      "steps": [
        "Treatment step 1",
        "Treatment step 2"
      ]
    }
  ],
  "homeCare": [
    "Home care tip 1",
    "Home care tip 2"
  ],
  "financialNotes": [
    "Financial note 1"
  ],
  "questionsForDentist": [
    "Important question for the dentist 1"
  ],
  "finalRecommendation": "Clear professional final recommendation"
}

Rules:
- confidence must be exactly one of: high, mid, low.
- priority must be exactly one of: high, mid, low.
- Do not provide a final diagnosis.
- Do not invent missing information.
- If data is incomplete, clearly state that clinical examination and X-rays are required.
- Focus on a realistic future treatment plan for the patient.
- Keep the writing professional, clear, and easy to read.
- Each treatment step should be concise.
- Do not use asterisks or markdown.
- End by stating that this analysis is for guidance only and the final decision belongs to the dentist after clinical and radiographic evaluation.
''';
  }

  static Map<String, dynamic> buildPayload({
    required bool isArabic,
    required String patientId,
    required String patientName,
    required Map<String, dynamic> patientData,
    required List<QueryDocumentSnapshot> treatmentDocs,
    required List<QueryDocumentSnapshot> paymentDocs,
  }) {
    final treatments = treatmentDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final price = PatientAccountUtils.toDouble(data['price']);
      final discount = PatientAccountUtils.toDouble(data['discount']);
      final quantity = _quantityValue(data['quantity']);

      return <String, dynamic>{
        'date': PatientAccountUtils.formatDate(data['date']),
        'category': data['category']?.toString() ?? '',
        'treatmentName': data['treatmentName']?.toString() ?? '',
        'detail': data['detail']?.toString() ?? '',
        'toothId': data['toothId']?.toString() ?? '',
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'total': (price * quantity) - discount,
      };
    }).toList(growable: false);

    final payments = paymentDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return <String, dynamic>{
        'date': PatientAccountUtils.formatDate(data['date']),
        'amount': PatientAccountUtils.toDouble(data['amount']),
        'discount': PatientAccountUtils.toDouble(data['discount']),
        'method': data['method']?.toString() ?? '',
        'note': data['note']?.toString() ?? '',
      };
    }).toList(growable: false);

    return <String, dynamic>{
      'language': isArabic ? 'ar' : 'en',
      'patient': <String, dynamic>{
        'patientId': patientId,
        'patientName': patientName,
        'fileNumber': patientData['file_number']?.toString() ?? patientId,
        'phone': patientData['phone']?.toString() ?? '',
        'gender': patientData['gender']?.toString() ?? '',
        'birthDate': PatientAccountUtils.formatDate(patientData['birth_date']),
        'alert': patientData['alert']?.toString() ?? '',
        'requiredAmount': PatientAccountUtils.toDouble(patientData['required_amount']),
        'discount': PatientAccountUtils.toDouble(patientData['discount']),
        'paidAmount': PatientAccountUtils.toDouble(patientData['paid_amount']),
        'remainingAmount': PatientAccountUtils.toDouble(patientData['remaining_amount']),
      },
      'treatments': treatments,
      'payments': payments,
    };
  }

  static double _quantityValue(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 1.0;
  }

  static Map<String, dynamic>? parseJson(String rawText) {
    try {
      var cleaned = rawText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll('```json', '')
            .replaceAll('```JSON', '')
            .replaceAll('```', '')
            .trim();
      }

      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  static String safeText(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? normalizeConfidence(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == 'high' || text == 'mid' || text == 'low') return text;
    return null;
  }

  static String friendlyErrorMessage({
    required Object error,
    required bool isArabic,
  }) {
    final message = error.toString().toLowerCase();

    if (message.contains('api key') ||
        message.contains('api_key') ||
        message.contains('invalid_argument') ||
        message.contains('400') ||
        message.contains('permission') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('403')) {
      return PatientAccountUtils.tr(
        isArabic,
        'تعذر الاتصال بخدمة الذكاء الاصطناعي. تأكد من Gemini API Key.',
        'Could not connect to the AI service. Please check the Gemini API Key.',
      );
    }

    if (message.contains('503') ||
        message.contains('unavailable') ||
        message.contains('overloaded') ||
        message.contains('high demand')) {
      return PatientAccountUtils.tr(
        isArabic,
        'خدمة الذكاء الاصطناعي مشغولة حاليًا. حاول مرة أخرى بعد قليل.',
        'The AI service is currently busy. Please try again shortly.',
      );
    }

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('timeout') ||
        message.contains('connection')) {
      return PatientAccountUtils.tr(
        isArabic,
        'حدثت مشكلة اتصال أثناء تحليل ملف المريض. تحقق من الإنترنت ثم حاول مجددًا.',
        'A connection problem occurred while analyzing the patient file. Check the internet and try again.',
      );
    }

    return PatientAccountUtils.tr(
      isArabic,
      'تعذر تحليل ملف المريض. حاول مرة أخرى.',
      'Could not analyze the patient file. Please try again.',
    );
  }

  static bool isGeminiApiKeyLooksValid(String key) {
    final cleanKey = key.trim();

    return cleanKey.isNotEmpty &&
        !cleanKey.contains('PUT_YOUR') &&
        (cleanKey.startsWith('AIza') || cleanKey.startsWith('AQ.'));
  }
}
