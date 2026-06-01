import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../services/patients_service.dart';
import '../../../core/layout/custom_layout.dart';
import 'patient_account_screen.dart';
import '../../../core/theme/app_theme_controller.dart';
import '../utils/patients_utils.dart';
import '../widgets/patients_pagination.dart';
import '../widgets/patients_header.dart';
import '../widgets/patients_success_message.dart';
import '../widgets/patients_empty_state.dart';
// مكتبات التصدير والطباعة
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class PatientsScreen extends StatefulWidget {
  final String username;
  final bool initialArabic;

  const PatientsScreen({
    super.key,
    required this.username,
    required this.initialArabic,
  });

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late bool isArabic;
  late String preferredLanguage;

  bool isAddingPatient = false;
  bool isEditMode = false;
  bool emailReminderEnabled = false;

  String? editingDocId;
  String? addError;
  String? successMessage;
  Timer? successTimer;
  bool isSavingPatient = false;
  int _patientFormStep = 0;

  String sortColumn = "serial_number";
  bool isAscending = true;
  String searchQuery = "";
  String? hoveredPatientRowId;
  TextEditingController searchController = TextEditingController();

  int? currentPage;
  int? rowsPerPage;

  int get _currentPage {
    currentPage ??= 1;
    return currentPage!;
  }

  int get _rowsPerPage {
    rowsPerPage ??= 10;
    return rowsPerPage!;
  }

  final TextEditingController serialNum = TextEditingController();
  final TextEditingController fileNum = TextEditingController();
  final TextEditingController fName = TextEditingController();
  final TextEditingController mName = TextEditingController();
  final TextEditingController gName = TextEditingController();
  final TextEditingController lName = TextEditingController();
  final TextEditingController phoneNum = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController nationality = TextEditingController();
  final TextEditingController doctor = TextEditingController();
  final TextEditingController notes = TextEditingController();
  final FocusNode notesFocusNode = FocusNode();

  final TextEditingController reqAmount = TextEditingController(text: "0");
  final TextEditingController paidAmount = TextEditingController(text: "0");
  final TextEditingController discount = TextEditingController(text: "0");
  final TextEditingController newPayments = TextEditingController(text: "0");
  final TextEditingController remaining = TextEditingController(text: "0");
  final TextEditingController finalBalance = TextEditingController(text: "0");

  String completePhoneNumber = "";
  DateTime? firstVisit, lastVisit, birthDate, nextSession;
  TimeOfDay? nextSessionTime;
  String gender = "ذكر";
  bool isFinished = false;
  bool _isFixingInputText = false;

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
    preferredLanguage = isArabic ? "ar" : "en";

    currentPage ??= 1;
    rowsPerPage ??= 10;

    _attachAllInputLimits();

    reqAmount.addListener(_calculateBalance);
    paidAmount.addListener(_calculateBalance);
    discount.addListener(_calculateBalance);
    newPayments.addListener(_calculateBalance);
  }

  @override
  void dispose() {
    searchController.dispose();
    serialNum.dispose();
    fileNum.dispose();
    fName.dispose();
    mName.dispose();
    gName.dispose();
    lName.dispose();
    phoneNum.dispose();
    emailController.dispose();
    address.dispose();
    nationality.dispose();
    doctor.dispose();
    notes.dispose();
    notesFocusNode.dispose();
    reqAmount.dispose();
    paidAmount.dispose();
    discount.dispose();
    newPayments.dispose();
    remaining.dispose();
    finalBalance.dispose();
    successTimer?.cancel();
    super.dispose();
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);

  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : lightGray.withOpacity(0.85);

  String _phoneDigits(String value) {
    return PatientsUtils.phoneDigits(value);
  }

  String _formatPhoneNumber(String value) {
    return PatientsUtils.formatPhoneNumber(value);
  }

  void _calculateBalance() {
    double req = double.tryParse(reqAmount.text) ?? 0;
    double paid = double.tryParse(paidAmount.text) ?? 0;
    double disc = double.tryParse(discount.text) ?? 0;
    double newPay = double.tryParse(newPayments.text) ?? 0;
    remaining.text = (req - (paid + disc + newPay)).toStringAsFixed(0);
    finalBalance.text = (paid + newPay).toStringAsFixed(0);
  }

  Future<int> _nextPatientSerialNumber() async {
  return PatientsService.nextPatientSerialNumber();
}

  Future<void> _generateSerial() async {
    final nextSerial = await _nextPatientSerialNumber();

    if (!mounted) return;

    serialNum.text = nextSerial.toString();
  }

  bool _isValidJordanPhone(String value) {
    return PatientsUtils.isValidJordanPhone(value);
  }



  Future<bool> _serialNumberExists(
  String serial, {
  String? excludePatientDocId,
}) async {
  return PatientsService.serialNumberExists(
    serial,
    excludePatientDocId: excludePatientDocId,
  );
}

  bool _isValidEmail(String value) {
    return PatientsUtils.isValidEmail(value);
  }

  DateTime _dateOnly(DateTime value) {
    return PatientsUtils.dateOnly(value);
  }

  String _dateKey(DateTime date) {
    return PatientsUtils.dateKey(date);
  }

  DateTime? _dateFromAppointmentValue(dynamic value) {
    return PatientsUtils.dateFromAppointmentValue(value);
  }

  bool _isClinicWorkingDay(DateTime date) {
    return PatientsUtils.isClinicWorkingDay(date);
  }

 

  int? _minutesFromStoredTime(String timeStr) {
    return PatientsUtils.minutesFromStoredTime(timeStr);
  }

  List<TimeOfDay> _clinicTimeSlots() {
    return PatientsUtils.clinicTimeSlots();
  }

  Set<String> _clinicTimeSlotKeys() {
    return PatientsUtils.clinicTimeSlotKeys();
  }

  String _timeKey(TimeOfDay time) {
    return PatientsUtils.timeKey(time);
  }

  String _timeKeyFromStoredValue(String value) {
    return PatientsUtils.timeKeyFromStoredValue(value);
  }

  DateTime _combineSessionDateTime(
    DateTime sessionDate,
    TimeOfDay? sessionTime,
  ) {
    final time = sessionTime ?? const TimeOfDay(hour: 10, minute: 0);

    return DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      time.hour,
      time.minute,
    );
  }

  String _formatTimeOfDayForStorage(TimeOfDay? time) {
    final value = time ?? const TimeOfDay(hour: 10, minute: 0);
    final hour12 = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.period == DayPeriod.am ? "AM" : "PM";

    return "$hour12:$minute $period";
  }

  TimeOfDay? _parseStoredTime(String? storedTime) {
    if (storedTime == null || storedTime.trim().isEmpty) return null;

    final minutes = _minutesFromStoredTime(storedTime);
    if (minutes == null) return null;

    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }


  DateTime _calculateReminderSchedule(DateTime appointmentDateTime) {
    final scheduled = appointmentDateTime.subtract(const Duration(hours: 24));
    final now = DateTime.now();

    return scheduled.isBefore(now) ? now : scheduled;
  }

  QueryDocumentSnapshot? _firstPendingDoc(QuerySnapshot snapshot) {
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final attended = data['attended'] ?? false;

      if (attended != true) {
        return doc;
      }
    }
    return null;
  }

  Future<QueryDocumentSnapshot?> _findPendingAppointmentDoc(
    String patientDocId,
  ) async {
    final appointmentsCollection =
        FirebaseFirestore.instance.collection('appointments');

    final bySource = await appointmentsCollection
        .where('source_patient_doc_id', isEqualTo: patientDocId)
        .limit(5)
        .get();

    final sourceDoc = _firstPendingDoc(bySource);
    if (sourceDoc != null) return sourceDoc;

    final byPatientId = await appointmentsCollection
        .where('patient_id', isEqualTo: patientDocId)
        .limit(5)
        .get();

    final patientIdDoc = _firstPendingDoc(byPatientId);
    if (patientIdDoc != null) return patientIdDoc;

    final bySerial = await appointmentsCollection
        .where('serial_number', isEqualTo: serialNum.text.trim())
        .limit(5)
        .get();

    final serialDoc = _firstPendingDoc(bySerial);
    if (serialDoc != null) return serialDoc;

    return null;
  }

  Future<String?> _excludedAppointmentDocIdForCurrentPatient() async {
    if (!isEditMode || editingDocId == null) return null;

    final existingDoc = await _findPendingAppointmentDoc(editingDocId!);
    return existingDoc?.id;
  }

  Future<Set<String>> _bookedTimeKeysForDate(
    DateTime date, {
    String? excludeAppointmentDocId,
  }) async {
    final start = _dateOnly(date);
    final end = start.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final booked = <String>{};

    for (final doc in snapshot.docs) {
      if (excludeAppointmentDocId != null && doc.id == excludeAppointmentDocId) {
        continue;
      }

      final data = doc.data();
      final key = _timeKeyFromStoredValue((data['time'] ?? '').toString());
      if (key.isNotEmpty) {
        booked.add(key);
      }
    }

    return booked;
  }

  Future<List<TimeOfDay>> _availableTimeSlotsForDate(
    DateTime date, {
    String? excludeAppointmentDocId,
  }) async {
    if (!_isClinicWorkingDay(date)) return [];

    final booked = await _bookedTimeKeysForDate(
      date,
      excludeAppointmentDocId: excludeAppointmentDocId,
    );

    return _clinicTimeSlots().where((slot) {
      return !booked.contains(_timeKey(slot));
    }).toList();
  }

  Future<Set<String>> _fullyBookedDateKeys(
    DateTime firstDate,
    DateTime lastDate, {
    String? excludeAppointmentDocId,
  }) async {
    final start = _dateOnly(firstDate);
    final end = _dateOnly(lastDate).add(const Duration(days: 1));
    final allSlots = _clinicTimeSlotKeys();

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final bookedByDate = <String, Set<String>>{};

    for (final doc in snapshot.docs) {
      if (excludeAppointmentDocId != null && doc.id == excludeAppointmentDocId) {
        continue;
      }

      final data = doc.data();
      final appointmentDate = _dateFromAppointmentValue(data['date']);
      if (appointmentDate == null) continue;

      final dateKey = _dateKey(appointmentDate);
      final timeKey = _timeKeyFromStoredValue((data['time'] ?? '').toString());

      if (allSlots.contains(timeKey)) {
        bookedByDate.putIfAbsent(dateKey, () => <String>{}).add(timeKey);
      }
    }

    return bookedByDate.entries
        .where((entry) => allSlots.every(entry.value.contains))
        .map((entry) => entry.key)
        .toSet();
  }

  DateTime? _firstSelectableNextSessionDate({
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime preferredDate,
    required Set<String> fullyBookedDates,
  }) {
    DateTime start = _dateOnly(preferredDate);

    if (start.isBefore(_dateOnly(firstDate))) {
      start = _dateOnly(firstDate);
    }

    if (start.isAfter(_dateOnly(lastDate))) {
      start = _dateOnly(firstDate);
    }

    DateTime day = start;
    while (!day.isAfter(_dateOnly(lastDate))) {
      if (_isClinicWorkingDay(day) && !fullyBookedDates.contains(_dateKey(day))) {
        return day;
      }
      day = day.add(const Duration(days: 1));
    }

    day = _dateOnly(firstDate);
    while (day.isBefore(start)) {
      if (_isClinicWorkingDay(day) && !fullyBookedDates.contains(_dateKey(day))) {
        return day;
      }
      day = day.add(const Duration(days: 1));
    }

    return null;
  }

  Future<void> _pickNextSessionDate() async {
    final firstDate = _dateOnly(DateTime.now());
    final lastDate = DateTime(2100);
    final excludeAppointmentDocId = await _excludedAppointmentDocIdForCurrentPatient();

    final fullyBookedDates = await _fullyBookedDateKeys(
      firstDate,
      lastDate,
      excludeAppointmentDocId: excludeAppointmentDocId,
    );

    if (!mounted) return;

    final initialDate = _firstSelectableNextSessionDate(
      firstDate: firstDate,
      lastDate: lastDate,
      preferredDate: nextSession ?? DateTime.now(),
      fullyBookedDates: fullyBookedDates,
    );

    if (initialDate == null) {
      setState(() {
        addError = tr(
          "⚠️ لا توجد تواريخ متاحة للحجز",
          "⚠️ No available dates for booking",
        );
      });
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) {
        return _isClinicWorkingDay(date) &&
            !fullyBookedDates.contains(_dateKey(date));
      },
    );

    if (picked == null || !mounted) return;

    final availableSlots = await _availableTimeSlotsForDate(
      picked,
      excludeAppointmentDocId: excludeAppointmentDocId,
    );

    if (!mounted) return;

    if (availableSlots.isEmpty) {
      setState(() {
        addError = tr(
          "⚠️ لا توجد أوقات متاحة في هذا التاريخ",
          "⚠️ No available times on this date",
        );
      });
      return;
    }

    setState(() {
      nextSession = picked;
      addError = null;

      if (nextSessionTime == null) {
        nextSessionTime = availableSlots.first;
        return;
      }

      final selectedKey = _timeKey(nextSessionTime!);
      final stillAvailable =
          availableSlots.any((slot) => _timeKey(slot) == selectedKey);

      if (!stillAvailable) {
        nextSessionTime = availableSlots.first;
      }
    });
  }

  Future<void> _pickNextSessionTime() async {
    if (nextSession == null) {
      await _pickNextSessionDate();
      if (!mounted || nextSession == null) return;
    }

    final excludeAppointmentDocId = await _excludedAppointmentDocIdForCurrentPatient();
    final availableSlots = await _availableTimeSlotsForDate(
      nextSession!,
      excludeAppointmentDocId: excludeAppointmentDocId,
    );

    if (!mounted) return;

    if (availableSlots.isEmpty) {
      setState(() {
        addError = tr(
          "⚠️ لا توجد أوقات متاحة في هذا التاريخ",
          "⚠️ No available times on this date",
        );
      });
      return;
    }

    final pickedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: _surface(context),
            title: Text(
              tr("اختر وقتًا متاحًا", "Pick an Available Time"),
              style: TextStyle(
                color: _textPrimary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment:
                    isArabic ? WrapAlignment.end : WrapAlignment.start,
                children: availableSlots.map((slot) {
                  final bool active =
                      nextSessionTime != null && _timeKey(slot) == _timeKey(nextSessionTime!);

                  return ChoiceChip(
                    selected: active,
                    label: Text(_formatTimeOfDayForStorage(slot)),
                    selectedColor: lapisBlue.withOpacity(0.18),
                    backgroundColor: _softFill(context),
                    labelStyle: TextStyle(
                      color: active ? lapisBlue : _textPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide(
                      color: active ? lapisBlue : _border(context),
                    ),
                    onSelected: (_) => Navigator.pop(context, slot),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr("إلغاء", "Cancel")),
              ),
            ],
          ),
        );
      },
    );

    if (pickedTime != null && mounted) {
      setState(() {
        nextSessionTime = pickedTime;
        addError = null;
      });
    }
  }

  Future<bool> _validateNextSessionSlot({
    String? excludeAppointmentDocId,
  }) async {
    if (nextSession == null) return true;

    if (nextSessionTime == null) {
      setState(() {
        addError = tr(
          "⚠️ يرجى اختيار ساعة الجلسة القادمة",
          "⚠️ Please select next session time",
        );
      });
      return false;
    }

    if (!_isClinicWorkingDay(nextSession!)) {
      setState(() {
        addError = tr(
          "⚠️ العيادة مغلقة يوم الجمعة",
          "⚠️ The clinic is closed on Friday",
        );
      });
      return false;
    }

    final selectedKey = _timeKey(nextSessionTime!);
    if (!_clinicTimeSlotKeys().contains(selectedKey)) {
      setState(() {
        addError = tr(
          "⚠️ اختر وقتًا ضمن دوام العيادة من 9 صباحًا حتى 7 مساءً",
          "⚠️ Pick a time during clinic hours from 9 AM to 7 PM",
        );
      });
      return false;
    }

    final booked = await _bookedTimeKeysForDate(
      nextSession!,
      excludeAppointmentDocId: excludeAppointmentDocId,
    );

    if (booked.contains(selectedKey)) {
      setState(() {
        addError = tr(
          "⚠️ هذا الوقت محجوز، اختر وقتًا متاحًا",
          "⚠️ This time is booked, pick an available time",
        );
      });
      return false;
    }

    return true;
  }

  Future<void> _removePendingAppointmentIfAny(String patientDocId) async {
    final appointmentsCollection =
        FirebaseFirestore.instance.collection('appointments');
    final existingDoc = await _findPendingAppointmentDoc(patientDocId);

    if (existingDoc != null) {
      await appointmentsCollection.doc(existingDoc.id).delete();
    }
  }

  Future<void> _upsertNextAppointment({
    required String patientDocId,
    required DateTime appointmentDateTime,
    required String formattedTime,
    required bool canSendReminder,
    required String patientName,
    required String patientEmail,
    required String doctorName,
    required String phone,
  }) async {
    final appointmentsCollection =
        FirebaseFirestore.instance.collection('appointments');
    final reminderScheduledFor =
        canSendReminder ? _calculateReminderSchedule(appointmentDateTime) : null;

    final appointmentData = <String, dynamic>{
      'first_name': fName.text.trim(),
      'father_name': mName.text.trim(),
      'last_name': lName.text.trim(),
      'patient_name': patientName,
      'phone': phone,
      'serial_number': serialNum.text.trim(),
      'price': 0.0,
      'time': formattedTime,
      'attended': false,
      'date': Timestamp.fromDate(_dateOnly(appointmentDateTime)),
      'appointment_datetime': Timestamp.fromDate(appointmentDateTime),
      'patient_id': patientDocId,
      'patient_email': patientEmail,
      'doctor_name': doctorName,
      'language': preferredLanguage,
      'reminder_channel': 'email',
      'reminder_enabled': canSendReminder,
      'reminder_status': canSendReminder ? 'pending' : 'disabled',
      'reminder_scheduled_for': reminderScheduledFor != null
          ? Timestamp.fromDate(reminderScheduledFor)
          : null,
      'reminder_sent_at': null,
      'reminder_error': null,
      'updated_at': Timestamp.now(),
      'source_patient_doc_id': patientDocId,
    };

    final existingDoc = await _findPendingAppointmentDoc(patientDocId);

    if (existingDoc != null) {
      final existingData = existingDoc.data() as Map<String, dynamic>;

      await appointmentsCollection.doc(existingDoc.id).update({
        ...appointmentData,
        'created_at': existingData['created_at'] ?? Timestamp.now(),
      });
    } else {
      await appointmentsCollection.add({
        ...appointmentData,
        'created_at': Timestamp.now(),
      });
    }
  }

  Future<void> _savePatient() async {
    setState(() => addError = null);
    _fixAllCurrentInputValues();

    final serialText = serialNum.text.trim();

    if (serialText.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الرقم التسلسلي", "⚠️ Please enter Serial Number"));
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(serialText)) {
      setState(() => addError = tr(
            "⚠️ الرقم التسلسلي يجب أن يحتوي على أرقام فقط",
            "⚠️ Serial number must contain digits only",
          ));
      return;
    }

    final serialExists = await _serialNumberExists(
      serialText,
      excludePatientDocId: isEditMode ? editingDocId : null,
    );

    if (serialExists) {
      setState(() => addError = tr(
            "⚠️ الرقم التسلسلي موجود مسبقًا، يرجى اختيار رقم آخر",
            "⚠️ Serial number already exists, please choose another number",
          ));
      return;
    }
    if (fileNum.text.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال رقم الملف", "⚠️ Please enter File Number"));
      return;
    }
    if (birthDate == null) {
      setState(() => addError =
          tr("⚠️ يرجى اختيار تاريخ الولادة", "⚠️ Please select Birth Date"));
      return;
    }
    if (fName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الاسم الأول", "⚠️ Please enter First Name"));
      return;
    }
    if (mName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال اسم الأب", "⚠️ Please enter Father Name"));
      return;
    }
    if (gName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال اسم الجد", "⚠️ Please enter Grandfather Name"));
      return;
    }
    if (lName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال العائلة", "⚠️ Please enter Family Name"));
      return;
    }

    if (fName.text.trim().length > 15 ||
        mName.text.trim().length > 15 ||
        gName.text.trim().length > 15 ||
        lName.text.trim().length > 15) {
      setState(() => addError = tr(
            "⚠️ كل خانة اسم يجب ألا تتجاوز 15 حرفًا",
            "⚠️ Each name field must be 15 characters or less",
          ));
      return;
    }
    if (nationality.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الجنسية", "⚠️ Please enter Nationality"));
      return;
    }
    if (phoneNum.text.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال رقم الهاتف", "⚠️ Please enter Phone Number"));
      return;
    }

    if (!_isValidJordanPhone(phoneNum.text)) {
      setState(() => addError = tr(
            "⚠️ رقم الهاتف يجب أن يكون 10 أرقام ويبدأ بـ 079 أو 078 أو 077",
            "⚠️ Phone number must be 10 digits and start with 079, 078, or 077",
          ));
      return;
    }
    if (address.text.trim().isEmpty) {
      setState(() =>
          addError = tr("⚠️ يرجى إدخال العنوان", "⚠️ Please enter Address"));
      return;
    }
    if (firstVisit == null) {
      setState(() => addError = tr(
            "⚠️ يرجى اختيار تاريخ أول زيارة",
            "⚠️ Please select First Visit Date",
          ));
      return;
    }
    if (lastVisit == null) {
      setState(() => addError = tr(
            "⚠️ يرجى اختيار تاريخ آخر زيارة",
            "⚠️ Please select Last Visit Date",
          ));
      return;
    }
    if (doctor.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال اسم الطبيب", "⚠️ Please enter Doctor Name"));
      return;
    }
    if (reqAmount.text.isEmpty) {
      setState(() => addError = tr(
          "⚠️ يرجى إدخال المبلغ المطلوب", "⚠️ Please enter Required Amount"));
      return;
    }

    final trimmedEmail = emailController.text.trim().toLowerCase();
    if (trimmedEmail.isNotEmpty && !_isValidEmail(trimmedEmail)) {
      setState(() => addError =
          tr("⚠️ البريد الإلكتروني غير صالح", "⚠️ Invalid email address"));
      return;
    }

    if (emailReminderEnabled && trimmedEmail.isEmpty) {
      setState(() => addError = tr(
            "⚠️ فعّل التذكير بعد إدخال البريد الإلكتروني",
            "⚠️ Enter an email before enabling reminders",
          ));
      return;
    }

    if (emailReminderEnabled && !_isValidEmail(trimmedEmail)) {
      setState(() => addError =
          tr("⚠️ البريد الإلكتروني غير صالح", "⚠️ Invalid email address"));
      return;
    }

    String? excludeAppointmentDocId;
    if (isEditMode && editingDocId != null && nextSession != null) {
      excludeAppointmentDocId = await _excludedAppointmentDocIdForCurrentPatient();
    }

    if (nextSession != null) {
      final slotIsAvailable = await _validateNextSessionSlot(
        excludeAppointmentDocId: excludeAppointmentDocId,
      );
      if (!slotIsAvailable) return;
    }

    final hasNextSession = nextSession != null;
    final nextSessionDateTime = hasNextSession
        ? _combineSessionDateTime(nextSession!, nextSessionTime)
        : null;
    final formattedTime =
        hasNextSession ? _formatTimeOfDayForStorage(nextSessionTime) : "";
    final canSendReminder =
        hasNextSession && emailReminderEnabled && trimmedEmail.isNotEmpty;

    final fullName =
        "${fName.text.trim()} ${mName.text.trim()} ${gName.text.trim()} ${lName.text.trim()}";
    final appointmentPatientName =
        "${fName.text.trim()} ${mName.text.trim()} ${lName.text.trim()}";
    final phone = _phoneDigits(phoneNum.text.trim());
    final doctorName = doctor.text.trim();

    final Map<String, dynamic> data = {
      'serial_number': serialNum.text.trim(),
      'file_number': int.tryParse(fileNum.text.trim()) ?? 0,
      'first_name': fName.text.trim(),
      'father_name': mName.text.trim(),
      'grandfather_name': gName.text.trim(),
      'last_name': lName.text.trim(),
      'full_name': fullName,
      'gender': gender,
      'phone': phone,
      'email': trimmedEmail,
      'email_reminder_enabled': emailReminderEnabled,
      'preferred_language': preferredLanguage,
      'address': address.text.trim(),
      'nationality': nationality.text.trim(),
      'treating_doctor': doctorName,
      'notes': notes.text.trim(),
      'is_finished': isFinished,
      'required_amount': double.tryParse(reqAmount.text) ?? 0.0,
      'paid_amount': double.tryParse(paidAmount.text) ?? 0.0,
      'discount': double.tryParse(discount.text) ?? 0.0,
      'new_payment': double.tryParse(newPayments.text) ?? 0.0,
      'remaining_amount': double.tryParse(remaining.text) ?? 0.0,
      'final_balance': double.tryParse(finalBalance.text) ?? 0.0,
      'birth_date': Timestamp.fromDate(birthDate!),
      'first_visit': Timestamp.fromDate(firstVisit!),
      'last_visit': Timestamp.fromDate(lastVisit!),
      'next_session':
          hasNextSession ? Timestamp.fromDate(_dateOnly(nextSession!)) : null,
      'next_session_datetime': nextSessionDateTime != null
          ? Timestamp.fromDate(nextSessionDateTime)
          : null,
      'next_session_time': hasNextSession ? formattedTime : "",
      'last_reminder_sent_at': null,
      'last_reminder_status':
          hasNextSession ? (canSendReminder ? 'pending' : 'disabled') : null,
      'last_reminder_error': null,
      'reminder_sent_for_session': null,
    };

    late final String patientDocId;
    final bool wasEditMode = isEditMode;

    if (isEditMode && editingDocId != null) {
      patientDocId = editingDocId!;
      await PatientsService.updatePatient(patientDocId, data);
    } else {
      final docRef = await PatientsService.addPatient(data);
      patientDocId = docRef.id;
    }

    if (nextSessionDateTime != null) {
      await _upsertNextAppointment(
        patientDocId: patientDocId,
        appointmentDateTime: nextSessionDateTime,
        formattedTime: formattedTime,
        canSendReminder: canSendReminder,
        patientName: appointmentPatientName,
        patientEmail: trimmedEmail,
        doctorName: doctorName,
        phone: phone,
      );
    } else {
      await _removePendingAppointmentIfAny(patientDocId);
    }

    _closePatientCard();

    _showSuccessMessage(
      wasEditMode
          ? tr(
              "تم تعديل بيانات المريض بنجاح",
              "Patient updated successfully",
            )
          : tr(
              "تمت إضافة المريض بنجاح",
              "Patient added successfully",
            ),
    );
  }

  void _closePatientCard() {
    setState(() {
      isAddingPatient = false;
      isEditMode = false;
      editingDocId = null;
      addError = null;
      _patientFormStep = 0;

      for (var c in [
        fName,
        mName,
        gName,
        lName,
        phoneNum,
        emailController,
        serialNum,
        fileNum,
        address,
        nationality,
        doctor,
        notes,
        reqAmount,
        paidAmount,
        discount,
        newPayments,
        remaining,
        finalBalance,
      ]) {
        c.clear();
      }

      reqAmount.text = "0";
      paidAmount.text = "0";
      discount.text = "0";
      newPayments.text = "0";
      remaining.text = "0";
      finalBalance.text = "0";

      firstVisit = null;
      lastVisit = null;
      birthDate = null;
      nextSession = null;
      nextSessionTime = null;
      isFinished = false;
      gender = "ذكر";
      completePhoneNumber = "";
      emailReminderEnabled = false;
      preferredLanguage = isArabic ? "ar" : "en";
    });
  }

  void _showSuccessMessage(String message) {
    successTimer?.cancel();

    setState(() {
      successMessage = message;
    });

    successTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        successMessage = null;
      });
    });
  }

