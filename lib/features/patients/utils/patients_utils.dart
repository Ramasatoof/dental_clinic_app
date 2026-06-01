import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PatientsUtils {
  static String phoneDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String formatPhoneNumber(String value) {
    final digits = phoneDigits(value);

    if (digits.isEmpty) return "";

    if (digits.startsWith("962") && digits.length == 12) {
      return "+962 ${digits.substring(3, 4)} ${digits.substring(4, 8)} ${digits.substring(8)}";
    }

    if (digits.length == 10 && digits.startsWith("0")) {
      return "${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}";
    }

    if (digits.length == 9) {
      return "${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}";
    }

    if (digits.length == 8) {
      return "${digits.substring(0, 4)} ${digits.substring(4)}";
    }

    final chunks = <String>[];
    for (int i = 0; i < digits.length; i += 3) {
      final end = i + 3 > digits.length ? digits.length : i + 3;
      chunks.add(digits.substring(i, end));
    }

    return chunks.join(" ");
  }

  static bool isValidJordanPhone(String value) {
    final digits = phoneDigits(value);
    return RegExp(r'^(079|078|077)[0-9]{7}$').hasMatch(digits);
  }

  static bool isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;

    final regex = RegExp(
      r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$",
    );
    return regex.hasMatch(email);
  }

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String dateKey(DateTime date) {
    final day = dateOnly(date);
    return "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
  }

  static DateTime? dateFromAppointmentValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static bool isClinicWorkingDay(DateTime date) {
    return date.weekday != DateTime.friday;
  }

  static String normalizeTimeText(String value) {
    const arabicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    String result = value.trim();
    arabicDigits.forEach((ar, en) {
      result = result.replaceAll(ar, en);
    });

    return result
        .replaceAll('صباحًا', 'AM')
        .replaceAll('مساءً', 'PM')
        .replaceAll('صباحا', 'AM')
        .replaceAll('مساء', 'PM')
        .replaceAll('ص', 'AM')
        .replaceAll('م', 'PM')
        .trim()
        .toUpperCase();
  }

  static int? minutesFromStoredTime(String timeStr) {
    try {
      final clean = normalizeTimeText(timeStr);
      if (clean.isEmpty) return null;

      final amPmAfterMatch =
          RegExp(r'^([0-9]{1,2}):([0-9]{2}) ?(AM|PM)$').firstMatch(clean);
      if (amPmAfterMatch != null) {
        int hour = int.parse(amPmAfterMatch.group(1)!);
        final int minute = int.parse(amPmAfterMatch.group(2)!);
        final String ampm = amPmAfterMatch.group(3)!;

        if (ampm == "PM" && hour < 12) hour += 12;
        if (ampm == "AM" && hour == 12) hour = 0;

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
      }

      final amPmBeforeMatch =
          RegExp(r'^(AM|PM) ?([0-9]{1,2}):([0-9]{2})$').firstMatch(clean);
      if (amPmBeforeMatch != null) {
        final String ampm = amPmBeforeMatch.group(1)!;
        int hour = int.parse(amPmBeforeMatch.group(2)!);
        final int minute = int.parse(amPmBeforeMatch.group(3)!);

        if (ampm == "PM" && hour < 12) hour += 12;
        if (ampm == "AM" && hour == 12) hour = 0;

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
      }

      final twentyFourHourMatch =
          RegExp(r'^([0-9]{1,2}):([0-9]{2})$').firstMatch(clean);
      if (twentyFourHourMatch != null) {
        final int hour = int.parse(twentyFourHourMatch.group(1)!);
        final int minute = int.parse(twentyFourHourMatch.group(2)!);

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static List<TimeOfDay> clinicTimeSlots() {
    final slots = <TimeOfDay>[];
    const int startMinutes = 9 * 60;
    const int endMinutes = 19 * 60;
    const int stepMinutes = 30;

    for (int minutes = startMinutes;
        minutes <= endMinutes;
        minutes += stepMinutes) {
      slots.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    }

    return slots;
  }

  static Set<String> clinicTimeSlotKeys() {
    return clinicTimeSlots().map(timeKey).toSet();
  }

  static String timeKey(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  static String timeKeyFromStoredValue(String value) {
    final minutes = minutesFromStoredTime(value);
    if (minutes == null) return "";
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  static String normalizeSearchText(dynamic value) {
    String text = (value ?? "").toString();

    const digitMap = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    digitMap.forEach((ar, en) {
      text = text.replaceAll(ar, en);
    });

    return text.toLowerCase().trim();
  }

  static String searchDigitsOnly(dynamic value) {
    return normalizeSearchText(value).replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String searchableDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return "";

    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return "$y-$m-$d $d/$m/$y ${date.year}-${date.month}-${date.day}";
  }

  static String searchableValue(dynamic value) {
    if (value == null) return "";

    if (value is Timestamp || value is DateTime) {
      return searchableDate(value);
    }

    if (value is bool) {
      return value
          ? "true نعم منتهية finished completed"
          : "false لا قيد المعالجة ongoing pending";
    }

    return value.toString();
  }
}