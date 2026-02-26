// lib/screens/auth/login_screen.dart
import 'dart:convert';
import 'dart:io'; // ✅ เพิ่ม import นี้เพื่อเช็คเรื่องเน็ตหลุด
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../home/home_screen.dart';

// 🎨 Palette สีสไตล์ Monochrome (ขาว-ดำ) เรียบหรู
const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF2A2A35); // ปรับแสงฟุ้งให้เป็นสีเทาอมม่วงนิดๆ ดูแพงขึ้น
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryWhite = Colors.white; // ⚪️ ใช้สีขาวเป็นสีหลักแทนสีเขียว

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

  // -----------------------------------------------------------
  // 🟢 ฟังก์ชันแปลภาษา Error ให้เป็นภาษาคนเข้าใจง่าย
  // -----------------------------------------------------------
  String _getFriendlyErrorMessage(String serverError) {
    String msg = serverError.toLowerCase();

    if (msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (msg.contains('email not confirmed')) {
      return 'กรุณายืนยันอีเมลใน Inbox ของคุณก่อนเข้าใช้งาน';
    }
    if (msg.contains('user already registered') || msg.contains('already exists')) {
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
            await prefs.setString('refresh_token', data['session']['refresh_token']);
          }

          if (data['user'] != null && data['user']['id'] != null) {
            await prefs.setString('user_id', data['user']['id']);
          } else if (data['session']['user'] != null && data['session']['user']['id'] != null) {
            await prefs.setString('user_id', data['session']['user']['id']);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HomeScreen(),
                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
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
                content: Text('✅ สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                backgroundColor: kPrimaryWhite, // ⚪️ แจ้งเตือนสีขาว
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
            );
          }
        }
      } else {
        throw data['error'] ?? 'Authentication failed (${response.statusCode})';
      }

    } on SocketException {
      if (mounted) {
        setState(() => error = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = _getFriendlyErrorMessage(e.toString().replaceAll('Exception:', '').trim()));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20), // ⚪️ ไอคอนสีขาวหม่น
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
      // ⚪️ ขอบสว่างเป็นสีขาวตอนกดพิมพ์
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryWhite, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            // 🌌 Background Glow (แสงเทาอมม่วง เรียบๆ)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.3)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container(color: Colors.transparent)),
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    // 🏗️ App Name
                    const Text(
                      'WallCraft',
                      style: TextStyle(
                        fontSize: 42, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white, 
                        letterSpacing: -1, 
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Professional system for\nmodern construction management.',
                      style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 48),
                    
                    // 🛡️ Glass Login Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: emailCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _buildInputDecoration('Email Address', Icons.alternate_email_rounded),
                                  validator: (v) => (v ?? '').contains('@') ? null : 'รูปแบบอีเมลไม่ถูกต้อง',
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: passCtrl,
                                  obscureText: !showPass,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _buildInputDecoration('Password', Icons.lock_open_rounded).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(() => showPass = !showPass),
                                      icon: Icon(showPass ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey, size: 20),
                                    ),
                                  ),
                                  validator: (v) => (v ?? '').length >= 6 ? null : 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
                                ),
                                
                                if (error != null) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.2))), 
                                      ],
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 32),
                                
                                // ⚪️ Main Button (พื้นขาว ตัวหนังสือดำ)
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : submitForm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kPrimaryWhite,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: loading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                                        : Text(isRegister ? 'CREATE ACCOUNT' : 'SIGN IN', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Toggle Register/Login
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isRegister ? 'Already have an account? ' : 'New to WallCraft? ', style: const TextStyle(color: Colors.grey)),
                          GestureDetector(
                            onTap: () => setState(() { isRegister = !isRegister; error = null; }),
                            child: const Text(
                              'Switch',
                              style: TextStyle(color: kPrimaryWhite, fontWeight: FontWeight.bold), // ⚪️ เปลี่ยนสีลิงก์เป็นสีขาว
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: Text(
                        'WALLCRAFT CMS • v1.0.2',
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.15), letterSpacing: 3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}