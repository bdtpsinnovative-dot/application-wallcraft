// lib/screens/settings/profile_screen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';

import '../../constants.dart';
import '../auth/login_screen.dart';
import '../orders/purchase_order_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'custom_crop_screen.dart';
import 'faq_screen.dart';
import '../teams/teams_screen.dart';

// 🎨 Palette สีสไตล์ Monochrome Dark Luxury (เรียบเนียน เนื้อเดียวกัน)
const Color kBgPureDark = Color(0xFF0C0C0E);
const Color kSurfaceDark = Color(0xFF161618);
const Color kBorderSubtle = Color(0xFF242428);
const Color kLimeGreen = Color(0xFFD2E862);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final teamNameCtrl = TextEditingController();
  final teamDescCtrl = TextEditingController();

  bool loading = true;
  String? avatarUrl;
  File? _imageFile;
  String? _errorMessage;

  bool _isAdmin = false;
  String _notiLevel = 'team'; // 'none', 'team', 'all'
  String _cacheSize = '0.0 MB';
  String _appVersion = '2.0.7';
  int? _serverLatencyMs;
  bool _isCheckingServer = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadAppVersion();
    _calcCacheSize();
    _checkServerPing();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    teamNameCtrl.dispose();
    teamDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      loading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final url = Uri.parse('${AppConfig.baseUrl}/profile');

    try {
      final response = await ApiService.post(
        url,
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = data['profile'];

        if (mounted) {
          setState(() {
            nameCtrl.text = profile['full_name'] ?? '';
            phoneCtrl.text = profile['phone_number'] ?? '';
            emailCtrl.text = profile['email'] ?? '';
            avatarUrl = profile['avatar_url'];
            _isAdmin = (profile['role'] == 'admin');
            _notiLevel = profile['noti_level']?.toString() ?? 'team';

            if (profile['teams'] != null) {
              teamNameCtrl.text = profile['teams']['team_name'] ?? 'ไม่มีทีม';
              teamDescCtrl.text = profile['teams']['description'] ?? '-';
            } else {
              teamNameCtrl.text = 'ไม่ได้สังกัดทีม';
              teamDescCtrl.text = '-';
            }
          });
        }
        try {
          await AuthService.updateCurrentRememberedAccountProfile(
            displayName: profile['full_name']?.toString(),
            avatarUrl: profile['avatar_url']?.toString(),
          );
        } catch (_) {}
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        throw "โหลดข้อมูลไม่สำเร็จ (${response.statusCode})";
      }
    } on SocketException {
      if (mounted) {
        setState(() => _errorMessage = "ขาดการเชื่อมต่ออินเทอร์เน็ต");
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _errorMessage = "เซิร์ฟเวอร์ตอบกลับช้าเกินไป");
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = "ไม่สามารถโหลดข้อมูลโปรไฟล์ได้ในขณะนี้");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = packageInfo.version);
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '2.0.7');
    }
  }

  Future<void> _calcCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (var file in files) {
          if (file is File) {
            totalBytes += file.lengthSync();
          }
        }
      }
      if (mounted) {
        setState(() {
          if (totalBytes < 1024 * 1024) {
            _cacheSize = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
          } else {
            _cacheSize = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '0.0 MB');
    }
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true, followLinks: false);
        for (var file in files) {
          try {
            if (file is File) file.deleteSync();
          } catch (_) {}
        }
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _calcCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'ล้างหน่วยความจำแคชเรียบร้อยแล้ว',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: kLimeGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/upload-avatar');
      var request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      var response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        return data['publicUrl'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;
      await _cropImage(File(pickedFile.path));
    } catch (_) {}
  }

  Future<void> _cropImage(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      if (!mounted) return;
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => CustomCropScreen(image: imageBytes),
        ),
      );

      if (croppedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/profile_temp.png').create();
        await file.writeAsBytes(croppedBytes);

        setState(() => _imageFile = file);
        _updateProfile();
      }
    } catch (_) {}
  }

  void _showImageSourceChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              const Text(
                "เปลี่ยนรูปโปรไฟล์",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageChoiceButton(Icons.camera_alt_rounded, "ถ่ายรูป", () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  }),
                  _buildImageChoiceButton(Icons.photo_library_rounded, "คลังรูปภาพ", () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  }),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageChoiceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }

  Future<void> _updateProfile() async {
    if (loading) return;
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final url = Uri.parse('${AppConfig.baseUrl}/profile');
    String? finalAvatarUrl = avatarUrl;

    try {
      if (_imageFile != null) {
        final uploadedUrl = await _uploadImage(_imageFile!);
        if (uploadedUrl != null) {
          finalAvatarUrl = uploadedUrl;
        } else {
          throw "อัปโหลดรูปภาพไม่สำเร็จ";
        }
      }

      final response = await http
          .put(
            url,
            headers: {
              "Content-Type": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              'token': token,
              'full_name': nameCtrl.text,
              'phone_number': phoneCtrl.text,
              'avatar_url': finalAvatarUrl,
              'noti_level': _notiLevel,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          await AuthService.updateCurrentRememberedAccountProfile(
            displayName: nameCtrl.text,
            avatarUrl: finalAvatarUrl,
          );
        } catch (_) {}
        if (mounted) {
          setState(() {
            avatarUrl = finalAvatarUrl;
            _imageFile = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'บันทึกข้อมูลเรียบร้อยแล้ว',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              backgroundColor: kLimeGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        _logout();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _updateNotiLevel(String newLevel) async {
    setState(() => _notiLevel = newLevel);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final url = Uri.parse('${AppConfig.baseUrl}/profile');
    try {
      await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          'token': token,
          'full_name': nameCtrl.text,
          'phone_number': phoneCtrl.text,
          'avatar_url': avatarUrl,
          'noti_level': newLevel,
        }),
      );
    } catch (_) {}
  }

  String _getNotiLabel(String level) {
    switch (level) {
      case 'all':
        return 'ทุกทีม';
      case 'team':
        return 'เฉพาะทีม';
      case 'none':
        return 'ปิดการเตือน';
      default:
        return 'เฉพาะทีม';
    }
  }

  // 🔑 เปลี่ยนรหัสผ่าน (ใส่รหัสเดิมก่อน ค่อยเปลี่ยน)
  void _showChangePasswordModal() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: kSurfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "เปลี่ยนรหัสผ่าน",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "กรุณากรอกรหัสผ่านปัจจุบันเพื่อความปลอดภัยก่อนตั้งรหัสผ่านใหม่",
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),

                    if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          localError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildFieldLabel("รหัสผ่านปัจจุบัน"),
                    _buildPasswordField(
                      controller: currentPassCtrl,
                      hint: "รหัสผ่านปัจจุบันของคุณ",
                      obscureText: obscureCurrent,
                      onToggleObscure: () =>
                          setModalState(() => obscureCurrent = !obscureCurrent),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel("รหัสผ่านใหม่"),
                    _buildPasswordField(
                      controller: newPassCtrl,
                      hint: "อย่างน้อย 6 ตัวอักษร",
                      obscureText: obscureNew,
                      onToggleObscure: () =>
                          setModalState(() => obscureNew = !obscureNew),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel("ยืนยันรหัสผ่านใหม่"),
                    _buildPasswordField(
                      controller: confirmPassCtrl,
                      hint: "กรอกรหัสผ่านใหม่อีกครั้ง",
                      obscureText: obscureConfirm,
                      onToggleObscure: () =>
                          setModalState(() => obscureConfirm = !obscureConfirm),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final currentPass = currentPassCtrl.text.trim();
                                final newPass = newPassCtrl.text.trim();
                                final confirmPass = confirmPassCtrl.text.trim();

                                if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                                  setModalState(() => localError = "กรุณากรอกข้อมูลให้ครบทุกช่อง");
                                  return;
                                }
                                if (newPass.length < 6) {
                                  setModalState(() => localError = "รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร");
                                  return;
                                }
                                if (newPass != confirmPass) {
                                  setModalState(() => localError = "รหัสผ่านใหม่ไม่ตรงกัน");
                                  return;
                                }
                                if (currentPass == newPass) {
                                  setModalState(() => localError = "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม");
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  localError = null;
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
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'เปลี่ยนรหัสผ่านสำเร็จเรียบร้อยแล้ว',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: kLimeGreen,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      localError = data['error'] ?? "ไม่สามารถเปลี่ยนรหัสผ่านได้";
                                    });
                                  }
                                } catch (_) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    localError = "เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่";
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLimeGreen,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'ยืนยันการเปลี่ยนรหัสผ่าน',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: const Icon(Icons.key_rounded, color: Colors.grey, size: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey[500],
              size: 18,
            ),
            onPressed: onToggleObscure,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // 🛡️ ความเป็นส่วนตัว & ความปลอดภัย
  void _showPrivacySecurityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "ความเป็นส่วนตัว & ความปลอดภัย",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPrivacyItem(
                  "การเข้ารหัสข้อมูลบัญชี",
                  "ข้อมูลการทำรายการทั้งหมดเข้ารหัสผ่าน SSL/TLS และเก็บกุญแจเข้ารหัสบน Hardware Secure Vault ของอุปกรณ์",
                ),
                const SizedBox(height: 10),
                _buildPrivacyItem(
                  "นโยบายพิกัดตำแหน่ง (GPS)",
                  "ระบบจับพิกัดเฉพาะตอนกดปุ่ม 'เช็คอินสถานที่' เพื่อยืนยันหน้างานจริงเท่านั้น ไม่มีการแอบติดตามตำแหน่งเบื้องหลังตลอดเวลา",
                ),
                const SizedBox(height: 10),
                _buildPrivacyItem(
                  "สิทธิ์กล้องและรูปภาพ",
                  "ใช้เพื่อแนบรูปภาพหน้างานประกอบการเช็คอิน และการเปลี่ยนรูปโปรไฟล์เท่านั้น ไม่มีการเข้าถึงข้อมูลส่วนตัวอื่น",
                ),
                const SizedBox(height: 10),
                _buildPrivacyItem(
                  "การคุ้มครองข้อมูลส่วนบุคคล (PDPA)",
                  "ข้อมูลคำสั่งซื้อ ลูกค้า และพิกัดสถานที่ทำงาน เป็นความลับเฉพาะภายในองค์กร ไม่มีการส่งต่อบุคคลภายนอก",
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("ปิดหน้านี้"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyItem(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  void _showNotificationSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),
              const Text(
                "การแจ้งเตือน (Notifications)",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                "เลือกระดับการแจ้งเตือนที่ต้องการรับบนอุปกรณ์นี้",
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              _buildNotiRow(
                level: 'all',
                title: 'ทุกทีม (All Teams)',
                subtitle: 'รับแจ้งเตือนกิจกรรมทั้งหมดในระบบ',
                ctx: ctx,
              ),
              const SizedBox(height: 8),
              _buildNotiRow(
                level: 'team',
                title: 'เฉพาะทีม (My Team)',
                subtitle: 'รับเฉพาะการแจ้งเตือนในทีมของฉัน',
                ctx: ctx,
              ),
              const SizedBox(height: 8),
              _buildNotiRow(
                level: 'none',
                title: 'ปิดการแจ้งเตือน (Mute)',
                subtitle: 'ปิดเสียงและการแจ้งเตือนทั้งหมด',
                ctx: ctx,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotiRow({
    required String level,
    required String title,
    required String subtitle,
    required BuildContext ctx,
  }) {
    final isSelected = _notiLevel == level;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _updateNotiLevel(level);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kLimeGreen : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: kLimeGreen, size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kSurfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "แก้ไขข้อมูลส่วนตัว",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildFieldLabel("อีเมลบัญชี (แก้ไขไม่ได้)"),
                _buildPlainTextField(emailCtrl, "อีเมล", readOnly: true),
                const SizedBox(height: 12),
                _buildFieldLabel("ชื่อ - นามสกุล"),
                _buildPlainTextField(nameCtrl, "ชื่อ-นามสกุล"),
                const SizedBox(height: 12),
                _buildFieldLabel("เบอร์โทรศัพท์"),
                _buildPlainTextField(phoneCtrl, "เบอร์โทรศัพท์", keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _buildFieldLabel("ทีมสังกัด"),
                _buildPlainTextField(teamNameCtrl, "ชื่อทีม", readOnly: true),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kLimeGreen,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'บันทึกข้อมูล',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainTextField(
    TextEditingController ctrl,
    String hint, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "ล้างหน่วยความจำแคช",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "ต้องการล้างไฟล์ชั่วคราวและรูปภาพขนาด $_cacheSize หรือไม่?\n(ไม่มีผลกระทบต่อข้อมูลของคุณ)",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("ล้างแคชทันที"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAppUpdate() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/check-update'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = Platform.isIOS
            ? (data['latest_version_ios'] ?? '1.0.0')
            : (data['latest_version_android'] ?? '1.0.0');
        final downloadUrl = Platform.isIOS
            ? data['download_url_ios']
            : data['download_url_android'];

        if (_appVersion != latestVersion && downloadUrl != null) {
          if (mounted) _showUpdateDialog(latestVersion, downloadUrl);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'คุณกำลังใช้งานเวอร์ชันล่าสุด (v$_appVersion) เรียบร้อยแล้ว',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: kSurfaceDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เวอร์ชันปัจจุบัน: v$_appVersion (เป็นเวอร์ชันล่าสุด)'),
            backgroundColor: kSurfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _checkServerPing({bool showToast = false}) async {
    if (_isCheckingServer) return;
    setState(() => _isCheckingServer = true);
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.baseUrl}/check-update'))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 404) {
        setState(() {
          _serverLatencyMs = stopwatch.elapsedMilliseconds;
          _isCheckingServer = false;
        });
        if (showToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ เซิร์ฟเวอร์ออนไลน์ปกติ (Latency: ${_serverLatencyMs}ms)'),
              backgroundColor: kSurfaceDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _serverLatencyMs = -1;
          _isCheckingServer = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverLatencyMs = -1;
          _isCheckingServer = false;
        });
        if (showToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Widget _buildServerStatusIndicator() {
    if (_isCheckingServer && _serverLatencyMs == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
          ),
          SizedBox(width: 6),
          Text("กำลังตรวจ...", style: TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      );
    }

    final isOk = _serverLatencyMs != null && _serverLatencyMs! >= 0;
    final dotColor = isOk ? const Color(0xFF00E676) : Colors.redAccent;
    final statusText = isOk ? "ออนไลน์ (${_serverLatencyMs}ms)" : "ออฟไลน์";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  void _showUpdateDialog(String latestVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String progress = '';
        bool isDownloading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kSurfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "มีอัปเดตเวอร์ชันใหม่!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Text(
                isDownloading
                    ? "กำลังดาวน์โหลด... $progress%\nกรุณารอสักครู่"
                    : "พบแอปเวอร์ชัน $latestVersion\nกรุณาอัปเดตเพื่อการใช้งานที่สมบูรณ์ที่สุดครับ",
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              actions: [
                if (!isDownloading)
                  TextButton(
                    child: const Text("ปิด", style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDownloading ? Colors.grey : kLimeGreen,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isDownloading
                      ? null
                      : () async {
                          if (Platform.isIOS) {
                            final Uri url = Uri.parse(downloadUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                            return;
                          }
                          setStateDialog(() {
                            isDownloading = true;
                            progress = '0';
                          });
                          try {
                            OtaUpdate()
                                .execute(
                                  downloadUrl,
                                  destinationFilename: 'wallcraft_update_$latestVersion.apk',
                                )
                                .listen((OtaEvent event) {
                                  setStateDialog(() {
                                    progress = event.value ?? '';
                                  });
                                  if (event.status == OtaStatus.INSTALLING && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                });
                          } catch (_) {
                            setStateDialog(() => isDownloading = false);
                          }
                        },
                  child: Text(
                    isDownloading ? "กำลังโหลด..." : "อัปเดตเลย",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "ออกจากระบบ",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบบัญชีนี้?",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("ออกจากระบบ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    PurchaseOrderScreen.clearCache();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kBgPureDark,
        body: loading
            ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('ลองใหม่อีกครั้ง'),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(
                          "การตั้งค่าบัญชี",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 1. Profile Header Card (Apple ID Style - สะอาด เรียบเนียน)
                      _buildProfileCard(),

                      const SizedBox(height: 14),

                      // เมนูทั้งหมดรวมเป็นกล่องเดียวติดกัน (Single Seamless Block)
                      _buildGroupContainer([
                        _buildSettingsRow(
                          icon: Icons.key_rounded,
                          title: "เปลี่ยนรหัสผ่าน",
                          subtitle: "ต้องยืนยันรหัสผ่านปัจจุบันก่อนเปลี่ยน",
                          onTap: _showChangePasswordModal,
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.shield_outlined,
                          title: "ความเป็นส่วนตัว & ความปลอดภัย",
                          subtitle: "นโยบาย GPS, สิทธิ์การใช้งาน และ PDPA",
                          onTap: _showPrivacySecurityModal,
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.groups_outlined,
                          title: "ข้อมูลสังกัด & เพื่อนร่วมทีม",
                          subtitle: teamNameCtrl.text.isEmpty
                              ? "ดูรายชื่อทีมและสมาชิกทั้งหมด"
                              : "สังกัดทีม: ${teamNameCtrl.text}",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TeamsScreen()),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.notifications_none_rounded,
                          title: "การแจ้งเตือน",
                          trailingText: _getNotiLabel(_notiLevel),
                          onTap: _showNotificationSettingsModal,
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.language_rounded,
                          title: "ภาษาของระบบ",
                          subtitle: "ภาษาเริ่มต้นของระบบ (ระบบล็อกไว้)",
                          trailingWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "ไทย (TH)",
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.lock_rounded, size: 13, color: Colors.white38),
                            ],
                          ),
                          showChevron: false,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("ระบบถูกล็อกให้แสดงผลเป็นภาษาไทย (TH) เป็นค่าเริ่มต้น"),
                                backgroundColor: kSurfaceDark,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.cleaning_services_outlined,
                          title: "ล้างแคชในเครื่อง",
                          trailingText: _cacheSize,
                          onTap: _confirmClearCache,
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.help_outline_rounded,
                          title: "คู่มือ & คำถามที่พบบ่อย (FAQ)",
                          subtitle: "วิธีเช็คอิน แผนงาน สต็อก และวิธีแก้ปัญหา",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FaqScreen()),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.cloud_done_outlined,
                          title: "สถานะการเชื่อมต่อเซิร์ฟเวอร์",
                          subtitle: "แตะเพื่อทดสอบความเร็ว API",
                          trailingWidget: _buildServerStatusIndicator(),
                          onTap: () => _checkServerPing(showToast: true),
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.info_outline_rounded,
                          title: "เวอร์ชันแอปพลิเคชัน",
                          trailingText: "v$_appVersion",
                          onTap: _checkAppUpdate,
                        ),
                        _buildDivider(),
                        _buildSettingsRow(
                          icon: Icons.logout_rounded,
                          iconColor: Colors.redAccent,
                          title: "ออกจากระบบ",
                          titleColor: Colors.redAccent,
                          subtitle: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                          showChevron: false,
                          onTap: _confirmLogout,
                        ),
                      ]),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showEditProfileModal,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with camera badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF222226),
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                      child: (_imageFile == null && (avatarUrl == null || avatarUrl!.isEmpty))
                          ? const Icon(Icons.person, color: Colors.white54, size: 30)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImageSourceChoice,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kLimeGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: kSurfaceDark, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 10, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name, Email, Team
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nameCtrl.text.isEmpty ? "ผู้ใช้งาน" : nameCtrl.text,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emailCtrl.text.isEmpty ? "-" : emailCtrl.text,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teamNameCtrl.text.isEmpty ? "ไม่มีทีม" : teamNameCtrl.text,
                        style: const TextStyle(fontSize: 11, color: kLimeGreen, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildGroupContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    String? trailingText,
    Widget? trailingWidget,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.white).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor ?? Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? Colors.white,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                trailingWidget,
                if (showChevron) const SizedBox(width: 4),
              ] else if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                if (showChevron) const SizedBox(width: 4),
              ],
              if (showChevron)
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 0.6,
      color: kBorderSubtle,
      indent: 60,
    );
  }
}
