import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../../core/layout/custom_layout.dart';
import 'home_screen.dart' as home;
import '../../../core/theme/app_theme_controller.dart';
import '../services/appointments_service.dart';
import '../utils/appointments_utils.dart';
import '../widgets/appointments_empty_state.dart';
import '../widgets/appointments_success_message.dart';
// مكتبات التصدير والطباعة
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

// EmailJS config
const String emailJsServiceId = 'service_x7hpnpg';
const String emailJsTemplateId = 'template_aer061c';
const String emailJsPublicKey = 'qbi9Ezg0zYPm-DYpn';
const String clinicName = 'VividDent';

class BookingsScreen extends StatefulWidget {
  final String username;
  final bool initialArabic;

  const BookingsScreen({
    super.key,
    required this.username,
    required this.initialArabic,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  static final RegExp _splitWhitespaceRegex = RegExp(r'\s+');

  late bool isArabic;
  String searchQuery = "";
  final TextEditingController searchController = TextEditingController();

  String sortColumn = "date";
  bool isAscending = true;
  int currentPage = 1;
  int rowsPerPage = 10;
  bool isSendingPageReminders = false;
  String? hoveredBookingRowId;

  bool isAddingAppointment = false;
  bool isEditMode = false;
  String? editingDocId;
  String? addError;
  String? successMessage;
  Timer? successTimer;
  bool isSavingAppointment = false;

  final TextEditingController fName = TextEditingController();
  final TextEditingController mName = TextEditingController();
  final TextEditingController lName = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController serial = TextEditingController();

  TimeOfDay selectedTime = TimeOfDay.now();
  DateTime selectedDate = DateTime.now();

  Set<String>? selectedReminderDocIds;

  Set<String> get _selectedReminderDocIds {
    selectedReminderDocIds ??= <String>{};
    return selectedReminderDocIds!;
  }

  @override
  void initState() {
    super.initState();
    isArabic = widget.initialArabic;
  }

  @override
  void dispose() {
    searchController.dispose();
    fName.dispose();
    mName.dispose();
    lName.dispose();
    phone.dispose();
    serial.dispose();
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

  Color _softFill(BuildContext context) => _isDark
      ? const Color(0xFF1F2937)
      : lightGray.withOpacity(0.85);

String _phoneDigits(String value) {
  return AppointmentsUtils.phoneDigits(value);
}

bool _isValidJordanMobileNumber(String value) {
  return AppointmentsUtils.isValidJordanMobileNumber(value);
}

String _localJordanPhoneForInput(String value) {
  return AppointmentsUtils.localJordanPhoneForInput(value);
}

int _serialToInt(dynamic value) {
  return AppointmentsUtils.serialToInt(value);
}

String _whatsappPhoneNumber(String value) {
  return AppointmentsUtils.whatsappPhoneNumber(value);
}

String _formatPhoneNumber(String value) {
  return AppointmentsUtils.formatPhoneNumber(value);
}


int _minutesFromTimeString(String timeStr) {
  return AppointmentsUtils.minutesFromTimeString(timeStr);
}

Stream<QuerySnapshot> getFutureAppointments() {
  return AppointmentsService.watchFutureAppointments();
}

DateTime _dateOnly(DateTime date) {
  return AppointmentsUtils.dateOnly(date);
}

String _dateKey(DateTime date) {
  return AppointmentsUtils.dateKey(date);
}

DateTime? _dateFromAppointmentValue(dynamic value) {
  return AppointmentsUtils.dateFromAppointmentValue(value);
}

bool _isClinicWorkingDay(DateTime date) {
  return AppointmentsUtils.isClinicWorkingDay(date);
}

List<TimeOfDay> _clinicTimeSlots() {
  return AppointmentsUtils.clinicTimeSlots();
}

Set<String> _clinicTimeSlotKeys() {
  return AppointmentsUtils.clinicTimeSlotKeys();
}

String _timeKey(TimeOfDay time) {
  return AppointmentsUtils.timeKey(time);
}

String _timeKeyFromStoredValue(String value) {
  return AppointmentsUtils.timeKeyFromStoredValue(value);
}

String _formatTimeForStorage(TimeOfDay time) {
  return AppointmentsUtils.formatTimeForStorage(time);
}


Future<int> _nextSerialNumber() async {
  final snapshot = await AppointmentsService.getAppointments();

  int maxSerial = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final value = _serialToInt(data['serial_number']);

    if (value > maxSerial) {
      maxSerial = value;
    }
  }

  return maxSerial + 1;
}

Future<bool> _serialExists(
  String serialValue, {
  String? ignoreDocId,
}) async {
  final cleanSerial = serialValue.trim();

  if (cleanSerial.isEmpty) {
    return false;
  }

  final snapshot = await AppointmentsService.getBySerialNumber(cleanSerial);

  for (final doc in snapshot.docs) {
    if (ignoreDocId == null || doc.id != ignoreDocId) {
      return true;
    }
  }

  return false;
}

Future<void> _loadNextSerialForNewAppointment() async {
  final nextSerial = await _nextSerialNumber();

  if (!mounted || !isAddingAppointment || isEditMode) {
    return;
  }

  setState(() {
    serial.text = nextSerial.toString();
  });
}

Future<Set<String>> _bookedTimeKeysForDate(DateTime date) async {
  final snapshot = await AppointmentsService.getAppointmentsForDate(date);

  final booked = <String>{};

  for (final doc in snapshot.docs) {
    if (isEditMode && editingDocId != null && doc.id == editingDocId) {
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

  Future<List<TimeOfDay>> _availableTimeSlotsForDate(DateTime date) async {
    if (!_isClinicWorkingDay(date)) return [];

    final booked = await _bookedTimeKeysForDate(date);

    return _clinicTimeSlots().where((slot) {
      return !booked.contains(_timeKey(slot));
    }).toList();
  }

Future<Set<String>> _fullyBookedDateKeys(
  DateTime firstDate,
  DateTime lastDate,
) async {
  final allSlots = _clinicTimeSlotKeys();

  final snapshot = await AppointmentsService.getAppointmentsBetween(
    firstDate: firstDate,
    lastDate: lastDate,
  );

  final bookedByDate = <String, Set<String>>{};

  for (final doc in snapshot.docs) {
    if (isEditMode && editingDocId != null && doc.id == editingDocId) {
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

  DateTime? _firstSelectableAppointmentDate({
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

  Future<void> _setFirstAvailableAppointmentSlot() async {
    DateTime day = _dateOnly(DateTime.now());

    for (int i = 0; i < 365; i++) {
      final availableSlots = await _availableTimeSlotsForDate(day);

      if (!mounted || !isAddingAppointment || isEditMode) return;

      if (availableSlots.isNotEmpty) {
        setState(() {
          selectedDate = day;
          selectedTime = availableSlots.first;
          addError = null;
        });
        return;
      }

      day = day.add(const Duration(days: 1));
    }

    if (!mounted || !isAddingAppointment || isEditMode) return;

    setState(() {
      addError = tr(
        "⚠️ لا توجد مواعيد متاحة خلال الفترة القادمة",
        "⚠️ No available appointments in the upcoming period",
      );
    });
  }

  Future<bool> _validateSelectedAppointmentSlot() async {
    if (!_isClinicWorkingDay(selectedDate)) {
      setState(() {
        addError = tr(
          "⚠️ العيادة مغلقة يوم الجمعة",
          "⚠️ The clinic is closed on Friday",
        );
      });
      return false;
    }

    final selectedKey = _timeKey(selectedTime);
    if (!_clinicTimeSlotKeys().contains(selectedKey)) {
      setState(() {
        addError = tr(
          "⚠️ اختر وقتًا ضمن دوام العيادة من 9 صباحًا حتى 7 مساءً",
          "⚠️ Pick a time during clinic hours from 9 AM to 7 PM",
        );
      });
      return false;
    }

    final booked = await _bookedTimeKeysForDate(selectedDate);

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

  void _openAddAppointmentForm() {
    setState(() {
      isAddingAppointment = true;
      isEditMode = false;
      editingDocId = null;
      addError = null;
      fName.clear();
      mName.clear();
      lName.clear();
      phone.clear();
      serial.clear();
      selectedDate = _dateOnly(DateTime.now());
      selectedTime = const TimeOfDay(hour: 9, minute: 0);
    });

    unawaited(_loadNextSerialForNewAppointment());
    unawaited(_setFirstAvailableAppointmentSlot());
  }

  void _prepareEdit(Map<String, dynamic> data, String docId) {
    final String patientName = (data['patient_name'] ?? "").toString().trim();
    final parts = patientName.isEmpty
        ? <String>[]
        : patientName.split(_splitWhitespaceRegex);

    final int mins = _minutesFromTimeString((data['time'] ?? "").toString());

    setState(() {
      isAddingAppointment = true;
      isEditMode = true;
      editingDocId = docId;
      addError = null;

      fName.text = (data['first_name'] ?? (parts.isNotEmpty ? parts[0] : ""))
          .toString();
      mName.text = (data['father_name'] ?? (parts.length > 1 ? parts[1] : ""))
          .toString();
      lName.text = (data['last_name'] ??
              (parts.length > 2 ? parts.sublist(2).join(" ") : ""))
          .toString();

      phone.text = _localJordanPhoneForInput((data['phone'] ?? "").toString());
      serial.text = (data['serial_number'] ?? "").toString();

      if (data['date'] is Timestamp) {
        selectedDate = (data['date'] as Timestamp).toDate();
      } else {
        selectedDate = DateTime.now();
      }

      if (mins > 0) {
        selectedTime = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
      } else {
        selectedTime = TimeOfDay.now();
      }
    });
  }

  void _closeAppointmentForm() {
    setState(() {
      isAddingAppointment = false;
      isEditMode = false;
      editingDocId = null;
      addError = null;
      fName.clear();
      mName.clear();
      lName.clear();
      phone.clear();
      serial.clear();
      selectedDate = DateTime.now();
      selectedTime = TimeOfDay.now();
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
  return AppointmentsSuccessMessage(
    message: successMessage,
    constraints: constraints,
  );
}

  void _submitAppointmentForm([String? _]) {
    if (isSavingAppointment) return;
    unawaited(_saveAppointment());
  }

  Future<void> _saveAppointment() async {
    if (isSavingAppointment) return;

    setState(() {
      isSavingAppointment = true;
    });

    try {
      final cleanPhone = _phoneDigits(phone.text.trim());
      final cleanSerial = serial.text.trim();

      final String firstName = fName.text.trim();
      final String middleName = mName.text.trim();
      final String lastName = lName.text.trim();

      if (firstName.isEmpty) {
        setState(() => addError = tr(
              "⚠️ يرجى إدخال الاسم الأول",
              "⚠️ Please enter first name",
            ));
        return;
      }

      if (firstName.length > 15) {
        setState(() => addError = tr(
              "⚠️ الاسم الأول يجب ألا يتجاوز 15 حرفًا",
              "⚠️ First name must be 15 characters or less",
            ));
        return;
      }

      if (middleName.isEmpty) {
        setState(() => addError = tr(
              "⚠️ يرجى إدخال اسم الأب",
              "⚠️ Please enter middle name",
            ));
        return;
      }

      if (middleName.length > 15) {
        setState(() => addError = tr(
              "⚠️ اسم الأب يجب ألا يتجاوز 15 حرفًا",
              "⚠️ Middle name must be 15 characters or less",
            ));
        return;
      }

      if (lastName.isEmpty) {
        setState(() => addError = tr(
              "⚠️ يرجى إدخال الكنية",
              "⚠️ Please enter last name",
            ));
        return;
      }

      if (lastName.length > 15) {
        setState(() => addError = tr(
              "⚠️ الكنية يجب ألا تتجاوز 15 حرفًا",
              "⚠️ Last name must be 15 characters or less",
            ));
        return;
      }

      if (cleanPhone.isEmpty) {
        setState(() => addError = tr(
              "⚠️ يرجى إدخال رقم الهاتف",
              "⚠️ Please enter phone number",
            ));
        return;
      }

      if (!_isValidJordanMobileNumber(cleanPhone)) {
        setState(() => addError = tr(
              "⚠️ رقم الهاتف يجب أن يكون 10 أرقام ويبدأ بـ 079 أو 078 أو 077",
              "⚠️ Phone number must be 10 digits and start with 079, 078, or 077",
            ));
        return;
      }

      if (cleanSerial.isEmpty) {
        setState(() => addError = tr(
              "⚠️ يرجى إدخال الرقم التسلسلي",
              "⚠️ Please enter serial number",
            ));
        return;
      }

      if (_serialToInt(cleanSerial) <= 0) {
        setState(() => addError = tr(
              "⚠️ الرقم التسلسلي يجب أن يكون رقمًا أكبر من صفر",
              "⚠️ Serial number must be greater than zero",
            ));
        return;
      }

      final serialAlreadyExists = await _serialExists(
        cleanSerial,
        ignoreDocId: isEditMode ? editingDocId : null,
      );

      if (serialAlreadyExists) {
        setState(() => addError = tr(
              "⚠️ الرقم التسلسلي مستخدم مسبقًا، اختاري رقمًا آخر",
              "⚠️ Serial number already exists. Choose another one",
            ));
        return;
      }

      final slotIsAvailable = await _validateSelectedAppointmentSlot();
      if (!slotIsAvailable) return;

      final bool wasEditMode = isEditMode;

      final String fullName = "$firstName $middleName $lastName";

      final appointmentData = {
        'first_name': firstName,
        'father_name': middleName,
        'last_name': lastName,
        'patient_name': fullName,
        'phone': cleanPhone,
        'serial_number': cleanSerial,
        'price': 0.0,
        'time': _formatTimeForStorage(selectedTime),
        'attended': false,
        'date': Timestamp.fromDate(_dateOnly(selectedDate)),
        'updated_at': Timestamp.now(),
      };

if (isEditMode && editingDocId != null) {
  await AppointmentsService.updateAppointment(
    editingDocId!,
    appointmentData,
  );
} else {
  await AppointmentsService.addAppointment({
    ...appointmentData,
    'created_at': Timestamp.now(),
  });
}

      final today = _dateOnly(DateTime.now());
      final selected = _dateOnly(selectedDate);

      _closeAppointmentForm();

      _showSuccessMessage(
        wasEditMode
            ? tr(
                "تم تعديل الموعد بنجاح",
                "Appointment updated successfully",
              )
            : selected.isAtSameMomentAs(today)
                ? tr(
                    "تمت إضافة الموعد بصفحة مواعيد اليوم بنجاح",
                    "Appointment added to Today's page successfully",
                  )
                : tr(
                    "تمت إضافة الموعد بصفحة الحجوزات بنجاح",
                    "Appointment added to Bookings page successfully",
                  ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingAppointment = false;
        });
      }
    }
  }

  Future<void> _pickAppointmentDate() async {
    final firstDate = _dateOnly(DateTime.now());
    final lastDate = DateTime(2100);

    final fullyBookedDates = await _fullyBookedDateKeys(firstDate, lastDate);

    if (!mounted) return;

    final initialDate = _firstSelectableAppointmentDate(
      firstDate: firstDate,
      lastDate: lastDate,
      preferredDate: selectedDate,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.of(context).copyWith(primary: lapisBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final availableSlots = await _availableTimeSlotsForDate(picked);
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
      selectedDate = picked;
      addError = null;

      final selectedKey = _timeKey(selectedTime);
      final stillAvailable =
          availableSlots.any((slot) => _timeKey(slot) == selectedKey);

      if (!stillAvailable) {
        selectedTime = availableSlots.first;
      }
    });
  }

  Future<void> _pickAppointmentTime() async {
    final availableSlots = await _availableTimeSlotsForDate(selectedDate);

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
                alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
                children: availableSlots.map((slot) {
                  final bool active = _timeKey(slot) == _timeKey(selectedTime);

                  return ChoiceChip(
                    selected: active,
                    label: Text(_formatTimeForStorage(slot)),
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
        selectedTime = pickedTime;
        addError = null;
      });
    }
  }

  Future<void> _exportToPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("تقرير مواعيد المرضى والحجوزات")),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ["الهاتف", "الوقت", "التاريخ", "الاسم", "الرقم"],
            data: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final date = (d['date'] as Timestamp).toDate();
              return [
                _formatPhoneNumber((d['phone'] ?? "-").toString()),
                d['time'] ?? "-",
                "${date.year}-${date.month}-${date.day}",
                d['patient_name'] ?? "-",
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
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['BookingsReport'];

    sheetObject.appendRow([
      TextCellValue("الرقم التسلسلي"),
      TextCellValue("اسم المريض"),
      TextCellValue("التاريخ"),
      TextCellValue("الوقت"),
      TextCellValue("رقم الهاتف"),
    ]);

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['date'] as Timestamp).toDate();
      sheetObject.appendRow([
        TextCellValue(d['serial_number']?.toString() ?? ""),
        TextCellValue(d['patient_name']?.toString() ?? ""),
        TextCellValue("${date.year}-${date.month}-${date.day}"),
        TextCellValue(d['time']?.toString() ?? ""),
        TextCellValue(_formatPhoneNumber(d['phone']?.toString() ?? "")),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null && kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([fileBytes]));
      html.AnchorElement(href: url)
        ..setAttribute("download", "Future_Bookings.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  List<QueryDocumentSnapshot> _prepareDocs(QuerySnapshot snapshot) {
    final allDocs = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['patient_name'] ?? "").toString().toLowerCase();
      final phone = (data['phone'] ?? "").toString().toLowerCase();
      final phoneDigits = _phoneDigits(phone);
      final formattedPhone = _formatPhoneNumber(phone).toLowerCase();
      final serial = (data['serial_number'] ?? "").toString().toLowerCase();

      return name.contains(searchQuery) ||
          phone.contains(searchQuery) ||
          phoneDigits.contains(searchQuery) ||
          formattedPhone.contains(searchQuery) ||
          serial.contains(searchQuery);
    }).toList();

    allDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      dynamic valA = dataA[sortColumn] ?? "";
      dynamic valB = dataB[sortColumn] ?? "";

      if (sortColumn == "date" && valA is Timestamp && valB is Timestamp) {
        return isAscending
            ? valA.toDate().compareTo(valB.toDate())
            : valB.toDate().compareTo(valA.toDate());
      }

      if (sortColumn == "time") {
        valA = _minutesFromTimeString((dataA['time'] ?? "").toString());
        valB = _minutesFromTimeString((dataB['time'] ?? "").toString());
        return isAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      }

      if (sortColumn == "serial_number") {
        final numA =
            double.tryParse((dataA['serial_number'] ?? "0").toString()) ?? 0;
        final numB =
            double.tryParse((dataB['serial_number'] ?? "0").toString()) ?? 0;

        return isAscending ? numA.compareTo(numB) : numB.compareTo(numA);
      }

      return isAscending
          ? valA.toString().compareTo(valB.toString())
          : valB.toString().compareTo(valA.toString());
    });

    return allDocs;
  }

  void _openTodayPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => home.HomeScreen(
          username: widget.username,
          role: "admin",
          initialArabic: isArabic,
        ),
      ),
    );
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }



  String _getLanguage(Map<String, dynamic> data) {
    final language = (data['language'] ?? "").toString().toLowerCase();
    return language == "en" ? "en" : "ar";
  }

  DateTime? _getAppointmentDateTime(Map<String, dynamic> data) {
    final appointmentDateTime = data['appointment_datetime'];
    if (appointmentDateTime is Timestamp) {
      return appointmentDateTime.toDate();
    }

    final date = data['date'];
    if (date is Timestamp) {
      return date.toDate();
    }

    return null;
  }

  String _getWeekdayName(DateTime date, String language) {
    const arDays = [
      "الاثنين",
      "الثلاثاء",
      "الأربعاء",
      "الخميس",
      "الجمعة",
      "السبت",
      "الأحد",
    ];

    const enDays = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];

    return language == "en"
        ? enDays[date.weekday - 1]
        : arDays[date.weekday - 1];
  }

 String _formatDate(DateTime date) {
  return AppointmentsUtils.formatDate(date);
}

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;

    final regex = _emailRegex;
    return regex.hasMatch(trimmed);
  }

  bool _reminderEnabledForDoc(Map<String, dynamic> data) {
    return data['reminder_enabled'] is bool
        ? data['reminder_enabled'] as bool
        : true;
  }

  bool _canSendEmailReminderForDoc(Map<String, dynamic> data) {
    final email = (data['patient_email'] ?? "").toString().trim();

    if (!_reminderEnabledForDoc(data)) return false;
    if (!_isValidEmail(email)) return false;

    return true;
  }

  bool _canSendWhatsAppReminderForDoc(Map<String, dynamic> data) {
    final phone = (data['phone'] ?? "").toString().trim();
    final whatsappNumber = _whatsappPhoneNumber(phone);

    if (!_reminderEnabledForDoc(data)) return false;
    if (whatsappNumber.isEmpty) return false;

    return true;
  }

  bool _canSendReminderForDoc(Map<String, dynamic> data) {
    return _canSendEmailReminderForDoc(data) ||
        _canSendWhatsAppReminderForDoc(data);
  }

  List<QueryDocumentSnapshot> _selectedEmailReminderDocs(
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _selectedReminderDocIds.contains(doc.id) &&
          _canSendEmailReminderForDoc(data);
    }).toList();
  }

