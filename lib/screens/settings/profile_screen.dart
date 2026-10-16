// lib/screens/settings/profile_screen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
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

// 🎨 Palette สี Dark Luxury
const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kCardDark = Color(0xFF161618);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
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
  String _cacheSize = '...';
  String _appVersion = '1.0.0';

  final ImagePicker _picker = ImagePicker();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);

    _fetchProfile();
    _loadAppVersion();
    _calcCacheSize();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    teamNameCtrl.dispose();
    teamDescCtrl.dispose();
    _animController.dispose();
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
          _animController.forward(from: 0.0);
        }
        try {
          await AuthService.updateCurrentRememberedAccountProfile(
            displayName: profile['full_name']?.toString(),
            avatarUrl: profile['avatar_url']?.toString(),
          );
        } catch (cacheError) {
          debugPrint('Could not cache remembered profile: $cacheError');
        }
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        throw "โหลดข้อมูลไม่สำเร็จ (${response.statusCode})";
      }
    } on SocketException {
      if (mounted) {
        setState(
          () => _errorMessage =
              "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G",
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _errorMessage =
              "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง",
        );
      }
    } catch (e) {
      debugPrint('🔴 Profile Fetch Error: $e');
      if (mounted) {
        setState(
          () => _errorMessage =
              "ไม่สามารถโหลดข้อมูลโปรไฟล์ได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง",
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
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
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'ล้างหน่วยความจำแคชเรียบร้อยแล้ว',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            backgroundColor: kLimeGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }
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
      } else {
        return null;
      }
    } catch (e) {
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
    } catch (e) {
      debugPrint('Pick Image Error: $e');
    }
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

        setState(() {
          _imageFile = file;
        });

        _updateProfile();
      }
    } catch (e) {
      debugPrint('🔴 Custom Crop Error: $e');
    }
  }

  void _showImageSourceChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              const Text(
                "เปลี่ยนรูปโปรไฟล์",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageOption(Icons.camera_alt_rounded, "ถ่ายรูป", () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  }),
                  _buildImageOption(Icons.photo_library_rounded, "อัลบั้ม", () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  }),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kLimeGreen, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          throw "อัปโหลดรูปภาพไม่สำเร็จ กรุณาลองใหม่";
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
        } catch (cacheError) {
          debugPrint('Could not cache updated profile: $cacheError');
        }
        if (mounted) {
          setState(() {
            avatarUrl = finalAvatarUrl;
            _imageFile = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: kCardDark),
                  SizedBox(width: 8),
                  Text(
                    'บันทึกข้อมูลสำเร็จ',
                    style: TextStyle(
                      color: kCardDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              backgroundColor: kLimeGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        _logout();
      } else {
        final data = jsonDecode(response.body);
        throw data['error'] ?? "Update failed";
      }
    } on SocketException {
      if (mounted) {
        _showErrorSnackBar(
          'ขาดการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถบันทึกข้อมูลได้',
        );
      }
    } on TimeoutException {
      if (mounted) {
        _showErrorSnackBar('เซิร์ฟเวอร์ตอบกลับช้าเกินไป กรุณาลองใหม่อีกครั้ง');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตการแจ้งเตือนเป็น: ${_getNotiLabel(newLevel)}'),
            backgroundColor: kCardDark,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  String _getNotiLabel(String level) {
    switch (level) {
      case 'all':
        return 'ทุกทีม';
      case 'team':
        return 'เฉพาะทีมตัวเอง';
      case 'none':
        return 'ปิดการแจ้งเตือน';
      default:
        return 'เฉพาะทีมตัวเอง';
    }
  }

  // 🔑 เปลี่ยนรหัสผ่าน (ใส่รหัสเดิมก่อน แล้วใส่รหัสใหม่ + ยืนยัน)
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
                color: Color(0xFF161618),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_reset_rounded,
                                color: kLimeGreen, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "เปลี่ยนรหัสผ่าน",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "เพื่อความปลอดภัย กรุณากรอกรหัสผ่านปัจจุบันก่อนตั้งรหัสผ่านใหม่",
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 18),

                    if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    _buildModalFieldLabel("รหัสผ่านปัจจุบัน (Current Password)"),
                    _buildPasswordField(
                      controller: currentPassCtrl,
                      hint: "กรอกรหัสผ่านปัจจุบันของคุณ",
                      obscureText: obscureCurrent,
                      onToggleObscure: () {
                        setModalState(
                            () => obscureCurrent = !obscureCurrent);
                      },
                    ),
                    const SizedBox(height: 14),

                    _buildModalFieldLabel("รหัสผ่านใหม่ (New Password)"),
                    _buildPasswordField(
                      controller: newPassCtrl,
                      hint: "ความยาวอย่างน้อย 6 ตัวอักษร",
                      obscureText: obscureNew,
                      onToggleObscure: () {
                        setModalState(() => obscureNew = !obscureNew);
                      },
                    ),
                    const SizedBox(height: 14),

                    _buildModalFieldLabel("ยืนยันรหัสผ่านใหม่ (Confirm Password)"),
                    _buildPasswordField(
                      controller: confirmPassCtrl,
                      hint: "กรอกรหัสผ่านใหม่อีกครั้งให้ตรงกัน",
                      obscureText: obscureConfirm,
                      onToggleObscure: () {
                        setModalState(
                            () => obscureConfirm = !obscureConfirm);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final currentPass =
                                    currentPassCtrl.text.trim();
                                final newPass = newPassCtrl.text.trim();
                                final confirmPass =
                                    confirmPassCtrl.text.trim();

                                if (currentPass.isEmpty ||
                                    newPass.isEmpty ||
                                    confirmPass.isEmpty) {
                                  setModalState(() => localError =
                                      "กรุณากรอกข้อมูลให้ครบทุกช่อง");
                                  return;
                                }

                                if (newPass.length < 6) {
                                  setModalState(() => localError =
                                      "รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร");
                                  return;
                                }

                                if (newPass != confirmPass) {
                                  setModalState(() => localError =
                                      "รหัสผ่านใหม่และการยืนยันไม่ตรงกัน");
                                  return;
                                }

                                if (currentPass == newPass) {
                                  setModalState(() => localError =
                                      "รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม");
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  localError = null;
                                });

                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final token =
                                      prefs.getString('auth_token');

                                  final response = await ApiService.post(
                                    Uri.parse(
                                        '${AppConfig.baseUrl}/auth/change-password'),
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
                                          content: const Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded,
                                                  color: Colors.black),
                                              SizedBox(width: 8),
                                              Text(
                                                'เปลี่ยนรหัสผ่านสำเร็จเรียบร้อยแล้ว',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: kLimeGreen,
                                          behavior:
                                              SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                  } else {
                                    setModalState(() {
                                      isSubmitting = false;
                                      localError = data['error'] ??
                                          "ไม่สามารถเปลี่ยนรหัสผ่านได้";
                                    });
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    localError =
                                        "เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่";
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLimeGreen,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'ยืนยันการเปลี่ยนรหัสผ่าน',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon:
              const Icon(Icons.key_rounded, color: Colors.grey, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Colors.grey[500],
              size: 20,
            ),
            onPressed: onToggleObscure,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // 🛡️ ข้อมูลความเป็นส่วนตัวและความปลอดภัย (PDPA & Permissions)
  void _showPrivacySecurityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: Colors.blueAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          "ความเป็นส่วนตัว & ความปลอดภัย",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildPrivacyCard(
                  icon: Icons.lock_outline_rounded,
                  iconColor: kLimeGreen,
                  title: "การเข้ารหัสและความปลอดภัยของบัญชี",
                  description:
                      "ข้อมูลทุกการทำรายการถูกเข้ารหัสผ่านเครือข่ายความปลอดภัย SSL/TLS ข้อมูลการเข้าสู่ระบบถูกจัดเก็บใน Secure Vault ที่เข้ารหัสระดับฮาร์ดแวร์บนอุปกรณ์ของคุณ",
                ),
                const SizedBox(height: 10),

                _buildPrivacyCard(
                  icon: Icons.location_on_outlined,
                  iconColor: Colors.amberAccent,
                  title: "นโยบายการเข้าถึงตำแหน่งที่ตั้ง (GPS)",
                  description:
                      "แอปพลิเคชันจะดึงพิกัดตำแหน่งเฉพาะในจังหวะที่คุณกดปุ่ม 'เช็คอินสถานที่' เพื่อยืนยันการเข้าพบลูกค้าหน้างานจริงเท่านั้น ไม่มีการแอบติดตามตำแหน่งเบื้องหลังตลอดเวลา",
                ),
                const SizedBox(height: 10),

                _buildPrivacyCard(
                  icon: Icons.camera_alt_outlined,
                  iconColor: Colors.purpleAccent,
                  title: "สิทธิ์กล้องและการเข้าถึงคลังรูปภาพ",
                  description:
                      "ใช้สำหรับการถ่ายรูปหน้างานเพื่อแนบเป็นหลักฐานการเข้าพบลูกค้า และการเลือกรูปเพื่อตั้งเป็นโปรไฟล์ส่วนบุคคลเท่านั้น ไม่มีการเข้าถึงรูปภาพส่วนตัวอื่นๆ",
                ),
                const SizedBox(height: 10),

                _buildPrivacyCard(
                  icon: Icons.verified_user_outlined,
                  iconColor: Colors.tealAccent,
                  title: "การคุ้มครองข้อมูลส่วนบุคคล (PDPA)",
                  description:
                      "ข้อมูลคำสั่งซื้อ ลูกค้า และบันทึกการทำงานทั้งหมดเป็นข้อมูลลับเฉพาะภายในองค์กร Wallcraft Operations จะไม่ถูกเปิดเผยหรือส่งต่อไปยังบุคคลภายนอกโดยเด็ดขาด",
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("เข้าใจแล้ว"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
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
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: kLimeGreen),
                    const SizedBox(width: 8),
                    Text(
                      'คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว (v$_appVersion) 🎉',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: kCardDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถตรวจสอบอัปเดตได้ในขณะนี้'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
              backgroundColor: kCardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "มีอัปเดตเวอร์ชันใหม่!",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                isDownloading
                    ? "กำลังดาวน์โหลด... $progress%\nกรุณารอสักครู่"
                    : "พบแอปเวอร์ชัน $latestVersion\nกรุณาอัปเดตเพื่อการใช้งานที่สมบูรณ์ที่สุดครับ",
                style: const TextStyle(color: Colors.white70, height: 1.5),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isDownloading
                      ? null
                      : () async {
                          if (Platform.isIOS) {
                            final Uri url = Uri.parse(downloadUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
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
                                  destinationFilename:
                                      'wallcraft_update_$latestVersion.apk',
                                )
                                .listen((OtaEvent event) {
                                  setStateDialog(() {
                                    progress = event.value ?? '';
                                  });
                                  if (event.status == OtaStatus.INSTALLING &&
                                      context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                });
                          } catch (e) {
                            debugPrint('Failed to make OTA update: $e');
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

  void _showNotificationSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
              ),
              const Text(
                "ตั้งค่าการแจ้งเตือน",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "เลือกระดับการแจ้งเตือนที่ต้องการรับบนอุปกรณ์นี้",
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              _buildNotiChoiceTile(
                level: 'all',
                title: 'ทุกทีม (All Teams)',
                subtitle: 'รับแจ้งเตือนกิจกรรมและคำสั่งซื้อทั้งหมดในระบบ',
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.amberAccent,
                onSelect: () {
                  Navigator.pop(ctx);
                  _updateNotiLevel('all');
                },
              ),
              const SizedBox(height: 10),
              _buildNotiChoiceTile(
                level: 'team',
                title: 'เฉพาะทีมตัวเอง (My Team)',
                subtitle: 'รับเฉพาะการแจ้งเตือนที่เกี่ยวข้องกับทีมของคุณ',
                icon: Icons.groups_rounded,
                iconColor: kLimeGreen,
                onSelect: () {
                  Navigator.pop(ctx);
                  _updateNotiLevel('team');
                },
              ),
              const SizedBox(height: 10),
              _buildNotiChoiceTile(
                level: 'none',
                title: 'ปิดการแจ้งเตือน (Mute All)',
                subtitle: 'ปิดเสียงและการแจ้งเตือนทั้งหมดชั่วคราว',
                icon: Icons.notifications_off_rounded,
                iconColor: Colors.redAccent,
                onSelect: () {
                  Navigator.pop(ctx);
                  _updateNotiLevel('none');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotiChoiceTile({
    required String level,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onSelect,
  }) {
    final isSelected = _notiLevel == level;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? kLimeGreen : Colors.white.withValues(alpha: 0.06),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
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
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: kLimeGreen,
                  size: 20,
                ),
            ],
          ),
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
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildModalFieldLabel("อีเมลบัญชี (ไม่สามารถแก้ไขได้)"),
                _buildModernField(
                  emailCtrl,
                  "อีเมล",
                  Icons.email_outlined,
                  readOnly: true,
                ),
                const SizedBox(height: 14),
                _buildModalFieldLabel("ชื่อ - นามสกุล"),
                _buildModernField(
                  nameCtrl,
                  "ชื่อ-นามสกุล",
                  Icons.person_outline,
                ),
                const SizedBox(height: 14),
                _buildModalFieldLabel("เบอร์โทรศัพท์ติดต่อ"),
                _buildModernField(
                  phoneCtrl,
                  "เบอร์โทรศัพท์",
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _buildModalFieldLabel("ทีมสังกัด"),
                _buildModernField(
                  teamNameCtrl,
                  "ชื่อทีม",
                  Icons.groups_outlined,
                  readOnly: true,
                  isTeam: true,
                ),
                const SizedBox(height: 24),
                _buildSaveButton(onSaved: () {
                  Navigator.pop(ctx);
                  _updateProfile();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  void _confirmClearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text(
              "ล้างหน่วยความจำแคช",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "ต้องการล้างไฟล์ชั่วคราวและแคชรูปภาพขนาด $_cacheSize หรือไม่?\n(ไม่มีผลกระทบต่อข้อมูลสำคัญของคุณ)",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
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
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ล้างแคชทันที",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "ออกจากระบบ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบบัญชีนี้?",
          style: TextStyle(color: Colors.white70, fontSize: 14),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ออกจากระบบ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: loading
            ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.redAccent,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchProfile,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'ลองใหม่อีกครั้ง',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kLimeGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // Glow background effect
                  Positioned(
                    top: -100,
                    right: -50,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGlowPurple.withValues(alpha: 0.25),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        // App Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (Navigator.of(context).canPop())
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                )
                              else
                                const SizedBox(width: 40),
                              const Text(
                                "Account & Settings",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                onPressed: () {
                                  _fetchProfile();
                                  _calcCacheSize();
                                },
                              ),
                            ],
                          ),
                        ),

                        // Scrollable Body
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Profile Header Card
                                    _buildProfileHeaderCard(),

                                    // 2. หมวด: ความปลอดภัย & บัญชี (Security & Account)
                                    _buildGroupCard(
                                      title: "ความปลอดภัย & บัญชี (ACCOUNT & SECURITY)",
                                      children: [
                                        _buildMenuTile(
                                          icon: Icons.lock_reset_rounded,
                                          iconColor: kLimeGreen,
                                          iconBgColor: kLimeGreen
                                              .withValues(alpha: 0.15),
                                          title: "เปลี่ยนรหัสผ่าน (Change Password)",
                                          subtitle:
                                              "กรอกรหัสผ่านปัจจุบันเพื่อตั้งรหัสใหม่",
                                          onTap: _showChangePasswordModal,
                                        ),
                                        _buildDivider(),
                                        _buildMenuTile(
                                          icon: Icons.shield_outlined,
                                          iconColor: Colors.blueAccent,
                                          iconBgColor: Colors.blueAccent
                                              .withValues(alpha: 0.15),
                                          title:
                                              "ความเป็นส่วนตัว & ความปลอดภัย",
                                          subtitle:
                                              "นโยบาย GPS, สิทธิ์การใช้งาน และ PDPA",
                                          onTap: _showPrivacySecurityModal,
                                        ),
                                      ],
                                    ),

                                    // 3. หมวด: การตั้งค่าระบบ (Preferences)
                                    _buildGroupCard(
                                      title: "การตั้งค่าระบบ (APP PREFERENCES)",
                                      children: [
                                        _buildMenuTile(
                                          icon: Icons.notifications_active_rounded,
                                          iconColor: Colors.orangeAccent,
                                          iconBgColor: Colors.orangeAccent
                                              .withValues(alpha: 0.15),
                                          title: "การแจ้งเตือน (Notifications)",
                                          subtitle:
                                              "ระดับ: ${_getNotiLabel(_notiLevel)}",
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getNotiLabel(_notiLevel),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: kLimeGreen,
                                              ),
                                            ),
                                          ),
                                          onTap: _showNotificationSettingsModal,
                                        ),
                                        _buildDivider(),
                                        _buildMenuTile(
                                          icon: Icons.cleaning_services_rounded,
                                          iconColor: Colors.tealAccent,
                                          iconBgColor: Colors.tealAccent
                                              .withValues(alpha: 0.15),
                                          title: "ล้างแคชในเครื่อง (Storage)",
                                          subtitle:
                                              "เคลียร์ไฟล์ชั่วคราวเพื่อประหยัดพื้นที่",
                                          trailing: Text(
                                            _cacheSize,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                          onTap: _confirmClearCache,
                                        ),
                                      ],
                                    ),

                                    // 4. หมวด: คู่มือ & เกี่ยวกับระบบ (Help & About)
                                    _buildGroupCard(
                                      title: "คู่มือ & เกี่ยวกับระบบ (HELP & ABOUT)",
                                      children: [
                                        _buildMenuTile(
                                          icon: Icons.menu_book_rounded,
                                          iconColor: Colors.purpleAccent,
                                          iconBgColor: Colors.purpleAccent
                                              .withValues(alpha: 0.15),
                                          title: "คู่มือ & คำถามที่พบบ่อย (FAQ)",
                                          subtitle:
                                              "ขั้นตอนเช็คอิน แผนงาน สต็อก และวิธีแก้ปัญหา",
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const FaqScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                        _buildDivider(),
                                        _buildMenuTile(
                                          icon: Icons.system_update_rounded,
                                          iconColor: Colors.greenAccent,
                                          iconBgColor: Colors.greenAccent
                                              .withValues(alpha: 0.15),
                                          title: "เวอร์ชันแอปพลิเคชัน",
                                          subtitle:
                                              "เวอร์ชันปัจจุบัน v$_appVersion",
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kLimeGreen
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              "ตรวจหาอัปเดต",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: kLimeGreen,
                                              ),
                                            ),
                                          ),
                                          onTap: _checkAppUpdate,
                                        ),
                                      ],
                                    ),

                                    // 5. หมวด: ออกจากระบบ (Session)
                                    _buildGroupCard(
                                      title: "ออกจากระบบ (SESSION)",
                                      children: [
                                        _buildMenuTile(
                                          icon: Icons.logout_rounded,
                                          iconColor: Colors.redAccent,
                                          iconBgColor: Colors.redAccent
                                              .withValues(alpha: 0.15),
                                          title: "ออกจากระบบ (Sign Out)",
                                          subtitle:
                                              "ออกจากระบบบัญชี ${emailCtrl.text}",
                                          isDestructive: true,
                                          showChevron: true,
                                          onTap: _confirmLogout,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 50),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221F2D), Color(0xFF16151B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: kGlowPurple.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarWidget(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nameCtrl.text.isEmpty ? "ผู้ใช้งาน" : nameCtrl.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFB300),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      emailCtrl.text.isEmpty ? "-" : emailCtrl.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 13,
                            color: kLimeGreen,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              teamNameCtrl.text.isEmpty
                                  ? "ไม่มีทีม"
                                  : teamNameCtrl.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showEditProfileModal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'แก้ไขข้อมูลส่วนตัว',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showImageSourceChoice,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: kLimeGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget() {
    return GestureDetector(
      onTap: _showImageSourceChoice,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
                color: kCardDark,
                boxShadow: [
                  BoxShadow(
                    color: kGlowPurple.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? Image.network(
                            avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: Colors.white54,
                          ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: kLimeGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: kDarkBg, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black87,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8, top: 22),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
    bool isDestructive = false,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.redAccent : Colors.white,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.8,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 58,
    );
  }

  Widget _buildModernField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool readOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isTeam = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: readOnly ? Colors.grey : kLimeGreen, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline, size: 16, color: Colors.white24)
              : null,
        ),
      ),
    );
  }

  Widget _buildSaveButton({VoidCallback? onSaved}) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: kLimeGreen,
        boxShadow: [
          BoxShadow(
            color: kLimeGreen.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (onSaved != null) {
            onSaved();
          } else {
            _updateProfile();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'บันทึกข้อมูล (Save Changes)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
