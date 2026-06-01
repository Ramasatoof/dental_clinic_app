import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/custom_layout.dart';
import '../../../core/preferences/app_preferences.dart' as prefs;
import '../../../core/theme/app_theme_controller.dart';
import '../services/appointments_service.dart';
import '../utils/appointments_utils.dart';
import 'bookings_screen.dart';
import '../widgets/appointments_pagination.dart';
import '../widgets/appointments_success_message.dart';
import '../widgets/appointments_empty_state.dart';
import '../widgets/home_stats_cards.dart';
import '../widgets/home_reminder_banner.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class HomeScreen extends StatefulWidget {
  final String username;
  final String role;
  final bool initialArabic;

  const HomeScreen({
    super.key,
    required this.username,
    required this.role,
    required this.initialArabic,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late bool isArabic;

  bool isAddingAppointment = false;
  bool isEditMode = false;
  bool isSavingAppointment = false;
  String? editingDocId;
  String? addError;
  String? successMessage;
  Timer? successTimer;
  String? reminderPatientName;
  String? hoveredAppointmentRowId;
  final List<String> dismissedReminders = [];

  final TextEditingController fName = TextEditingController();
  final TextEditingController mName = TextEditingController();
  final TextEditingController lName = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController serial = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String completePhoneNumber = '';
  String searchQuery = '';
  String sortColumn = 'time';
  bool isAscending = true;
  int currentPage = 1;
  int rowsPerPage = 10;

  TimeOfDay selectedTime = TimeOfDay.now();
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    isArabic = prefs.AppPreferences.getSavedIsArabic();
  }

  @override
  void dispose() {
    fName.dispose();
    mName.dispose();
    lName.dispose();
    phone.dispose();
    serial.dispose();
    searchController.dispose();
    successTimer?.cancel();
    super.dispose();
  }

  String tr(String ar, String en) => isArabic ? ar : en;

  bool _isMobileContext(BuildContext context) =>
      MediaQuery.of(context).size.width < 700;

  bool get _isDark => AppThemeController.isDark;

  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);
  Color _softFill(BuildContext context) =>
      _isDark ? const Color(0xFF1F2937) : lightGray.withOpacity(0.85);

  String _phoneDigits(String value) => AppointmentsUtils.phoneDigits(value);

  String _formatPhoneNumber(String value) =>
      AppointmentsUtils.formatPhoneNumber(value);

  bool _isValidJordanMobileNumber(String value) =>
      AppointmentsUtils.isValidJordanMobileNumber(value);

  int _serialToInt(dynamic value) => AppointmentsUtils.serialToInt(value);


  int _minutesFromTimeString(String timeStr) =>
      AppointmentsUtils.minutesFromTimeString(timeStr);

  DateTime _dateOnly(DateTime date) => AppointmentsUtils.dateOnly(date);

  String _dateKey(DateTime date) => AppointmentsUtils.dateKey(date);

  DateTime? _dateFromAppointmentValue(dynamic value) =>
      AppointmentsUtils.dateFromAppointmentValue(value);

  bool _isClinicWorkingDay(DateTime date) =>
      AppointmentsUtils.isClinicWorkingDay(date);

  List<TimeOfDay> _clinicTimeSlots() => AppointmentsUtils.clinicTimeSlots();

  Set<String> _clinicTimeSlotKeys() => AppointmentsUtils.clinicTimeSlotKeys();

  String _timeKey(TimeOfDay time) => AppointmentsUtils.timeKey(time);

  String _timeKeyFromStoredValue(String value) =>
      AppointmentsUtils.timeKeyFromStoredValue(value);

  String _formatTimeForStorage(TimeOfDay time) =>
      AppointmentsUtils.formatTimeForStorage(time);

  Future<int> _getNextSerialNumber() async {
    final snapshot = await AppointmentsService.getAppointments();
    int maxSerial = 0;

    for (final doc in snapshot.docs) {
      final value = _serialToInt(doc.data()['serial_number']);
      if (value > maxSerial) maxSerial = value;
    }

    return maxSerial + 1;
  }

  Future<void> _setNextSerialNumberForNewAppointment() async {
    try {
      final nextSerial = await _getNextSerialNumber();
      if (!mounted || !isAddingAppointment || isEditMode) return;
      setState(() => serial.text = nextSerial.toString());
    } catch (_) {
      if (!mounted || !isAddingAppointment || isEditMode) return;
      setState(() => serial.text = '');
    }
  }

  Future<bool> _serialNumberExists(
    String serialNumber, {
    String? excludedDocId,
  }) async {
    final cleanSerial = serialNumber.trim();
    if (cleanSerial.isEmpty) return false;

    final snapshot = await AppointmentsService.getAppointments();
    for (final doc in snapshot.docs) {
      if (excludedDocId != null && doc.id == excludedDocId) continue;
      final current = (doc.data()['serial_number'] ?? '').toString().trim();
      if (current == cleanSerial) return true;
    }

    return false;
  }

  Future<Set<String>> _bookedTimeKeysForDate(DateTime date) async {
    final snapshot = await AppointmentsService.getAppointmentsForDate(date);
    final booked = <String>{};

    for (final doc in snapshot.docs) {
      if (isEditMode && editingDocId != null && doc.id == editingDocId) {
        continue;
      }

      final key = _timeKeyFromStoredValue(
        (doc.data()['time'] ?? '').toString(),
      );
      if (key.isNotEmpty) booked.add(key);
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

    if (start.isBefore(_dateOnly(firstDate))) start = _dateOnly(firstDate);
    if (start.isAfter(_dateOnly(lastDate))) start = _dateOnly(firstDate);

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

  Future<void> _pickAppointmentDate() async {
    final firstDate = DateTime(2020);
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
          '⚠️ لا توجد تواريخ متاحة للحجز',
          '⚠️ No available dates for booking',
        );
      });
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (date) {
        return _isClinicWorkingDay(date) &&
            !fullyBookedDates.contains(_dateKey(date));
      },
    );

    if (pickedDate == null || !mounted) return;

    final availableSlots = await _availableTimeSlotsForDate(pickedDate);
    if (!mounted) return;

    if (availableSlots.isEmpty) {
      setState(() {
        addError = tr(
          '⚠️ لا توجد أوقات متاحة في هذا التاريخ',
          '⚠️ No available times on this date',
        );
      });
      return;
    }

    setState(() {
      selectedDate = pickedDate;
      addError = null;

      final selectedKey = _timeKey(selectedTime);
      final stillAvailable =
          availableSlots.any((slot) => _timeKey(slot) == selectedKey);
      if (!stillAvailable) selectedTime = availableSlots.first;
    });
  }

  Future<void> _pickAppointmentTime() async {
    final availableSlots = await _availableTimeSlotsForDate(selectedDate);

    if (!mounted) return;

    if (availableSlots.isEmpty) {
      setState(() {
        addError = tr(
          '⚠️ لا توجد أوقات متاحة في هذا التاريخ',
          '⚠️ No available times on this date',
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
              tr('اختر وقتًا متاحًا', 'Pick an Available Time'),
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
                  final active = _timeKey(slot) == _timeKey(selectedTime);

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
                child: Text(tr('إلغاء', 'Cancel')),
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

  Future<bool> _validateSelectedAppointmentSlot() async {
    if (!_isClinicWorkingDay(selectedDate)) {
      setState(() {
        addError = tr(
          '⚠️ العيادة مغلقة يوم الجمعة',
          '⚠️ The clinic is closed on Friday',
        );
      });
      return false;
    }

    final selectedKey = _timeKey(selectedTime);
    if (!_clinicTimeSlotKeys().contains(selectedKey)) {
      setState(() {
        addError = tr(
          '⚠️ اختر وقتًا ضمن دوام العيادة من 9 صباحًا حتى 7 مساءً',
          '⚠️ Pick a time during clinic hours from 9 AM to 7 PM',
        );
      });
      return false;
    }

    final booked = await _bookedTimeKeysForDate(selectedDate);
    if (booked.contains(selectedKey)) {
      setState(() {
        addError = tr(
          '⚠️ هذا الوقت محجوز، اختر وقتًا متاحًا',
          '⚠️ This time is booked, pick an available time',
        );
      });
      return false;
    }

    return true;
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
        '⚠️ لا توجد مواعيد متاحة خلال الفترة القادمة',
        '⚠️ No available appointments in the upcoming period',
      );
    });
  }

  void resetToHome() {
    setState(() {
      searchController.clear();
      searchQuery = '';
      isAddingAppointment = false;
      isEditMode = false;
      editingDocId = null;
      addError = null;
      reminderPatientName = null;
      sortColumn = 'time';
      isAscending = true;
      currentPage = 1;
      selectedDate = DateTime.now();
      selectedTime = TimeOfDay.now();
      phone.clear();
      serial.clear();
      completePhoneNumber = '';
    });
  }

  void _sortDocs(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db = b.data() as Map<String, dynamic>;

      dynamic va;
      dynamic vb;

      switch (sortColumn) {
        case 'time':
          va = _minutesFromTimeString((da['time'] ?? '').toString());
          vb = _minutesFromTimeString((db['time'] ?? '').toString());
          break;
        case 'attended':
          va = (da['attended'] ?? false) ? 1 : 0;
          vb = (db['attended'] ?? false) ? 1 : 0;
          break;
        default:
          va = (da[sortColumn] ?? '').toString().toLowerCase();
          vb = (db[sortColumn] ?? '').toString().toLowerCase();
      }

      final result = va is num && vb is num
          ? va.compareTo(vb)
          : va.toString().compareTo(vb.toString());

      return isAscending ? result : -result;
    });
  }

  void _prepareEdit(Map<String, dynamic> data, String docId) {
    setState(() {
      editingDocId = docId;
      isEditMode = true;
      isAddingAppointment = true;
      addError = null;
      fName.text = (data['first_name'] ?? '').toString();
      mName.text = (data['father_name'] ?? '').toString();
      lName.text = (data['last_name'] ?? '').toString();
      phone.text = _phoneDigits((data['phone'] ?? '').toString());
      serial.text = (data['serial_number'] ?? '').toString();

      final date = _dateFromAppointmentValue(data['date']);
      if (date != null) selectedDate = date;

      final timeStr = (data['time'] ?? '').toString();
      if (timeStr.isNotEmpty) {
        final mins = _minutesFromTimeString(timeStr);
        selectedTime = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
      }
    });
  }

  void _showSuccessMessage(String message) {
    successTimer?.cancel();
    setState(() => successMessage = message);

    successTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => successMessage = null);
    });
  }
