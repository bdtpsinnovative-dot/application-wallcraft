import 'dart:convert';
import 'dart:async'; 
import 'dart:io'; 
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ota_update/ota_update.dart';
// 🌟 เพิ่ม 2 Packages นี้สำหรับการเช็คเวอร์ชันและเปิดเว็บ
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tracking/tracking_screen.dart';
import '../admin_summary/admin_summary_screen.dart';
import '../products/price_check_screen.dart';
import '../../constants.dart';
import '../../services/api_service.dart';
import '../pool_project/pool_project_screen.dart';
import '../auth/login_screen.dart';
import '../orders/purchase_order_screen.dart';
import '../voice_chat_sceenai/ai_chat_hub_screen.dart';
import '../settings/profile_screen.dart';
import '../teams/teams_screen.dart'; 
import '../image_ai/ai_image_search_screen.dart'; 

const Color kDarkBg = Color(0xFF0F0F11); 
const Color kGlowPurple = Color(0xFF4A3080); 
const Color kCardPurpleStart = Color(0xFFB9A2D8); 
const Color kCardPurpleEnd = Color(0xFF6C4AB6); 
const Color kLimeGreen = Color(0xFFD2E862); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kPremiumGold = Color(0xFFFFC107); 

// ==========================================================
// 1. HomeScreen (Shell - Glass Theme)
// ==========================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<_HomeDashboardState> _homeKey = GlobalKey();

  bool _isAdmin = false;

  late final Widget _homeDashboard;
  late final Widget _teamsScreen;
  late final Widget _profileScreen;
  late final Widget _adminSummaryScreen;

  @override
  void initState() {
    super.initState();
    _homeDashboard = _HomeDashboard(
      key: _homeKey, 
      onRoleChecked: _updateAdminStatus,
    );
    _teamsScreen = const TeamsScreen();
    _profileScreen = const ProfileScreen();
    _adminSummaryScreen = const AdminSummaryScreen(); 
    
    // 🌟 สั่งเช็คอัปเดตทันทีที่เปิดแอป
    _checkForUpdate();
  }

  // ==========================================================
  // 🌟 ส่วนของ Logic ตรวจสอบเวอร์ชันแอป
  // ==========================================================
  Future<void> _checkForUpdate() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; 

      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/check-update'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['latest_version'];
        
        // ดึง URL แยกตามระบบ
        String downloadUrlAndroid = data['download_url_android'];
        String downloadUrlIos = data['download_url_ios'];

        if (currentVersion != latestVersion) {
          // ส่ง Link เข้า Dialog โดยเช็คจาก Platform ทันที
          String targetUrl = Platform.isIOS ? downloadUrlIos : downloadUrlAndroid;
          _showUpdateDialog(latestVersion, targetUrl);
        }
      }
    } catch (e) {
      debugPrint("Error checking update: $e");
    }
  }
void _showUpdateDialog(String latestVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // บังคับให้โหลดจนเสร็จหรือกดปิดเอง
      builder: (BuildContext context) {
        // ตัวแปรสำหรับเก็บสถานะใน Dialog
        String progress = '';
        bool isDownloading = false;

        // ใช้ StatefulBuilder เพื่อให้อัปเดต UI แค่ในหน้าต่าง Dialog นี้
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kCardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("มีอัปเดตเวอร์ชันใหม่!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text(
                isDownloading 
                    ? "กำลังดาวน์โหลด... $progress%\nกรุณารอสักครู่" 
                    : "พบแอปเวอร์ชัน $latestVersion\nกรุณาอัปเดตเพื่อการใช้งานที่สมบูรณ์ที่สุดครับ",
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                // ถ้ากำลังโหลดอยู่ ซ่อนปุ่มปิดไปเลย กัน User กดหนี
                if (!isDownloading)
                  TextButton(
                    child: const Text("ปิด", style: TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDownloading ? Colors.grey : kLimeGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  // ถ้ากำลังโหลดอยู่ ให้ปุ่มกดไม่ได้ (null)
                  onPressed: isDownloading ? null : () async {
                    // ถ้าระบบเป็น iOS ให้เด้งเปิด TestFlight เลย
                    if (Platform.isIOS) {
                      final Uri url = Uri.parse(downloadUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                      return; // หยุดการทำงาน ไม่ต้องลงไปรัน OTA ข้างล่าง
                    }

                    // ถ้าระบบเป็น Android ให้รัน OTA โหลด APK ตามปกติ
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
                          .listen(
                        (OtaEvent event) {
                          setStateDialog(() {
                            progress = event.value ?? '';
                          });
                          if (event.status == OtaStatus.INSTALLING) {
                            Navigator.of(context).pop(); 
                          }
                        },
                      );
                    } catch (e) {
                      debugPrint('Failed to make OTA update. Details: $e');
                      setStateDialog(() => isDownloading = false);
                    }
                  },
                  child: Text(
                    isDownloading ? "กำลังโหลด..." : "อัปเดตเลย", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }
  void _updateAdminStatus(bool isAdmin) {
    if (_isAdmin != isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
        if (!_isAdmin && _selectedIndex > 2) {
          _selectedIndex = 0;
        }
      });
    }
  }

  List<Widget> get _currentPages {
    if (_isAdmin) {
      return [_homeDashboard, _teamsScreen, _adminSummaryScreen, _profileScreen];
    } else {
      return [_homeDashboard, _teamsScreen, _profileScreen];
    }
  }

  List<BottomNavigationBarItem> get _navItems {
    if (_isAdmin) {
      return [
        _buildNavItem(Icons.grid_view_rounded, 0),
        _buildNavItem(Icons.groups_rounded, 1),
        _buildNavItem(Icons.analytics_rounded, 2), 
        _buildNavItem(Icons.person_rounded, 3),
      ];
    } else {
      return [
        _buildNavItem(Icons.grid_view_rounded, 0),
        _buildNavItem(Icons.groups_rounded, 1),
        _buildNavItem(Icons.person_rounded, 2),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kGlowPurple.withOpacity(0.35),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            IndexedStack(index: _selectedIndex, children: _currentPages),
          ],
        ),
        
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: kDarkBg, 
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))), 
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
              if (index == 0) {
                _homeKey.currentState?.refreshData(); 
              }
            },
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white, 
            unselectedItemColor: Colors.grey[600], 
            showSelectedLabels: false,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: _navItems, 
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    Color iconColor = (icon == Icons.analytics_rounded && isSelected) ? kPremiumGold : (isSelected ? Colors.white : Colors.grey[600]!);

    return BottomNavigationBarItem(
      icon: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0, 
        duration: const Duration(milliseconds: 350), 
        curve: Curves.elasticOut, 
        child: Padding(
          padding: const EdgeInsets.all(10), 
          child: Icon(icon, size: 26, color: iconColor), 
        ),
      ),
      label: '',
    );
  }
} 

