import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../home/home_screen.dart';
import '../orders/purchase_order_screen.dart';

const Color kDarkBg = Color(0xFF0C0C0E);
const Color kCardDark = Color(0xFF18181B);
const Color kGlowPurple = Color(0xFF7B2CBF);
const Color kLimeGreen = Color(0xFFD2E862);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;
  bool showPass = false;
  bool showConfirmPass = false;
  bool isRegister = false;
  bool _showAccountChooser = false;
  bool _rememberedAccountsLoaded = false;
  String? error;
  List<RememberedAccount> _rememberedAccounts = const [];

  @override
  void initState() {
    super.initState();
    _loadRememberedAccounts();
  }

  Future<void> _loadRememberedAccounts() async {
    try {
      final accounts = await AuthService.loadRememberedAccounts();
      if (!mounted) return;
      setState(() {
        _rememberedAccounts = accounts;
        _showAccountChooser = accounts.isNotEmpty;
        _rememberedAccountsLoaded = true;
      });
    } catch (loadError) {
      debugPrint(
        '[AuthService] Could not load remembered accounts: $loadError',
      );
      if (mounted) setState(() => _rememberedAccountsLoaded = true);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(String serverError) {
    final message = serverError.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_grant')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (message.contains('email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าใช้งาน';
    }
    if (message.contains('user already registered') ||
        message.contains('already exists')) {
      return 'อีเมลนี้ถูกลงทะเบียนแล้ว กรุณาเข้าสู่ระบบ';
    }
    if (message.contains('password') && message.contains('6 characters')) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    if (message.contains('rate limit')) {
      return 'ทำรายการบ่อยเกินไป กรุณารอสักครู่';
    }
    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  Future<void> _finishAuthentication() async {
    PurchaseOrderScreen.clearCache();
    try {
      final fcmToken = await NotificationService.getFcmToken();
      if (fcmToken != null) {
        await NotificationService.uploadTokenToServer(fcmToken);
      }
    } catch (fcmError) {
      debugPrint('FCM Token Upload Failed: $fcmError');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _quickSignIn(RememberedAccount account) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AuthService.signInRememberedAccount(account);
      if (result == AuthRefreshResult.refreshed) {
        await _finishAuthentication();
      } else if (result == AuthRefreshResult.invalid) {
        _showManualLogin(
          email: account.email,
          message: 'รหัสผ่านที่จำไว้ใช้ไม่ได้ กรุณากรอกรหัสผ่านล่าสุด',
        );
      } else {
        _showManualLogin(
          email: account.email,
          message: 'เชื่อมต่อระบบไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
        );
      }
    } catch (quickSignInError) {
      _showManualLogin(
        email: account.email,
        message: _getFriendlyErrorMessage('$quickSignInError'),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _forgetRememberedAccount(RememberedAccount account) async {
    try {
      await AuthService.forgetRememberedAccount(account.email);
      if (!mounted) return;
      setState(() {
        _rememberedAccounts = _rememberedAccounts
            .where((saved) => saved.email != account.email)
            .toList(growable: false);
        if (_rememberedAccounts.isEmpty) {
          _showAccountChooser = false;
          emailCtrl.clear();
          passCtrl.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('นำ ${account.label} ออกจากเครื่องนี้แล้ว'),
          backgroundColor: kCardDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'ไม่สามารถลบบัญชีที่จำไว้ได้ กรุณาลองใหม่');
      }
    }
  }

  void _showAccountOptions() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF151518),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'จัดการบัญชีที่จำไว้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rememberedAccounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final account = _rememberedAccounts[index];
                    final avatarUrl = account.avatarUrl?.trim() ?? '';
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1),
                      tileColor: Colors.white.withValues(alpha: 0.055),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: kGlowPurple,
                        foregroundImage: avatarUrl.isEmpty
                            ? null
                            : NetworkImage(avatarUrl),
                        child: Text(
                          account.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        account.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'ลบโปรไฟล์นี้ออก',
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _forgetRememberedAccount(account);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualLogin({String? email, String? message}) {
    if (!mounted) return;
    setState(() {
      _showAccountChooser = false;
      isRegister = false;
      emailCtrl.text = email ?? '';
      passCtrl.clear();
      confirmPassCtrl.clear();
      error = message;
      _formKey.currentState?.reset();
    });
  }

  void _showRegistration() {
    setState(() {
      _showAccountChooser = false;
      isRegister = true;
      emailCtrl.clear();
      passCtrl.clear();
      confirmPassCtrl.clear();
      error = null;
      _formKey.currentState?.reset();
    });
  }

  void _showChooser() {
    if (_rememberedAccounts.isEmpty) return;
    setState(() {
      _showAccountChooser = true;
      isRegister = false;
      passCtrl.clear();
      confirmPassCtrl.clear();
      error = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> submitForm() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (isRegister && passCtrl.text != confirmPassCtrl.text) {
      setState(() {
        error = 'รหัสผ่านทั้งสองช่องไม่ตรงกัน';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final url = isRegister ? AppConfig.registerUrl : AppConfig.loginUrl;
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailCtrl.text.trim(),
          'password': passCtrl.text,
        }),
      );
      final decoded = jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};

      if (response.statusCode == 200) {
        if (data['session'] != null) {
          final persisted = await AuthService.persistLoginSession(
            response: data,
            email: emailCtrl.text.trim(),
            password: passCtrl.text,
          );
          if (!persisted) {
            throw const FormatException('Login response has no access token');
          }
          await _finishAuthentication();
        } else if (isRegister && mounted) {
          setState(() {
            isRegister = false;
            passCtrl.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'สมัครสมาชิกสำเร็จ กรุณาเข้าสู่ระบบ',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: kLimeGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw data['error'] ?? 'Authentication failed';
      }
    } on SocketException {
      if (mounted) setState(() => error = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } catch (submitError) {
      if (mounted) {
        setState(
          () => error = _getFriendlyErrorMessage(
            submitError.toString().replaceAll('Exception:', '').trim(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildLogo() {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLimeGreen.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: kLimeGreen.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.architecture_rounded, color: kLimeGreen, size: 30),
      ),
    );
  }

  Widget _buildBrand() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.4,
        ),
        children: [
          TextSpan(
            text: 'WALL',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'CRAFT',
            style: TextStyle(color: kLimeGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberedAccountCard(RememberedAccount account) {
    final avatarUrl = account.avatarUrl?.trim() ?? '';
    return Material(
      color: Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : () => _quickSignIn(account),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kGlowPurple,
                foregroundImage: avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: Text(
                  account.initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  account.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      isDense: true,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.48),
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(color: kLimeGreen, fontSize: 13),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.55),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: kLimeGreen, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.4),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF5252).withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF7B7B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFFF9A9A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            label: 'อีเมล',
            icon: Icons.alternate_email_rounded,
          ),
          validator: (value) =>
              (value ?? '').contains('@') ? null : 'รูปแบบอีเมลไม่ถูกต้อง',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: passCtrl,
          obscureText: !showPass,
          textInputAction: TextInputAction.done,
          autofillHints: isRegister
              ? const [AutofillHints.newPassword]
              : const [AutofillHints.password],
          onFieldSubmitted: (_) => submitForm(),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _inputDecoration(
            label: 'รหัสผ่าน',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => showPass = !showPass),
              icon: Icon(
                showPass
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 20,
              ),
            ),
          ),
          validator: (value) => (value ?? '').length >= 6
              ? null
              : 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
        ),
        if (isRegister) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPassCtrl,
            obscureText: !showConfirmPass,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => submitForm(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDecoration(
              label: 'ยืนยันรหัสผ่าน',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => showConfirmPass = !showConfirmPass),
                icon: Icon(
                  showConfirmPass
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.white.withValues(alpha: 0.45),
                  size: 20,
                ),
              ),
            ),
            validator: (value) {
              if (!isRegister) return null;
              if ((value ?? '').isEmpty) return 'กรุณากรอกยืนยันรหัสผ่าน';
              if (value != passCtrl.text) return 'รหัสผ่านทั้งสองช่องไม่ตรงกัน';
              return null;
            },
          ),
        ],
        if (error != null) ...[const SizedBox(height: 14), _buildErrorBanner()],
        const SizedBox(height: 22),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kLimeGreen,
              foregroundColor: const Color(0xFF141800),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: loading ? null : submitForm,
            child: Text(
              isRegister ? 'สร้างบัญชี' : 'เข้าสู่ระบบ',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: kLimeGreen),
          onPressed: loading
              ? null
              : () => setState(() {
                  isRegister = !isRegister;
                  error = null;
                  passCtrl.clear();
                  confirmPassCtrl.clear();
                  _formKey.currentState?.reset();
                }),
          child: Text(
            isRegister
                ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                : 'ยังไม่มีบัญชี? สร้างบัญชี',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_rememberedAccountsLoaded) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: kDarkBg,
          body: Center(child: _buildLogo()),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kDarkBg,
        systemNavigationBarDividerColor: kDarkBg,
      ),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF15161A), kDarkBg],
                    stops: [0, 0.72],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -145,
              right: -105,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        kLimeGreen.withValues(alpha: 0.11),
                        kLimeGreen.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    20,
                    18,
                    _showAccountChooser ? 88 : 20,
                  ),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: EdgeInsets.symmetric(
                      horizontal: _showAccountChooser ? 2 : 22,
                      vertical: _showAccountChooser ? 12 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: _showAccountChooser
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showAccountChooser
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildLogo(),
                                if (!_showAccountChooser &&
                                    _rememberedAccounts.isNotEmpty)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'กลับไปเลือกบัญชี',
                                      onPressed: loading ? null : _showChooser,
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(child: _buildBrand()),
                          const SizedBox(height: 16),
                          Text(
                            _showAccountChooser
                                ? 'เลือกบัญชี'
                                : isRegister
                                ? 'สร้างบัญชี'
                                : 'เข้าสู่ระบบ',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _showAccountChooser
                                ? 'เลือกบัญชีเพื่อเข้าสู่ระบบ'
                                : isRegister
                                ? 'สมัครใช้งาน WallCraft'
                                : 'ลงชื่อเข้าใช้ WallCraft',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                              fontSize: 13,
                            ),
                          ),
                          if (error != null && _showAccountChooser) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 22),
                          if (_showAccountChooser) ...[
                            for (
                              var index = 0;
                              index < _rememberedAccounts.length;
                              index++
                            ) ...[
                              _buildRememberedAccountCard(
                                _rememberedAccounts[index],
                              ),
                              if (index < _rememberedAccounts.length - 1)
                                const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: kLimeGreen,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: loading ? null : _showManualLogin,
                                child: const Text(
                                  'ใช้บัญชีอื่น',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ] else
                            _buildForm(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showAccountChooser)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 2,
                right: 6,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'จัดการบัญชีที่จำไว้',
                  onPressed: loading ? null : _showAccountOptions,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            if (_showAccountChooser)
              Positioned(
                left: 18,
                right: 18,
                bottom: MediaQuery.paddingOf(context).bottom + 10,
                child: Center(
                  child: SizedBox(
                    width: 180,
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kLimeGreen,
                        backgroundColor: kDarkBg.withValues(alpha: 0.94),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        side: BorderSide(
                          color: kLimeGreen.withValues(alpha: 0.8),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: loading ? null : _showRegistration,
                      child: const Text(
                        'สร้างบัญชีใหม่',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: kLimeGreen),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
