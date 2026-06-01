import 'package:cloud_firestore/cloud_firestore.dart';

class PatientsService {
  static final CollectionReference<Map<String, dynamic>> _patients =
      FirebaseFirestore.instance.collection('patients');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchPatients() {
    return _patients.snapshots();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getPatients() {
    return _patients.get();
  }

  static Future<DocumentReference<Map<String, dynamic>>> addPatient(
    Map<String, dynamic> data,
  ) {
    return _patients.add(data);
  }

  static Future<void> updatePatient(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _patients.doc(docId).update(data);
  }

  static Future<void> deletePatient(String docId) {
    return _patients.doc(docId).delete();
  }

  static Future<void> updatePatientField({
    required String docId,
    required String field,
    required dynamic value,
  }) {
    return _patients.doc(docId).update({field: value});
  }

  static Future<int> nextPatientSerialNumber() async {
    final snapshot = await _patients.get();

    int maxSerial = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final current =
          int.tryParse((data['serial_number'] ?? '').toString().trim()) ?? 0;

      if (current > maxSerial) {
        maxSerial = current;
      }
    }

    return maxSerial + 1;
  }

  static Future<bool> serialNumberExists(
    String serial, {
    String? excludePatientDocId,
  }) async {
    final snapshot = await _patients.get();

    for (final doc in snapshot.docs) {
      if (excludePatientDocId != null && doc.id == excludePatientDocId) {
        continue;
      }

      final data = doc.data();
      final currentSerial = (data['serial_number'] ?? '').toString().trim();

      if (currentSerial == serial.trim()) {
        return true;
      }
    }

    return false;
  }
}