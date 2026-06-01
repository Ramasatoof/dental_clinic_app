import 'package:cloud_firestore/cloud_firestore.dart';

class StatsService {
  static final CollectionReference<Map<String, dynamic>> _patients =
      FirebaseFirestore.instance.collection('patients');

  static final CollectionReference<Map<String, dynamic>> _materials =
      FirebaseFirestore.instance.collection('materials');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchPatientsByLastVisit({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _patients
        .where(
          'last_visit',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where(
          'last_visit',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        )
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMaterials() {
    return _materials.snapshots();
  }
}