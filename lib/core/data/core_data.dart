import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 1. النماذج (Models)
// ==========================================

class SubDetail {
  String id;
  String name;
  Color color;
  int order;

  SubDetail({required this.id, required this.name, required this.color, required this.order});

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'color': color.value, 'order': order,
  };

  factory SubDetail.fromMap(Map<String, dynamic> map) => SubDetail(
    id: map['id'], name: map['name'], color: Color(map['color']), order: map['order'],
  );
}

class TreatmentItem {
  String id;
  String category;
  String name;
  Color color;
  double price;
  String textCode;
  String imageCode;
  bool hasLab;
  String actionType;
  List<SubDetail> details;

  TreatmentItem({
    required this.id, required this.category, required this.name,
    this.color = Colors.blue, this.price = 0.0, this.textCode = '',
    this.imageCode = '', this.hasLab = false, this.actionType = 'general',
    this.details = const [],
  });

  Map<String, dynamic> toMap() => {
    'category': category, 'name': name, 'color': color.value, 'price': price,
    'textCode': textCode, 'imageCode': imageCode, 'hasLab': hasLab,
    'actionType': actionType,
    'details': details.map((d) => d.toMap()).toList(),
  };

  factory TreatmentItem.fromMap(String id, Map<String, dynamic> map) => TreatmentItem(
    id: id, category: map['category'] ?? '', name: map['name'] ?? '',
    color: Color(map['color'] ?? Colors.blue.value),
    price: (map['price'] ?? 0).toDouble(),
    textCode: map['textCode'] ?? '', imageCode: map['imageCode'] ?? '',
    hasLab: map['hasLab'] ?? false, actionType: map['actionType'] ?? 'general',
    details: (map['details'] as List<dynamic>? ?? []).map((d) => SubDetail.fromMap(d)).toList(),
  );
}

class ToothModel {
  final int id;
  bool isSelected;
  Color statusColor;
  String? note;
  DateTime? lastTreatmentDate;
  List<String> treatmentsHistory;

  bool hasRCT, hasCrown, hasAppliance, hasBridge, hasImplant;
  bool isMissing, hasCaries, hasVeneer, hasBraces, hasAbscess, isImpacted, hasScaling;
  Map<String, bool> surfaces;
  String condition;

  ToothModel({
    required this.id, this.isSelected = false, this.statusColor = Colors.transparent,
    this.note, this.lastTreatmentDate, List<String>? treatmentsHistory,
    this.hasRCT = false, this.hasCrown = false, this.hasAppliance = false,
    this.hasBridge = false, this.hasImplant = false, this.isMissing = false,
    this.hasCaries = false, this.hasVeneer = false, this.hasBraces = false,
    this.hasAbscess = false, this.isImpacted = false, this.hasScaling = false,
    this.condition = 'healthy', Map<String, bool>? surfaces,
  }) : surfaces = surfaces ?? {'center': false, 'top': false, 'bottom': false, 'left': false, 'right': false},
       treatmentsHistory = treatmentsHistory ?? [];
}

