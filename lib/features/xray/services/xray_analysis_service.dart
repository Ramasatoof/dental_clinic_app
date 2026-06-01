import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class XRayAnalysisService {
  static final CollectionReference<Map<String, dynamic>> _xrays =
      FirebaseFirestore.instance.collection("xrays");

  static const String _modelName = 'gemini-2.5-flash-lite';
  static bool _isGeminiRequestRunning = false;

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchUserAnalyses({
    required String username,
  }) {
    return _xrays.where("username", isEqualTo: username).snapshots();
  }

  static Future<String> analyzeImageWithGemini({
    required String apiKey,
    required String prompt,
    required Uint8List imageBytes,
    required String imagePath,
  }) async {
    final cleanKey = apiKey.trim();

    if (cleanKey.isEmpty) {
      throw Exception("401 Missing Gemini API key.");
    }

    if (_isGeminiRequestRunning) {
      throw Exception("analysis_in_progress: X-ray analysis already running.");
    }

    _isGeminiRequestRunning = true;

    try {
      final mimeType = _safeMimeType(imagePath);
      final base64Image = base64Encode(imageBytes);

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent',
      );

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
                    {'text': prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Image,
                      },
                    },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'topP': 0.85,
                'topK': 20,
                'maxOutputTokens': 1200,
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
        throw Exception("No Gemini response candidates.");
      }

      final firstCandidate = candidates.first;
      if (firstCandidate is! Map) {
        throw Exception("Invalid Gemini response candidate.");
      }

      final content = firstCandidate['content'];
      if (content is! Map) {
        throw Exception("Invalid Gemini response content.");
      }

      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        throw Exception("Invalid Gemini response parts.");
      }

      final firstPart = parts.first;
      if (firstPart is! Map) {
        throw Exception("Invalid Gemini response part.");
      }

      final text = firstPart['text']?.toString().trim() ?? '';

      if (text.isEmpty) {
        throw Exception("Empty Gemini response text.");
      }

      return text;
    } on TimeoutException {
      throw Exception("timeout: Gemini request took too long.");
    } finally {
      _isGeminiRequestRunning = false;
    }
  }

  static String _safeMimeType(String imagePath) {
    final detected = lookupMimeType(imagePath);

    if (detected == null || !detected.startsWith('image/')) {
      return 'image/jpeg';
    }

    return detected;
  }

  static Never _throwFriendlyGeminiError(http.Response response) {
    final body = response.body.toLowerCase();

    if (response.statusCode == 401) {
      throw Exception(
        "401 Unauthorized: Invalid Gemini API key or unsupported credential type.",
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        "403 Forbidden: API key is restricted, disabled, or not allowed for Generative Language API.",
      );
    }

    if (response.statusCode == 404) {
      throw Exception(
        "404 Not Found: Gemini model $_modelName is not available for this key/project.",
      );
    }

    if (response.statusCode == 429 ||
        body.contains("too many requests") ||
        body.contains("quota") ||
        body.contains("rate limit") ||
        body.contains("resource exhausted")) {
      throw Exception(
        "429 Too Many Requests: Gemini quota or rate limit exceeded.",
      );
    }

    if (response.statusCode == 503 ||
        body.contains("service unavailable") ||
        body.contains("unavailable") ||
        body.contains("overloaded")) {
      throw Exception(
        "503 Service Unavailable: Gemini is temporarily busy.",
      );
    }

    throw Exception(
      "Gemini request failed: ${response.statusCode} ${response.body}",
    );
  }

  static Future<String> saveAnalysis({
    required String title,
    required String resultText,
    required String? confidenceLevel,
    required List<Map<String, dynamic>> findings,
    required String username,
    required String language,
  }) async {
    final docRef = _xrays.doc();

    await docRef.set({
      "title": title,
      "result": resultText,
      "confidence": confidenceLevel,
      "findings": findings,
      "username": username,
      "language": language,
      "patient_id": "",
      "patient_name": "",
      "status": "saved",
      "created_at": Timestamp.now(),
    });

    return docRef.id;
  }

  static Future<void> deleteAnalysis(String docId) async {
    await _xrays.doc(docId).delete();
  }
}