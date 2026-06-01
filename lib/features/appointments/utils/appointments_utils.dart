import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppointmentsUtils {
  static final RegExp nonDigitRegex = RegExp(r'[^0-9]');
  static final RegExp jordanMobileRegex = RegExp(r'^(077|078|079)[0-9]{7}$');

  static final RegExp timeAmPmAfterRegex =
      RegExp(r'^([0-9]{1,2}):([0-9]{2}) ?(AM|PM)$');
  static final RegExp timeAmPmBeforeRegex =
      RegExp(r'^(AM|PM) ?([0-9]{1,2}):([0-9]{2})$');
  static final RegExp timeTwentyFourRegex =
      RegExp(r'^([0-9]{1,2}):([0-9]{2})$');

  static const Map<String, String> arabicDigitMap = {
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

  static String phoneDigits(String value) {
    return value.replaceAll(nonDigitRegex, '');
  }

  static bool isValidJordanMobileNumber(String value) {
    final digits = phoneDigits(value);
    return jordanMobileRegex.hasMatch(digits);
  }

  static String localJordanPhoneForInput(String value) {
    final digits = phoneDigits(value);

    if (digits.startsWith('00962') && digits.length == 14) {
      return '0${digits.substring(5)}';
    }

    if (digits.startsWith('962') && digits.length == 12) {
      return '0${digits.substring(3)}';
    }

    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  static int serialToInt(dynamic value) {
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  static String whatsappPhoneNumber(String value) {
    final digits = phoneDigits(value);

    if (digits.isEmpty) return "";

    if (digits.startsWith("00")) {
      return digits.substring(2);
    }

    if (digits.startsWith("962")) {
      return digits;
    }

    if (digits.length == 10 && digits.startsWith("0")) {
      return "962${digits.substring(1)}";
    }

    if (digits.length == 9 && digits.startsWith("7")) {
      return "962$digits";
    }

    return digits;
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

  static String normalizeTimeText(String value) {
    String result = value.trim();

    arabicDigitMap.forEach((ar, en) {
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

      final amPmAfterMatch = timeAmPmAfterRegex.firstMatch(clean);
      if (amPmAfterMatch != null) {
        int hour = int.parse(amPmAfterMatch.group(1)!);
        final int minute = int.parse(amPmAfterMatch.group(2)!);
        final String ampm = amPmAfterMatch.group(3)!;

        if (ampm == "PM" && hour < 12) hour += 12;
        if (ampm == "AM" && hour == 12) hour = 0;

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
      }

      final amPmBeforeMatch = timeAmPmBeforeRegex.firstMatch(clean);
      if (amPmBeforeMatch != null) {
        final String ampm = amPmBeforeMatch.group(1)!;
        int hour = int.parse(amPmBeforeMatch.group(2)!);
        final int minute = int.parse(amPmBeforeMatch.group(3)!);

        if (ampm == "PM" && hour < 12) hour += 12;
        if (ampm == "AM" && hour == 12) hour = 0;

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
        return hour * 60 + minute;
      }

      final twentyFourHourMatch = timeTwentyFourRegex.firstMatch(clean);
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

  static int minutesFromTimeString(String timeStr) {
    return minutesFromStoredTime(timeStr) ?? 0;
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

    return List<TimeOfDay>.unmodifiable(slots);
  }

  static Set<String> clinicTimeSlotKeys() {
    return Set<String>.unmodifiable(clinicTimeSlots().map(timeKey));
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

  static String formatTimeForStorage(TimeOfDay time) {
    final int hourOfPeriod = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hourOfPeriod:$minute $period";
  }

  static String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String formatDate(DateTime date) {
    return "${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}";
  }
}