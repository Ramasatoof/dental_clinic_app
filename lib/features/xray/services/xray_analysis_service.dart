import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mime/mime.dart';

class XRayAnalysisService {
  static final CollectionReference<Map<String, dynamic>> _xrays =
      FirebaseFirestore.instance.collection("xrays");

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
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    final mimeType = lookupMimeType(imagePath) ?? 'image/jpeg';

    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, imageBytes),
      ]),
    ]);

    return response.text ?? '';
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