//lib/screens/settings/profile_screen.dart
import 'dart:convert';
import 'dart:async'; 
import 'dart:io';    
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import '../../constants.dart';
import '../auth/login_screen.dart';
import '../../services/api_service.dart';
import 'package:path_provider/path_provider.dart'; 
import 'custom_crop_screen.dart';

// 🎨 Palette สี
const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kLimeGreen = Color(0xFFD2E862); 
const Color kCardDark = Color(0xFF1C1C1E); 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final teamNameCtrl = TextEditingController();
  final teamDescCtrl = TextEditingController();
  
  bool loading = true;
  String? avatarUrl;
  File? _imageFile; 
  String? _errorMessage; 

  // 🌟 ตัวแปรสำหรับตั้งค่าแจ้งเตือน (เหลือแค่นี้)
  String _notiLevel = 'team'; // 'none', 'team', 'all'

  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    final curve = CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(curve);
    
    _fetchProfile();
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

            // 🌟 อัปเดตค่าจาก Database (บังคับแปลง Type ให้ชัวร์)
            _notiLevel = profile['noti_level']?.toString() ?? 'team';

            if (profile['teams'] != null) {
              teamNameCtrl.text = profile['teams']['team_name'] ?? 'ไม่มีทีม';
              teamDescCtrl.text = profile['teams']['description'] ?? '-';
            } else {
              teamNameCtrl.text = 'ไม่ได้สังกัดทีม';
              teamDescCtrl.text = '-';
            }
          });
          _animController.forward();
        }
      } else if (response.statusCode == 401) {
        _logout(); 
      } else {
        throw "โหลดข้อมูลไม่สำเร็จ (${response.statusCode})";
      }
    } on SocketException {
      if (mounted) setState(() => _errorMessage = "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G");
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง");
    } catch (e) {
      debugPrint('🔴 Profile Fetch Error: $e');
      if (mounted) setState(() => _errorMessage = "ไม่สามารถโหลดข้อมูลโปรไฟล์ได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/upload-avatar'); 

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
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
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
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
        MaterialPageRoute(builder: (context) => CustomCropScreen(image: imageBytes)),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 20)),
              const Text("เปลี่ยนรูปโปรไฟล์", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: kLimeGreen, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white70)),
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
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white)))
          ]
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

      // ✅ ยิง http.put ตรงๆ
      final response = await http.put(
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
          'noti_level': _notiLevel, // 🌟 ส่งแค่ค่าระดับการแจ้งเตือน
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if(mounted) {
          setState(() {
            avatarUrl = finalAvatarUrl;
            _imageFile = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [Icon(Icons.check_circle, color: kCardDark), SizedBox(width: 8), Text('บันทึกข้อมูลสำเร็จ', style: TextStyle(color: kCardDark, fontWeight: FontWeight.bold))]),
              backgroundColor: kLimeGreen, 
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      if(mounted) _showErrorSnackBar('ขาดการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถบันทึกข้อมูลได้');
    } on TimeoutException {
      if(mounted) _showErrorSnackBar('เซิร์ฟเวอร์ตอบกลับช้าเกินไป กรุณาลองใหม่อีกครั้ง');
    } catch (e) {
      if(mounted) _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if(mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    
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
        backgroundColor: kDarkBg,
        body: loading 
          ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchProfile, 
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLimeGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned(
                      top: -100, right: -50, 
                      child: Container(
                        width: 300, height: 300,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.3)),
                        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
                      ),
                    ),

                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 320, 
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  child: SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (Navigator.of(context).canPop())
                                            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context))
                                          else
                                            const SizedBox(width: 48),
                                          const Text("Edit Profile", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 48), 
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(bottom: 20, left: 0, right: 0, child: _buildAvatarSection()),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  children: [
                                    _buildSectionTitle("Personal Info"),
                                    _buildModernField(emailCtrl, "อีเมล", Icons.email_outlined, readOnly: true),
                                    const SizedBox(height: 16),
                                    _buildModernField(nameCtrl, "ชื่อ-นามสกุล", Icons.person_outline),
                                    const SizedBox(height: 16),
                                    _buildModernField(phoneCtrl, "เบอร์โทรศัพท์", Icons.phone_outlined, keyboardType: TextInputType.phone),
                                    
                                    const SizedBox(height: 32),
                                    
                                    _buildSectionTitle("Team Info"),
                                    _buildModernField(teamNameCtrl, "ชื่อทีม", Icons.groups_outlined, readOnly: true, isTeam: true),
                                    const SizedBox(height: 16),
                                    _buildModernField(teamDescCtrl, "รายละเอียด", Icons.info_outline, readOnly: true, maxLines: 2, isTeam: true),
                                    
                                    const SizedBox(height: 32),
                                    
                                    // 🌟 🌟 🌟 ส่วนตั้งค่าการแจ้งเตือน (เอาสั่นออกแล้ว) 🌟 🌟 🌟
                                    _buildSectionTitle("Notification Settings"),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: kCardDark,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("รับการแจ้งเตือน", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                            DropdownButton<String>(
                                              value: _notiLevel,
                                              dropdownColor: kCardDark,
                                              underline: const SizedBox(),
                                              icon: const Icon(Icons.arrow_drop_down_rounded, color: kLimeGreen),
                                              style: const TextStyle(color: kLimeGreen, fontSize: 14, fontWeight: FontWeight.bold),
                                              items: const [
                                                DropdownMenuItem(value: 'none', child: Text("ปิดการแจ้งเตือน", style: TextStyle(color: Colors.redAccent))),
                                                DropdownMenuItem(value: 'team', child: Text("เฉพาะทีมตัวเอง")),
                                                DropdownMenuItem(value: 'all', child: Text("ทุกทีม")),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) setState(() => _notiLevel = val);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 🌟 🌟 🌟 จบส่วนตั้งค่า 🌟 🌟 🌟

                                    const SizedBox(height: 40),
                                    _buildSaveButton(),
                                    const SizedBox(height: 20),
                                    _buildLogoutButton(),
                                    const SizedBox(height: 100), 
                                  ],
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

  Widget _buildAvatarSection() {
    return Center(
      child: SizedBox(
        width: 140, height: 140,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: kGlowPurple.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)])),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2), width: 2), color: kCardDark),
              child: CircleAvatar(
                backgroundColor: kCardDark,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : (avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null) as ImageProvider?,
                child: (_imageFile == null && (avatarUrl == null || avatarUrl!.isEmpty)) ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
              ),
            ),
            Positioned(
              bottom: 0, right: 0, 
              child: GestureDetector(
                onTap: _showImageSourceChoice,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kLimeGreen, shape: BoxShape.circle, border: Border.all(color: kDarkBg, width: 3)),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildModernField(TextEditingController ctrl, String hint, IconData icon, {bool readOnly = false, TextInputType? keyboardType, int maxLines = 1, bool isTeam = false}) {
    return Container(
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextField(
        controller: ctrl, readOnly: readOnly, keyboardType: keyboardType, maxLines: maxLines,
        style: TextStyle(color: readOnly ? Colors.white54 : Colors.white, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: readOnly ? Colors.grey : kLimeGreen), 
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: readOnly ? const Icon(Icons.lock_outline, size: 16, color: Colors.white24) : null,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: kLimeGreen, boxShadow: [BoxShadow(color: kLimeGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
      child: ElevatedButton(
        onPressed: _updateProfile,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), 
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: OutlinedButton.icon(
        onPressed: _logout, icon: const Icon(Icons.logout_rounded), label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: Colors.transparent),
      ),
    );
  }
}