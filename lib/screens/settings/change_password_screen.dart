import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

// 🎨 Palette สีสไตล์ Monochrome Dark Luxury
const Color kBgPureDark = Color(0xFF0C0C0E);
const Color kSurfaceDark = Color(0xFF161618);
const Color kBorderSubtle = Color(0xFF242428);
const Color kLimeGreen = Color(0xFFD2E862);

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPassCtrl.addListener(_onFieldChanged);
    _newPassCtrl.addListener(_onFieldChanged);
    _confirmPassCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPassCtrl.text.length >= 6;
  bool get _hasMatch =>
      _newPassCtrl.text.isNotEmpty && _newPassCtrl.text == _confirmPassCtrl.text;
  bool get _isDifferentFromCurrent =>
      _currentPassCtrl.text.isNotEmpty &&
      _newPassCtrl.text.isNotEmpty &&
      _currentPassCtrl.text != _newPassCtrl.text;

  Future<void> _submitChangePassword() async {
    FocusScope.of(context).unfocus();

    final currentPass = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _errorMessage = "กรุณากรอกข้อมูลให้ครบทุกช่อง");
      return;
    }

    if (newPass.length < 6) {
      setState(() => _errorMessage = "รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร");
      return;
    }

    if (newPass != confirmPass) {
      setState(() => _errorMessage = "รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน");
      return;
    }

    if (currentPass == newPass) {
      setState(() => _errorMessage = "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await ApiService.post(
        Uri.parse('${AppConfig.baseUrl}/auth/change-password'),
        body: jsonEncode({
          'token': token,
          'current_password': currentPass,
          'new_password': newPass,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = data['error'] ?? "ไม่สามารถเปลี่ยนรหัสผ่านได้ กรุณาตรวจสอบรหัสเดิม";
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่";
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kBorderSubtle),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: kLimeGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kLimeGreen.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: kLimeGreen, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                "เปลี่ยนรหัสผ่านสำเร็จ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "ระบบได้ทำการอัปเดตรหัสผ่านใหม่ของคุณเรียบร้อยแล้ว ท่านสามารถใช้รหัสผ่านใหม่นี้ในการเข้าสู่ระบบครั้งถัดไปได้ทันที",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context); // Pop screen back to Profile
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLimeGreen,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "เสร็จสิ้น",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kBgPureDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "เปลี่ยนรหัสผ่าน",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // 🛡️ Header Hero Icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: kLimeGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: kLimeGreen.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: const Icon(Icons.shield_outlined, color: kLimeGreen, size: 34),
                ),
                const SizedBox(height: 16),
                const Text(
                  "ความปลอดภัยบัญชีผู้ใช้งาน",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "กรุณายืนยันรหัสผ่านปัจจุบันของคุณก่อน เพื่อความปลอดภัยในการตั้งรหัสผ่านใหม่",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.4),
                ),
                const SizedBox(height: 24),

                // ⚠️ Error Box
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 📋 Form Container (Monolithic Apple Box)
                Container(
                  decoration: BoxDecoration(
                    color: kSurfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderSubtle),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller: _currentPassCtrl,
                          focusNode: _currentFocus,
                          nextFocusNode: _newFocus,
                          label: "รหัสผ่านปัจจุบัน",
                          hintText: "กรอกรหัสผ่านปัจจุบันของคุณ",
                          icon: Icons.key_rounded,
                          obscureText: _obscureCurrent,
                          onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        const Divider(height: 1, thickness: 0.6, color: kBorderSubtle, indent: 52),
                        _buildInputField(
                          controller: _newPassCtrl,
                          focusNode: _newFocus,
                          nextFocusNode: _confirmFocus,
                          label: "รหัสผ่านใหม่",
                          hintText: "กำหนดรหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)",
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureNew,
                          onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        const Divider(height: 1, thickness: 0.6, color: kBorderSubtle, indent: 52),
                        _buildInputField(
                          controller: _confirmPassCtrl,
                          focusNode: _confirmFocus,
                          label: "ยืนยันรหัสผ่านใหม่",
                          hintText: "กรอกรหัสผ่านใหม่อีกครั้งให้ตรงกัน",
                          icon: Icons.lock_rounded,
                          obscureText: _obscureConfirm,
                          isLast: true,
                          onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          onSubmitted: (_) => _submitChangePassword(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔍 Live Security Checklist Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kSurfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "เงื่อนไขความปลอดภัยของรหัสผ่าน",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildChecklistRow(
                        isValid: _hasMinLength,
                        text: "ความยาวอย่างน้อย 6 ตัวอักษรขึ้นไป",
                      ),
                      const SizedBox(height: 8),
                      _buildChecklistRow(
                        isValid: _hasMatch,
                        text: "รหัสผ่านใหม่และยืนยันรหัสผ่านตรงกัน",
                      ),
                      const SizedBox(height: 8),
                      _buildChecklistRow(
                        isValid: _isDifferentFromCurrent,
                        text: "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ℹ️ Tip Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "คำแนะนำ: หลีกเลี่ยงการใช้รหัสผ่านที่เป็นข้อมูลเปิดเผย เช่น วันเกิด หรือเบอร์โทรศัพท์ เพื่อความปลอดภัยสูงสุดของข้อมูลงาน",
                          style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 🚀 Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitChangePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kLimeGreen,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: kLimeGreen.withValues(alpha: 0.3),
                      disabledForegroundColor: Colors.black38,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.black,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "บันทึกรหัสผ่านใหม่",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    bool isLast = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white70, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: (val) {
                    if (nextFocusNode != null) {
                      FocusScope.of(context).requestFocus(nextFocusNode);
                    } else if (onSubmitted != null) {
                      onSubmitted(val);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey[500],
              size: 20,
            ),
            onPressed: onToggleObscure,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow({required bool isValid, required String text}) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isValid ? kLimeGreen : Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isValid ? Icons.check_rounded : Icons.circle,
            size: isValid ? 13 : 5,
            color: isValid ? Colors.black : Colors.white24,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isValid ? Colors.white : Colors.white54,
            fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
