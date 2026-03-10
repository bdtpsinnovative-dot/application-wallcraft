import 'dart:convert';
import 'dart:async'; // ✅ เพิ่มสำหรับจัดการ Timeout
import 'dart:io'; // ✅ เพิ่มสำหรับดักจับเน็ตหลุด (SocketException)
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../products/price_check_screen.dart';
import '../../constants.dart';
import '../../services/api_service.dart';
import '../pool_project/pool_project_screen.dart';
import '../auth/login_screen.dart';
import '../orders/purchase_order_screen.dart';
import '../voice_chat_sceenai/ai_chat_hub_screen.dart';
import '../settings/profile_screen.dart';
import '../orders/order_history_screen.dart';
// 🌟 แก้ไข Import ให้ตรงกับชื่อไฟล์ในเครื่องพี่ชาย และลบอันที่ซ้ำออกครับ
import '../image_ai/ai_image_search_screen.dart'; 

// 🎨 Palette สี (ตาม Reference รูป)
const Color kDarkBg = Color(0xFF0F0F11); 
const Color kGlowPurple = Color(0xFF4A3080); 
const Color kCardPurpleStart = Color(0xFFB9A2D8); 
const Color kCardPurpleEnd = Color(0xFF6C4AB6); 
const Color kLimeGreen = Color(0xFFD2E862); 
const Color kCardDark = Color(0xFF1C1C1E); 

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

  late final List<Widget> _pages = [
    _HomeDashboard(key: _homeKey),
    const OrderHistoryScreen(),
    const ProfileScreen(),
  ];

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
            // 🌌 1. Background Glow
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

            // 📄 2. Content
            IndexedStack(index: _selectedIndex, children: _pages),
          ],
        ),
        
        // 🚤 Bottom Nav
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
            items: [
              _buildNavItem(Icons.grid_view_rounded, 0),
              _buildNavItem(Icons.history_rounded, 1),
              _buildNavItem(Icons.person_rounded, 2),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 อัปเกรดความสนุก: ใส่ลูกเล่น "เด้งดึ๋ง" ตอนกดให้ไอคอนเมนูล่าง
  BottomNavigationBarItem _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0, 
        duration: const Duration(milliseconds: 350), 
        curve: Curves.elasticOut, 
        child: Padding(
          padding: const EdgeInsets.all(10), 
          child: Icon(icon, size: 26), 
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
  const _HomeDashboard({super.key}); 
  
  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> with SingleTickerProviderStateMixin {
  String _displayName = "...";
  String? _avatarUrl;
  
  int _myOrders = 0;
  int _teamOrders = 0;
  int _totalOrders = 0;

  bool _isLoading = true; // ✅ เพิ่มตัวแปรสำหรับโชว์ Loading
  String? _errorMessage; // ✅ เพิ่มตัวแปรสำหรับโชว์ข้อความเน็ตหลุด

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

  // ✅ เปลี่ยนระบบดึงข้อมูลให้จัดการ Error อย่างชาญฉลาด
  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // ล้าง Error เก่าทิ้ง
    });

    try {
      // ใช้ timeout ป้องกันไม่ให้แอปหมุนค้างนานเกินไป (15 วิ)
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

  // ✅ เปลี่ยนให้โยน Error ออกไปแทนการกลืนหายไปเงียบๆ
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
        });
      }
    } else {
      throw Exception("Failed to load profile");
    }
  }

  // ✅ เปลี่ยนให้โยน Error ออกไป
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
        physics: const AlwaysScrollableScrollPhysics(), // บังคับให้ไถดึงลงมาได้เสมอ
        child: _isLoading 
            ? SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: const Center(child: CircularProgressIndicator(color: kLimeGreen)),
              )
            : _errorMessage != null
                // ❌ กรณี Error / เน็ตหลุด โชว์หน้านี้
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!, 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: refreshData, // กดเพื่อดึงข้อมูลใหม่
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                // ✅ กรณีปกติ เน็ตดี โชว์หน้าแดชบอร์ด
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        _buildMinimalHeader(),
                      
                        const SizedBox(height: 30),
                        _buildPurpleStatsCard(),

                        const SizedBox(height: 30),
                        
                        const Text(
                          "Management Tools", 
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white, 
                            letterSpacing: 0.5
                          )
                        ),
                        const SizedBox(height: 16),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16, 
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1, 
                          children: [
                            _buildGlassMenuCard(
                              0, 'Lead&Checkin', 'ลีด&เช็คอิน', 
                              Icons.add_circle_outline_rounded, 
                              Colors.blueAccent, 
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()))
                            ),
                            _buildGlassMenuCard(
                              1, 'Price Check', 'เช็คราคาสินค้า', 
                              Icons.price_check_rounded, 
                              Colors.orangeAccent, 
                              () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => const PriceCheckScreen())
                                );
                              }
                            ),
                            _buildGlassMenuCard(
                              2, 'AI Expert', 'AIผู้เชี่ยวชาญ', 
                              Icons.auto_awesome_rounded, 
                              Colors.purpleAccent, 
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatHubScreen()))
                            ),
                            _buildGlassMenuCard(
                              3, 'AI Search', 'ค้นหารูปด้วยAI', 
                              Icons.image_search_rounded, 
                              Colors.cyanAccent, 
                              // 🌟 เอาคำว่า const ออกไปแล้วครับ
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiSearchScreen()))
                            ),
                            _buildGlassMenuCard(
                              4, 'Pool Project', 'โปรเจกต์ทั้งหมด', 
                              Icons.workspaces_rounded, 
                              Colors.indigoAccent, 
                              () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => const PoolProjectScreen())
                                );
                              }
                            ),
                            _buildGlassMenuCard(
                              5, 'เช็คการขนส่ง', 'เร็วๆนี้', 
                              Icons.local_shipping_rounded, 
                              Colors.pinkAccent, 
                              () {
                                // TODO: ใส่ Navigator ไปหน้าเช็คการขนส่ง
                              }
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    ); 
  }

  // 🌟 ส่วนที่แก้ไขเรื่องชื่อยาวไม่ให้ดันรูปครับ
  Widget _buildMinimalHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ใช้ Expanded เพื่อบังคับให้ข้อความมีขอบเขตจำกัด ไม่ให้ไปผลักรูปกระเด็น
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good Morning,', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                _displayName, 
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                maxLines: 1, // บังคับมี 1 บรรทัด
                overflow: TextOverflow.ellipsis, // ถ้าชื่อยาวเกินจอ ให้เปลี่ยนเป็น ...
              ),
            ],
          ),
        ),
        const SizedBox(width: 16), // เว้นระยะห่างระหว่างชื่อกับรูป
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2), 
            image: (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null,
          ),
          child: (_avatarUrl == null || _avatarUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white70) : null,
        )
      ],
    );
  }

  Widget _buildPurpleStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kCardPurpleStart, kCardPurpleEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: kGlowPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
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
        Text(
          value, 
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: isHighlight ? Colors.white : const Color(0xFF1E1E1E), 
          )
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.05)), 
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20), 
          splashColor: iconColor.withOpacity(0.3), 
          highlightColor: iconColor.withOpacity(0.1), 
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withOpacity(0.15),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
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