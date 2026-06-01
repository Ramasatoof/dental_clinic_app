import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialsService {
  static final CollectionReference _materialsCollection =
      FirebaseFirestore.instance.collection('materials');

  static Stream<QuerySnapshot> watchMaterials() {
    return _materialsCollection.snapshots();
  }

  static Future<DocumentReference> addMaterial(Map<String, dynamic> data) {
    return _materialsCollection.add(data);
  }

  static Future<void> updateMaterial(
    String docId,
    Map<String, dynamic> data,
  ) {
    return _materialsCollection.doc(docId).update(data);
  }

  static Future<void> deleteMaterial(String docId) {
    return _materialsCollection.doc(docId).delete();
  }

  static Future<void> updateMaterialField({
    required String docId,
    required String field,
    required double value,
  }) {
    return _materialsCollection.doc(docId).update({
      field: value,
      'last_updated': Timestamp.now(),
    });
  }

  static Future<void> fixInvalidMaterialNumbers({
    required String docId,
    required Map<String, dynamic> fixes,
  }) {
    return _materialsCollection.doc(docId).update({
      ...fixes,
      'last_updated': Timestamp.now(),
    });
  }
}
