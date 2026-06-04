import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/appointments/screens/home_screen.dart' as home;
import '../../features/patients/screens/patients_screen.dart' as patients;
import '../../features/appointments/screens/bookings_screen.dart' as bookings;
import '../../features/stats/screens/stats_screen.dart' as stats;
import '../../features/xray/screens/xray_analysis_screen.dart' as xray;
import '../../features/materials/screens/materials_screen.dart';

import '../preferences/app_preferences.dart' as prefs;
import '../services/custom_layout_access_service.dart';
import '../theme/app_theme_controller.dart';
import '../utils/custom_layout_utils.dart';

const Color lapisBlue = AppThemeColors.lapisBlue;
const Color lightGray = AppThemeColors.lightGray;
const Color lightBlue = AppThemeColors.lightBlue;

class CustomScaffold extends StatefulWidget {
  final Widget body;
  final String username;
  final int selectedIndex;
  final bool isArabic;
  final Function(bool) onLanguageChanged;
  final Function(String) onSearchChanged;
  final TextEditingController searchController;

  const CustomScaffold({
    super.key,
    required this.body,
    required this.username,
    required this.selectedIndex,
    required this.isArabic,
    required this.onLanguageChanged,
    required this.onSearchChanged,
    required this.searchController,
  });

  @override
  State<CustomScaffold> createState() => _CustomScaffoldState();
}

class _CustomScaffoldState extends State<CustomScaffold> {
  // ─── Static cache: يبقى محفوظ بين الصفحات طول عمر التطبيق ───
  static String _cachedRole = '';
  static Map<String, dynamic> _cachedPermissions = {};
  static bool _cacheLoaded = false;

  String? dismissedWarningSignature;