// ==========================================================
// 2. _HomeDashboard 
// ==========================================================
class _HomeDashboard extends StatefulWidget {
  final Function(bool) onRoleChecked;
  const _HomeDashboard({super.key, required this.onRoleChecked}); 
  
  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> with SingleTickerProviderStateMixin {
  String _displayName = "...";
  String? _avatarUrl;
  bool _isAdmin = false; 
  
  int _myOrders = 0;
  int _teamOrders = 0;
  int _totalOrders = 0;

  bool _isLoading = true; 
  String? _errorMessage; 

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _controller.forward();
    refreshData(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; 
    });

    try {
      await Future.wait([
        _loadUserProfile(),
        _fetchStats(),
      ]).timeout(const Duration(seconds: 15)); 
    } on SocketException {
      if (mounted) setState(() => _errorMessage = "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G");
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง");
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "ไม่สามารถโหลดข้อมูลได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception("No token");

    final response = await ApiService.post(Uri.parse('${AppConfig.baseUrl}/profile'), body: jsonEncode({'token': token}));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['profile'];
      if (mounted) {
        setState(() {
          _displayName = data['full_name'] ?? "User";
          _avatarUrl = data['avatar_url'];
          _isAdmin = (data['role'] == 'admin'); 
          widget.onRoleChecked(_isAdmin); 
        });
      }
    } else {
      throw Exception("Failed to load profile");
    }
  }

  Future<void> _fetchStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception("No token");

    final response = await ApiService.post(Uri.parse('${AppConfig.baseUrl}/dashboard/stats'), body: jsonEncode({'token': token}));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _myOrders = data['myOrders'] ?? 0;
          _teamOrders = data['teamOrders'] ?? 0;
          _totalOrders = data['totalOrders'] ?? 0;
        });
      }
    } else {
      throw Exception("Failed to load stats");
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.white, 
      backgroundColor: kCardDark, 
      onRefresh: refreshData, 
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), 
        child: _isLoading 
            ? SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: const Center(child: CircularProgressIndicator(color: kLimeGreen)),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _buildBody(),
      ),
    ); 
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: refreshData, 
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          _buildMinimalHeader(),
          const SizedBox(height: 30),
          _buildPurpleStatsCard(),
          const SizedBox(height: 30),
          const Text("Management Tools", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16, mainAxisSpacing: 16,
            childAspectRatio: 1.1, 
            children: [
              _buildGlassMenuCard(0, 'Lead&Checkin', 'ลีด&เช็คอิน', Icons.add_circle_outline_rounded, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()))),
              _buildGlassMenuCard(1, 'Price Check', 'เช็คราคาสินค้า', Icons.price_check_rounded, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PriceCheckScreen()))),
              _buildGlassMenuCard(2, 'AI Expert', 'AIผู้เชี่ยวชาญ', Icons.auto_awesome_rounded, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatHubScreen()))),
              _buildGlassMenuCard(3, 'AI Search', 'ค้นหารูปด้วยAI', Icons.image_search_rounded, Colors.cyanAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiSearchScreen()))),
              _buildGlassMenuCard(4, 'Pool Project', 'โปรเจกต์ทั้งหมด', Icons.workspaces_rounded, Colors.indigoAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PoolProjectScreen()))),
              _buildGlassMenuCard(
                5, 
                'เช็คการขนส่ง', 
                'ติดตามสถานะ',
                Icons.local_shipping_rounded, 
                Colors.pinkAccent, 
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrackingScreen()))
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMinimalHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good Morning,', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(child: Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Text("ADMIN", style: TextStyle(color: kPremiumGold, fontSize: 10, fontWeight: FontWeight.bold)))
                  ]
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2), image: (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null),
          child: (_avatarUrl == null || _avatarUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white70) : null,
        )
      ],
    );
  }

  Widget _buildPurpleStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 24),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [kCardPurpleStart, kCardPurpleEnd], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: kGlowPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem('Me', '$_myOrders'),
          Container(width: 1, height: 40, color: Colors.black12), 
          _statItem('Team', '$_teamOrders'),
          Container(width: 1, height: 40, color: Colors.black12),
          _statItem('Total', '$_totalOrders', isHighlight: true),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isHighlight ? Colors.white : const Color(0xFF1E1E1E))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }

  Widget _buildGlassMenuCard(int index, String title, String subtitle, IconData icon, Color iconColor, VoidCallback? onTap) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut))),
      child: Material(
        color: const Color(0xFF1C1C1E), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(20), splashColor: iconColor.withOpacity(0.3), highlightColor: iconColor.withOpacity(0.1), 
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withOpacity(0.15)), child: Icon(icon, color: iconColor, size: 24)),
                const Spacer(),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}