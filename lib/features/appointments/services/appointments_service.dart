import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentsService {
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchTodayAppointments() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  return _appointments
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .snapshots();
}
  static final CollectionReference<Map<String, dynamic>> _appointments =
      FirebaseFirestore.instance.collection('appointments');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchFutureAppointments() {
    final now = DateTime.now();
    final tomorrowStart =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    return _appointments
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart))
        .snapshots();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getAppointments() {
    return _appointments.get();
  }

  static Future<DocumentReference<Map<String, dynamic>>> addAppointment(
    Map<String, dynamic> data,
  ) {
    return _appointments.add(data);
  }

  static Future<void> updateAppointment(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _appointments.doc(docId).update(data);
  }

  static Future<void> deleteAppointment(String docId) {
    return _appointments.doc(docId).delete();
  }

  static Future<void> updateAppointmentField({
    required String docId,
    required String field,
    required dynamic value,
  }) {
    return _appointments.doc(docId).update({field: value});
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getAppointmentsForDate(
    DateTime date,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _appointments
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getAppointmentsBetween({
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    final start = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final end = DateTime(lastDate.year, lastDate.month, lastDate.day)
        .add(const Duration(days: 1));

    return _appointments
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getBySerialNumber(
    String serialValue,
  ) {
    return _appointments
        .where('serial_number', isEqualTo: serialValue.trim())
        .limit(3)
        .get();
  }
}