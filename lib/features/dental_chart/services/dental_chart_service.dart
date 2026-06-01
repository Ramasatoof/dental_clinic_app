import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  Future<List<Map<String, dynamic>>> getPatientDentalChart(String patientId) async {
    final query = await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('dental_chart')
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  Future<void> saveToothVisualState(
      String patientId, int toothId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('dental_chart')
        .doc(toothId.toString())
        .set(data, SetOptions(merge: true));
  }
}
