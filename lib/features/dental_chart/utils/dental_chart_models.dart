import 'package:flutter/material.dart';

class ToothModel {
  final int id;
  bool isSelected;
  Color statusColor;
  String? note;
  DateTime? lastTreatmentDate;
  List<String> treatmentsHistory;
  bool hasRCT;
  bool hasCrown;
  bool hasAppliance;
  bool hasBridge;
  bool hasImplant;
  bool isMissing;
  bool hasCaries;
  bool hasVeneer;
  bool hasBraces;
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
    this.hasCrown = false,
    this.hasAppliance = false,
    this.hasBridge = false,
    this.hasImplant = false,
    this.isMissing = false,
    this.hasCaries = false,
    this.hasVeneer = false,
    this.hasBraces = false,
    this.hasAbscess = false,
    this.isImpacted = false,
    this.hasScaling = false,
    this.condition = 'healthy',
    Map<String, bool>? surfaces,
  })  : surfaces = surfaces ??
            {'center': false, 'top': false, 'bottom': false, 'left': false, 'right': false},
        treatmentsHistory = treatmentsHistory ?? [];

  Map<String, dynamic> toMap() {
    return {
      'statusColor': statusColor.value,
      'note': note,
      'lastTreatmentDate': lastTreatmentDate?.toIso8601String(),
      'treatmentsHistory': treatmentsHistory,
      'hasRCT': hasRCT,
      'hasCrown': hasCrown,
      'hasAppliance': hasAppliance,
      'hasBridge': hasBridge,
      'hasImplant': hasImplant,
      'isMissing': isMissing,
      'hasCaries': hasCaries,
      'hasVeneer': hasVeneer,
      'hasBraces': hasBraces,
      'hasAbscess': hasAbscess,
      'isImpacted': isImpacted,
      'hasScaling': hasScaling,
      'condition': condition,
      'surfaces': surfaces,
    };
  }

  void fromMap(Map<String, dynamic> map) {
    statusColor = Color(map['statusColor'] ?? Colors.transparent.value);
    note = map['note'];
    lastTreatmentDate = map['lastTreatmentDate'] != null
        ? DateTime.parse(map['lastTreatmentDate'])
        : null;
    treatmentsHistory = List<String>.from(map['treatmentsHistory'] ?? []);
    hasRCT = map['hasRCT'] ?? false;
    hasCrown = map['hasCrown'] ?? false;
    hasAppliance = map['hasAppliance'] ?? false;
    hasBridge = map['hasBridge'] ?? false;
    hasImplant = map['hasImplant'] ?? false;
    isMissing = map['isMissing'] ?? false;
    hasCaries = map['hasCaries'] ?? false;
    hasVeneer = map['hasVeneer'] ?? false;
    hasBraces = map['hasBraces'] ?? false;
    hasAbscess = map['hasAbscess'] ?? false;
    isImpacted = map['isImpacted'] ?? false;
    hasScaling = map['hasScaling'] ?? false;
    condition = map['condition'] ?? 'healthy';
    if (map['surfaces'] != null) {
      surfaces = Map<String, bool>.from(map['surfaces']);
    }
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
