import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../appointments/screens/home_screen.dart';
import '../../../core/preferences/app_preferences.dart' as prefs;
import '../../../core/theme/app_theme_controller.dart' as theme;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final FocusNode _userFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _confirmPassFocus = FocusNode();

  bool loading = false;
  bool isSignupMode = false;
  late bool isArabic;

  String? errorMessage;
  String? successMessage;

  static const Color lapisBlue = Color(0xFF26619C);
  static const Color lightGray = Color(0xFFF2F2F2);

  String tr(String ar, String en) => isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    isArabic = prefs.AppPreferences.getSavedIsArabic();

    _userFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    _confirmPassFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    _userFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmPassFocus.dispose();

    super.dispose();
  }

  void _clearMessages() {
    errorMessage = null;
    successMessage = null;
  }

  bool get _isDark => theme.AppThemeController.isDark;

  Color get _pageBg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _cardBg => _isDark ? const Color(0xFF111827) : Colors.white;
  Color get _inputBg => _isDark ? const Color(0xFF1F2937) : lightGray;
  Color get _primaryText => _isDark ? Colors.white : lapisBlue;
  Color get _normalText => _isDark ? Colors.white : Colors.black87;
  Color get _secondaryText => _isDark ? Colors.white70 : Colors.black54;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : Colors.transparent;

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Map<String, dynamic> _defaultPermissionsForRole(String role) {
    final bool isAdmin = role == 'admin';

    return {
      'canViewFinancialReports': isAdmin,
      'canEditPatientTreatment': isAdmin,
      'canAccessTreatmentSettings': isAdmin,
    };
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return tr('البريد الإلكتروني غير صحيح', 'Invalid email address');
      case 'email-already-in-use':
        return tr(
          'هذا البريد الإلكتروني مستخدم مسبقًا',
          'This email is already in use',
        );
      case 'user-not-found':
        return tr(
          'لا يوجد حساب مرتبط بهذا البريد الإلكتروني',
          'No account found for this email',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return tr(
          'بيانات الدخول غير صحيحة',
          'Invalid login credentials',
        );
      case 'weak-password':
        return tr(
          'كلمة المرور ضعيفة، يجب أن تكون 6 أحرف أو أرقام على الأقل',
          'Password is too weak. It must be at least 6 characters',
        );
      case 'network-request-failed':
        return tr(
          'تحقق من الاتصال بالإنترنت',
          'Please check your internet connection',
        );
      default:
        return tr(
          'حدث خطأ: ${e.message ?? e.code}',
          'An error occurred: ${e.message ?? e.code}',
        );
    }
  }

  Future<int> _usersCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.length;
  }

  Future<bool> _usernameExists(String username) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<bool> _emailExists(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  String _roleForNewUser(int currentUsersCount) {
    if (currentUsersCount == 0) return 'admin';
    return 'secretary';
  }

  Future<void> _signup() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final passwordText = passwordController.text.trim();
    final confirmPasswordText = confirmPasswordController.text.trim();

    setState(() {
      _clearMessages();
    });

    if (username.isEmpty ||
        email.isEmpty ||
        passwordText.isEmpty ||
        confirmPasswordText.isEmpty) {
      setState(() {
        errorMessage = tr(
          'يرجى ملء جميع الحقول',
          'Please fill in all fields',
        );
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        errorMessage = tr(
          'أدخل بريدًا إلكترونيًا صحيحًا',
          'Please enter a valid email address',
        );
      });
      return;
    }

    if (passwordText.length < 6) {
      setState(() {
        errorMessage = tr(
          'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل',
          'Password must be at least 6 characters',
        );
      });
      return;
    }

    if (passwordText != confirmPasswordText) {
      setState(() {
        errorMessage = tr(
          'كلمة المرور وتأكيدها غير متطابقين',
          'Password and confirmation do not match',
        );
      });
      return;
    }

    setState(() => loading = true);

    UserCredential? credential;

    try {
      final count = await _usersCount();

      if (count >= 2) {
        setState(() {
          errorMessage = tr(
            'تم الوصول للحد الأقصى للحسابات المسموحة لهذه النسخة',
            'The maximum number of accounts allowed for this copy has been reached',
          );
        });
        return;
      }

      final usernameAlreadyExists = await _usernameExists(username);
      if (usernameAlreadyExists) {
        setState(() {
          errorMessage = tr(
            'اسم المستخدم موجود مسبقًا',
            'Username already exists',
          );
        });
        return;
      }

      final emailAlreadyExists = await _emailExists(email);
      if (emailAlreadyExists) {
        setState(() {
          errorMessage = tr(
            'هذا البريد الإلكتروني مستخدم مسبقًا',
            'This email is already in use',
          );
        });
        return;
      }

      final role = _roleForNewUser(count);

      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordText,
      );

      await FirebaseFirestore.instance.collection('users').add({
        'uid': credential.user?.uid,
        'username': username,
        'email': email,
        'role': role,
        'active': true,
        'permissions': _defaultPermissionsForRole(role),
        'created_at': Timestamp.now(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        isSignupMode = false;
        successMessage = role == 'admin'
            ? tr(
                'تم إنشاء حساب الدكتور بنجاح، يمكنك تسجيل الدخول الآن',
                'Doctor admin account created successfully. You can log in now',
              )
            : tr(
                'تم إنشاء حساب السكرتيرة بنجاح، يمكنك تسجيل الدخول الآن',
                'Secretary account created successfully. You can log in now',
              );

        passwordController.clear();
        confirmPasswordController.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _firebaseAuthMessage(e);
      });
    } catch (e) {
      try {
        await credential?.user?.delete();
      } catch (_) {}

      setState(() {
        errorMessage = tr(
          'حدث خطأ: $e',
          'An error occurred: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _login() async {
    final username = usernameController.text.trim();
    final passwordText = passwordController.text.trim();

    setState(() {
      _clearMessages();
    });

    if (username.isEmpty || passwordText.isEmpty) {
      setState(() {
        errorMessage = tr(
          'يرجى ملء اسم المستخدم وكلمة المرور',
          'Please enter username and password',
        );
      });
      return;
    }

    setState(() => loading = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          errorMessage = tr(
            'بيانات خاطئة أو الحساب غير مفعل',
            'Invalid credentials or inactive account',
          );
        });
        return;
      }

      final data = query.docs.first.data();
      final role = (data['role'] ?? '').toString();
      final email = (data['email'] ?? '').toString().trim().toLowerCase();

      if (email.isEmpty) {
        setState(() {
          errorMessage = tr(
            'هذا الحساب لا يحتوي على بريد إلكتروني. أعد إنشاء الحساب أو أضف البريد من قاعدة البيانات',
            'This account does not have an email. Recreate it or add an email in the database',
          );
        });
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: passwordText,
      );

      prefs.AppPreferences.saveUsername(username);
      prefs.AppPreferences.saveRole(role);
      prefs.AppPreferences.saveLastRoute('/home');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            username: username,
            role: role,
            initialArabic: prefs.AppPreferences.getSavedIsArabic(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _firebaseAuthMessage(e);
      });
    } catch (e) {
      setState(() {
        errorMessage = tr(
          'حدث خطأ: $e',
          'An error occurred: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      setState(() {
        errorMessage = tr(
          'أدخل البريد الإلكتروني أولًا',
          'Please enter your email first',
        );
      });
      return;
    }

    if (!_isValidEmail(cleanEmail)) {
      setState(() {
        errorMessage = tr(
          'أدخل بريدًا إلكترونيًا صحيحًا',
          'Please enter a valid email address',
        );
      });
      return;
    }

    setState(() {
      loading = true;
      _clearMessages();
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          errorMessage = tr(
            'هذا البريد الإلكتروني غير مرتبط بأي حساب فعال',
            'This email is not linked to any active account',
          );
        });
        return;
      }

      final userData = userQuery.docs.first.data();
      final authUid = (userData['uid'] ?? '').toString().trim();

      if (authUid.isEmpty) {
        setState(() {
          errorMessage = tr(
            'هذا الحساب قديم وغير مربوط بـ Firebase Authentication. أعد إنشاء الحساب من صفحة إنشاء حساب.',
            'This is an old account and is not linked to Firebase Authentication. Recreate it from Sign Up.',
          );
        });
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);

      if (!mounted) return;

      setState(() {
        successMessage = tr(
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني. افحص البريد غير الهام أيضًا.',
          'Password reset link has been sent to your email. Please also check spam.',
        );
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _firebaseAuthMessage(e);
      });
    } catch (e) {
      setState(() {
        errorMessage = tr(
          'حدث خطأ: $e',
          'An error occurred: $e',
        );
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: emailController.text.trim().toLowerCase(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              tr('نسيت كلمة المرور؟', 'Forgot Password?'),
              style: TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(
                    'أدخل البريد الإلكتروني المرتبط بحسابك وسيتم إرسال رابط لإعادة تعيين كلمة المرور.',
                    'Enter the email linked to your account and a password reset link will be sent.',
                  ),
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: _normalText),
                  decoration: InputDecoration(
                    labelText: tr('البريد الإلكتروني', 'Email'),
                    labelStyle: TextStyle(color: _secondaryText),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: lapisBlue,
                    ),
                    filled: true,
                    fillColor: _inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: lapisBlue),
                    ),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(dialogContext);
                    _sendPasswordResetEmail(resetEmailController.text);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(tr('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: lapisBlue,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _sendPasswordResetEmail(resetEmailController.text);
                },
                child: Text(
                  tr('إرسال الرابط', 'Send Link'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (loading) return;

    if (isSignupMode) {
      await _signup();
    } else {
      await _login();
    }
  }

  Widget _buildModeSwitch(int usersCount) {
    final bool canSignup = usersCount < 2;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: loading
                  ? null
                  : () {
                      setState(() {
                        isSignupMode = false;
                        _clearMessages();
                      });
                    },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: !isSignupMode ? lapisBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  tr('تسجيل دخول', 'Login'),
                  style: TextStyle(
                    color: !isSignupMode ? Colors.white : _primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: loading || !canSignup
                  ? null
                  : () {
                      setState(() {
                        isSignupMode = true;
                        _clearMessages();
                      });
                    },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSignupMode ? lapisBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  tr('إنشاء حساب', 'Sign Up'),
                  style: TextStyle(
                    color: !canSignup
                        ? Colors.grey
                        : isSignupMode
                            ? Colors.white
                            : _primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputAction textInputAction = TextInputAction.next,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onSubmitted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        style: TextStyle(color: _normalText),
        cursorColor: lapisBlue,
        onSubmitted: (_) {
          if (onSubmitted != null) onSubmitted();
        },
        decoration: InputDecoration(
          hintText: focusNode.hasFocus ? '' : hint,
          hintStyle: TextStyle(color: _secondaryText),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: lapisBlue),
        ),
      ),
    );
  }

  Widget _buildRoleHint(int usersCount) {
    if (!isSignupMode) return const SizedBox.shrink();

    String text;
    if (usersCount == 0) {
      text = tr(
        'سيتم إنشاء الحساب الأول كحساب دكتور / أدمن',
        'The first account will be created as Doctor / Admin',
      );
    } else if (usersCount == 1) {
      text = tr(
        'سيتم إنشاء الحساب الثاني كحساب سكرتيرة',
        'The second account will be created as Secretary',
      );
    } else {
      text = tr(
        'تم إنشاء الحسابين المسموحين لهذه النسخة',
        'The two allowed accounts for this copy have already been created',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: usersCount >= 2
            ? Colors.red.withOpacity(_isDark ? 0.16 : 0.08)
            : lapisBlue.withOpacity(_isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: usersCount >= 2
              ? Colors.red.withOpacity(0.35)
              : lapisBlue.withOpacity(0.25),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: usersCount >= 2 ? Colors.redAccent : lapisBlue,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    isArabic = prefs.AppPreferences.getSavedIsArabic();

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: FutureBuilder<int>(
        future: _usersCount(),
        builder: (context, snapshot) {
          final int usersCount = snapshot.data ?? 0;
          final bool canSignup = usersCount < 2;

          if (!canSignup && isSignupMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => isSignupMode = false);
              }
            });
          }

          return Scaffold(
            backgroundColor: _pageBg,
            body: Container(
              decoration: BoxDecoration(
                color: _pageBg,
                gradient: _isDark
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF111827),
                          Color(0xFF0B2944),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : LinearGradient(
                        colors: [lapisBlue.withOpacity(0.7), lapisBlue],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 390),
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _isDark
                            ? const Color(0xFF334155)
                            : Colors.transparent,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(_isDark ? 0.35 : 0.1),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
Image.asset(
  'assets/logo.png',
  width: 180,
  height: 180,
  fit: BoxFit.contain,
),                     const SizedBox(height: 20),
                        Text(
                          tr('VividDent ', 'VividDent '),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _primaryText,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildModeSwitch(usersCount),
                        const SizedBox(height: 18),
                        _buildRoleHint(usersCount),
                        SizedBox(height: isSignupMode ? 18 : 28),
                        _buildTextField(
                          controller: usernameController,
                          focusNode: _userFocus,
                          hint: tr('اسم المستخدم', 'Username'),
                          icon: Icons.person_outline,
                        ),
                        if (isSignupMode) ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: emailController,
                            focusNode: _emailFocus,
                            hint: tr('البريد الإلكتروني', 'Email'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: passwordController,
                          focusNode: _passFocus,
                          hint: tr('كلمة المرور', 'Password'),
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: isSignupMode
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onSubmitted: isSignupMode ? null : _submit,
                        ),
                        if (!isSignupMode) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: isArabic
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  loading ? null : _showForgotPasswordDialog,
                              child: const Text(
                                '',
                              ),
                            ),
                          ),
                        ],
                        if (!isSignupMode) ...[
                          Align(
                            alignment: isArabic
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  loading ? null : _showForgotPasswordDialog,
                              child: Text(
                                tr('نسيت كلمة المرور؟', 'Forgot password?'),
                                style: const TextStyle(
                                  color: lapisBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (isSignupMode) ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: confirmPasswordController,
                            focusNode: _confirmPassFocus,
                            hint: tr('تأكيد كلمة المرور', 'Confirm Password'),
                            icon: Icons.lock_reset_outlined,
                            obscure: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _submit,
                          ),
                        ],
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : isSignupMode && !canSignup
                                    ? null
                                    : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lapisBlue,
                              disabledBackgroundColor: Colors.grey.shade500,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 6,
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    isSignupMode
                                        ? tr('إنشاء حساب', 'Sign Up')
                                        : tr('دخول', 'Login'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        if (successMessage != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            successMessage!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}