import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
    if (_isGeminiRequestRunning) {
      throw Exception(
        "analysis_in_progress: An analysis request is already running.",
      );
    }

    _isGeminiRequestRunning = true;

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.2,
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 900,
        ),
      );

      final mimeType = _safeMimeType(imagePath);

      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]).timeout(const Duration(seconds: 45));

      final text = (response.text ?? '').trim();

      if (text.isEmpty) {
        throw Exception("empty_response: Empty response from Gemini.");
      }

      return text;
    } on TimeoutException {
      throw Exception("timeout: Gemini request took too long.");
    } catch (e) {
      final message = e.toString().toLowerCase();

      if (message.contains("429") ||
          message.contains("too many requests") ||
          message.contains("quota") ||
          message.contains("rate limit") ||
          message.contains("resource exhausted")) {
        throw Exception(
          "429 Too Many Requests: Gemini quota or rate limit exceeded.",
        );
      }

      if (message.contains("503") ||
          message.contains("service unavailable") ||
          message.contains("unavailable") ||
          message.contains("overloaded")) {
        throw Exception(
          "503 Service Unavailable: Gemini is temporarily busy.",
        );
      }

      if (message.contains("403") ||
          message.contains("forbidden") ||
          message.contains("permission") ||
          message.contains("unauthorized") ||
          message.contains("api key")) {
        throw Exception(
          "403 Forbidden: API key is invalid, restricted, or not allowed.",
        );
      }

      rethrow;
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