// ==========================================
// 2. خدمة قاعدة البيانات (Database Service)
// ==========================================

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<String>> getCategories() async {
    var snapshot = await _db.collection('treatment_categories').orderBy('timestamp').get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<void> addCategory(String name) async {
    await _db.collection('treatment_categories').add({'name': name, 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<List<TreatmentItem>> getTreatments() async {
    var snapshot = await _db.collection('treatments_setup').get();
    return snapshot.docs.map((doc) => TreatmentItem.fromMap(doc.id, doc.data())).toList();
  }

  Future<String> addTreatment(TreatmentItem item) async {
    var docRef = await _db.collection('treatments_setup').add(item.toMap());
    return docRef.id;
  }

  Future<void> updateTreatment(TreatmentItem item) async {
    await _db.collection('treatments_setup').doc(item.id).update(item.toMap());
  }

  Future<void> deleteTreatment(String id) async {
    await _db.collection('treatments_setup').doc(id).delete();
  }

  // ==========================================
  // دوال خاصة بملف المريض والتشخيص البصري
  // ==========================================

  // 1. إضافة مريض جديد
  Future<String> createNewPatient({required String name, required String phone, required String age, required String gender}) async {
    var docRef = await _db.collection('patients').add({
      'name': name,
      'phone': phone,
      'age': age,
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id; // إرجاع رقم الملف الجديد
  }

  // 2. جلب المخطط السني البصري للمريض (Dental Chart State)
  Future<List<Map<String, dynamic>>> getPatientDentalChart(String patientId) async {
    var snapshot = await _db.collection('patients').doc(patientId).collection('dental_chart').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // 3. حفظ المخطط السني البصري (تحديث حالة السن)
  Future<void> saveToothVisualState(String patientId, int toothId, Map<String, dynamic> toothData) async {
    await _db.collection('patients')
        .doc(patientId)
        .collection('dental_chart')
        .doc(toothId.toString()) // جعل رقم السن هو اسم الـ Document
        .set(toothData, SetOptions(merge: true)); // دمج البيانات لكي لا نمسح البيانات السابقة
  }

  // ==========================================
  // دوال خاصة بملف المريض وحسابه (تمت إضافتها)
  // ==========================================

  // 1. حفظ معالجة جديدة في ملف المريض
  Future<void> savePatientTreatment({
    required String patientId,
    required int toothId,
    required String treatmentName,
    required String doctorName,
    required double price,
    required String status,
    String? category,
    String? detail,
    double discount = 0.0,
  }) async {
    await _db.collection('patient_treatments').add({
      'patientId': patientId,
      'toothId': toothId,
      'treatmentName': treatmentName,
      'doctorName': doctorName,
      'price': price,
      'status': status,
      'category': category ?? 'عام', // حفظ التصنيف
      'detail': detail ?? '',       // حفظ التفصيل (إن وجد)
      'discount': discount,         // حفظ الخصم
      'date': FieldValue.serverTimestamp(),
    });
  }

  // 2. حفظ دفعة مالية جديدة للمريض
  Future<void> addPatientPayment({
    required String patientId,
    required double amount,
    required String receiptNo,
    required String method,
  }) async {
    await _db.collection('patient_payments').add({
      'patientId': patientId,
      'amount': amount,
      'receiptNo': receiptNo,
      'method': method,
      'date': FieldValue.serverTimestamp(),
    });
  }

  // 3. حذف دفعة مالية (إذا أخطأ المحاسب)
  Future<void> deletePatientPayment(String paymentId) async {
    await _db.collection('patient_payments').doc(paymentId).delete();
  }
}

// ==========================================
// 3. إدارة الحالة (Provider)
// ==========================================

class DentalProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  List<String> categories = [];
  List<TreatmentItem> allTreatments = [];
  bool isLoading = true;

  DentalProvider() { _loadData(); }

  Future<void> _loadData() async {
    try {
      categories = await _dbService.getCategories();
      allTreatments = await _dbService.getTreatments();
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    categories.add(name);
    notifyListeners();
    await _dbService.addCategory(name);
  }

  Future<void> addTreatment(TreatmentItem item) async {
    allTreatments.add(item);
    notifyListeners();
    String id = await _dbService.addTreatment(item);
    item.id = id;
    notifyListeners();
  }

  Future<void> updateTreatment(TreatmentItem item) async {
    int index = allTreatments.indexWhere((t) => t.id == item.id);
    if (index != -1) {
      allTreatments[index] = item;
      notifyListeners();
      await _dbService.updateTreatment(item);
    }
  }

  Future<void> deleteTreatment(TreatmentItem item) async {
    allTreatments.removeWhere((t) => t.id == item.id);
    notifyListeners();
    await _dbService.deleteTreatment(item.id);
  }

  List<TreatmentItem> getTreatmentsByCategory(String category) {
    return allTreatments.where((t) => t.category == category).toList();
  }
}