Widget _buildSuccessMessageBox(BoxConstraints constraints) {
  return AppointmentsSuccessMessage(
    message: successMessage,
    constraints: constraints,
  );
}

  void _showDeleteConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _surface(context),
          title: Text(
            tr('تأكيد الحذف', 'Confirm Delete'),
            style: TextStyle(color: _textPrimary(context)),
          ),
          content: Text(
            tr(
              'هل أنت متأكد من حذف هذا الموعد؟',
              'Are you sure you want to delete this appointment?',
            ),
            style: TextStyle(color: _textPrimary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('لا', 'No')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
              ),
              onPressed: () async {
                await AppointmentsService.deleteAppointment(docId);
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                tr('نعم', 'Yes'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkUpcomingAppointments(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final pName = (data['patient_name'] ?? '').toString();
      final timeStr = (data['time'] ?? '').toString();

      if (timeStr.isEmpty || dismissedReminders.contains(pName)) continue;

      final mins = _minutesFromTimeString(timeStr);
      final apptTime = DateTime(
        now.year,
        now.month,
        now.day,
        mins ~/ 60,
        mins % 60,
      );
      final difference = apptTime.difference(now).inMinutes;

      if (difference <= 30 && difference > 0 && reminderPatientName != pName) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => reminderPatientName = pName);
          SystemSound.play(SystemSoundType.alert);
        });
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (isSavingAppointment) return;
    setState(() => isSavingAppointment = true);

    try {
      final cleanPhone = _phoneDigits(phone.text.trim());
      final cleanSerial = serial.text.trim();
      final firstName = fName.text.trim();
      final middleName = mName.text.trim();
      final lastName = lName.text.trim();

      if (firstName.isEmpty) {
        setState(() => addError = tr('⚠️ يرجى إدخال الاسم الأول', '⚠️ Please enter first name'));
        return;
      }
      if (firstName.length > 15) {
        setState(() => addError = tr('⚠️ الاسم الأول يجب ألا يتجاوز 15 حرفًا', '⚠️ First name must not exceed 15 characters'));
        return;
      }
      if (middleName.isEmpty) {
        setState(() => addError = tr('⚠️ يرجى إدخال اسم الأب', '⚠️ Please enter middle name'));
        return;
      }
      if (middleName.length > 15) {
        setState(() => addError = tr('⚠️ اسم الأب يجب ألا يتجاوز 15 حرفًا', '⚠️ Middle name must not exceed 15 characters'));
        return;
      }
      if (lastName.isEmpty) {
        setState(() => addError = tr('⚠️ يرجى إدخال الكنية', '⚠️ Please enter last name'));
        return;
      }
      if (lastName.length > 15) {
        setState(() => addError = tr('⚠️ الكنية يجب ألا تتجاوز 15 حرفًا', '⚠️ Last name must not exceed 15 characters'));
        return;
      }
      if (cleanPhone.isEmpty) {
        setState(() => addError = tr('⚠️ يرجى إدخال رقم الهاتف', '⚠️ Please enter phone number'));
        return;
      }
      if (cleanPhone.length != 10) {
        setState(() => addError = tr('⚠️ رقم الهاتف يجب أن يكون 10 أرقام', '⚠️ Phone number must be exactly 10 digits'));
        return;
      }
      if (!_isValidJordanMobileNumber(cleanPhone)) {
        setState(() => addError = tr('⚠️ رقم الهاتف يجب أن يبدأ بـ 079 أو 078 أو 077', '⚠️ Phone number must start with 079, 078, or 077'));
        return;
      }
      if (cleanSerial.isEmpty) {
        setState(() => addError = tr('⚠️ يرجى إدخال الرقم التسلسلي', '⚠️ Please enter serial number'));
        return;
      }

      final serialExists = await _serialNumberExists(
        cleanSerial,
        excludedDocId: isEditMode ? editingDocId : null,
      );
      if (serialExists) {
        setState(() {
          addError = tr(
            '⚠️ الرقم التسلسلي مستخدم مسبقًا، يرجى اختيار رقم آخر',
            '⚠️ Serial number already exists. Please choose another number',
          );
        });
        return;
      }

      final slotIsAvailable = await _validateSelectedAppointmentSlot();
      if (!slotIsAvailable) return;

      final wasEditMode = isEditMode;
      final savedSelectedDate = _dateOnly(selectedDate);
      final savedForTodayPage =
          savedSelectedDate.isAtSameMomentAs(_dateOnly(DateTime.now()));

      final appointmentData = {
        'first_name': firstName,
        'father_name': middleName,
        'last_name': lastName,
        'patient_name': '$firstName $middleName $lastName',
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

      fName.clear();
      mName.clear();
      lName.clear();
      phone.clear();
      serial.clear();

      if (!mounted) return;

      setState(() {
        isAddingAppointment = false;
        isEditMode = false;
        editingDocId = null;
        addError = null;
        selectedDate = DateTime.now();
        selectedTime = TimeOfDay.now();
        completePhoneNumber = '';
        currentPage = 1;
      });

      if (!wasEditMode) {
        _showSuccessMessage(
          savedForTodayPage
              ? tr(
                  'تمت إضافة الموعد بصفحة مواعيد اليوم بنجاح',
                  "Appointment added to Today's page successfully",
                )
              : tr(
                  'تمت إضافة الموعد بصفحة الحجوزات بنجاح',
                  'Appointment added to Bookings page successfully',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => isSavingAppointment = false);
    }
  }

  Stream<QuerySnapshot> getTodayAppointments() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Stream<QuerySnapshot> getTodayPatientsPayments() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('patients')
        .where('first_visit', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('first_visit', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Stream<QuerySnapshot> getMonthlyPatientsPayments() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    return FirebaseFirestore.instance
        .collection('patients')
        .where('first_visit', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('first_visit', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  void _openAddAppointmentForm() {
    setState(() {
      isEditMode = false;
      editingDocId = null;
      isAddingAppointment = true;
      serial.clear();
      fName.clear();
      mName.clear();
      lName.clear();
      phone.clear();
      selectedDate = DateTime.now();
      selectedTime = const TimeOfDay(hour: 9, minute: 0);
      completePhoneNumber = '';
      addError = null;
    });

    unawaited(_setNextSerialNumberForNewAppointment());
    unawaited(_setFirstAvailableAppointmentSlot());
  }

  void _openBookingsPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsScreen(
          username: widget.username,
          initialArabic: prefs.AppPreferences.getSavedIsArabic(),
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
    final isMobile = _isMobileContext(context);

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: isMobile ? 17 : 20,
        color: active ? Colors.white : lapisBlue,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : lapisBlue,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 13 : null,
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
    final content = [
      _viewSwitchButton(
        label: tr('مواعيد اليوم', 'Today'),
        icon: Icons.today_rounded,
        active: true,
        onTap: resetToHome,
      ),
      _viewSwitchButton(
        label: tr('الحجوزات', 'Bookings'),
        icon: Icons.event_note_rounded,
        active: false,
        onTap: _openBookingsPage,
      ),
    ];

    return desktop
        ? Row(
            children: [
              content[0],
              const SizedBox(width: 12),
              content[1],
            ],
          )
        : Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
            children: content,
          );
  }

  Widget _buildRowsPerPageSelector() {
    final isMobile = _isMobileContext(context);
    final buttonHeight = isMobile ? 36.0 : 42.0;
    final menuWidth = isMobile ? 112.0 : 132.0;

    return PopupMenuButton<int>(
      tooltip: tr('عدد الصفوف', 'Rows per page'),
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
        final selected = rowsPerPage == value;

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
                  tr('إظهار $value', 'Show $value'),
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
              tr('إظهار $rowsPerPage', 'Show $rowsPerPage'),
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

  Widget _buildDesktopHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('جدول مواعيد اليوم', "Today's Schedule"),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: lapisBlue,
                    ),
                  ),
                  Text(
                    DateTime.now().toString().substring(0, 10),
                    style: TextStyle(
                      fontSize: 18,
                      color: _textSecondary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openAddAppointmentForm,
                      icon: const Icon(Icons.add, color: Colors.white, size: 22),
                      label: Text(
                        tr('إضافة موعد جديد', 'Add Appointment'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lapisBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    _buildRowsPerPageSelector(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        _buildViewButtons(desktop: true),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: isArabic ? WrapAlignment.end : WrapAlignment.start,
            children: [
              Text(
                tr('جدول مواعيد اليوم', "Today's Schedule"),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: lapisBlue,
                ),
              ),
              Text(
                DateTime.now().toString().substring(0, 10),
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _openAddAppointmentForm,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: Text(
                  tr('إضافة موعد جديد', 'Add Appointment'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lapisBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              _buildRowsPerPageSelector(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
          child: _buildViewButtons(desktop: false),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(
    String title, {
    String? sortKey,
    Alignment alignment = Alignment.center,
  }) {
    final isActive = sortKey != null && sortColumn == sortKey;

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
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (sortKey != null) ...[
              const SizedBox(width: 4),
              Icon(
                isActive
                    ? (isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
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

  Widget _tableBodyCell(
    Widget child, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }

  Widget _hoverableRowCell(String rowId, Widget child) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hoveredAppointmentRowId = rowId),
      onExit: (_) {
        if (hoveredAppointmentRowId == rowId) {
          setState(() => hoveredAppointmentRowId = null);
        }
      },
      child: child,
    );
  }

  Widget _buildDesktopTable(
    AsyncSnapshot<QuerySnapshot> todaySnapshot,
    List<QueryDocumentSnapshot> docs,
    int startIndex,
  ) {
    const minTableWidth = 1200.0;
    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(0.8),
      1: FlexColumnWidth(3.5),
      2: FlexColumnWidth(1.5),
      3: FlexColumnWidth(2.3),
      4: FlexColumnWidth(1.2),
      5: FlexColumnWidth(1.4),
    };

    Widget buildTableHeader() {
      return Table(
        columnWidths: columnWidths,
        border: TableBorder(
          top: const BorderSide(color: lapisBlue, width: 1),
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
              _tableHeaderCell('#'),
              _tableHeaderCell(
                tr('اسم المريض الثلاثي', 'Patient Full Name'),
                alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
              ),
              _tableHeaderCell(tr('الساعة', 'Time'), sortKey: 'time'),
              _tableHeaderCell(tr('الهاتف', 'Phone')),
              _tableHeaderCell(tr('الحالة', 'Status'), sortKey: 'attended'),
              _tableHeaderCell(tr('إجراءات', 'Actions')),
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
            final dId = entry.value.id;
            final isAttended = data['attended'] ?? false;
            final rawPhone = (data['phone'] ?? '').toString();
            final phoneDigits = _phoneDigits(rawPhone);
            final displayPhone = _formatPhoneNumber(rawPhone);
            final isHovered = hoveredAppointmentRowId == dId;
            final rowNumber = startIndex + index + 1;

            return TableRow(
              decoration: BoxDecoration(
                color: isHovered
                    ? lapisBlue.withOpacity(0.08)
                    : isAttended
                        ? Colors.green.withOpacity(0.08)
                        : (index.isEven ? _surface(context) : _softFill(context)),
              ),
              children: [
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Text(
                      '$rowNumber',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: lapisBlue,
                      ),
                    ),
                  ),
                ),
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Align(
                      alignment:
                          isArabic ? Alignment.centerRight : Alignment.centerLeft,
                      child: Text(
                        '${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['last_name'] ?? ''}',
                        textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          fontSize: 15,
                          color: _textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Text(
                      (data['time'] ?? '').toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _textPrimary(context),
                      ),
                    ),
                  ),
                ),
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              displayPhone.isEmpty ? '-' : displayPhone,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: _textPrimary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<int>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.contact_phone,
                              size: 20,
                              color: lightBlue,
                            ),
                            color: _surface(context),
                            tooltip: tr('خيارات الاتصال', 'Contact options'),
                            onSelected: (val) {
                              if (phoneDigits.isEmpty) return;
                              if (val == 1) launchUrl(Uri.parse('tel:$phoneDigits'));
                              if (val == 2) launchUrl(Uri.parse('sms:$phoneDigits'));
                              if (val == 3) launchUrl(Uri.parse('https://wa.me/$phoneDigits'));
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(tr('اتصال', 'Call')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 2,
                                child: Row(
                                  children: [
                                    const Icon(Icons.sms, color: Colors.blue, size: 18),
                                    const SizedBox(width: 8),
                                    Text(tr('رسالة SMS', 'SMS')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 3,
                                child: Row(
                                  children: [
                                    const Icon(Icons.chat, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(tr('واتساب', 'WhatsApp')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Checkbox(
                      activeColor: Colors.green,
                      value: isAttended,
                      onChanged: (val) => AppointmentsService.updateAppointmentField(
                        docId: dId,
                        field: 'attended',
                        value: val,
                      ),
                    ),
                  ),
                ),
                _hoverableRowCell(
                  dId,
                  _tableBodyCell(
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green, size: 20),
                          onPressed: () => _prepareEdit(data, dId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFE57373), size: 20),
                          onPressed: () => _showDeleteConfirmation(dId),
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
                child: !todaySnapshot.hasData
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SelectionArea(
                        child: Column(
                          children: [
                            buildTableHeader(),
                            Expanded(
                              child: SingleChildScrollView(
                                child: docs.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: Center(
                                          child: Text(
                                            tr('لا توجد مواعيد اليوم', 'No appointments today'),
                                            style: TextStyle(
                                              color: _textSecondary(context),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : buildTableBody(),
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

  Widget _appointmentBadgeChip({
    required IconData icon,
    required String label,
    Color? color,
    Color? background,
  }) {
    final isMobile = _isMobileContext(context);
    final mainColor = color ?? lapisBlue;
    final bgColor = background ?? mainColor.withOpacity(0.10);

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
          Icon(icon, size: isMobile ? 12 : 14, color: mainColor),
          SizedBox(width: isMobile ? 5 : 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12.5,
                fontWeight: FontWeight.w700,
                color: mainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = _isMobileContext(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      child: Container(
        width: isMobile ? 34 : 42,
        height: isMobile ? 34 : 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        child: Icon(icon, color: color, size: isMobile ? 17 : 20),
      ),
    );
  }

  Widget _buildMobileAppointmentCard(Map<String, dynamic> data, String dId) {
    final isAttended = data['attended'] ?? false;
    final rawPhone = (data['phone'] ?? '').toString();
    final phoneDigits = _phoneDigits(rawPhone);
    final displayPhone = _formatPhoneNumber(rawPhone);
    final fullName =
        '${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['last_name'] ?? ''}';
    final serialNumber = (data['serial_number'] ?? '').toString();
    final timeValue = (data['time'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAttended ? Colors.green.withOpacity(0.20) : _border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: lapisBlue.withOpacity(0.12),
                child: Text(
                  fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: lapisBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: lapisBlue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('موعد اليوم', "Today's Appointment"),
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _appointmentBadgeChip(
                icon: Icons.access_time,
                label: timeValue.isEmpty ? '-' : timeValue,
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
              _appointmentBadgeChip(
                icon: Icons.badge_outlined,
                label: '${tr('رقم', 'Serial')} $serialNumber',
              ),
              _appointmentBadgeChip(
                icon: Icons.event_available_outlined,
                label: isAttended ? tr('تم الحضور', 'Attended') : tr('غير مؤكد', 'Pending'),
                color: isAttended ? Colors.green : lapisBlue,
                background: isAttended ? Colors.green.withOpacity(0.10) : lapisBlue.withOpacity(0.10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _softFill(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone, color: lapisBlue, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      displayPhone.isEmpty ? '-' : displayPhone,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _textPrimary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _appointmentQuickAction(
                  icon: Icons.phone,
                  color: Colors.green,
                  onTap: () {
                    if (phoneDigits.isNotEmpty) launchUrl(Uri.parse('tel:$phoneDigits'));
                  },
                ),
                const SizedBox(width: 6),
                _appointmentQuickAction(
                  icon: Icons.sms,
                  color: Colors.blue,
                  onTap: () {
                    if (phoneDigits.isNotEmpty) launchUrl(Uri.parse('sms:$phoneDigits'));
                  },
                ),
                const SizedBox(width: 6),
                _appointmentQuickAction(
                  icon: Icons.chat,
                  color: Colors.green,
                  onTap: () {
                    if (phoneDigits.isNotEmpty) launchUrl(Uri.parse('https://wa.me/$phoneDigits'));
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
              color: isAttended ? Colors.green.withOpacity(0.06) : lapisBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isAttended
                        ? tr('حالة الموعد: تم التأكيد بالحضور', 'Appointment Status: Attended')
                        : tr('حالة الموعد: بانتظار التأكيد', 'Appointment Status: Pending'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isAttended ? Colors.green.shade700 : lapisBlue,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.82,
                  child: Switch.adaptive(
                    value: isAttended,
                    activeColor: Colors.green,
                    onChanged: (val) => AppointmentsService.updateAppointmentField(
                      docId: dId,
                      field: 'attended',
                      value: val,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _appointmentQuickAction(
                  icon: Icons.edit,
                  color: Colors.green,
                  onTap: () => _prepareEdit(data, dId),
                ),
                const SizedBox(width: 8),
                _appointmentQuickAction(
                  icon: Icons.delete,
                  color: Colors.redAccent,
                  onTap: () => _showDeleteConfirmation(dId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAppointmentsList(
    AsyncSnapshot<QuerySnapshot> todaySnapshot,
    List<QueryDocumentSnapshot> docs,
  ) {
    if (!todaySnapshot.hasData) return const Center(child: CircularProgressIndicator());
if (docs.isEmpty) {
  return AppointmentsEmptyState(
    isArabic: isArabic,
    arabicText: "لا توجد مواعيد اليوم",
    englishText: "No appointments today",
  ).padded(context);
}

    return ListView.builder(
      itemCount: docs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        return _buildMobileAppointmentCard(data, docs[index].id);
      },
    );
  }

Widget _buildPaginationBar(int totalPages) {
  return AppointmentsPagination(
    totalPages: totalPages,
    currentPage: currentPage,
    isDark: _isDark,
    onPageChanged: (page) {
      setState(() => currentPage = page);
    },
  );
}

Widget _buildStatsBlock(int todayCount, int attendedCount) {
  return StreamBuilder<QuerySnapshot>(
    stream: getTodayPatientsPayments(),
    builder: (context, todaySnapshot) {
      final double todaySum = todaySnapshot.hasData
          ? todaySnapshot.data!.docs.fold(
              0.0,
              (v, e) => v + ((e['paid_amount'] ?? 0.0) as num).toDouble(),
            )
          : 0.0;

      return StreamBuilder<QuerySnapshot>(
        stream: getMonthlyPatientsPayments(),
        builder: (context, monthlySnapshot) {
          final double monthlySum = monthlySnapshot.hasData
              ? monthlySnapshot.data!.docs.fold(
                  0.0,
                  (v, e) => v + ((e['paid_amount'] ?? 0.0) as num).toDouble(),
                )
              : 0.0;

          return HomeStatsCards(
            isArabic: isArabic,
            todayCount: todayCount,
            attendedCount: attendedCount,
            todaySum: todaySum,
            monthlySum: monthlySum,
          );
        },
      );
    },
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
      onLanguageChanged: (val) => setState(() {
        prefs.AppPreferences.saveLanguage(val);
        isArabic = val;
      }),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useDesktopTable = constraints.maxWidth >= 1200;
          final compactDialog = constraints.maxWidth < 950;
          final isMobile = constraints.maxWidth < 700;
          final pagePadding = isMobile ? 10.0 : 20.0;
          final dialogWidth =
              compactDialog ? min(constraints.maxWidth * 0.94, 640.0) : 850.0;

          return StreamBuilder<QuerySnapshot>(
            stream: getTodayAppointments(),
            builder: (context, todaySnapshot) {
              int todayCount = 0;
              int attendedCount = 0;
              List<QueryDocumentSnapshot> docs = [];

              if (todaySnapshot.hasData) {
                docs = todaySnapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['patient_name'] ?? '').toString().toLowerCase();
                  final phoneText = (data['phone'] ?? '').toString().toLowerCase();
                  final phoneDigits = _phoneDigits(phoneText);
                  final serialText = (data['serial_number'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) ||
                      phoneText.contains(searchQuery) ||
                      phoneDigits.contains(searchQuery) ||
                      serialText.contains(searchQuery);
                }).toList();

                todayCount = todaySnapshot.data!.docs.length;
                attendedCount = todaySnapshot.data!.docs.where((d) {
                  return (d.data() as Map<String, dynamic>)['attended'] == true;
                }).length;

                _checkUpcomingAppointments(todaySnapshot.data!.docs);
                _sortDocs(docs);
              }

              final totalItems = docs.length;
              final totalPages = totalItems == 0 ? 0 : (totalItems / rowsPerPage).ceil();

              if (totalPages > 0 && currentPage > totalPages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => currentPage = totalPages);
                });
              }

              final safePage = totalPages == 0
                  ? 1
                  : currentPage > totalPages
                      ? totalPages
                      : currentPage;

              final startIndex = (safePage - 1) * rowsPerPage;
              var endIndex = startIndex + rowsPerPage;
              if (endIndex > totalItems) endIndex = totalItems;

              final pagedDocs = totalItems > 0 ? docs.sublist(startIndex, endIndex) : <QueryDocumentSnapshot>[];

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: pagePadding,
                      vertical: isMobile ? 12 : 25,
                    ),
                    child: useDesktopTable
                        ? Column(
                            children: [
                              _buildDesktopHeader(),
                              const SizedBox(height: 25),
                              Expanded(
                                child: _buildDesktopTable(
                                  todaySnapshot,
                                  pagedDocs,
                                  startIndex,
                                ),
                              ),
                              if (totalPages > 1) _buildPaginationBar(totalPages),
                              const SizedBox(height: 25),
                              _buildStatsBlock(todayCount, attendedCount),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildMobileHeader(),
                                const SizedBox(height: 12),
                                _buildMobileAppointmentsList(todaySnapshot, pagedDocs),
                                if (totalPages > 1) _buildPaginationBar(totalPages),
                                const SizedBox(height: 12),
                                _buildStatsBlock(todayCount, attendedCount),
                              ],
                            ),
                          ),
                  ),
HomeReminderBanner(
  isArabic: isArabic,
  patientName: reminderPatientName,
  constraints: constraints,
  onClose: () {
    setState(() {
      dismissedReminders.add(reminderPatientName!);
      reminderPatientName = null;
    });
  },
),
                  if (successMessage != null) _buildSuccessMessageBox(constraints),
                  if (isAddingAppointment)
                    _buildAppointmentOverlay(
                      dialogWidth: dialogWidth,
                      compactDialog: compactDialog,
                      isMobile: isMobile,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAppointmentOverlay({
    required double dialogWidth,
    required bool compactDialog,
    required bool isMobile,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.7),
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
                padding: EdgeInsets.all(compactDialog ? 18 : 30),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(blurRadius: 25, color: Colors.black45),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isEditMode
                          ? tr('تعديل بيانات الموعد', 'Edit Appointment Data')
                          : tr('إضافة موعد جديد', 'Add Appointment'),
                      style: TextStyle(
                        fontSize: compactDialog ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: lapisBlue,
                      ),
                    ),
                    Divider(height: compactDialog ? 26 : 40, color: _border(context)),
                    if (!compactDialog)
                      Row(
                        children: [
                          Expanded(child: _buildInput(fName, tr('الاسم الأول', 'First Name'))),
                          const SizedBox(width: 20),
                          Expanded(child: _buildInput(mName, tr('اسم الأب', 'Middle Name'))),
                          const SizedBox(width: 20),
                          Expanded(child: _buildInput(lName, tr('الكنية', 'Last Name'))),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInput(fName, tr('الاسم الأول', 'First Name')),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(mName, tr('اسم الأب', 'Middle Name')),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(lName, tr('الكنية', 'Last Name')),
                        ],
                      ),
                    SizedBox(height: compactDialog ? 16 : 25),
                    if (!compactDialog)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInput(
                              phone,
                              tr('رقم الهاتف', 'Phone Number'),
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInput(
                              serial,
                              tr('الرقم التسلسلي', 'Serial'),
                              isNum: true,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInput(phone, tr('رقم الهاتف', 'Phone Number'), isNum: true),
                          SizedBox(height: isMobile ? 12 : 20),
                          _buildInput(serial, tr('الرقم التسلسلي', 'Serial'), isNum: true),
                        ],
                      ),
                    SizedBox(height: compactDialog ? 18 : 30),
                    if (!compactDialog)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _datePickerSection(isMobile)),
                          const SizedBox(width: 20),
                          Expanded(child: _timePickerSection(isMobile)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _datePickerRow(isMobile),
                          SizedBox(height: isMobile ? 12 : 20),
                          _timePickerRow(isMobile),
                        ],
                      ),
                    SizedBox(height: compactDialog ? 22 : 40),
                    if (!compactDialog)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: isSavingAppointment ? null : _saveAppointment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lapisBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                            ),
                            child: Text(
                              tr('حفظ', 'Save'),
                              style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 18),
                            ),
                          ),
                          const SizedBox(width: 25),
                          OutlinedButton(
                            onPressed: _cancelAppointmentForm,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                            ),
                            child: Text(tr('إلغاء', 'Cancel'), style: const TextStyle(fontSize: 18)),
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
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 20),
                              ),
                              child: Text(
                                tr('حفظ', 'Save'),
                                style: TextStyle(color: Colors.white, fontSize: isMobile ? 15 : 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancelAppointmentForm,
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 20),
                              ),
                              child: Text(
                                tr('إلغاء', 'Cancel'),
                                style: TextStyle(fontSize: isMobile ? 15 : 18),
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

  Widget _datePickerSection(bool isMobile) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${tr('التاريخ:', 'Date:')} ${selectedDate.toString().substring(0, 10)}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textPrimary(context),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _pickAppointmentDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(tr('تغيير التاريخ', 'Pick Date')),
        ),
      ],
    );
  }

  Widget _timePickerSection(bool isMobile) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${tr('التوقيت:', 'Time:')} ${_formatTimeForStorage(selectedTime)}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textPrimary(context),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _pickAppointmentTime,
          icon: const Icon(Icons.access_time),
          label: Text(tr('اختيار الوقت', 'Pick Time')),
        ),
      ],
    );
  }

  Widget _datePickerRow(bool isMobile) {
    return Row(
      children: [
        Expanded(child: _datePickerSection(isMobile)),
      ],
    );
  }

  Widget _timePickerRow(bool isMobile) {
    return Row(
      children: [
        Expanded(child: _timePickerSection(isMobile)),
      ],
    );
  }

  void _cancelAppointmentForm() {
    setState(() {
      isAddingAppointment = false;
      isEditMode = false;
      editingDocId = null;
      addError = null;
    });
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool isNum = false,
  }) {
    final isNameField = controller == fName || controller == mName || controller == lName;
    final isPhoneField = controller == phone;
    final isMobile = _isMobileContext(context);

    final inputFormatters = <TextInputFormatter>[];
    if (isNum) inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
    if (isNameField) inputFormatters.add(LengthLimitingTextInputFormatter(15));
    if (isPhoneField) inputFormatters.add(LengthLimitingTextInputFormatter(10));

    return TextField(
      controller: controller,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (isAddingAppointment) _saveAppointment();
      },
      inputFormatters: inputFormatters.isEmpty ? null : inputFormatters,
      style: TextStyle(
        color: _textPrimary(context),
        fontSize: isMobile ? 13 : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _textSecondary(context),
          fontSize: isMobile ? 13 : null,
        ),
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.all(isMobile ? 12 : 15),
      ),
    );
  }
}
