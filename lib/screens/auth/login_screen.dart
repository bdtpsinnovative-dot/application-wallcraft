// lib/screens/auth/login_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 🌟 Import เพื่อจัดการระบบแจ้งเตือน
import '../../services/notification_service.dart';

import '../../constants.dart';
import '../home/home_screen.dart';
import '../orders/purchase_order_screen.dart';

const Color kDarkBg = Color(0xFF0C0C0E);
const Color kCardDark = Color(0xFF18181B);
const Color kGlowPurple = Color(0xFF7B2CBF);
const Color kGlowViolet = Color(0xFF4A3080);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kLimeGreenBright = Color(0xFFE4FA63);
const Color kPremiumGold = Color(0xFFFFC107);
const Color kPrimaryWhite = Colors.white;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;
  String? error;
  bool showPass = false;
  bool isRegister = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  String _getFriendlyErrorMessage(String serverError) {
    String msg = serverError.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_grant')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (msg.contains('email not confirmed')) {
      return 'กรุณายืนยันอีเมลใน Inbox ของคุณก่อนเข้าใช้งาน';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists')) {
      return 'อีเมลนี้ถูกลงทะเบียนไปแล้ว กรุณาล็อกอิน';
    }
    if (msg.contains('password') && msg.contains('6 characters')) {
      return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
    }
    if (msg.contains('email') && msg.contains('required')) {
      return 'กรุณากรอกอีเมลให้ครบถ้วน';
    }
    if (msg.contains('rate limit')) {
      return 'คุณทำรายการบ่อยเกินไป กรุณารอสักครู่';
    }

    return 'เกิดข้อผิดพลาด ($serverError)';
  }

  Future<void> submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['session'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['session']['access_token']);

          if (data['session']['refresh_token'] != null) {
            await prefs.setString(
              'refresh_token',
              data['session']['refresh_token'],
            );
          }

          if (data['user'] != null && data['user']['id'] != null) {
            await prefs.setString('user_id', data['user']['id']);
          } else if (data['session']['user'] != null &&
              data['session']['user']['id'] != null) {
            await prefs.setString('user_id', data['session']['user']['id']);
          }

          // 🧹 ล้างแคชข้อมูลของ User เก่าทิ้งทันทีเพื่อให้ User ใหม่ได้ข้อมูลของตัวเอง 100%
          PurchaseOrderScreen.clearCache();

          // 🌟 ดึงและอัปโหลด FCM Token ทันทีที่ล็อกอินสำเร็จ!
          try {
            String? fcmToken = await NotificationService.getFcmToken();
            if (fcmToken != null) {
              await NotificationService.uploadTokenToServer(fcmToken);
            }
          } catch (fcmError) {
            debugPrint("FCM Token Upload Failed: $fcmError");
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
              ),
            );
          }
        } else {
          if (isRegister && mounted) {
            setState(() {
              error = null;
              isRegister = false;
              passCtrl.clear();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: kLimeGreen,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            );
          }
        }
      } else {
        throw data['error'] ?? 'Authentication failed (${response.statusCode})';
      }
    } on SocketException {
      if (mounted) {
        setState(
          () => error =
              'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = _getFriendlyErrorMessage(
            e.toString().replaceAll('Exception:', '').trim(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: kLimeGreen,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.7),
          size: 20,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kLimeGreen, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.6),
      ),
    );
  }

  Widget _buildBrandLogo() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: kLimeGreen.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: kLimeGreen.withValues(alpha: 0.22),
            blurRadius: 30,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: kGlowPurple.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Image.asset(
              'assets/icon/app_icon.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.architecture_rounded,
                  color: kLimeGreen,
                  size: 42,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 700;
    final contentWidth = screenSize.width < 390 ? screenSize.width - 36 : 360.0;

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
            // 🌌 1. Ambient Glow Orbs
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGlowPurple.withValues(alpha: 0.35),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kLimeGreen.withValues(alpha: 0.12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGlowViolet.withValues(alpha: 0.25),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // 🌟 2. Interactive Content with Entrance Animation
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isCompact ? 16 : 28,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🌟 Brand Logo with Glass Highlight
                            _buildBrandLogo(),
                            const SizedBox(height: 16),

                            // 🏷️ Brand Name Text
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'WALL',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 3.2,
                                  ),
                                ),
                                Text(
                                  'CRAFT',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: kLimeGreen,
                                    letterSpacing: 3.2,
                                    shadows: [
                                      Shadow(
                                        color: kLimeGreen.withValues(alpha: 0.5),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isCompact ? 24 : 32),

                            // 🪟 Glass Form Card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  padding: EdgeInsets.all(isCompact ? 20 : 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        // 📧 Email Field
                                        TextFormField(
                                          controller: emailCtrl,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          decoration: _buildInputDecoration(
                                            'Email Address',
                                            Icons.alternate_email_rounded,
                                          ),
                                          validator: (v) =>
                                              (v ?? '').contains('@')
                                                  ? null
                                                  : 'รูปแบบอีเมลไม่ถูกต้อง',
                                        ),
                                        const SizedBox(height: 16),

                                        // 🔒 Password Field
                                        TextFormField(
                                          controller: passCtrl,
                                          obscureText: !showPass,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          decoration: _buildInputDecoration(
                                            'Password',
                                            Icons.lock_outline_rounded,
                                          ).copyWith(
                                            suffixIcon: IconButton(
                                              onPressed: () => setState(
                                                () => showPass = !showPass,
                                              ),
                                              icon: Icon(
                                                showPass
                                                    ? Icons.visibility_rounded
                                                    : Icons
                                                        .visibility_off_rounded,
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          validator: (v) => (v ?? '').length >= 6
                                              ? null
                                              : 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
                                        ),

                                        // ⚠️ Error Message Display
                                        if (error != null) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF5252)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFFF5252)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  color: Color(0xFFFF5252),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    error!,
                                                    style: const TextStyle(
                                                      color: Color(0xFFFF8A80),
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      height: 1.25,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        SizedBox(height: isCompact ? 20 : 26),

                                        // 🚀 Sign In / Register Button (Neon Lime Glow)
                                        Container(
                                          width: double.infinity,
                                          height: 54,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            gradient: const LinearGradient(
                                              colors: [
                                                kLimeGreenBright,
                                                kLimeGreen,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: kLimeGreen.withValues(
                                                  alpha: loading ? 0.1 : 0.38,
                                                ),
                                                blurRadius: 22,
                                                spreadRadius: -2,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed:
                                                loading ? null : submitForm,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor:
                                                  const Color(0xFF141800),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                            child: loading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Color(0xFF141800),
                                                      strokeWidth: 2.8,
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        isRegister
                                                            ? 'CREATE ACCOUNT'
                                                            : 'SIGN IN',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: 1.2,
                                                          color:
                                                              Color(0xFF141800),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF141800),
                                                      ),
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
                            const SizedBox(height: 22),

                            // 🔄 Switch Mode (Sign in <-> Sign up)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isRegister
                                      ? 'Already have an account? '
                                      : 'New to WallCraft? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    isRegister = !isRegister;
                                    error = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      isRegister ? 'Sign In' : 'Switch',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kLimeGreen,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                        decorationColor: kLimeGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
