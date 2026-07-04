import 'package:flutter/material.dart';


class ToothModel {
  final int id;
  bool isSelected;
  Color statusColor;
  String? note;
  DateTime? lastTreatmentDate;
  List<String> treatmentsHistory;
  
  // حقول الحالات البصرية مع الألوان
  bool hasRCT;
  int rctColorVal; // تخزين قيمة لون سحب العصب

  bool hasCrown;
  int crownColorVal; // تخزين قيمة لون التاج

  bool hasAppliance;
  int applianceColorVal;

  bool hasBridge;
  bool hasImplant;
  int implantColorVal; // تخزين قيمة لون الزرعة

  bool isMissing;
  bool hasCaries;
  bool hasVeneer;
  int veneerColorVal; // تخزين قيمة لون الفينير

  bool hasBraces;
  int bracesColorVal; // تخزين قيمة لون التقويم

  bool hasAbscess;
  bool isImpacted;
  bool hasScaling;
  Map<String, bool> surfaces;
  String condition;

  ToothModel({
    required this.id,
    this.isSelected = false,
    this.statusColor = Colors.transparent,
    this.note,
    this.lastTreatmentDate,
    List<String>? treatmentsHistory,
    this.hasRCT = false,
    this.rctColorVal = 0xFF9C27B0, // القيمة الافتراضية
    this.hasCrown = false,
    this.crownColorVal = 0xFF9C27B0,
    this.hasAppliance = false,
    this.applianceColorVal = 0xFFE91E63,
    this.hasBridge = false,
    this.hasImplant = false,
    this.implantColorVal = 0xFF607D8B,
    this.isMissing = false,
    this.hasCaries = false,
    this.hasVeneer = false,
    this.veneerColorVal = 0xFF00BCD4,
    this.hasBraces = false,
    this.bracesColorVal = 0xFF9E9E9E,
    this.hasAbscess = false,
    this.isImpacted = false,
    this.hasScaling = false,
    this.condition = 'healthy',
    Map<String, bool>? surfaces,
  })  : surfaces = surfaces ??
            {'center': false, 'top': false, 'bottom': false, 'left': false, 'right': false},
        treatmentsHistory = treatmentsHistory ?? [];

  // تصدير البيانات شامل الألوان
  Map<String, dynamic> toMap() {
    return {
      'statusColor': statusColor.value,
      'note': note,
      'lastTreatmentDate': lastTreatmentDate?.toIso8601String(),
      'treatmentsHistory': treatmentsHistory,
      'hasRCT': hasRCT,
      'rctColorVal': rctColorVal,
      'hasCrown': hasCrown,
      'crownColorVal': crownColorVal,
      'hasAppliance': hasAppliance,
      'applianceColorVal': applianceColorVal,
      'hasBridge': hasBridge,
      'hasImplant': hasImplant,
      'implantColorVal': implantColorVal,
      'isMissing': isMissing,
      'hasCaries': hasCaries,
      'hasVeneer': hasVeneer,
      'veneerColorVal': veneerColorVal,
      'hasBraces': hasBraces,
      'bracesColorVal': bracesColorVal,
      'hasAbscess': hasAbscess,
      'isImpacted': isImpacted,
      'hasScaling': hasScaling,
      'condition': condition,
      'surfaces': surfaces,
    };
  }

  // استيراد وقراءة البيانات شامل الألوان
  void fromMap(Map<String, dynamic> map) {
    statusColor = Color(map['statusColor'] ?? Colors.transparent.value);
    note = map['note'];
    lastTreatmentDate = map['lastTreatmentDate'] != null
        ? DateTime.parse(map['lastTreatmentDate'])
        : null;
    treatmentsHistory = List<String>.from(map['treatmentsHistory'] ?? []);
    hasRCT = map['hasRCT'] ?? false;
    rctColorVal = map['rctColorVal'] ?? 0xFF9C27B0;
    hasCrown = map['hasCrown'] ?? false;
    crownColorVal = map['crownColorVal'] ?? 0xFF9C27B0;
    hasAppliance = map['hasAppliance'] ?? false;
    applianceColorVal = map['applianceColorVal'] ?? 0xFFE91E63;
    hasBridge = map['hasBridge'] ?? false;
    hasImplant = map['hasImplant'] ?? false;
    implantColorVal = map['implantColorVal'] ?? 0xFF607D8B;
    isMissing = map['isMissing'] ?? false;
    hasCaries = map['hasCaries'] ?? false;
    hasVeneer = map['hasVeneer'] ?? false;
    veneerColorVal = map['veneerColorVal'] ?? 0xFF00BCD4;
    hasBraces = map['hasBraces'] ?? false;
    bracesColorVal = map['bracesColorVal'] ?? 0xFF9E9E9E;
    hasAbscess = map['hasAbscess'] ?? false;
    isImpacted = map['isImpacted'] ?? false;
    hasScaling = map['hasScaling'] ?? false;
    condition = map['condition'] ?? 'healthy';
    if (map['surfaces'] != null) {
      surfaces = Map<String, bool>.from(map['surfaces']);
    }
  }

  ToothModel copy() {
    return ToothModel(
      id: id,
      isSelected: isSelected,
      statusColor: statusColor,
      note: note,
      lastTreatmentDate: lastTreatmentDate,
      treatmentsHistory: List<String>.from(treatmentsHistory),
      hasRCT: hasRCT,
      rctColorVal: rctColorVal,
      hasCrown: hasCrown,
      crownColorVal: crownColorVal,
      hasAppliance: hasAppliance,
      applianceColorVal: applianceColorVal,
      hasBridge: hasBridge,
      hasImplant: hasImplant,
      implantColorVal: implantColorVal,
      isMissing: isMissing,
      hasCaries: hasCaries,
      hasVeneer: hasVeneer,
      veneerColorVal: veneerColorVal,
      hasBraces: hasBraces,
      bracesColorVal: bracesColorVal,
      hasAbscess: hasAbscess,
      isImpacted: isImpacted,
      hasScaling: hasScaling,
      condition: condition,
      surfaces: Map<String, bool>.from(surfaces),
    );
  }
}

class StatusItem {
  final String ar;
  final String en;
  final Color color;
  final bool square;
  final String statusCode;

  StatusItem({
    required this.ar,
    required this.en,
    required this.color,
    required this.square,
    required this.statusCode,
  });
}
