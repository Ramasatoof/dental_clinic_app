import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class PatientAiAnalysisService {
  static const String _modelName = 'gemini-2.5-flash-lite';
  static bool _isPatientAiRequestRunning = false;

  static Future<String> analyzePatientFileWithGemini({
    required String apiKey,
    required String prompt,
    required Map<String, dynamic> patientPayload,
  }) async {
    final cleanKey = apiKey.trim();

    if (cleanKey.isEmpty) {
      throw Exception('401 Missing Gemini API key.');
    }

    if (_isPatientAiRequestRunning) {
      throw Exception(
        'analysis_in_progress: Patient AI analysis already running.',
      );
    }

    _isPatientAiRequestRunning = true;

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent',
      );

      final fullPrompt = '''
$prompt

Patient file data JSON:
${jsonEncode(patientPayload)}
''';

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': cleanKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': fullPrompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.25,
                'topP': 0.85,
                'topK': 20,
                'maxOutputTokens': 1800,
              },
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwFriendlyGeminiError(response);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        throw Exception('No Gemini response candidates.');
      }

      final firstCandidate = candidates.first;
      if (firstCandidate is! Map) {
        throw Exception('Invalid Gemini response candidate.');
      }

      final content = firstCandidate['content'];
      if (content is! Map) {
        throw Exception('Invalid Gemini response content.');
      }

      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        throw Exception('Invalid Gemini response parts.');
      }

      final firstPart = parts.first;
      if (firstPart is! Map) {
        throw Exception('Invalid Gemini response part.');
      }

      final text = firstPart['text']?.toString().trim() ?? '';

      if (text.isEmpty) {
        throw Exception('Empty Gemini response text.');
      }

      return text;
    } on TimeoutException {
      throw Exception('timeout: Gemini patient analysis request took too long.');
    } finally {
      _isPatientAiRequestRunning = false;
    }
  }

  static Never _throwFriendlyGeminiError(http.Response response) {
    final body = response.body.toLowerCase();

    if (response.statusCode == 401) {
      throw Exception(
        '401 Unauthorized: Invalid Gemini API key or unsupported credential type.',
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        '403 Forbidden: API key is restricted, disabled, or Generative Language API is not allowed.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        '404 Not Found: Gemini model $_modelName is not available for this key/project.',
      );
    }

    if (response.statusCode == 429 ||
        body.contains('too many requests') ||
        body.contains('quota') ||
        body.contains('rate limit') ||
        body.contains('resource exhausted')) {
      throw Exception(
        '429 Too Many Requests: Gemini quota or rate limit exceeded.',
      );
    }

    if (response.statusCode == 503 ||
        body.contains('service unavailable') ||
        body.contains('unavailable') ||
        body.contains('overloaded')) {
      throw Exception(
        '503 Service Unavailable: Gemini is temporarily busy.',
      );
    }

    throw Exception(
      'Gemini request failed: ${response.statusCode} ${response.body}',
    );
  }

  static Future<String> saveAnalysis({
    required String patientId,
    required String patientName,
    required String title,
    required String resultText,
    required String? confidenceLevel,
    required Map<String, dynamic>? structuredResult,
    required Map<String, dynamic> payload,
    required String username,
    required String language,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('patient_ai_analyses')
        .add({
      'patientId': patientId,
      'patientName': patientName,
      'title': title,
      'result': resultText,
      'confidence': confidenceLevel,
      'structuredResult': structuredResult,
      'payload': payload,
      'createdBy': username,
      'language': language,
      'created_at': Timestamp.now(),
    });

    return doc.id;
  }

  static Stream<QuerySnapshot> watchPatientAnalyses({
    required String patientId,
  }) {
    return FirebaseFirestore.instance
        .collection('patient_ai_analyses')
        .where('patientId', isEqualTo: patientId)
        .snapshots();
  }

  static Future<void> deleteAnalysis(String docId) {
    return FirebaseFirestore.instance
        .collection('patient_ai_analyses')
        .doc(docId)
        .delete();
  }
}