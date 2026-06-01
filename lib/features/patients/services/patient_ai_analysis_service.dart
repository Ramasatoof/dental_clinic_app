import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class PatientAiAnalysisService {
  static Future<String> analyzePatientFileWithGemini({
    required String apiKey,
    required String prompt,
    required Map<String, dynamic> patientPayload,
  }) async {
 final uri = Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
);

    final fullPrompt = '''
$prompt

Patient file data JSON:
${jsonEncode(patientPayload)}
''';

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
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
          'temperature': 0.35,
          'topP': 0.9,
          'maxOutputTokens': 4096,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Gemini request failed: ${response.statusCode} ${response.body}',
      );
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

    return firstPart['text']?.toString() ?? '';
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