  // يقرأ من الـ cache مباشرة (مش فاضي من أول)
  String _currentUserRole = _cachedRole;
  Map<String, dynamic> _currentUserPermissions = _cachedPermissions;
  bool _currentUserLoaded = _cacheLoaded;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAccess();
  }

  Future<void> _loadCurrentUserAccess() async {
    // إذا الـ cache جاهز، استخدمه فوراً بدون ما ننتظر Firestore
    if (_cacheLoaded) {
      if (mounted) {
        setState(() {
          _currentUserRole = _cachedRole;
          _currentUserPermissions = _cachedPermissions;
          _currentUserLoaded = true;
        });
      }
      return;
    }

    final access = await CustomLayoutAccessService.loadUserAccess(widget.username);

    // احفظ في الـ static cache
    _cachedRole = access.role;
    _cachedPermissions = access.permissions;
    _cacheLoaded = true;

    if (!mounted) return;
    setState(() {
      _currentUserRole = _cachedRole;
      _currentUserPermissions = _cachedPermissions;
      _currentUserLoaded = true;
    });
  }

  String tr(String ar, String en) => widget.isArabic ? ar : en;

  bool get _isDark => AppThemeController.isDark;

  bool get _isAdminUser => _currentUserRole == 'admin';

  String get _effectiveRole =>
      _currentUserRole.isNotEmpty ? _currentUserRole : 'admin';

  bool _hasPermission(String key) {
    if (_isAdminUser) return true;
    // وقت التحميل: نخلي الزر ظاهر لحد ما يتأكد من الصلاحيات
    if (!_currentUserLoaded) return true;
    return _currentUserPermissions[key] == true;
  }

  bool get _canViewFinancialReports =>
      _hasPermission('canViewFinancialReports');

  bool get _canAccessTreatmentSettings =>
      _hasPermission('canAccessTreatmentSettings');

  Color _pageBg(BuildContext context) => AppThemeColors.pageBg(context);
  Color _surface(BuildContext context) => AppThemeColors.surface(context);
  Color _border(BuildContext context) => AppThemeColors.border(context);
  Color _textPrimary(BuildContext context) =>
      AppThemeColors.textPrimary(context);
  Color _textSecondary(BuildContext context) =>
      AppThemeColors.textSecondary(context);
  Color _appBarBg(BuildContext context) => AppThemeColors.appBar(context);
  Color _warningBar(BuildContext context) =>
      AppThemeColors.warningBar(context);
  Color _searchFill(BuildContext context) =>
      AppThemeColors.searchFill(context);
  Color _selectedTile(BuildContext context) =>
      AppThemeColors.selectedTile(context);

  Widget _applyDesktopScale({
    required BoxConstraints constraints,
    required Widget child,
  }) {
    final double scale = CustomLayoutUtils.desktopUiScale(constraints.maxWidth);

    if (scale == 1.0) return child;

    final Alignment scaleAlignment =
        widget.isArabic ? Alignment.topRight : Alignment.topLeft;

    final double expandedWidth = constraints.maxWidth / scale;
    final double expandedHeight = constraints.maxHeight / scale;

    return SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: scaleAlignment,
          minWidth: expandedWidth,
          maxWidth: expandedWidth,
          minHeight: expandedHeight,
          maxHeight: expandedHeight,
          child: Transform.scale(
            scale: scale,
            alignment: scaleAlignment,
            child: SizedBox(
              width: expandedWidth,
              height: expandedHeight,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  void _saveLastRouteForPage(Widget page) {
    final routeName = CustomLayoutUtils.routeNameForPage(page);
    if (routeName == null) return;
    prefs.AppPreferences.saveLastRoute(routeName);
  }

  void _navigateSmoothly(BuildContext context, Widget page) {
    _saveLastRouteForPage(page);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _navigateFromDrawer(BuildContext context, Widget page) {
    _saveLastRouteForPage(page);

    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _navigateSmoothly(context, page);
    });
  }

  Future<void> _openPatientFile(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        prefs.AppPreferences.saveLastRoute('/patients');

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => patients.PatientsScreen(
              username: widget.username,
              initialArabic: widget.isArabic,
            ),
          ),
        );
        return;
      }

      final docs = snapshot.docs.toList();

      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();

        final aSerial = int.tryParse((aData['serial_number'] ?? '').toString());
        final bSerial = int.tryParse((bData['serial_number'] ?? '').toString());

        if (aSerial != null && bSerial != null) {
          return bSerial.compareTo(aSerial);
        }

        final aFile = int.tryParse((aData['file_number'] ?? '').toString()) ?? 0;
        final bFile = int.tryParse((bData['file_number'] ?? '').toString()) ?? 0;

        return bFile.compareTo(aFile);
      });

      final lastPatientDoc = docs.first;
      final data = lastPatientDoc.data();

      final patientName = (data['full_name'] ??
              '${data['first_name'] ?? ''} ${data['father_name'] ?? ''} ${data['grandfather_name'] ?? ''} ${data['last_name'] ?? ''}')
          .toString()
          .trim();

      prefs.AppPreferences.saveLastRoute('/patients');

      Navigator.of(context).pushReplacementNamed(
        '/patient-account',
        arguments: {
          'patientId': lastPatientDoc.id,
          'patientName': patientName,
          'username': widget.username,
          'isArabic': widget.isArabic,
        },
      );
    } catch (e) {
      if (!mounted) return;

      prefs.AppPreferences.saveLastRoute('/patients');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => patients.PatientsScreen(
            username: widget.username,
            initialArabic: widget.isArabic,
          ),
        ),
      );
    }
  }

  void _openTreatmentSetup(BuildContext context) {
    prefs.AppPreferences.saveLastRoute('/setup');

    Navigator.of(context).pushReplacementNamed(
      '/setup',
      arguments: {
        'username': widget.username,
        'initialArabic': widget.isArabic,
      },
    );
  }

  String _currentPageTitle() {
    switch (widget.selectedIndex) {
      case 0:
        return tr('المواعيد', 'Appointments');
      case 1:
        return tr('المرضى', 'Patients');
      case 2:
        return tr('الأشعة', 'X-Rays');
      case 3:
        return tr('المواد', 'Materials');
      case 4:
        return tr('الإحصائيات', 'Stats');
      case 5:
        return tr('ملف المريض', 'Patient File');
      case 6:
        return tr('إعداد المعالجات', 'Treatment Setup');
      default:
        return tr('العيادة', 'Clinic');
    }
  }

  Widget _buildGlobalWarning(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('materials').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final outOfStockItems = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final qty = CustomLayoutUtils.numValue(data['quantity']);
          return qty == 0;
        }).toList();

        final lowStockItems = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final qty = CustomLayoutUtils.numValue(data['quantity']);
          final minQty = CustomLayoutUtils.numValue(data['min_quantity']);
          return qty > 0 && qty <= minQty;
        }).toList();

        if (outOfStockItems.isEmpty && lowStockItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final outNames = outOfStockItems
            .map((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['name'] ?? '').toString();
            })
            .where((e) => e.isNotEmpty)
            .toList();

        final lowNames = lowStockItems
            .map((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['name'] ?? '').toString();
            })
            .where((e) => e.isNotEmpty)
            .toList();

        final bool hasOutOfStock = outNames.isNotEmpty;
        final bool hasLowStock = lowNames.isNotEmpty;

        final signature =
            'out|${outNames.join('|')}--low|${lowNames.join('|')}';

        if (dismissedWarningSignature == signature) {
          return const SizedBox.shrink();
        }

        String alertTitle;
        if (hasOutOfStock && hasLowStock) {
          alertTitle = tr(
            'تنبيه: يوجد مواد نفذت ومواد ناقصة!',
            'Warning: Out of stock and low stock items!',
          );
        } else if (hasOutOfStock) {
          alertTitle = tr(
            'تنبيه: نفذت مواد من المخزون!',
            'Warning: Some items are out of stock!',
          );
        } else {
          alertTitle = tr(
            'تنبيه: نقص في المخزون!',
            'Warning: Low stock!',
          );
        }

        final List<String> messageParts = [];

        if (hasOutOfStock) {
          messageParts.add(
            tr(
                  'المواد التي نفذت من المخزون: ',
                  'Out of stock items: ',
                ) +
                outNames.join(' ، '),
          );
        }

        if (hasLowStock) {
          messageParts.add(
            tr(
                  'المواد التي نقصت وشارفت على الانتهاء: ',
                  'Low stock items: ',
                ) +
                lowNames.join(' ، '),
          );
        }

        final alertMessage = messageParts.join('   |   ');

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 900;

            return Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 12,
                horizontal: isMobile ? 12 : 20,
              ),
              margin: const EdgeInsets.only(bottom: 1),
              color: _warningBar(context),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alertTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alertMessage,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  dismissedWarningSignature = signature;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: widget.isArabic
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _navigateSmoothly(
                              context,
                              MaterialsScreen(
                                username: widget.username,
                                initialArabic: widget.isArabic,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              tr('عرض التفاصيل', 'View Details'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alertTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                alertMessage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _navigateSmoothly(
                            context,
                            MaterialsScreen(
                              username: widget.username,
                              initialArabic: widget.isArabic,
                            ),
                          ),
                          child: Text(
                            tr('عرض التفاصيل', 'View Details'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              dismissedWarningSignature = signature;
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: tr('إخفاء', 'Dismiss'),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobileLayout = constraints.maxWidth < 1100;
          final bool isCompactDesktop =
              !isMobileLayout && constraints.maxWidth < 1450;

          final bool compactUserMenu = isCompactDesktop ||
              (!widget.isArabic && constraints.maxWidth < 1600);

          final double desktopSearchWidth = constraints.maxWidth > 1650
              ? 500
              : constraints.maxWidth > 1450
                  ? (widget.isArabic ? 420 : 330)
                  : (widget.isArabic ? 240 : 220);

          final double betweenNavGap = isCompactDesktop ? 14 : 30;
          final double firstNavGap = isCompactDesktop ? 12 : 20;

          final double searchStartGap = isCompactDesktop
              ? 18
              : widget.isArabic
                  ? 130
                  : 45;

          return _applyDesktopScale(
            constraints: constraints,
            child: Scaffold(
              backgroundColor: _pageBg(context),
              drawer: isMobileLayout ? _buildMobileDrawer(context) : null,
              appBar: AppBar(
                automaticallyImplyLeading: isMobileLayout,
                backgroundColor: _appBarBg(context),
                elevation: 0,
                toolbarHeight: isMobileLayout ? 62 : 68,
                titleSpacing: isMobileLayout ? 8 : 12,
                title: isMobileLayout
                    ? Text(
                        _currentPageTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      )
                    : Row(
                        children: [
                          PopupMenuButton<int>(
                            constraints: const BoxConstraints(
                              minWidth: 150,
                              maxWidth: 230,
                            ),
                            offset: const Offset(0, 44),
                            color: _surface(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            elevation: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _navItemContent(
                                  context,
                                  tr('المواعيد', 'Appointments'),
                                  Icons.calendar_today,
                                  widget.selectedIndex == 0,
                                  compact: isCompactDesktop,
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                value: 1,
                                child: _popupRow(
                                  icon: Icons.today,
                                  text: tr(
                                    'مواعيد اليوم',
                                    "Today's Appointments",
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem(
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                value: 2,
                                child: _popupRow(
                                  icon: Icons.event_note,
                                  text: tr(
                                    'مواعيد المرضى والحجوزات',
                                    'Future Bookings',
                                  ),
                                ),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 1) {
                                _navigateSmoothly(
                                  context,
                                  home.HomeScreen(
                                    username: widget.username,
                                    role: _effectiveRole,
                                    initialArabic: widget.isArabic,
                                  ),
                                );
                              } else if (val == 2) {
                                _navigateSmoothly(
                                  context,
                                  bookings.BookingsScreen(
                                    username: widget.username,
                                    initialArabic: widget.isArabic,
                                  ),
                                );
                              }
                            },
                          ),
                          SizedBox(width: firstNavGap),
                          _navItem(
                            context,
                            tr('المرضى', 'Patients'),
                            Icons.people,
                            1,
                            compact: isCompactDesktop,
                          ),
                          SizedBox(width: betweenNavGap),
                          _navItem(
                            context,
                            tr('ملف المريض', 'Patient File'),
                            Icons.folder_shared,
                            5,
                            compact: isCompactDesktop,
                          ),
                          SizedBox(width: betweenNavGap),
                          _navItem(
                            context,
                            tr('الأشعة', 'X-Rays'),
                            Icons.visibility,
                            2,
                            compact: isCompactDesktop,
                          ),
                          SizedBox(width: betweenNavGap),
                          _navItem(
                            context,
                            tr('المواد', 'Materials'),
                            Icons.inventory,
                            3,
                            compact: isCompactDesktop,
                          ),
                          if (_canAccessTreatmentSettings) ...[
                            SizedBox(width: betweenNavGap),
                            _navItem(
                              context,
                              tr('إعداد المعالجات', 'Treatment Setup'),
                              Icons.settings_suggest,
                              6,
                              compact: isCompactDesktop,
                            ),
                          ],
                          if (_canViewFinancialReports) ...[
                            SizedBox(width: betweenNavGap),
                            PopupMenuButton<int>(
                              constraints: const BoxConstraints(
                                minWidth: 150,
                                maxWidth: 230,
                              ),
                              offset: const Offset(0, 44),
                              color: _surface(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              elevation: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _navItemContent(
                                    context,
                                    tr('الإحصائيات', 'Stats'),
                                    Icons.bar_chart,
                                    widget.selectedIndex == 4,
                                    compact: isCompactDesktop,
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  value: 0,
                                  child: _popupRow(
                                    icon: Icons.table_view,
                                    text: tr(
                                      'الجداول المالية',
                                      'Financial Tables',
                                    ),
                                  ),
                                ),
                                const PopupMenuDivider(height: 1),
                                PopupMenuItem(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  value: 1,
                                  child: _popupRow(
                                    icon: Icons.pie_chart_outline,
                                    text: tr(
                                      'الرسوم البيانية',
                                      'Charts & Analytics',
                                    ),
                                  ),
                                ),
                              ],
                              onSelected: (val) => _navigateSmoothly(
                                context,
                                stats.StatsScreen(
                                  username: widget.username,
                                  initialView: val,
                                  initialArabic: widget.isArabic,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(width: searchStartGap),
                          SizedBox(
                            width: desktopSearchWidth,
                            height: 38,
                            child: _buildSearchField(),
                          ),
                          const Spacer(),
                          _settingsMenu(context),
                          SizedBox(width: isCompactDesktop ? 8 : 12),
                          _userMenu(context, compact: compactUserMenu),
                        ],
                      ),
                actions: isMobileLayout
                    ? [
                        _settingsMenu(context),
                        _userMenu(context, compact: true),
                        const SizedBox(width: 8),
                      ]
                    : null,
                bottom: isMobileLayout
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(52),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: SizedBox(
                            height: 36,
                            child: _buildSearchField(),
                          ),
                        ),
                      )
                    : null,
              ),
              body: Column(
                children: [
                  _buildGlobalWarning(context),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _popupRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: lapisBlue, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: lapisBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSearchChanged(String value) {
    setState(() {});
    widget.onSearchChanged(CustomLayoutUtils.normalizeSearchText(value));
  }

  void _clearSearch() {
    widget.searchController.clear();
    _handleSearchChanged('');
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _searchFill(context),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.searchController,
        onChanged: _handleSearchChanged,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14, color: _textPrimary(context)),
        decoration: InputDecoration(
          hintText: tr('بحث...', 'Search...'),
          hintStyle: TextStyle(color: _textSecondary(context)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: lapisBlue,
          ),
          suffixIcon: widget.searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: lapisBlue,
                  ),
                  tooltip: tr('مسح البحث', 'Clear search'),
                ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = screenWidth < 380 ? 245 : 268;

    return Drawer(
      width: drawerWidth,
      backgroundColor: _surface(context),
      child: SafeArea(
        child: Container(
          color: _surface(context),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: _appBarBg(context),
                child: Column(
                  crossAxisAlignment: widget.isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr('مرحباً', 'Welcome')} ${widget.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('لوحة التحكم', 'Dashboard'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  children: [
                    _drawerItem(
                      context,
                      icon: Icons.today,
                      text: tr('مواعيد اليوم', "Today's Appointments"),
                      selected: widget.selectedIndex == 0,
                      onTap: () => _navigateFromDrawer(
                        context,
                        home.HomeScreen(
                          username: widget.username,
                          role: _effectiveRole,
                          initialArabic: widget.isArabic,
                        ),
                      ),
                    ),
                    _drawerItem(
                      context,
                      icon: Icons.event_note,
                      text: tr('مواعيد المرضى والحجوزات', 'Future Bookings'),
                      selected: false,
                      onTap: () => _navigateFromDrawer(
                        context,
                        bookings.BookingsScreen(
                          username: widget.username,
                          initialArabic: widget.isArabic,
                        ),
                      ),
                    ),
                    _drawerItem(
                      context,
                      icon: Icons.people,
                      text: tr('المرضى', 'Patients'),
                      selected: widget.selectedIndex == 1,
                      onTap: () => _navigateFromDrawer(
                        context,
                        patients.PatientsScreen(
                          username: widget.username,
                          initialArabic: widget.isArabic,
                        ),
                      ),
                    ),
                    _drawerItem(
                      context,
                      icon: Icons.folder_shared,
                      text: tr('ملف المريض', 'Patient File'),
                      selected: widget.selectedIndex == 5,
                      onTap: () {
                        Navigator.pop(context);
                        _openPatientFile(context);
                      },
                    ),
                    _drawerItem(
                      context,
                      icon: Icons.visibility,
                      text: tr('الأشعة', 'X-Rays'),
                      selected: widget.selectedIndex == 2,
                      onTap: () => _navigateFromDrawer(
                        context,
                        xray.XRayAnalysisScreen(
                          username: widget.username,
                          initialArabic: widget.isArabic,
                        ),
                      ),
                    ),
                    _drawerItem(
                      context,
                      icon: Icons.inventory,
                      text: tr('المواد', 'Materials'),
                      selected: widget.selectedIndex == 3,
                      onTap: () => _navigateFromDrawer(
                        context,
                        MaterialsScreen(
                          username: widget.username,
                          initialArabic: widget.isArabic,
                        ),
                      ),
                    ),
                    if (_canAccessTreatmentSettings)
                      _drawerItem(
                        context,
                        icon: Icons.settings_suggest,
                        text: tr('إعداد المعالجات', 'Treatment Setup'),
                        selected: widget.selectedIndex == 6,
                        onTap: () {
                          Navigator.pop(context);
                          _openTreatmentSetup(context);
                        },
                      ),
                    if (_canViewFinancialReports) ...[
                      Divider(height: 16, color: _border(context)),
                      _drawerItem(
                        context,
                        icon: Icons.table_view,
                        text: tr('الجداول المالية', 'Financial Tables'),
                        selected: widget.selectedIndex == 4,
                        onTap: () => _navigateFromDrawer(
                          context,
                          stats.StatsScreen(
                            username: widget.username,
                            initialView: 0,
                            initialArabic: widget.isArabic,
                          ),
                        ),
                      ),
                      _drawerItem(
                        context,
                        icon: Icons.pie_chart_outline,
                        text: tr('الرسوم البيانية', 'Charts & Analytics'),
                        selected: widget.selectedIndex == 4,
                        onTap: () => _navigateFromDrawer(
                          context,
                          stats.StatsScreen(
                            username: widget.username,
                            initialView: 1,
                            initialArabic: widget.isArabic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required bool selected,
  }) {
    return ListTile(
      dense: true,
      minLeadingWidth: 22,
      minVerticalPadding: 0,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(
        icon,
        size: 20,
        color: selected ? lapisBlue : _textSecondary(context),
      ),
      title: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: selected ? lapisBlue : _textPrimary(context),
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: _selectedTile(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }

  Widget _navItemContent(
    BuildContext context,
    String text,
    IconData icon,
    bool active, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 17 : 19),
              SizedBox(width: compact ? 5 : 7),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: compact ? 100 : 150,
                ),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 13 : 15,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 3 : 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            height: 3,
            width: active ? (compact ? 56 : 72) : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    String text,
    IconData icon,
    int index, {
    bool compact = false,
  }) {
    final active = widget.selectedIndex == index;

    return InkWell(
      onTap: () {
        if (index == 0) {
          _navigateSmoothly(
            context,
            home.HomeScreen(
              username: widget.username,
              role: _effectiveRole,
              initialArabic: widget.isArabic,
            ),
          );
        } else if (index == 1) {
          _navigateSmoothly(
            context,
            patients.PatientsScreen(
              username: widget.username,
              initialArabic: widget.isArabic,
            ),
          );
        } else if (index == 2) {
          _navigateSmoothly(
            context,
            xray.XRayAnalysisScreen(
              username: widget.username,
              initialArabic: widget.isArabic,
            ),
          );
        } else if (index == 3) {
          _navigateSmoothly(
            context,
            MaterialsScreen(
              username: widget.username,
              initialArabic: widget.isArabic,
            ),
          );
        } else if (index == 5) {
          _openPatientFile(context);
        } else if (index == 6) {
          _openTreatmentSetup(context);
        }
      },
      hoverColor: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: _navItemContent(
        context,
        text,
        icon,
        active,
        compact: compact,
      ),
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool saving,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: lapisBlue, size: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: widget.isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: widget.isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: widget.isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: _textSecondary(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Checkbox(
            value: value,
            activeColor: lapisBlue,
            onChanged: saving
                ? null
                : (checked) {
                    onChanged(checked ?? false);
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _showSecretaryPermissionsDialog(BuildContext context) async {
    if (!_isAdminUser) return;

    QuerySnapshot<Map<String, dynamic>> secretaryQuery;

    try {
      secretaryQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'secretary')
          .limit(1)
          .get();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'تعذر تحميل بيانات حساب السكرتيرة: $e',
              'Could not load secretary account data: $e',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (secretaryQuery.docs.isEmpty) {
      await showDialog(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection:
              widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: _surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              tr('إدارة صلاحيات السكرتيرة', 'Manage Secretary Permissions'),
              style: TextStyle(
                color: _textPrimary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              tr(
                'لم يتم العثور على حساب سكرتيرة حاليًا.',
                'No secretary account was found.',
              ),
              style: TextStyle(
                color: _textPrimary(context),
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  tr('حسنًا', 'OK'),
                  style: const TextStyle(
                    color: lapisBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final secretaryDoc = secretaryQuery.docs.first;
    final data = secretaryDoc.data();
    final rawPermissions = data['permissions'];
    final permissions = rawPermissions is Map
        ? Map<String, dynamic>.from(rawPermissions)
        : <String, dynamic>{};

    final secretaryName = (data['username'] ?? '').toString();

    bool canViewFinancialReports =
        permissions['canViewFinancialReports'] == true;
    bool canEditPatientTreatment =
        permissions['canEditPatientTreatment'] == true;
    bool canAccessTreatmentSettings =
        permissions['canAccessTreatmentSettings'] == true;

    bool expanded = true;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection:
                  widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: _surface(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                title: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: lapisBlue,
                      size: 27,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          'إدارة صلاحيات السكرتيرة',
                          'Manage Secretary Permissions',
                        ),
                        style: TextStyle(
                          color: _textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(dialogContext),
                      tooltip: tr('إغلاق', 'Close'),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _textSecondary(context),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 610,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF111827)
                          : lightGray.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border(context)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: expanded,
                        onExpansionChanged: saving
                            ? null
                            : (value) {
                                setDialogState(() => expanded = value);
                              },
                        iconColor: lapisBlue,
                        collapsedIconColor: lapisBlue,
                        leading: const Icon(
                          Icons.manage_accounts_outlined,
                          color: lapisBlue,
                        ),
                        title: Text(
                          secretaryName.isEmpty
                              ? tr('حساب السكرتيرة', 'Secretary Account')
                              : '${tr('حساب السكرتيرة', 'Secretary Account')}: $secretaryName',
                          style: TextStyle(
                            color: _textPrimary(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          tr(
                            'حدّد الصلاحيات التي تريد منحها للسكرتيرة، ثم اضغط حفظ.',
                            'Select permissions, then press Save.',
                          ),
                          style: TextStyle(
                            color: _textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        children: [
                          _buildPermissionRow(
                            icon: Icons.query_stats_rounded,
                            title: tr(
                              'عرض التقارير المالية',
                              'View financial reports',
                            ),
                            subtitle: tr(
                              'يسمح للسكرتيرة بفتح صفحة الإحصائيات.',
                              'Allows the secretary to open the statistics page.',
                            ),
                            value: canViewFinancialReports,
                            saving: saving,
                            onChanged: (value) {
                              setDialogState(
                                () => canViewFinancialReports = value,
                              );
                            },
                          ),
                          Divider(color: _border(context)),
                          _buildPermissionRow(
                            icon: Icons.medical_services_outlined,
                            title: tr(
                              'تعديل معالجات المرضى',
                              'Edit patient treatments',
                            ),
                            subtitle: tr(
                              'يسمح بإضافة وتعديل معالجات المرضى.',
                              'Allows adding and editing patient treatments.',
                            ),
                            value: canEditPatientTreatment,
                            saving: saving,
                            onChanged: (value) {
                              setDialogState(
                                () => canEditPatientTreatment = value,
                              );
                            },
                          ),
                          Divider(color: _border(context)),
                          _buildPermissionRow(
                            icon: Icons.tune_rounded,
                            title: tr(
                              'الدخول إلى إعدادات المعالجات',
                              'Access treatment settings',
                            ),
                            subtitle: tr(
                              'يسمح بفتح صفحة إعداد المعالجات.',
                              'Allows opening treatment setup.',
                            ),
                            value: canAccessTreatmentSettings,
                            saving: saving,
                            onChanged: (value) {
                              setDialogState(
                                () => canAccessTreatmentSettings = value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setDialogState(() => saving = true);

                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(secretaryDoc.id)
                                  .set(
                                {
                                  'permissions': {
                                    'canViewFinancialReports':
                                        canViewFinancialReports,
                                    'canEditPatientTreatment':
                                        canEditPatientTreatment,
                                    'canAccessTreatmentSettings':
                                        canAccessTreatmentSettings,
                                  },
                                },
                                SetOptions(merge: true),
                              );

                              if (!mounted) return;

                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr(
                                      'تم حفظ الصلاحيات بنجاح',
                                      'Permissions were saved successfully',
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // مسح الـ cache لإجبار إعادة التحميل من Firestore
                              _cacheLoaded = false;
                              await _loadCurrentUserAccess();
                            } catch (e) {
                              if (!mounted) return;

                              setDialogState(() => saving = false);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr(
                                      'تعذر حفظ الصلاحيات: $e',
                                      'Could not save permissions: $e',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                      saving
                          ? tr('جارٍ الحفظ...', 'Saving...')
                          : tr('حفظ', 'Save'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lapisBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingsMenu(BuildContext context) {
    final bool isPhoneMenu = MediaQuery.of(context).size.width < 700;

    return PopupMenuButton<int>(
      constraints: BoxConstraints(
        minWidth: isPhoneMenu ? 132 : 150,
        maxWidth: isPhoneMenu ? 210 : 250,
      ),
      icon: Icon(
        Icons.settings,
        color: Colors.white,
        size: isPhoneMenu ? 22 : 25,
      ),
      offset: Offset(0, isPhoneMenu ? 38 : 44),
      color: _surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhoneMenu ? 9 : 10),
      ),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[
          PopupMenuItem(
            height: isPhoneMenu ? 34 : 38,
            padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
            value: 1,
            child: Row(
              children: [
                Icon(
                  Icons.translate,
                  size: isPhoneMenu ? 16 : 18,
                  color: lapisBlue,
                ),
                SizedBox(width: isPhoneMenu ? 6 : 8),
                Text(
                  tr('اللغة', 'Language'),
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontSize: isPhoneMenu ? 12 : 13,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  size: isPhoneMenu ? 16 : 18,
                  color: _textSecondary(context),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            height: isPhoneMenu ? 34 : 38,
            padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
            value: 2,
            child: Row(
              children: [
                Icon(
                  _isDark ? Icons.dark_mode : Icons.light_mode,
                  size: isPhoneMenu ? 16 : 20,
                  color: lapisBlue,
                ),
                SizedBox(width: isPhoneMenu ? 6 : 8),
                Text(
                  tr('المظهر', 'Appearance'),
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontSize: isPhoneMenu ? 12 : 13,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  size: isPhoneMenu ? 16 : 18,
                  color: _textSecondary(context),
                ),
              ],
            ),
          ),
        ];

        if (_isAdminUser) {
          items.add(const PopupMenuDivider(height: 1));
          items.add(
            PopupMenuItem(
              height: isPhoneMenu ? 38 : 42,
              padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
              value: 3,
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: isPhoneMenu ? 16 : 19,
                    color: lapisBlue,
                  ),
                  SizedBox(width: isPhoneMenu ? 6 : 8),
                  Expanded(
                    child: Text(
                      tr(
                        'إدارة صلاحيات السكرتيرة',
                        'Manage Secretary Permissions',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: isPhoneMenu ? 12 : 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.checklist_rounded,
                    size: isPhoneMenu ? 15 : 17,
                    color: _textSecondary(context),
                  ),
                ],
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (val) {
        if (val == 1) {
          _showLanguageMenu(context);
        } else if (val == 2) {
          _showAppearanceMenu(context);
        } else if (val == 3) {
          _showSecretaryPermissionsDialog(context);
        }
      },
    );
  }

  void _showLanguageMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final bool isPhoneMenu = MediaQuery.of(context).size.width < 700;

    showMenu(
      context: context,
      color: _surface(context),
      position: RelativeRect.fromLTRB(
        widget.isArabic ? offset.dx : offset.dx + (isPhoneMenu ? 58 : 80),
        offset.dy + (isPhoneMenu ? 44 : 60),
        widget.isArabic ? offset.dx + (isPhoneMenu ? 58 : 80) : offset.dx,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhoneMenu ? 9 : 10),
      ),
      constraints: BoxConstraints(
        minWidth: isPhoneMenu ? 118 : 150,
        maxWidth: isPhoneMenu ? 170 : 230,
      ),
      items: [
        PopupMenuItem(
          height: isPhoneMenu ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
          onTap: () {
            prefs.AppPreferences.saveLanguage(true);
            widget.onLanguageChanged(true);
          },
          child: _languageRow(
            isPhoneMenu: isPhoneMenu,
            label: 'العربية',
            selected: widget.isArabic,
          ),
        ),
        PopupMenuItem(
          height: isPhoneMenu ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
          onTap: () {
            prefs.AppPreferences.saveLanguage(false);
            widget.onLanguageChanged(false);
          },
          child: _languageRow(
            isPhoneMenu: isPhoneMenu,
            label: 'English',
            selected: !widget.isArabic,
          ),
        ),
      ],
    );
  }

  Widget _languageRow({
    required bool isPhoneMenu,
    required String label,
    required bool selected,
  }) {
    return Row(
      children: [
        Icon(
          Icons.language,
          size: isPhoneMenu ? 16 : 18,
          color: selected ? lapisBlue : _textSecondary(context),
        ),
        SizedBox(width: isPhoneMenu ? 6 : 8),
        Text(
          label,
          style: TextStyle(
            color: _textPrimary(context),
            fontSize: isPhoneMenu ? 12 : 13,
          ),
        ),
        if (selected) const Spacer(),
        if (selected)
          Icon(Icons.check, size: isPhoneMenu ? 14 : 16, color: Colors.green),
      ],
    );
  }

  void _showAppearanceMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final bool isPhoneMenu = MediaQuery.of(context).size.width < 700;

    showMenu(
      context: context,
      color: _surface(context),
      position: RelativeRect.fromLTRB(
        widget.isArabic ? offset.dx : offset.dx + (isPhoneMenu ? 58 : 80),
        offset.dy + (isPhoneMenu ? 44 : 60),
        widget.isArabic ? offset.dx + (isPhoneMenu ? 58 : 80) : offset.dx,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhoneMenu ? 9 : 10),
      ),
      constraints: BoxConstraints(
        minWidth: isPhoneMenu ? 118 : 150,
        maxWidth: isPhoneMenu ? 170 : 230,
      ),
      items: [
        PopupMenuItem(
          height: isPhoneMenu ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
          onTap: () {
            AppThemeController.setLight();
            if (mounted) setState(() {});
          },
          child: _appearanceRow(
            isPhoneMenu: isPhoneMenu,
            label: tr('فاتح', 'Light'),
            icon: Icons.light_mode,
            selected: !_isDark,
          ),
        ),
        PopupMenuItem(
          height: isPhoneMenu ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
          onTap: () {
            AppThemeController.setDark();
            if (mounted) setState(() {});
          },
          child: _appearanceRow(
            isPhoneMenu: isPhoneMenu,
            label: tr('داكن', 'Dark'),
            icon: Icons.dark_mode,
            selected: _isDark,
          ),
        ),
      ],
    );
  }

  Widget _appearanceRow({
    required bool isPhoneMenu,
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: isPhoneMenu ? 16 : 18,
          color: selected ? lapisBlue : _textSecondary(context),
        ),
        SizedBox(width: isPhoneMenu ? 6 : 8),
        Text(
          label,
          style: TextStyle(
            color: _textPrimary(context),
            fontSize: isPhoneMenu ? 12 : 13,
          ),
        ),
        if (selected) const Spacer(),
        if (selected)
          Icon(Icons.check, size: isPhoneMenu ? 14 : 16, color: Colors.green),
      ],
    );
  }

  Widget _userMenu(BuildContext context, {bool compact = false}) {
    final bool isPhoneMenu = MediaQuery.of(context).size.width < 700;

    return PopupMenuButton<int>(
      constraints: BoxConstraints(
        minWidth: isPhoneMenu ? 118 : 150,
        maxWidth: isPhoneMenu ? 178 : 230,
      ),
      color: _surface(context),
      offset: Offset(0, isPhoneMenu ? 39 : 46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhoneMenu ? 9 : 10),
      ),
      icon: compact
          ? Icon(
              Icons.account_circle,
              color: Colors.white,
              size: isPhoneMenu ? 28 : 32,
            )
          : null,
      child: compact
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Text(
                    '${tr('مرحباً', 'Welcome')} ${widget.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.account_circle, color: Colors.white, size: 29),
              ],
            ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          height: isPhoneMenu ? 34 : 38,
          padding: EdgeInsets.symmetric(horizontal: isPhoneMenu ? 10 : 12),
          value: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('تسجيل خروج', 'Logout'),
                style: TextStyle(
                  color: lightBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: isPhoneMenu ? 12 : 13,
                ),
              ),
              Icon(
                Icons.logout,
                color: lightBlue,
                size: isPhoneMenu ? 16 : 18,
              ),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 1) {
          // مسح الـ static cache عند تسجيل الخروج
          _cachedRole = '';
          _cachedPermissions = {};
          _cacheLoaded = false;

          prefs.AppPreferences.clearSession();
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      },
    );
  }
}