// lib/screens/auth/login_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 🌟 1. เพิ่ม Import 2 ตัวนี้เข้ามาเพื่อจัดการระบบแจ้งเตือน
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/notification_service.dart';

import '../../constants.dart';
import '../home/home_screen.dart';
import '../orders/purchase_order_screen.dart';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF2A2A35);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryWhite = Colors.white;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool loading = false;
  String? error;
  bool showPass = false;
  bool isRegister = false;

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

          // 🌟 2. เพิ่มโค้ดดึงและอัปโหลด FCM Token ทันทีที่ล็อกอินสำเร็จ!
          try {
            String? fcmToken = await NotificationService.getFcmToken();
            if (fcmToken != null) {
              await NotificationService.uploadTokenToServer(fcmToken);
            }
          } catch (fcmError) {
            print("FCM Token Upload Failed: $fcmError");
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
                backgroundColor: kPrimaryWhite,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
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
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryWhite, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildBrandLogo(double width) {
    return Container(
      width: width,
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.06),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ClipRect(
          child: Align(
            alignment: const Alignment(0, 0.02),
            heightFactor: 0.38,
            child: Transform.scale(
              scale: 2.2,
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: width - 24,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 680;
    final contentWidth = screenSize.width < 390 ? screenSize.width - 40 : 360.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -110,
              right: -90,
              child: Container(
                width: 310,
                height: 310,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGlowPurple.withOpacity(0.42),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -120,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.025),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isCompact ? 18 : 32,
                  ),
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBrandLogo(contentWidth),
                        SizedBox(height: isCompact ? 18 : 26),
                        Text(
                          isRegister ? 'CREATE YOUR ACCOUNT' : 'WELCOME BACK',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Professional system for modern\nconstruction management.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: isCompact ? 22 : 30),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: EdgeInsets.all(isCompact ? 20 : 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.055),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: emailCtrl,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _buildInputDecoration(
                                        'Email Address',
                                        Icons.alternate_email_rounded,
                                      ),
                                      validator: (v) => (v ?? '').contains('@')
                                          ? null
                                          : 'รูปแบบอีเมลไม่ถูกต้อง',
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: passCtrl,
                                      obscureText: !showPass,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration:
                                          _buildInputDecoration(
                                            'Password',
                                            Icons.lock_open_rounded,
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
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                      validator: (v) => (v ?? '').length >= 6
                                          ? null
                                          : 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
                                    ),
                                    if (error != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                error!,
                                                style: const TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: isCompact ? 22 : 28),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: loading ? null : submitForm,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kPrimaryWhite,
                                          foregroundColor: Colors.black,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.black,
                                                      strokeWidth: 3,
                                                    ),
                                              )
                                            : Text(
                                                isRegister
                                                    ? 'CREATE ACCOUNT'
                                                    : 'SIGN IN',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.2,
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
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isRegister
                                  ? 'Already have an account? '
                                  : 'New to WallCraft? ',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                isRegister = !isRegister;
                                error = null;
                              }),
                              child: const Text(
                                'Switch',
                                style: TextStyle(
                                  color: kPrimaryWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 24 : 34),
                        Text(
                          'WALLCRAFT CMS • v1.0.2',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.2),
                            letterSpacing: 2.6,
                          ),
                        ),
                      ],
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