Widget _buildSuccessMessageBox(BoxConstraints constraints) {
  return PatientsSuccessMessage(
    message: successMessage,
    constraints: constraints,
  );
}

  Future<void> _submitPatientForm() async {
    if (isSavingPatient) return;

    setState(() {
      isSavingPatient = true;
    });

    try {
      await _savePatient();
    } finally {
      if (mounted) {
        setState(() {
          isSavingPatient = false;
        });
      }
    }
  }


  void _prepareEdit(Map<String, dynamic> data, String id) {
    setState(() {
      editingDocId = id;
      isEditMode = true;
      isAddingPatient = true;
      _patientFormStep = 0;

      fName.text = (data['first_name'] ?? "").toString();
      mName.text = (data['father_name'] ?? "").toString();
      gName.text = (data['grandfather_name'] ?? "").toString();
      lName.text = (data['last_name'] ?? "").toString();
      phoneNum.text = _phoneDigits((data['phone'] ?? "").toString());
      emailController.text = (data['email'] ?? "").toString();
      serialNum.text = (data['serial_number'] ?? "").toString();
      fileNum.text = (data['file_number'] ?? "").toString();
      address.text = (data['address'] ?? "").toString();
      nationality.text = (data['nationality'] ?? "").toString();
      doctor.text = (data['treating_doctor'] ?? "").toString();
      notes.text = (data['notes'] ?? "").toString();
      reqAmount.text = (data['required_amount'] ?? "0").toString();
      paidAmount.text = (data['paid_amount'] ?? "0").toString();
      discount.text = (data['discount'] ?? "0").toString();
      newPayments.text = (data['new_payment'] ?? "0").toString();
      isFinished = data['is_finished'] ?? false;
      emailReminderEnabled = data['email_reminder_enabled'] ?? false;

      final storedLanguage = (data['preferred_language'] ?? "").toString();
      preferredLanguage = storedLanguage == "en" ? "en" : "ar";

      birthDate = data['birth_date'] != null
          ? (data['birth_date'] as Timestamp).toDate()
          : null;
      firstVisit = data['first_visit'] != null
          ? (data['first_visit'] as Timestamp).toDate()
          : null;
      lastVisit = data['last_visit'] != null
          ? (data['last_visit'] as Timestamp).toDate()
          : null;

      if (data['next_session_datetime'] != null) {
        final nextSessionDateTime =
            (data['next_session_datetime'] as Timestamp).toDate();
        nextSession = _dateOnly(nextSessionDateTime);
        nextSessionTime = TimeOfDay(
          hour: nextSessionDateTime.hour,
          minute: nextSessionDateTime.minute,
        );
      } else if (data['next_session'] != null) {
        nextSession = (data['next_session'] as Timestamp).toDate();
        nextSessionTime = _parseStoredTime(data['next_session_time']?.toString());
      } else {
        nextSession = null;
        nextSessionTime = null;
      }

      String g = (data['gender'] ?? "ذكر").toString();
      gender = (g == "ذكر" || g == "أنثى") ? g : "ذكر";

      _calculateBalance();
      _fixAllCurrentInputValues();
    });
  }

  void _showDeleteConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _surface(context),
          title: Text(
            tr("تأكيد الحذف", "Confirm Delete"),
            style: TextStyle(color: _textPrimary(context)),
          ),
          content: Text(
            tr(
              "هل أنت متأكد من حذف هذا المريض؟",
              "Are you sure you want to delete this patient?",
            ),
            style: TextStyle(color: _textPrimary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr("لا", "No")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
              ),
              onPressed: () async {
              await PatientsService.deletePatient(docId);
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                tr("نعم", "Yes"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("تقرير قائمة المرضى")),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["المتبقي", "الطبيب", "الهاتف", "الاسم الرباعي", "الرقم"],
            data: docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              return [
                "${d['remaining_amount'] ?? 0} JD",
                d['treating_doctor'] ?? "-",
                _formatPhoneNumber((d['phone'] ?? "-").toString()),
                "${d['first_name']} ${d['father_name']} ${d['grandfather_name']} ${d['last_name']}",
                d['serial_number'] ?? "-",
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['PatientsReport'];

    sheetObject.appendRow([
      TextCellValue("الرقم التسلسلي"),
      TextCellValue("الاسم الرباعي"),
      TextCellValue("رقم الهاتف"),
      TextCellValue("الطبيب"),
      TextCellValue("المبلغ المتبقي"),
    ]);

    for (var doc in docs) {
      var d = doc.data() as Map<String, dynamic>;
      sheetObject.appendRow([
        TextCellValue(d['serial_number']?.toString() ?? ""),
        TextCellValue(
          "${d['first_name']} ${d['father_name']} ${d['grandfather_name']} ${d['last_name']}",
        ),
        TextCellValue(_formatPhoneNumber(d['phone']?.toString() ?? "")),
        TextCellValue(d['treating_doctor']?.toString() ?? ""),
        TextCellValue("${d['remaining_amount']} JD"),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null && kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([fileBytes]));
      html.AnchorElement(href: url)
        ..setAttribute("download", "Patients_List.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  String _normalizeSearchText(dynamic value) {
    return PatientsUtils.normalizeSearchText(value);
  }

  String _searchDigitsOnly(dynamic value) {
    return PatientsUtils.searchDigitsOnly(value);
  }
  String _searchableValue(dynamic value) {
    return PatientsUtils.searchableValue(value);
  }

  List<QueryDocumentSnapshot> _prepareDocs(QuerySnapshot snapshot) {
    final normalizedQuery = _normalizeSearchText(searchQuery);
    final queryDigits = _searchDigitsOnly(searchQuery);

    var docs = snapshot.docs.where((d) {
      var data = d.data() as Map<String, dynamic>;

      final fullName =
          "${data['first_name'] ?? ""} ${data['father_name'] ?? ""} ${data['grandfather_name'] ?? ""} ${data['last_name'] ?? ""}";

      final rawPhone = (data['phone'] ?? "").toString();
      final formattedPhone = _formatPhoneNumber(rawPhone);

      final extraSearchText = [
        fullName,
        formattedPhone,
        data['serial_number'],
        data['file_number'],
        data['first_name'],
        data['father_name'],
        data['grandfather_name'],
        data['last_name'],
        data['phone'],
        data['email'],
        data['address'],
        data['nationality'],
        data['treating_doctor'],
        data['notes'],
        data['gender'],
        data['required_amount'],
        data['paid_amount'],
        data['discount'],
        data['new_payment'],
        data['remaining_amount'],
        data['final_balance'],
        data['birth_date'],
        data['first_visit'],
        data['last_visit'],
        data['next_session'],
        data['next_session_datetime'],
        data['next_session_time'],
        data['is_finished'],
      ].map(_searchableValue).join(" ");

      final allDataSearchText = data.entries
          .map((entry) => "${entry.key} ${_searchableValue(entry.value)}")
          .join(" ");

      final haystack = _normalizeSearchText(
        "$extraSearchText $allDataSearchText",
      );

      final digitsHaystack = [
        data['serial_number'],
        data['file_number'],
        data['phone'],
        data['required_amount'],
        data['paid_amount'],
        data['discount'],
        data['new_payment'],
        data['remaining_amount'],
        data['final_balance'],
        formattedPhone,
      ].map(_searchDigitsOnly).join(" ");

      return haystack.contains(normalizedQuery) ||
          (queryDigits.isNotEmpty && digitsHaystack.contains(queryDigits));
    }).toList();

    docs.sort((a, b) {
      var dataA = a.data() as Map<String, dynamic>;
      var dataB = b.data() as Map<String, dynamic>;

      dynamic valA;
      dynamic valB;

      if (sortColumn == "full_name") {
        valA =
            "${dataA['first_name'] ?? ""} ${dataA['father_name'] ?? ""} ${dataA['grandfather_name'] ?? ""} ${dataA['last_name'] ?? ""}"
                .toLowerCase();
        valB =
            "${dataB['first_name'] ?? ""} ${dataB['father_name'] ?? ""} ${dataB['grandfather_name'] ?? ""} ${dataB['last_name'] ?? ""}"
                .toLowerCase();
      } else {
        valA = dataA[sortColumn] ?? "";
        valB = dataB[sortColumn] ?? "";
      }

      if (sortColumn == "serial_number" ||
          sortColumn == "remaining_amount" ||
          sortColumn == "file_number") {
        double numA = double.tryParse(valA.toString()) ?? 0;
        double numB = double.tryParse(valB.toString()) ?? 0;
        return isAscending ? numA.compareTo(numB) : numB.compareTo(numA);
      }

      if (sortColumn == "birth_date") {
        final DateTime dateA = valA is Timestamp
            ? valA.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime dateB = valB is Timestamp
            ? valB.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        return isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      }

      if (sortColumn == "is_finished") {
        final boolA = (dataA['is_finished'] ?? false) ? 1 : 0;
        final boolB = (dataB['is_finished'] ?? false) ? 1 : 0;
        return isAscending ? boolA.compareTo(boolB) : boolB.compareTo(boolA);
      }

      return isAscending
          ? valA.toString().compareTo(valB.toString())
          : valB.toString().compareTo(valA.toString());
    });

    return docs;
  }

  void _openProfile(String id, String patientFullName) { // 🔴 تم إضافة المتغير هنا
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientAccountScreen(
          patientId: id,
          patientName: patientFullName, // 🔴 استخدمناه هنا
          username: widget.username,
          isArabic: isArabic,
        ),
      ),
    );
  }
 Widget _buildDesktopHeader(AsyncSnapshot<QuerySnapshot> snapshot) {
  return PatientsHeader(
    isArabic: isArabic,
    isMobileLayout: false,
    snapshot: snapshot,
    rowsPerPage: _rowsPerPage,
    onAddPatient: () async {
      _closePatientCard();
      setState(() {
        isAddingPatient = true;
      });
      await _generateSerial();
    },
    onRowsPerPageChanged: (value) {
      setState(() {
        rowsPerPage = value;
        currentPage = 1;
      });
    },
    onExportPdf: _exportToPDF,
    onExportExcel: _exportToExcel,
  );
}

Widget _buildMobileHeader(AsyncSnapshot<QuerySnapshot> snapshot) {
  return PatientsHeader(
    isArabic: isArabic,
    isMobileLayout: true,
    snapshot: snapshot,
    rowsPerPage: _rowsPerPage,
    onAddPatient: () async {
      _closePatientCard();
      setState(() {
        isAddingPatient = true;
      });
      await _generateSerial();
    },
    onRowsPerPageChanged: (value) {
      setState(() {
        rowsPerPage = value;
        currentPage = 1;
      });
    },
    onExportPdf: _exportToPDF,
    onExportExcel: _exportToExcel,
  );
}


Widget _buildDesktopTable(
  List<QueryDocumentSnapshot> docs,
  int startIndex,
) {
  const double minTableWidth = 1500;

  const Map<int, TableColumnWidth> columnWidths = {
    0: FlexColumnWidth(0.7),
    1: FlexColumnWidth(1.5),
    2: FlexColumnWidth(1.3),
    3: FlexColumnWidth(3.7),
    4: FlexColumnWidth(1.8),
    5: FlexColumnWidth(2.2),
    6: FlexColumnWidth(1.7),
    7: FlexColumnWidth(1.5),
    8: FlexColumnWidth(1.7),
    9: FlexColumnWidth(1.5),
  };

  Widget tableHeaderCell(
    String title, {
    String? sortKey,
    Alignment alignment = Alignment.center,
    TextAlign textAlign = TextAlign.center,
  }) {
    final bool active = sortKey != null && sortColumn == sortKey;

    return InkWell(
      onTap: sortKey == null
          ? null
          : () => setState(() {
                if (sortColumn == sortKey) {
                  isAscending = !isAscending;
                } else {
                  sortColumn = sortKey;
                  isAscending = true;
                }
              }),
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          mainAxisAlignment: alignment == Alignment.center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            if (sortKey != null) ...[
              const SizedBox(width: 4),
              Icon(
                active
                    ? (isAscending
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down)
                    : Icons.unfold_more,
                color: Colors.white,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget tableBodyCell(
    Widget child, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: child,
    );
  }

  Widget hoverablePatientRowCell(String rowId,String fullName, Widget child) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hoveredPatientRowId = rowId),
      onExit: (_) {
        if (hoveredPatientRowId == rowId) {
          setState(() => hoveredPatientRowId = null);
        }
      },
      child: GestureDetector(
        onDoubleTap: () => _openProfile(rowId,fullName),
        child: child,
      ),
    );
  }

  Widget buildTableHeader() {
    return Table(
      columnWidths: columnWidths,
      border: TableBorder(
        top: BorderSide(color: lapisBlue, width: 1),
        bottom: BorderSide(color: _border(context), width: 1),
        left: BorderSide(color: _border(context), width: 1),
        right: BorderSide(color: _border(context), width: 1),
        horizontalInside: BorderSide(color: _border(context), width: 1),
        verticalInside: BorderSide(color: _border(context), width: 1),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: lapisBlue),
          children: [
            tableHeaderCell("#"),
            tableHeaderCell(
              tr("الرقم", "Serial"),
              sortKey: "serial_number",
            ),
            tableHeaderCell(
              tr("رقم الملف", "File Num"),
              sortKey: "file_number",
            ),
            tableHeaderCell(
              tr("اسم المريض", "Full Patient Name"),
              sortKey: "full_name",
              alignment: isArabic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            tableHeaderCell(
              tr("تاريخ الولادة", "Birth Date"),
              sortKey: "birth_date",
            ),
            tableHeaderCell(
              tr("الهاتف", "Phone"),
            ),
            tableHeaderCell(
              tr("الطبيب المعالج", "Doctor"),
              sortKey: "treating_doctor",
            ),
            tableHeaderCell(
              tr("حالة المعالجة", "Status"),
              sortKey: "is_finished",
            ),
            tableHeaderCell(
              tr("المبلغ المتبقي", "Balance"),
              sortKey: "remaining_amount",
            ),
            tableHeaderCell(tr("إجراءات", "Actions")),
          ],
        ),
      ],
    );
  }

  Widget buildTableBody() {
    return Table(
      columnWidths: columnWidths,
      border: TableBorder(
        bottom: BorderSide(color: _border(context), width: 1),
        left: BorderSide(color: _border(context), width: 1),
        right: BorderSide(color: _border(context), width: 1),
        horizontalInside: BorderSide(color: _border(context), width: 1),
        verticalInside: BorderSide(color: _border(context), width: 1),
      ),
      children: [
        ...docs.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value.data() as Map<String, dynamic>;
          final id = entry.value.id;
          final String fullName = "${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['grandfather_name'] ?? ''} ${data['last_name'] ?? ''}";
           final bool finished = data['is_finished'] ?? false;
          
          final String rawPhone = (data['phone'] ?? "").toString();
          final String uPhone = _phoneDigits(rawPhone);
          final String displayPhone = _formatPhoneNumber(rawPhone);
          final String bDateStr = data['birth_date'] != null
              ? (data['birth_date'] as Timestamp)
                  .toDate()
                  .toString()
                  .split(' ')[0]
              : "-";
          final bool isHovered = hoveredPatientRowId == id;

          return TableRow(
            decoration: BoxDecoration(
              color: isHovered
                  ? lapisBlue.withOpacity(0.08)
                  : finished
                      ? Colors.green.withOpacity(0.05)
                      : index.isEven
                          ? _surface(context)
                          : _softFill(context),
            ),
            children: [
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    "${startIndex + index + 1}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    (data['serial_number'] ?? "").toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    (data['file_number'] ?? "").toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    "${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['grandfather_name'] ?? ''} ${data['last_name'] ?? ''}",
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  alignment: isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    bDateStr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PopupMenuButton<int>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.contact_phone,
                            size: 20,
                            color: lightBlue,
                          ),
                          color: _surface(context),
                          onSelected: (val) {
                            if (uPhone.isEmpty) return;

                            if (val == 1) {
                              launchUrl(Uri.parse("tel:$uPhone"));
                            }
                            if (val == 2) {
                              launchUrl(Uri.parse("sms:$uPhone"));
                            }
                            if (val == 3) {
                              launchUrl(
                                Uri.parse("https://wa.me/$uPhone"),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 1,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr("اتصال", "Call"),
                                    style: TextStyle(
                                      color: _textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 2,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.sms,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr("رسالة SMS", "SMS"),
                                    style: TextStyle(
                                      color: _textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 3,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr("واتساب", "WhatsApp"),
                                    style: TextStyle(
                                      color: _textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            displayPhone.isEmpty ? "-" : displayPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: _textPrimary(context),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    (data['treating_doctor'] ?? "-").toString(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textPrimary(context)),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Checkbox(
                    activeColor: Colors.green,
                    value: finished,
                    onChanged: (v) => PatientsService.updatePatientField(
                      docId: id,
                      field: 'is_finished',
                      value: v,
                    ),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Text(
                    "${data['remaining_amount'] ?? 0} JD",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              hoverablePatientRowCell(
                id,fullName,
                tableBodyCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.green,
                          size: 20,
                        ),
                        onPressed: () => _prepareEdit(data, id),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Color(0xFFE57373),
                          size: 20,
                        ),
                        onPressed: () => _showDeleteConfirmation(id),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final double tableWidth = constraints.maxWidth > minTableWidth
          ? constraints.maxWidth
          : minTableWidth;

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: SelectionArea(
                child: Column(
                  children: [
                    buildTableHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: buildTableBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _badgeChip({
    required IconData icon,
    required String label,
    Color? color,
    Color? background,
  }) {
    final Color mainColor = color ?? lapisBlue;
    final Color bgColor = background ?? mainColor.withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mainColor.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: mainColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: mainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }

  Widget _buildMobilePatientCard(
    Map<String, dynamic> data,
    String id,
    int index,
  ) {
    final String fullName = "${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['grandfather_name'] ?? ''} ${data['last_name'] ?? ''}";

    final bool finished = data['is_finished'] ?? false;
    final String rawPhone = (data['phone'] ?? "").toString();
    final String uPhone = _phoneDigits(rawPhone);
    final String displayPhone = _formatPhoneNumber(rawPhone);
    final String bDateStr = data['birth_date'] != null
        ? (data['birth_date'] as Timestamp).toDate().toString().split(' ')[0]
        : "-";
   
    final String serial = (data['serial_number'] ?? "").toString();
    final String fileNumber = (data['file_number'] ?? "").toString();
    final String doctorName = (data['treating_doctor'] ?? "-").toString();
    final String balance = "${data['remaining_amount'] ?? 0} JD";

    return GestureDetector(
      onDoubleTap: () => _openProfile(id,fullName),
      child: SelectionArea(
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: finished
                ? Colors.green.withOpacity(0.20)
                : _border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: lapisBlue.withOpacity(0.12),
                  child: Text(
                    fullName.trim().isNotEmpty
                        ? fullName.trim()[0].toUpperCase()
                        : "?",
                    style: const TextStyle(
                      color: lapisBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isArabic
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: lapisBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctorName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _badgeChip(
                  icon: Icons.payments_outlined,
                  label: balance,
                  color: Colors.red,
                  background: Colors.red.withOpacity(0.08),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
              children: [
                _badgeChip(
                  icon: Icons.confirmation_number_outlined,
                  label: "${tr("رقم", "Serial")} $serial",
                ),
                _badgeChip(
                  icon: Icons.folder_open_outlined,
                  label: "${tr("ملف", "File")} $fileNumber",
                ),
                _badgeChip(
                  icon: Icons.calendar_today_outlined,
                  label: bDateStr,
                ),
                _badgeChip(
                  icon: Icons.person_outline,
                  label: finished
                      ? tr("منتهية", "Finished")
                      : tr("قيد المعالجة", "In Progress"),
                  color: finished ? Colors.green : lapisBlue,
                  background: finished
                      ? Colors.green.withOpacity(0.10)
                      : lapisBlue.withOpacity(0.10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _softFill(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: lapisBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        displayPhone.isEmpty ? "-" : displayPhone,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: _textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _mobileQuickAction(
                    icon: Icons.phone,
                    color: Colors.green,
                    onTap: () {
                      if (uPhone.isNotEmpty) {
                        launchUrl(Uri.parse("tel:$uPhone"));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _mobileQuickAction(
                    icon: Icons.sms,
                    color: Colors.blue,
                    onTap: () {
                      if (uPhone.isNotEmpty) {
                        launchUrl(Uri.parse("sms:$uPhone"));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _mobileQuickAction(
                    icon: Icons.chat,
                    color: Colors.green,
                    onTap: () {
                      if (uPhone.isNotEmpty) {
                        launchUrl(Uri.parse("https://wa.me/$uPhone"));
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: finished
                    ? Colors.green.withOpacity(0.06)
                    : lapisBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      finished
                          ? tr("حالة المعالجة: منتهية",
                              "Treatment Status: Finished")
                          : tr("حالة المعالجة: قيد المتابعة",
                              "Treatment Status: Ongoing"),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: finished ? Colors.green.shade700 : lapisBlue,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: finished,
                    activeColor: Colors.green,
                   onChanged: (v) => PatientsService.updatePatientField(
                      docId: id,
                      field: 'is_finished',
                      value: v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openProfile(id,fullName),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: Text(tr("ملف المريض", "Patient Profile")),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lapisBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _mobileQuickAction(
                  icon: Icons.edit,
                  color: Colors.green,
                  onTap: () => _prepareEdit(data, id),
                ),
                const SizedBox(width: 10),
                _mobileQuickAction(
                  icon: Icons.delete,
                  color: Colors.redAccent,
                  onTap: () => _showDeleteConfirmation(id),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<QueryDocumentSnapshot> docs) {
if (docs.isEmpty) {
  return PatientsEmptyState(isArabic: isArabic).simpleText(context);
}

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final id = docs[index].id;
        return _buildMobilePatientCard(data, id, index);
      },
    );
  }

  Widget _buildReminderLanguageField() {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return DropdownButtonFormField<String>(
      initialValue: preferredLanguage,
      decoration: InputDecoration(
        labelText: tr("لغة التذكير", "Reminder Language"),
        labelStyle: TextStyle(fontSize: compact ? 12.5 : 14),
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 12 : 15,
        ),
      ),
      dropdownColor: _surface(context),
      style: TextStyle(
        color: _textPrimary(context),
        fontSize: compact ? 13 : 14,
      ),
      items: [
        DropdownMenuItem(
          value: "ar",
          child: Text(
            tr("العربية", "Arabic"),
            style: TextStyle(
              color: _textPrimary(context),
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
        DropdownMenuItem(
          value: "en",
          child: Text(
            "English",
            style: TextStyle(
              color: _textPrimary(context),
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => preferredLanguage = v);
      },
    );
  }

  Widget _buildReminderToggleField() {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: _surface(context),
        border: Border.all(color: _border(context)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  tr("تذكير البريد الإلكتروني", "Email Reminder"),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: lapisBlue,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                SizedBox(height: compact ? 3 : 4),
                Text(
                  tr(
                    "إرسال تذكير تلقائي عند وجود جلسة قادمة",
                    "Auto send reminder when next session is set",
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12.5,
                    color: _textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 8 : 12),
          Transform.scale(
            scale: compact ? 0.86 : 1,
            child: Switch.adaptive(
              value: emailReminderEnabled,
              activeColor: Colors.green,
              onChanged: (v) => setState(() => emailReminderEnabled = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientFormProgress(bool isCompactLayout) {
    final bool isBasicStep = _patientFormStep == 0;

    Widget stepCircle({
      required int step,
      required IconData icon,
      required String label,
    }) {
      final bool active = _patientFormStep == step;
      final bool done = _patientFormStep > step;
      final Color color = active || done ? lapisBlue : _border(context);

      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompactLayout ? 32 : 38,
              height: isCompactLayout ? 32 : 38,
              decoration: BoxDecoration(
                color: active || done ? lapisBlue : _surface(context),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                done ? Icons.check_rounded : icon,
                color: active || done ? Colors.white : _textSecondary(context),
                size: isCompactLayout ? 17 : 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? lapisBlue : _textSecondary(context),
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                fontSize: isCompactLayout ? 11.5 : 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            stepCircle(
              step: 0,
              icon: Icons.person_outline,
              label: tr("المعلومات الأساسية", "Basic Info"),
            ),
            Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(
                  bottom: isCompactLayout ? 22 : 28,
                ),
                decoration: BoxDecoration(
                  color: isBasicStep ? _border(context) : lapisBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            stepCircle(
              step: 1,
              icon: Icons.medical_services_outlined,
              label: tr("الطبية والمالية", "Medical & Financial"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: _patientFormStep == 0 ? 0.5 : 1,
            color: lapisBlue,
            backgroundColor: _border(context).withOpacity(0.35),
          ),
        ),
      ],
    );
  }

  Future<bool> _validateBasicPatientStep() async {
    setState(() => addError = null);
    _fixAllCurrentInputValues();

    final serialText = serialNum.text.trim();

    if (serialText.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الرقم التسلسلي", "⚠️ Please enter Serial Number"));
      return false;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(serialText)) {
      setState(() => addError = tr(
            "⚠️ الرقم التسلسلي يجب أن يحتوي على أرقام فقط",
            "⚠️ Serial number must contain digits only",
          ));
      return false;
    }

    final serialExists = await _serialNumberExists(
      serialText,
      excludePatientDocId: isEditMode ? editingDocId : null,
    );

    if (!mounted) return false;

    if (serialExists) {
      setState(() => addError = tr(
            "⚠️ الرقم التسلسلي موجود مسبقًا، يرجى اختيار رقم آخر",
            "⚠️ Serial number already exists, please choose another number",
          ));
      return false;
    }

    if (fileNum.text.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال رقم الملف", "⚠️ Please enter File Number"));
      return false;
    }

    if (birthDate == null) {
      setState(() => addError =
          tr("⚠️ يرجى اختيار تاريخ الولادة", "⚠️ Please select Birth Date"));
      return false;
    }

    if (fName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الاسم الأول", "⚠️ Please enter First Name"));
      return false;
    }

    if (mName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال اسم الأب", "⚠️ Please enter Father Name"));
      return false;
    }

    if (gName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال اسم الجد", "⚠️ Please enter Grandfather Name"));
      return false;
    }

    if (lName.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال العائلة", "⚠️ Please enter Family Name"));
      return false;
    }

    if (fName.text.trim().length > 15 ||
        mName.text.trim().length > 15 ||
        gName.text.trim().length > 15 ||
        lName.text.trim().length > 15) {
      setState(() => addError = tr(
            "⚠️ كل خانة اسم يجب ألا تتجاوز 15 حرفًا",
            "⚠️ Each name field must be 15 characters or less",
          ));
      return false;
    }

    if (nationality.text.trim().isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال الجنسية", "⚠️ Please enter Nationality"));
      return false;
    }

    if (phoneNum.text.isEmpty) {
      setState(() => addError =
          tr("⚠️ يرجى إدخال رقم الهاتف", "⚠️ Please enter Phone Number"));
      return false;
    }

    if (!_isValidJordanPhone(phoneNum.text)) {
      setState(() => addError = tr(
            "⚠️ رقم الهاتف يجب أن يكون 10 أرقام ويبدأ بـ 079 أو 078 أو 077",
            "⚠️ Phone number must be 10 digits and start with 079, 078, or 077",
          ));
      return false;
    }

    if (address.text.trim().isEmpty) {
      setState(() =>
          addError = tr("⚠️ يرجى إدخال العنوان", "⚠️ Please enter Address"));
      return false;
    }

    final trimmedEmail = emailController.text.trim().toLowerCase();
    if (trimmedEmail.isNotEmpty && !_isValidEmail(trimmedEmail)) {
      setState(() => addError =
          tr("⚠️ البريد الإلكتروني غير صالح", "⚠️ Invalid email address"));
      return false;
    }

    if (emailReminderEnabled && trimmedEmail.isEmpty) {
      setState(() => addError = tr(
            "⚠️ فعّل التذكير بعد إدخال البريد الإلكتروني",
            "⚠️ Enter an email before enabling reminders",
          ));
      return false;
    }

    if (emailReminderEnabled && !_isValidEmail(trimmedEmail)) {
      setState(() => addError =
          tr("⚠️ البريد الإلكتروني غير صالح", "⚠️ Invalid email address"));
      return false;
    }

    return true;
  }

  Future<void> _goToMedicalFinancialStep() async {
    if (isSavingPatient) return;

    setState(() {
      isSavingPatient = true;
    });

    try {
      final valid = await _validateBasicPatientStep();
      if (!mounted || !valid) return;
      setState(() {
        _patientFormStep = 1;
        addError = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          isSavingPatient = false;
        });
      }
    }
  }

  void _goToBasicPatientStep() {
    setState(() {
      _patientFormStep = 0;
      addError = null;
    });
  }

  Widget _buildBasicPatientFormStep(bool isCompactLayout) {
    return Column(
      children: [
        _sectionTitle(tr("المعلومات الأساسية", "Basic Info")),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  serialNum,
                  tr("الرقم التسلسلي", "Serial"),
                  isNum: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildInput(
                  fileNum,
                  tr("رقم الملف", "File Num"),
                  isNum: true,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDatePicker(
                  tr("تاريخ الولادة", "Birth Date"),
                  birthDate,
                  (d) => setState(() => birthDate = d),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildInput(
                serialNum,
                tr("الرقم التسلسلي", "Serial"),
                isNum: true,
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(
                fileNum,
                tr("رقم الملف", "File Num"),
                isNum: true,
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildDatePicker(
                tr("تاريخ الولادة", "Birth Date"),
                birthDate,
                (d) => setState(() => birthDate = d),
              ),
            ],
          ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(child: _buildInput(fName, tr("الاسم الأول", "First Name"))),
              const SizedBox(width: 10),
              Expanded(child: _buildInput(mName, tr("الأب", "Father"))),
              const SizedBox(width: 10),
              Expanded(child: _buildInput(gName, tr("الجد", "Grandfather"))),
              const SizedBox(width: 10),
              Expanded(child: _buildInput(lName, tr("العائلة", "Family"))),
            ],
          )
        else
          Column(
            children: [
              _buildInput(fName, tr("الاسم الأول", "First Name")),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(mName, tr("الأب", "Father")),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(gName, tr("الجد", "Grandfather")),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(lName, tr("العائلة", "Family")),
            ],
          ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  nationality,
                  tr("الجنسية", "Nationality"),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(child: _buildGenderDropdown()),
              const SizedBox(width: 15),
              Expanded(
                flex: 2,
                child: _buildInput(
                  phoneNum,
                  tr("رقم الهاتف", "Phone Number"),
                  isNum: true,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildInput(nationality, tr("الجنسية", "Nationality")),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildGenderDropdown(),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(
                phoneNum,
                tr("رقم الهاتف", "Phone Number"),
                isNum: true,
              ),
            ],
          ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        _buildInput(
          emailController,
          tr("البريد الإلكتروني", "Email"),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        _buildInput(address, tr("العنوان", "Address")),
        SizedBox(height: isCompactLayout ? 10 : 15),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(child: _buildReminderLanguageField()),
              const SizedBox(width: 15),
              Expanded(child: _buildReminderToggleField()),
            ],
          )
        else
          Column(
            children: [
              _buildReminderLanguageField(),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildReminderToggleField(),
            ],
          ),
      ],
    );
  }

  Widget _buildMedicalFinancialFormStep(bool isCompactLayout) {
    return Column(
      children: [
        _sectionTitle(tr("المعلومات الطبية والمالية", "Medical & Financial")),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  tr("أول زيارة", "First Visit"),
                  firstVisit,
                  (d) => setState(() => firstVisit = d),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildDatePicker(
                  tr("آخر زيارة", "Last Visit"),
                  lastVisit,
                  (d) => setState(() => lastVisit = d),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildInput(
                  doctor,
                  tr("الطبيب المعالج", "Doctor"),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildDatePicker(
                tr("أول زيارة", "First Visit"),
                firstVisit,
                (d) => setState(() => firstVisit = d),
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildDatePicker(
                tr("آخر زيارة", "Last Visit"),
                lastVisit,
                (d) => setState(() => lastVisit = d),
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(doctor, tr("الطبيب المعالج", "Doctor")),
            ],
          ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildNextSessionDatePicker(
                  tr("الجلسة القادمة", "Next Session"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildNextSessionTimePicker(),
              ),
              const SizedBox(width: 15),
              Flexible(
                child: Text(
                  tr("حالة المعالجة:", "Treatment Status:"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Checkbox(
                activeColor: Colors.green,
                value: isFinished,
                onChanged: (v) => setState(() => isFinished = v!),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildNextSessionDatePicker(
                tr("الجلسة القادمة", "Next Session"),
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildNextSessionTimePicker(),
              SizedBox(height: isCompactLayout ? 10 : 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr("حالة المعالجة:", "Treatment Status:"),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context),
                      ),
                    ),
                  ),
                  Checkbox(
                    activeColor: Colors.green,
                    value: isFinished,
                    onChanged: (v) => setState(() => isFinished = v!),
                  ),
                ],
              ),
            ],
          ),
        SizedBox(height: isCompactLayout ? 10 : 15),
        _buildInput(
          notes,
          tr("ملاحظات طبية / عامة", "Medical / General Notes"),
          maxLines: 3,
          focusNode: notesFocusNode,
        ),
        SizedBox(height: isCompactLayout ? 14 : 20),
        if (!isCompactLayout)
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  reqAmount,
                  tr("المطلوب", "Required"),
                  isNum: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInput(
                  paidAmount,
                  tr("المدفوع", "Paid"),
                  isNum: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInput(
                  discount,
                  tr("خصم", "Discount"),
                  isNum: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInput(
                  remaining,
                  tr("المتبقي", "Remaining"),
                  enabled: false,
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildInput(
                reqAmount,
                tr("المطلوب", "Required"),
                isNum: true,
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(
                paidAmount,
                tr("المدفوع", "Paid"),
                isNum: true,
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(
                discount,
                tr("خصم", "Discount"),
                isNum: true,
              ),
              SizedBox(height: isCompactLayout ? 10 : 15),
              _buildInput(
                remaining,
                tr("المتبقي", "Remaining"),
                enabled: false,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPatientFormActions(bool isCompactLayout) {
    final bool isBasicStep = _patientFormStep == 0;
    final double horizontalPadding = isCompactLayout ? 42 : 60;
    final double verticalPadding = isCompactLayout ? 16 : 20;

    final nextButton = ElevatedButton(
      onPressed: isSavingPatient ? null : _goToMedicalFinancialStep,
      style: ElevatedButton.styleFrom(
        backgroundColor: lapisBlue,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        tr("التالي", "Next"),
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompactLayout ? 14 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final backButton = OutlinedButton(
      onPressed: isSavingPatient ? null : _goToBasicPatientStep,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        tr("السابق", "Back"),
        style: const TextStyle(fontSize: 16),
      ),
    );

    final saveButton = ElevatedButton(
      onPressed: isSavingPatient ? null : _submitPatientForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: lapisBlue,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        tr("حفظ البيانات", "Save"),
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompactLayout ? 14 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final cancelButton = OutlinedButton(
      onPressed: isSavingPatient ? null : _closePatientCard,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        tr("إلغاء", "Cancel"),
        style: const TextStyle(fontSize: 16),
      ),
    );

    if (!isCompactLayout) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: isBasicStep
            ? [nextButton, const SizedBox(width: 15), cancelButton]
            : [backButton, const SizedBox(width: 15), saveButton, const SizedBox(width: 15), cancelButton],
      );
    }

    return Column(
      children: isBasicStep
          ? [
              SizedBox(width: double.infinity, child: nextButton),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: cancelButton),
            ]
          : [
              SizedBox(width: double.infinity, child: backButton),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: saveButton),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: cancelButton),
            ],
    );
  }

  Widget _buildFormDialog(bool isCompactLayout, double dialogWidth) {
    return Center(
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.only(
          top: isCompactLayout ? 20 : 30,
          bottom: isCompactLayout ? 20 : 30,
          left: isCompactLayout ? 14 : 30,
          right: isCompactLayout ? 14 : 30,
        ),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(blurRadius: 25, color: Colors.black45),
          ],
        ),
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
              if (notesFocusNode.hasFocus) {
                return KeyEventResult.ignored;
              }

              if (_patientFormStep == 0) {
                _goToMedicalFinancialStep();
              } else {
                _submitPatientForm();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isEditMode
                            ? tr("بطاقة بيانات المريض", "Patient Information Card")
                            : tr("إضافة مريض جديد", "Add New Patient"),
                        style: TextStyle(
                          fontSize: isCompactLayout ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: lapisBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _textPrimary(context)),
                      onPressed: _closePatientCard,
                    ),
                  ],
                ),
                if (addError != null)
                  Text(
                    addError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Divider(height: isCompactLayout ? 22 : 30, color: _border(context)),
                _buildPatientFormProgress(isCompactLayout),
                SizedBox(height: isCompactLayout ? 18 : 26),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey<int>(_patientFormStep),
                    child: _patientFormStep == 0
                        ? _buildBasicPatientFormStep(isCompactLayout)
                        : _buildMedicalFinancialFormStep(isCompactLayout),
                  ),
                ),
                SizedBox(height: isCompactLayout ? 20 : 30),
                _buildPatientFormActions(isCompactLayout),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildPaginationBar(int totalPages) {
  return PatientsPagination(
    totalPages: totalPages,
    currentPage: _currentPage,
    isDark: _isDark,
    onPageChanged: (page) {
      setState(() => currentPage = page);
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 1,
      searchController: searchController,
      onSearchChanged: (v) => setState(() {
        searchQuery = v.toLowerCase();
        currentPage = 1;
      }),
      onLanguageChanged: (val) => setState(() {
        isArabic = val;
        if (!isAddingPatient) {
          preferredLanguage = isArabic ? "ar" : "en";
        }
      }),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobileLayout = constraints.maxWidth < 1100;
          final bool isCompactDialog = constraints.maxWidth < 1000;
          final double dialogWidth = isCompactDialog
              ? min(constraints.maxWidth * 0.95, 760)
              : min(constraints.maxWidth * 0.95, 1000);
          final double pagePadding = constraints.maxWidth < 700 ? 12 : 20;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pagePadding,
                  vertical: constraints.maxWidth < 700 ? 14 : 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: PatientsService.watchPatients(),
                      builder: (context, snapshot) {
                        return isMobileLayout
                            ? _buildMobileHeader(snapshot)
                            : _buildDesktopHeader(snapshot);
                      },
                    ),
                    SizedBox(height: isMobileLayout ? 14 : 25),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: PatientsService.watchPatients(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              decoration: BoxDecoration(
                                color: _surface(context),
                                border: Border.all(color: _border(context)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final docs = _prepareDocs(snapshot.data!);

                          final int totalItems = docs.length;
                          final int totalPages = totalItems == 0
                              ? 0
                              : (totalItems / _rowsPerPage).ceil();

                          if (totalPages > 0 && _currentPage > totalPages) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => currentPage = totalPages);
                              }
                            });
                          }

                          final int safePage = totalPages == 0
                              ? 1
                              : _currentPage > totalPages
                                  ? totalPages
                                  : _currentPage;

                          final int startIndex = (safePage - 1) * _rowsPerPage;
                          int endIndex = startIndex + _rowsPerPage;
                          if (endIndex > totalItems) endIndex = totalItems;

                          final List<QueryDocumentSnapshot> pagedDocs =
                              totalItems > 0
                                  ? docs.sublist(startIndex, endIndex)
                                  : [];

                       if (docs.isEmpty) {
  return PatientsEmptyState(isArabic: isArabic);
}

                        return Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Expanded(
      child: isMobileLayout
          ? Container(
              decoration: BoxDecoration(
                color: _surface(context),
                border: Border.all(
                  color: _border(context),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: EdgeInsets.all(
                  constraints.maxWidth < 700 ? 10 : 14,
                ),
                child: _buildMobileCards(pagedDocs),
              ),
            )
          : _buildDesktopTable(
              pagedDocs,
              startIndex,
            ),
    ),
    if (totalPages > 1)
      _buildPaginationBar(totalPages),
  ],
);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (successMessage != null) _buildSuccessMessageBox(constraints),
              if (isAddingPatient)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Padding(
                    padding: EdgeInsets.all(
                      constraints.maxWidth < 700 ? 10 : 16,
                    ),
                    child: _buildFormDialog(isCompactDialog, dialogWidth),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int? _maxLengthForController(TextEditingController controller) {
    if (controller == fName ||
        controller == mName ||
        controller == gName ||
        controller == lName) {
      return 15;
    }

    if (controller == phoneNum) return 10;

    if (controller == serialNum) return 6;
    if (controller == fileNum) return 6;

    if (controller == nationality) return 20;
    if (controller == doctor) return 30;
    if (controller == address) return 60;
    if (controller == notes) return 200;

    if (controller == reqAmount ||
        controller == paidAmount ||
        controller == discount ||
        controller == newPayments ||
        controller == remaining ||
        controller == finalBalance) {
      return 8;
    }

    if (controller == emailController) return 254;

    return null;
  }

  bool _digitsOnlyController(TextEditingController controller) {
    return controller == phoneNum ||
        controller == serialNum ||
        controller == fileNum ||
        controller == reqAmount ||
        controller == paidAmount ||
        controller == discount ||
        controller == newPayments ||
        controller == remaining ||
        controller == finalBalance;
  }

  String _fixedInputValue(TextEditingController controller, String value) {
    String fixed = value;

    if (_digitsOnlyController(controller)) {
      fixed = fixed.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (controller == emailController) {
      fixed = fixed
          .replaceAll(RegExp(r'\s'), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9@._%+\-]'), '');
    }

    final maxLength = _maxLengthForController(controller);
    if (maxLength != null && fixed.length > maxLength) {
      fixed = fixed.substring(0, maxLength);
    }

    return fixed;
  }

  void _setFixedControllerValue(
    TextEditingController controller,
    String fixedText, {
    int? oldOffset,
  }) {
    final int safeOffset = oldOffset == null || oldOffset < 0
        ? fixedText.length
        : min(oldOffset, fixedText.length);

    controller.value = TextEditingValue(
      text: fixedText,
      selection: TextSelection.collapsed(offset: safeOffset),
      composing: TextRange.empty,
    );
  }

  void _fixControllerValue(TextEditingController controller) {
    if (_isFixingInputText) return;

    final oldText = controller.text;
    final fixedText = _fixedInputValue(controller, oldText);

    if (oldText == fixedText) return;

    _isFixingInputText = true;
    _setFixedControllerValue(
      controller,
      fixedText,
      oldOffset: controller.selection.baseOffset,
    );
    _isFixingInputText = false;
  }

  void _attachLimitListener(TextEditingController controller) {
    controller.addListener(() {
      _fixControllerValue(controller);
    });
  }

  void _attachAllInputLimits() {
    final controllers = [
      serialNum,
      fileNum,
      fName,
      mName,
      gName,
      lName,
      phoneNum,
      emailController,
      address,
      nationality,
      doctor,
      notes,
      reqAmount,
      paidAmount,
      discount,
      newPayments,
      remaining,
      finalBalance,
    ];

    for (final controller in controllers) {
      _attachLimitListener(controller);
    }
  }

  void _fixAllCurrentInputValues() {
    final controllers = [
      serialNum,
      fileNum,
      fName,
      mName,
      gName,
      lName,
      phoneNum,
      emailController,
      address,
      nationality,
      doctor,
      notes,
      reqAmount,
      paidAmount,
      discount,
      newPayments,
      remaining,
      finalBalance,
    ];

    _isFixingInputText = true;

    for (final controller in controllers) {
      final fixedText = _fixedInputValue(controller, controller.text);

      if (fixedText != controller.text) {
        _setFixedControllerValue(controller, fixedText);
      }
    }

    _isFixingInputText = false;
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool isNum = false,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    final bool compact = MediaQuery.of(context).size.width < 700;

 // في _buildInput، غيري هذا الجزء:
final int? maxLength = _maxLengthForController(controller);
final inputFormatters = <TextInputFormatter>[];

if (controller == emailController) {
  inputFormatters.add(FilteringTextInputFormatter.deny(RegExp(r'\s')));
  inputFormatters.add(
    FilteringTextInputFormatter.allow(
      RegExp(r'[A-Za-z0-9@._%+\-]'),
    ),
  );
} else if (isNum || _digitsOnlyController(controller)) {
  inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
}

// LengthLimitingTextInputFormatter دايماً آخر واحد
if (maxLength != null) {
  inputFormatters.add(LengthLimitingTextInputFormatter(maxLength));
}

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType ??
          (maxLines > 1
              ? TextInputType.multiline
              : ((isNum || _digitsOnlyController(controller))
                  ? TextInputType.number
                  : TextInputType.text)),
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
      onChanged: (_) {
        _fixControllerValue(controller);
      },
      onEditingComplete: enabled && maxLines == 1
          ? () => _submitPatientForm()
          : null,
      onSubmitted: enabled && maxLines == 1
          ? (_) => _submitPatientForm()
          : null,
      style: TextStyle(
        color: _textPrimary(context),
        fontSize: compact ? 13 : 14,
      ),
      inputFormatters: inputFormatters,
      buildCounter: (
        context, {
        required int currentLength,
        required bool isFocused,
        required int? maxLength,
      }) {
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        labelStyle: TextStyle(
          color: _textSecondary(context),
          fontSize: compact ? 12.5 : 14,
        ),
        border: const OutlineInputBorder(),
        filled: !enabled,
        fillColor: enabled
            ? (_isDark ? const Color(0xFF1F2937) : Colors.transparent)
            : (_isDark ? const Color(0xFF111827) : Colors.grey.shade100),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 12 : 15,
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onPick,
  ) {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 12 : 15,
        ),
        decoration: BoxDecoration(
          color: _surface(context),
          border: Border.all(color: _border(context)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: compact ? 16 : 18,
              color: lapisBlue,
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                date == null ? label : date.toString().split(' ')[0],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary(context),
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSessionDatePicker(String label) {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return InkWell(
      onTap: _pickNextSessionDate,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 12 : 15,
        ),
        decoration: BoxDecoration(
          color: _surface(context),
          border: Border.all(color: _border(context)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: compact ? 16 : 18,
              color: lapisBlue,
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                nextSession == null ? label : nextSession.toString().split(' ')[0],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary(context),
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSessionTimePicker() {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return InkWell(
      onTap: _pickNextSessionTime,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 12 : 15,
        ),
        decoration: BoxDecoration(
          color: _surface(context),
          border: Border.all(color: _border(context)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: compact ? 16 : 18,
              color: lapisBlue,
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                nextSessionTime == null
                    ? tr("الساعة", "Time")
                    : _formatTimeOfDayForStorage(nextSessionTime),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary(context),
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return Container(
      height: compact ? 44 : null,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: _surface(context),
        border: Border.all(color: _border(context)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: gender,
          isExpanded: true,
          dropdownColor: _surface(context),
          style: TextStyle(
            color: _textPrimary(context),
            fontSize: compact ? 13 : 14,
          ),
          items: ["ذكر", "أنثى"]
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(
                      color: _textPrimary(context),
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => gender = v!),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final bool compact = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: compact ? 10 : 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.bold,
          color: lapisBlue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

}