  List<QueryDocumentSnapshot> _selectedWhatsAppReminderDocs(
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _selectedReminderDocIds.contains(doc.id) &&
          _canSendWhatsAppReminderForDoc(data);
    }).toList();
  }


  int _selectedReminderCount(List<QueryDocumentSnapshot> allDocs) {
    return _selectedEmailReminderDocs(allDocs).length;
  }

  int _selectedWhatsAppReminderCount(List<QueryDocumentSnapshot> allDocs) {
    return _selectedWhatsAppReminderDocs(allDocs).length;
  }

  bool _allEligiblePageRemindersSelected(List<QueryDocumentSnapshot> allDocs) {
    final eligibleDocs = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _canSendReminderForDoc(data);
    }).toList();

    if (eligibleDocs.isEmpty) return false;

    return eligibleDocs.every((doc) => _selectedReminderDocIds.contains(doc.id));
  }

  bool _someEligiblePageRemindersSelected(List<QueryDocumentSnapshot> allDocs) {
    final eligibleDocs = allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _canSendReminderForDoc(data);
    }).toList();

    if (eligibleDocs.isEmpty) return false;

    return eligibleDocs.any((doc) => _selectedReminderDocIds.contains(doc.id));
  }

  void _toggleReminderSelection(String docId, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedReminderDocIds.add(docId);
      } else {
        _selectedReminderDocIds.remove(docId);
      }
    });
  }

  void _toggleSelectAllReminders(
    List<QueryDocumentSnapshot> allDocs,
    bool? selected,
  ) {
    setState(() {
      for (final doc in allDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (_canSendReminderForDoc(data)) {
          if (selected == true) {
            _selectedReminderDocIds.add(doc.id);
          } else {
            _selectedReminderDocIds.remove(doc.id);
          }
        }
      }
    });
  }

  Map<String, String> _buildReminderContent(Map<String, dynamic> data) {
    final language = _getLanguage(data);
    final patientName = (data['patient_name'] ?? "").toString().trim();
    final doctorName = (data['doctor_name'] ?? "").toString().trim();
    final timeText = (data['time'] ?? "").toString().trim();
    final dateTime = _getAppointmentDateTime(data);

    String dayText = "";
    String dateText = "";
    if (dateTime != null) {
      dayText = _getWeekdayName(dateTime, language);
      dateText = _formatDate(dateTime);
    }

    if (language == "en") {
      final subject = "Reminder: Your upcoming appointment";
      final body = [
        "Hello ${patientName.isEmpty ? 'Patient' : patientName},",
        "",
        "This is a reminder about your upcoming appointment at $clinicName.",
        if (dayText.isNotEmpty) "Day: $dayText",
        if (dateText.isNotEmpty) "Date: $dateText",
        if (timeText.isNotEmpty) "Time: $timeText",
        if (doctorName.isNotEmpty) "Doctor: $doctorName",
        "",
        "Please arrive a few minutes early.",
        "Thank you.",
      ].join("\n");

      return {
        "subject": subject,
        "body": body,
        "patient_name": patientName,
        "session_day": dayText,
        "session_date": dateText,
        "session_time": timeText,
        "doctor_name": doctorName,
      };
    }

    final subject = "تذكير بموعدك القادم";
    final body = [
      "مرحبًا ${patientName.isEmpty ? 'مريضنا الكريم' : patientName}،",
      "",
      "هذا تذكير بموعدك القادم في $clinicName.",
      if (dayText.isNotEmpty) "اليوم: $dayText",
      if (dateText.isNotEmpty) "التاريخ: $dateText",
      if (timeText.isNotEmpty) "الوقت: $timeText",
      if (doctorName.isNotEmpty) "الطبيب: $doctorName",
      "",
      "يرجى الحضور قبل الموعد بعدة دقائق.",
      "مع تمنياتنا لك بالسلامة.",
    ].join("\n");

    return {
      "subject": subject,
      "body": body,
      "patient_name": patientName,
      "session_day": dayText,
      "session_date": dateText,
      "session_time": timeText,
      "doctor_name": doctorName,
    };
  }


  String _buildWhatsappReminderText(Map<String, dynamic> data) {
    final content = _buildReminderContent(data);
    return content['body'] ?? '';
  }

  Future<void> _openWhatsAppReminder({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final phone = (data['phone'] ?? "").toString();
    final whatsappNumber = _whatsappPhoneNumber(phone);

    if (whatsappNumber.isEmpty) {
      throw Exception(
        tr(
          "رقم الهاتف غير صالح للواتساب",
          "Invalid WhatsApp phone number",
        ),
      );
    }

    final message = _buildWhatsappReminderText(data);

    final uri = Uri.parse(
      "https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}",
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw Exception(
        tr(
          "تعذر فتح واتساب",
          "Could not open WhatsApp",
        ),
      );
    }

    await _markReminderStatus(
      docId: docId,
      data: data,
      status: 'whatsapp_opened',
    );
  }

  Future<void> _markReminderStatus({
    required String docId,
    required Map<String, dynamic> data,
    required String status,
    String? errorMessage,
  }) async {
    final now = Timestamp.now();

    await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
      'reminder_status': status,
      'reminder_sent_at': status == 'sent' ? now : null,
      'reminder_error': errorMessage,
      'updated_at': now,
    });

    final patientId = (data['patient_id'] ?? "").toString().trim();
    if (patientId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('patients').doc(patientId).update({
        'last_reminder_status': status,
        'last_reminder_sent_at': status == 'sent' ? now : null,
        'last_reminder_error': errorMessage,
        'reminder_sent_for_session': data['appointment_datetime'],
      });
    }
  }

  Future<void> _sendEmailJsReminder({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    if (emailJsServiceId == 'YOUR_EMAILJS_SERVICE_ID' ||
        emailJsTemplateId == 'YOUR_EMAILJS_TEMPLATE_ID' ||
        emailJsPublicKey == 'YOUR_EMAILJS_PUBLIC_KEY') {
      throw Exception(
        tr(
          "املئي بيانات EmailJS داخل الكود أولًا",
          "Fill EmailJS config values first",
        ),
      );
    }

    final email = (data['patient_email'] ?? "").toString().trim();
    if (!_isValidEmail(email)) {
      throw Exception(
        tr("البريد الإلكتروني غير صالح", "Invalid patient email"),
      );
    }

    final content = _buildReminderContent(data);

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': emailJsServiceId,
        'template_id': emailJsTemplateId,
        'user_id': emailJsPublicKey,
        'template_params': {
          'to_email': email,
          'patient_email': email,
          'patient_name': content['patient_name'] ?? '',
          'session_day': content['session_day'] ?? '',
          'session_date': content['session_date'] ?? '',
          'session_time': content['session_time'] ?? '',
          'doctor_name': content['doctor_name'] ?? '',
          'clinic_name': clinicName,
          'subject': content['subject'] ?? '',
          'message': content['body'] ?? '',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        response.body.isEmpty
            ? tr("فشل إرسال التذكير", "Failed to send reminder")
            : response.body,
      );
    }

    await _markReminderStatus(
      docId: docId,
      data: data,
      status: 'sent',
    );
  }

  Future<void> _sendPageReminders(List<QueryDocumentSnapshot> allDocs) async {
    if (isSendingPageReminders) return;

    final eligibleDocs = _selectedEmailReminderDocs(allDocs);

    if (eligibleDocs.isEmpty) {
      _showSnack(
        tr(
          "يرجى تحديد المرضى الذين لديهم بريد إلكتروني صالح",
          "Please select patients with valid email addresses",
        ),
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

    setState(() => isSendingPageReminders = true);

    int sentCount = 0;
    int failedCount = 0;

    for (int i = 0; i < eligibleDocs.length; i++) {
      final doc = eligibleDocs[i];
      final data = doc.data() as Map<String, dynamic>;

      try {
        await _sendEmailJsReminder(docId: doc.id, data: data);
        sentCount++;
      } catch (e) {
        failedCount++;

        try {
          await _markReminderStatus(
            docId: doc.id,
            data: data,
            status: 'failed',
            errorMessage: e.toString(),
          );
        } catch (_) {}

        if (mounted) {
          _showSnack(
            isArabic
                ? "فشل إرسال إيميل إلى ${(data['patient_name'] ?? '').toString()}"
                : "Failed sending email to ${(data['patient_name'] ?? '').toString()}",
            backgroundColor: Colors.red.shade700,
          );
        }
      }

      if (i < eligibleDocs.length - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (!mounted) return;

    setState(() {
      isSendingPageReminders = false;
      for (final doc in eligibleDocs) {
        _selectedReminderDocIds.remove(doc.id);
      }
    });

    _showSnack(
      isArabic
          ? "تم إرسال $sentCount إيميل/إيميلات، وفشل $failedCount"
          : "Sent $sentCount email reminder(s), failed $failedCount",
      backgroundColor:
          failedCount == 0 ? Colors.green.shade700 : Colors.orange.shade700,
    );
  }

  Future<void> _sendWhatsAppPageReminders(
    List<QueryDocumentSnapshot> allDocs,
  ) async {
    if (isSendingPageReminders) return;

    final eligibleDocs = _selectedWhatsAppReminderDocs(allDocs);

    if (eligibleDocs.isEmpty) {
      _showSnack(
        tr(
          "يرجى تحديد المرضى الذين لديهم رقم هاتف صالح للواتساب",
          "Please select patients with valid WhatsApp phone numbers",
        ),
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

    setState(() => isSendingPageReminders = true);

    int openedCount = 0;
    int failedCount = 0;

    for (int i = 0; i < eligibleDocs.length; i++) {
      final doc = eligibleDocs[i];
      final data = doc.data() as Map<String, dynamic>;

      try {
        await _openWhatsAppReminder(
          docId: doc.id,
          data: data,
        );
        openedCount++;
      } catch (e) {
        failedCount++;

        try {
          await _markReminderStatus(
            docId: doc.id,
            data: data,
            status: 'failed',
            errorMessage: e.toString(),
          );
        } catch (_) {}

        if (mounted) {
          _showSnack(
            isArabic
                ? "فشل فتح واتساب للمريض ${(data['patient_name'] ?? '').toString()}"
                : "Failed opening WhatsApp for ${(data['patient_name'] ?? '').toString()}",
            backgroundColor: Colors.red.shade700,
          );
        }
      }

      if (i < eligibleDocs.length - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    if (!mounted) return;

    setState(() {
      isSendingPageReminders = false;
      for (final doc in eligibleDocs) {
        _selectedReminderDocIds.remove(doc.id);
      }
    });

    _showSnack(
      isArabic
          ? "تم فتح $openedCount رسالة واتساب، وفشل $failedCount"
          : "Opened $openedCount WhatsApp reminder(s), failed $failedCount",
      backgroundColor:
          failedCount == 0 ? Colors.green.shade700 : Colors.orange.shade700,
    );
  }

  Widget _buildSendPageRemindersButton(List<QueryDocumentSnapshot> allDocs) {
    final count = _selectedReminderCount(allDocs);
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return SizedBox(
      height: isMobile ? 42 : null,
      child: ElevatedButton.icon(
        onPressed: (count == 0 || isSendingPageReminders)
            ? null
            : () => _sendPageReminders(allDocs),
        icon: isSendingPageReminders
            ? SizedBox(
                width: isMobile ? 16 : 18,
                height: isMobile ? 16 : 18,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: isMobile ? 17 : 20,
              ),
        label: Text(
          isSendingPageReminders
              ? tr("جارٍ إرسال الإيميل...", "Sending email...")
              : tr("إرسال إيميل ($count)", "Email ($count)"),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 12.5 : 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: count == 0 ? Colors.grey.shade400 : Colors.green,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 18,
            vertical: isMobile ? 10 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSendWhatsAppRemindersButton(
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final count = _selectedWhatsAppReminderCount(allDocs);
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return SizedBox(
      height: isMobile ? 42 : null,
      child: ElevatedButton.icon(
        onPressed: (count == 0 || isSendingPageReminders)
            ? null
            : () => _sendWhatsAppPageReminders(allDocs),
        icon: isSendingPageReminders
            ? SizedBox(
                width: isMobile ? 16 : 18,
                height: isMobile ? 16 : 18,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.chat,
                color: Colors.white,
                size: isMobile ? 17 : 20,
              ),
        label: Text(
          isSendingPageReminders
              ? tr("جارٍ فتح واتساب...", "Opening WhatsApp...")
              : tr("واتساب ($count)", "WhatsApp ($count)"),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 12.5 : 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: count == 0 ? Colors.grey.shade400 : Colors.green,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 18,
            vertical: isMobile ? 10 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildRowsPerPageSelector() {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final double buttonHeight = isMobile ? 36 : 42;
    final double menuWidth = isMobile ? 112 : 132;

    return PopupMenuButton<int>(
      tooltip: tr("عدد الصفوف", "Rows per page"),
      offset: Offset(0, buttonHeight + 6),
      color: _surface(context),
      elevation: 8,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth + 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        side: BorderSide(color: _border(context)),
      ),
      onSelected: (value) {
        setState(() {
          rowsPerPage = value;
          currentPage = 1;
        });
      },
      itemBuilder: (context) => [10, 50, 100].map((value) {
        final bool selected = rowsPerPage == value;

        return PopupMenuItem<int>(
          value: value,
          height: isMobile ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: selected ? lapisBlue.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: isMobile ? 15 : 16,
                  color: selected ? lapisBlue : _textSecondary(context),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Text(
                  tr("إظهار $value", "Show $value"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? lapisBlue : _textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12.5 : 13.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: buttonHeight,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 13),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(isMobile ? 8 : 9),
          border: Border.all(color: lapisBlue, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.14 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: lapisBlue,
              size: isMobile ? 17 : 20,
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Text(
              tr("إظهار $rowsPerPage", "Show $rowsPerPage"),
              style: TextStyle(
                color: _textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12.5 : 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewSwitchButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: isMobile ? 17 : 20,
        color: active ? Colors.white : lapisBlue,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? Colors.white : lapisBlue,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 13 : 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? lapisBlue : _surface(context),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 20,
          vertical: isMobile ? 10 : 15,
        ),
        side: const BorderSide(color: lapisBlue, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildViewButtons({required bool desktop}) {
    final items = [
      _viewSwitchButton(
        label: tr("مواعيد اليوم", "Today"),
        icon: Icons.today_rounded,
        active: false,
        onTap: _openTodayPage,
      ),
      _viewSwitchButton(
        label: tr("الحجوزات", "Bookings"),
        icon: Icons.event_note_rounded,
        active: true,
        onTap: () {},
      ),
    ];

    if (desktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          items[0],
          const SizedBox(width: 12),
          items[1],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
      children: items,
    );
  }

  Widget _buildViewButtonsWithPrint({
    required bool desktop,
    required AsyncSnapshot<QuerySnapshot> snapshot,
  }) {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildViewButtons(desktop: desktop),
        const SizedBox(height: 12),
        _buildPrintButton(snapshot),
      ],
    );
  }

  Widget _buildPrintButton(AsyncSnapshot<QuerySnapshot> snapshot) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return PopupMenuButton<int>(
      offset: Offset(0, isMobile ? 42 : 50),
      color: _surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 15),
      ),
      elevation: 8,
      onSelected: (val) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          if (val == 1) _exportToPDF(snapshot.data!.docs);
          if (val == 2) _exportToExcel(snapshot.data!.docs);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          height: isMobile ? 40 : 48,
          value: 1,
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                tr("تصدير PDF", "Export PDF"),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          height: isMobile ? 40 : 48,
          value: 2,
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                color: Colors.green,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                tr("تصدير Excel", "Export Excel"),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: isMobile ? 42 : null,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 18,
          vertical: isMobile ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: lapisBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print, size: isMobile ? 15 : 16, color: Colors.white),
            SizedBox(width: isMobile ? 4 : 4),
            Text(
              tr("طباعة", "Print"),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12.5 : 13,
              ),
            ),
            SizedBox(width: isMobile ? 4 : 5),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
              size: isMobile ? 15 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAppointmentButton() {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return ElevatedButton.icon(
      onPressed: _openAddAppointmentForm,
      icon: Icon(Icons.add, color: Colors.white, size: isMobile ? 20 : 26),
      label: Text(
        tr("إضافة موعد جديد", "Add Appointment"),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 13 : 15,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: lapisBlue,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 26,
          vertical: isMobile ? 12 : 17,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 9),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildDesktopHeader(
    AsyncSnapshot<QuerySnapshot> snapshot,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                isArabic ? CrossAxisAlignment.start : CrossAxisAlignment.start,
            children: [
              Text(
                tr("مواعيد المرضى والحجوزات", "Patient Bookings"),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: lapisBlue,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildAddAppointmentButton(),
                  _buildRowsPerPageSelector(),
                  _buildSendPageRemindersButton(allDocs),
                  _buildSendWhatsAppRemindersButton(allDocs),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        _buildViewButtonsWithPrint(
          desktop: true,
          snapshot: snapshot,
        ),
      ],
    );
  }

  Widget _buildMobileHeader(
    AsyncSnapshot<QuerySnapshot> snapshot,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            tr("مواعيد المرضى والحجوزات", "Patient Bookings"),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: lapisBlue,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
              children: [
                _buildRowsPerPageSelector(),
                _buildPrintButton(snapshot),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: _buildViewButtons(desktop: false),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Directionality(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
              children: [
                _buildAddAppointmentButton(),
                _buildSendPageRemindersButton(allDocs),
                _buildSendWhatsAppRemindersButton(allDocs),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopHeaderCell(
    String title, {
    String? sortKey,
    Alignment alignment = Alignment.center,
  }) {
    final active = sortKey != null && sortColumn == sortKey;

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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

  Widget _desktopSelectAllCell(List<QueryDocumentSnapshot> allDocs) {
    final bool allSelected = _allEligiblePageRemindersSelected(allDocs);
    final bool someSelected = _someEligiblePageRemindersSelected(allDocs);
    final bool hasEligible = allDocs.any((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _canSendReminderForDoc(data);
    });

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Tooltip(
        message: tr("تحديد الكل", "Select All"),
        child: Checkbox(
          shape: const CircleBorder(),
          side: const BorderSide(color: Colors.white, width: 1.5),
          activeColor: Colors.white,
          checkColor: lapisBlue,
          tristate: true,
          value: allSelected ? true : (someSelected ? null : false),
          onChanged: hasEligible
              ? (val) => _toggleSelectAllReminders(
                    allDocs,
                    val ?? false,
                  )
              : null,
        ),
      ),
    );
  }

  Widget _desktopReminderSelectCell({
    required String rowId,
    required bool canSendReminder,
  }) {
    return _hoverableBookingRowCell(
      rowId,
      _desktopBodyCell(
        Checkbox(
          shape: const CircleBorder(),
          activeColor: lapisBlue,
          checkColor: Colors.white,
          value: _selectedReminderDocIds.contains(rowId),
          onChanged: canSendReminder
              ? (val) => _toggleReminderSelection(rowId, val)
              : null,
        ),
      ),
    );
  }

  Widget _desktopBodyCell(
    Widget child, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }

  Widget _hoverableBookingRowCell(String rowId, Widget child) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hoveredBookingRowId = rowId),
      onExit: (_) {
        if (hoveredBookingRowId == rowId) {
          setState(() => hoveredBookingRowId = null);
        }
      },
      child: child,
    );
  }

  Widget _buildDesktopTable(
    List<QueryDocumentSnapshot> pagedDocs,
    int startIndex,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    const double minTableWidth = 1250;

    const Map<int, TableColumnWidth> columnWidths = {
      0: FlexColumnWidth(0.7),
      1: FlexColumnWidth(0.9),
      2: FlexColumnWidth(1.6),
      3: FlexColumnWidth(3.1),
      4: FlexColumnWidth(1.8),
      5: FlexColumnWidth(1.5),
      6: FlexColumnWidth(2.5),
      7: FlexColumnWidth(1.4),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

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
      child: pagedDocs.isEmpty
    ? AppointmentsEmptyState(isArabic: isArabic).padded(context)
    : Column(
                          children: [
                            Table(
                              columnWidths: columnWidths,
                              border: TableBorder(
                                top: BorderSide(color: lapisBlue, width: 1),
                                bottom: BorderSide(
                                  color: _border(context),
                                  width: 1,
                                ),
                                left: BorderSide(color: _border(context), width: 1),
                                right: BorderSide(color: _border(context), width: 1),
                                horizontalInside:
                                    BorderSide(color: _border(context), width: 1),
                                verticalInside:
                                    BorderSide(color: _border(context), width: 1),
                              ),
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: lapisBlue),
                                  children: [
                                    _desktopSelectAllCell(allDocs),
                                    _desktopHeaderCell("#"),
                                    _desktopHeaderCell(
                                      tr("الرقم التسلسلي", "Serial"),
                                      sortKey: "serial_number",
                                    ),
                                    _desktopHeaderCell(
                                      tr("اسم المريض", "Patient Name"),
                                      sortKey: "patient_name",
                                      alignment: isArabic
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                    ),
                                    _desktopHeaderCell(
                                      tr("التاريخ", "Date"),
                                      sortKey: "date",
                                    ),
                                    _desktopHeaderCell(
                                      tr("الوقت", "Time"),
                                      sortKey: "time",
                                    ),
                                    _desktopHeaderCell(
                                      tr("الهاتف", "Phone"),
                                    ),
                                    _desktopHeaderCell(
                                      tr("إجراءات", "Actions"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Table(
                                  columnWidths: columnWidths,
                                  border: TableBorder(
                                    bottom: BorderSide(
                                      color: _border(context),
                                      width: 1,
                                    ),
                                    left: BorderSide(
                                      color: _border(context),
                                      width: 1,
                                    ),
                                    right: BorderSide(
                                      color: _border(context),
                                      width: 1,
                                    ),
                                    horizontalInside: BorderSide(
                                      color: _border(context),
                                      width: 1,
                                    ),
                                    verticalInside: BorderSide(
                                      color: _border(context),
                                      width: 1,
                                    ),
                                  ),
                                  children: [
                                    ...pagedDocs.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final doc = entry.value;
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final date =
                                          (data['date'] as Timestamp).toDate();
                                      final actualIndex = startIndex + index + 1;
                                      final rawPhone =
                                          (data['phone'] ?? "").toString();
                                      final phoneDigits = _phoneDigits(rawPhone);
                                      final displayPhone =
                                          _formatPhoneNumber(rawPhone);
                                      final rowId = doc.id;
                                      final isHovered =
                                          hoveredBookingRowId == rowId;
                                      final canSendReminder =
                                          _canSendReminderForDoc(data);

                                      return TableRow(
                                        decoration: BoxDecoration(
                                          color: isHovered
                                              ? lapisBlue.withOpacity(0.08)
                                              : index.isEven
                                                  ? _surface(context)
                                                  : _softFill(context),
                                        ),
                                        children: [
                                          _desktopReminderSelectCell(
                                            rowId: rowId,
                                            canSendReminder: canSendReminder,
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Text(
                                                "$actualIndex",
                                                style: TextStyle(
                                                  color: _textPrimary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Text(
                                                (data['serial_number'] ?? "-")
                                                    .toString(),
                                                style: TextStyle(
                                                  color: _textPrimary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Align(
                                                alignment: isArabic
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                child: Text(
                                                  (data['patient_name'] ?? "")
                                                      .toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: _textPrimary(context),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Text(
                                                "${date.year}-${date.month}-${date.day}",
                                                style: TextStyle(
                                                  color: _textPrimary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Text(
                                                (data['time'] ?? "--:--").toString(),
                                                style: TextStyle(
                                                  color: _textPrimary(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Center(
                                                child: Directionality(
                                                  textDirection: TextDirection.ltr,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Builder(
                                                        builder: (ctx) => IconButton(
                                                          padding: EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(),
                                                          icon: const Icon(
                                                            Icons.contact_phone,
                                                            size: 18,
                                                            color: lightBlue,
                                                          ),
                                                          onPressed: () =>
                                                              _showContactMenu(
                                                            ctx,
                                                            phoneDigits,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          displayPhone.isEmpty
                                                              ? "-"
                                                              : displayPhone,
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color: _textPrimary(
                                                              context,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          _hoverableBookingRowCell(
                                            rowId,
                                            _desktopBodyCell(
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _prepareEdit(data, rowId),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.redAccent,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _confirmDelete(rowId),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
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

  Widget _bookingBadgeChip({
    required IconData icon,
    required String label,
    Color? color,
    Color? background,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    final Color mainColor = color ?? lapisBlue;
    final Color bgColor = background ?? mainColor.withOpacity(0.10);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(color: mainColor.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 13 : 14, color: mainColor),
          SizedBox(width: isMobile ? 5 : 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
                color: mainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      child: Container(
        width: isMobile ? 36 : 42,
        height: isMobile ? 36 : 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        child: Icon(icon, color: color, size: isMobile ? 18 : 20),
      ),
    );
  }

  Widget _buildMobileBookingCard(
    Map<String, dynamic> data,
    String docId,
    int actualIndex,
  ) {
    final DateTime date = (data['date'] as Timestamp).toDate();
    final String rawPhone = (data['phone'] ?? "").toString();
    final String phoneDigits = _phoneDigits(rawPhone);
    final String displayPhone = _formatPhoneNumber(rawPhone);
    final String patientName = (data['patient_name'] ?? "").toString();
    final String serial = (data['serial_number'] ?? "-").toString();
    final String time = (data['time'] ?? "--:--").toString();
    final String dateText = "${date.year}-${date.month}-${date.day}";
    final bool canSendReminder = _canSendReminderForDoc(data);
    final bool isSelectedForReminder = _selectedReminderDocIds.contains(docId);

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(context)),
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
                Checkbox(
                  shape: const CircleBorder(),
                  activeColor: lapisBlue,
                  checkColor: Colors.white,
                  value: isSelectedForReminder,
                  onChanged: canSendReminder
                      ? (val) => _toggleReminderSelection(docId, val)
                      : null,
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: lapisBlue.withOpacity(0.12),
                  child: Text(
                    patientName.trim().isNotEmpty
                        ? patientName.trim()[0].toUpperCase()
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
                        patientName,
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: lapisBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr("حجز مستقبلي", "Upcoming Booking"),
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
                _bookingBadgeChip(
                  icon: Icons.access_time,
                  label: time,
                  color: lapisBlue,
                  background: lapisBlue.withOpacity(0.10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
              children: [
                _bookingBadgeChip(
                  icon: Icons.badge_outlined,
                  label: "${tr("رقم", "Serial")} $serial",
                ),
                _bookingBadgeChip(
                  icon: Icons.calendar_today_outlined,
                  label: dateText,
                ),
                if (_canSendEmailReminderForDoc(data))
                  _bookingBadgeChip(
                    icon: Icons.email_outlined,
                    label: tr("إيميل", "Email"),
                    color: Colors.blueGrey,
                    background: Colors.blueGrey.withOpacity(0.10),
                  ),
                if (_canSendWhatsAppReminderForDoc(data))
                  _bookingBadgeChip(
                    icon: Icons.chat,
                    label: tr("واتساب", "WhatsApp"),
                    color: Colors.green,
                    background: Colors.green.withOpacity(0.10),
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
                  const SizedBox(width: 6),
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
                  const SizedBox(width: 6),
                  _bookingQuickAction(
                    icon: Icons.phone,
                    color: Colors.green,
                    onTap: () {
                      if (phoneDigits.isNotEmpty) {
                        launchUrl(Uri.parse("tel:$phoneDigits"));
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _bookingQuickAction(
                    icon: Icons.sms,
                    color: Colors.blue,
                    onTap: () {
                      if (phoneDigits.isNotEmpty) {
                        launchUrl(Uri.parse("sms:$phoneDigits"));
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _bookingQuickAction(
                    icon: Icons.chat,
                    color: Colors.green,
                    onTap: () {
                      unawaited(
                        _openWhatsAppReminder(
                          docId: docId,
                          data: data,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (canSendReminder)
              InkWell(
                onTap: () => _toggleReminderSelection(
                  docId,
                  !isSelectedForReminder,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelectedForReminder
                        ? lapisBlue.withOpacity(0.12)
                        : _softFill(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelectedForReminder
                          ? lapisBlue
                          : _border(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelectedForReminder
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelectedForReminder
                            ? lapisBlue
                            : _textSecondary(context),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSelectedForReminder
                            ? tr("محدد للتذكير", "Selected for reminder")
                            : tr("تحديد للتذكير", "Select for reminder"),
                        style: TextStyle(
                          color: isSelectedForReminder
                              ? lapisBlue
                              : _textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: lapisBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr("حجز رقم $actualIndex", "Booking #$actualIndex"),
                      style: const TextStyle(
                        color: lapisBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _bookingQuickAction(
                  icon: Icons.edit,
                  color: Colors.green,
                  onTap: () => _prepareEdit(data, docId),
                ),
                const SizedBox(width: 10),
                _bookingQuickAction(
                  icon: Icons.delete,
                  color: Colors.redAccent,
                  onTap: () => _confirmDelete(docId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCards(
    List<QueryDocumentSnapshot> pagedDocs,
    int startIndex,
  ) {
    return ListView.builder(
      itemCount: pagedDocs.length,
      itemBuilder: (context, index) {
        final data = pagedDocs[index].data() as Map<String, dynamic>;
        final actualIndex = startIndex + index + 1;
        return _buildMobileBookingCard(
          data,
          pagedDocs[index].id,
          actualIndex,
        );
      },
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: _softFill(context),
        border: Border(top: BorderSide(color: _border(context))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: isMobile ? 4 : 6,
        runSpacing: isMobile ? 4 : 6,
        children: [
          IconButton(
            visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
            icon: Icon(Icons.chevron_right, size: isMobile ? 20 : 24),
            onPressed:
                currentPage > 1 ? () => setState(() => currentPage--) : null,
          ),
          for (int i = 1; i <= totalPages; i++)
            GestureDetector(
              onTap: () => setState(() => currentPage = i),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 2),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: isMobile ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: currentPage == i ? lapisBlue : _surface(context),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: lapisBlue),
                ),
                child: Text(
                  "$i",
                  style: TextStyle(
                    color: currentPage == i ? Colors.white : lapisBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ),
            ),
          IconButton(
            visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
            icon: Icon(Icons.chevron_left, size: isMobile ? 20 : 24),
            onPressed: currentPage < totalPages
                ? () => setState(() => currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  void _showContactMenu(BuildContext context, String phone) {
    final phoneDigits = _phoneDigits(phone);

    if (phoneDigits.isEmpty) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      color: _surface(context),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        0,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.phone, color: Colors.green),
              const SizedBox(width: 10),
              Text(
                tr("اتصال", "Call"),
                style: TextStyle(color: _textPrimary(context)),
              ),
            ],
          ),
          onTap: () => launchUrl(Uri.parse("tel:$phoneDigits")),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.chat, color: Colors.green),
              const SizedBox(width: 10),
              Text(
                tr("واتساب", "WhatsApp"),
                style: TextStyle(color: _textPrimary(context)),
              ),
            ],
          ),
          onTap: () {
            final whatsappNumber = _whatsappPhoneNumber(phoneDigits);
            if (whatsappNumber.isNotEmpty) {
              launchUrl(Uri.parse("https://wa.me/$whatsappNumber"));
            }
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.sms, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                tr("رسالة", "SMS"),
                style: TextStyle(color: _textPrimary(context)),
              ),
            ],
          ),
          onTap: () => launchUrl(Uri.parse("sms:$phoneDigits")),
        ),
      ],
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface(context),
        title: Text(
          tr("حذف الموعد", "Delete"),
          style: TextStyle(color: _textPrimary(context)),
        ),
        content: Text(
          tr("هل أنت متأكد؟", "Are you sure?"),
          style: TextStyle(color: _textPrimary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("لا", "No")),
          ),
          ElevatedButton(
            onPressed: () async {
           await AppointmentsService.deleteAppointment(docId);
              if (mounted) Navigator.pop(context);
            },
            child: Text(tr("نعم", "Yes")),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool isNum = false,
    int? maxLength,
  }) {
    final inputFormatters = <TextInputFormatter>[];

    if (isNum) {
      inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
    }

    if (maxLength != null) {
      inputFormatters.add(LengthLimitingTextInputFormatter(maxLength));
    }

    return TextField(
      controller: controller,
      keyboardType: isNum
          ? const TextInputType.numberWithOptions(decimal: false)
          : TextInputType.text,
      textInputAction: TextInputAction.done,
      onSubmitted: _submitAppointmentForm,
      inputFormatters: inputFormatters.isEmpty ? null : inputFormatters,
      style: TextStyle(
        color: _textPrimary(context),
        fontSize: MediaQuery.of(context).size.width < 700 ? 13 : 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textSecondary(context)),
        border: const OutlineInputBorder(),
        counterText: "",
        contentPadding: EdgeInsets.all(
          MediaQuery.of(context).size.width < 700 ? 12 : 15,
        ),
      ),
    );
  }


  Widget _buildAppointmentOverlay(BoxConstraints constraints) {
    final bool isMobile = constraints.maxWidth < 950;
    final double dialogWidth = isMobile ? constraints.maxWidth * 0.94 : 850;

    return Container(
      color: Colors.black.withOpacity(0.70),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (addError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    addError!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              Container(
                width: dialogWidth,
                padding: EdgeInsets.all(isMobile ? 18 : 30),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 25,
                      color: Colors.black45,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isEditMode
                          ? tr("تعديل بيانات الموعد", "Edit Appointment Data")
                          : tr("إضافة موعد جديد", "Add Appointment"),
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: lapisBlue,
                      ),
                    ),
                    Divider(height: isMobile ? 28 : 40, color: _border(context)),
                    if (!isMobile)
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              fName,
                              tr("الاسم الأول", "First Name"),
                              maxLength: 15,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInput(
                              mName,
                              tr("اسم الأب", "Middle Name"),
                              maxLength: 15,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInput(
                              lName,
                              tr("الكنية", "Last Name"),
                              maxLength: 15,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInput(
                            fName,
                            tr("الاسم الأول", "First Name"),
                            maxLength: 15,
                          ),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(
                            mName,
                            tr("اسم الأب", "Middle Name"),
                            maxLength: 15,
                          ),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(
                            lName,
                            tr("الكنية", "Last Name"),
                            maxLength: 15,
                          ),
                        ],
                      ),
                    SizedBox(height: isMobile ? 16 : 25),
                    if (!isMobile)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInput(
                              phone,
                              tr("رقم الهاتف", "Phone Number"),
                              isNum: true,
                              maxLength: 10,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInput(
                              serial,
                              tr("الرقم التسلسلي", "Serial"),
                              isNum: true,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInput(
                            phone,
                            tr("رقم الهاتف", "Phone Number"),
                            isNum: true,
                            maxLength: 10,
                          ),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(
                            serial,
                            tr("الرقم التسلسلي", "Serial"),
                            isNum: true,
                          ),
                        ],
                      ),
                    SizedBox(height: isMobile ? 18 : 30),
                    if (!isMobile)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "${tr("التاريخ:", "Date:")} ${selectedDate.toString().substring(0, 10)}",
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary(context),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickAppointmentDate,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(
                                    tr("تغيير التاريخ", "Pick Date"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "${tr("التوقيت:", "Time:")} ${_formatTimeForStorage(selectedTime)}",
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary(context),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickAppointmentTime,
                                  icon: const Icon(Icons.access_time),
                                  label: Text(
                                    tr("اختيار الوقت", "Pick Time"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${tr("التاريخ:", "Date:")} ${selectedDate.toString().substring(0, 10)}",
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary(context),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickAppointmentDate,
                                icon: const Icon(Icons.calendar_month),
                                label: Text(
                                  tr("تغيير التاريخ", "Pick Date"),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 12 : 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${tr("التوقيت:", "Time:")} ${_formatTimeForStorage(selectedTime)}",
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 17,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary(context),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _pickAppointmentTime,
                                icon: const Icon(Icons.access_time),
                                label: Text(
                                  tr("اختيار الوقت", "Pick Time"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    SizedBox(height: isMobile ? 22 : 40),
                    if (!isMobile)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: isSavingAppointment ? null : _saveAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lapisBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 60,
                                vertical: 20,
                              ),
                            ),
                            child: Text(
                              tr("حفظ", "Save"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 25),
                          OutlinedButton(
                            onPressed: _closeAppointmentForm,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 60,
                                vertical: 20,
                              ),
                            ),
                            child: Text(
                              tr("إلغاء", "Cancel"),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSavingAppointment ? null : _saveAppointment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: lapisBlue,
                                padding:
                                    EdgeInsets.symmetric(vertical: isMobile ? 14 : 20),
                              ),
                              child: Text(
                                tr("حفظ", "Save"),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 15 : 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _closeAppointmentForm,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    EdgeInsets.symmetric(vertical: isMobile ? 14 : 20),
                              ),
                              child: Text(
                                tr("إلغاء", "Cancel"),
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      username: widget.username,
      isArabic: isArabic,
      selectedIndex: 0,
      searchController: searchController,
      onSearchChanged: (v) => setState(() {
        searchQuery = v.toLowerCase();
        currentPage = 1;
      }),
      onLanguageChanged: (val) => setState(() => isArabic = val),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool useDesktopTable = constraints.maxWidth >= 1200;
          final bool isMobilePage = constraints.maxWidth < 700;
          final double pagePadding = isMobilePage ? 12 : 20;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pagePadding,
                  vertical: isMobilePage ? 14 : 25,
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: getFutureAppointments(),
                  builder: (context, snapshot) {
                    List<QueryDocumentSnapshot> allDocs = [];
                    int totalItems = 0;
                    int totalPages = 0;
                    int startIndex = 0;
                    int endIndex = 0;
                    List<QueryDocumentSnapshot> pagedDocs = [];

                    if (snapshot.hasData) {
                      allDocs = _prepareDocs(snapshot.data!);
                      totalItems = allDocs.length;
                      totalPages = totalItems == 0
                          ? 0
                          : (totalItems / rowsPerPage).ceil();

                      if (totalPages > 0 && currentPage > totalPages) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => currentPage = totalPages);
                          }
                        });
                      }

                      final safePage = totalPages == 0
                          ? 1
                          : currentPage > totalPages
                              ? totalPages
                              : currentPage;

                      startIndex = (safePage - 1) * rowsPerPage;
                      endIndex = startIndex + rowsPerPage;
                      if (endIndex > totalItems) endIndex = totalItems;

                      pagedDocs = totalItems > 0
                          ? allDocs.sublist(startIndex, endIndex)
                          : [];
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        useDesktopTable
                            ? _buildDesktopHeader(snapshot, allDocs)
                            : _buildMobileHeader(snapshot, allDocs),
                        SizedBox(height: isMobilePage ? 12 : 25),
                        Expanded(
                          child: !snapshot.hasData
                              ? const Center(child: CircularProgressIndicator())
                          : allDocs.isEmpty
    ? AppointmentsEmptyState(isArabic: isArabic)
                                  : useDesktopTable
                                      ? _buildDesktopTable(
                                          pagedDocs,
                                          startIndex,
                                          allDocs,
                                        )
                                      : _buildMobileCards(
                                          pagedDocs,
                                          startIndex,
                                        ),
                        ),
                        if (totalPages > 1) _buildPaginationBar(totalPages),
                      ],
                    );
                  },
                ),
              ),
              if (successMessage != null) _buildSuccessMessageBox(constraints),
              if (isAddingAppointment) _buildAppointmentOverlay(constraints),
            ],
          );
        },
      ),
    );
  }
}