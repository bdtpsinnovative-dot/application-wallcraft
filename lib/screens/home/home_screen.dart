import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import '../visit_planner/visit_planner_screen.dart'; // 🌟 นำเข้า Visit Planner
import '../teams/teams_screen.dart'; // เก็บไว้เผื่อใช้
import '../image_ai/ai_image_search_screen.dart';
import '../notifications/NotificationScreen.dart';
import '../../services/notification_service.dart';

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
  final GlobalKey<VisitPlannerScreenState> _visitPlannerKey = GlobalKey();

  bool _isAdmin = false;

  late final Widget _homeDashboard;
  late final Widget _visitPlannerScreen; // 🌟 เปลี่นเป็นแผนงาน
  late final Widget _profileScreen;
  late final Widget _adminSummaryScreen;
  late final Widget _notificationScreen;

  @override
  void initState() {
    super.initState();

    // 🌟 ดักฟังกรณีเปิดแอปจาก Notification ที่ถูกแตะตอนปิดแอปไปแล้ว
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        NotificationService.handleNotificationTap(message.data);
      }
    });

    _homeDashboard = _HomeDashboard(
      key: _homeKey,
      onRoleChecked: _updateAdminStatus,
    );
    _visitPlannerScreen = VisitPlannerScreen(
      key: _visitPlannerKey,
    ); // 🌟 หน้าแผนงาน 12 สัปดาห์ พร้อม Key สำหรับ auto-refresh
    _profileScreen = const ProfileScreen();
    _adminSummaryScreen = const AdminSummaryScreen();
    _notificationScreen = const NotificationScreen();

    // ⚡ 1. Prefetch Pipeline เก็บในแรมทันทีที่เปิดแอป (ทำให้หน้า New Record & Visit Planner เปิดได้ทันใจ 0ms!)
    ApiService.getPipeline();

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

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/check-update'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ดึง Version แยกตามระบบ
        String latestVersionAndroid = data['latest_version_android'] ?? '1.0.0';
        String latestVersionIos = data['latest_version_ios'] ?? '1.0.0';

        // ดึง URL แยกตามระบบ
        String downloadUrlAndroid = data['download_url_android'];
        String downloadUrlIos = data['download_url_ios'];

        // ตรวจสอบแยกแพลตฟอร์ม
        String targetLatestVersion = Platform.isIOS
            ? latestVersionIos
            : latestVersionAndroid;
        String targetUrl = Platform.isIOS ? downloadUrlIos : downloadUrlAndroid;

        if (currentVersion != targetLatestVersion) {
          _showUpdateDialog(targetLatestVersion, targetUrl);
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
                // ถ้ากำลังโหลดอยู่ ซ่อนปุ่มปิดไปเลย กัน User กดหนี
                if (!isDownloading)
                  TextButton(
                    child: const Text(
                      "ปิด",
                      style: TextStyle(color: Colors.grey),
                    ),
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
                  // ถ้ากำลังโหลดอยู่ ให้ปุ่มกดไม่ได้ (null)
                  onPressed: isDownloading
                      ? null
                      : () async {
                          // ถ้าระบบเป็น iOS ให้เด้งเปิด TestFlight เลย
                          if (Platform.isIOS) {
                            final Uri url = Uri.parse(downloadUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
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
                                  destinationFilename:
                                      'wallcraft_update_$latestVersion.apk',
                                )
                                .listen((OtaEvent event) {
                                  setStateDialog(() {
                                    progress = event.value ?? '';
                                  });
                                  if (event.status == OtaStatus.INSTALLING) {
                                    Navigator.of(context).pop();
                                  }
                                });
                          } catch (e) {
                            debugPrint(
                              'Failed to make OTA update. Details: $e',
                            );
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

  void _updateAdminStatus(bool isAdmin) {
    if (_isAdmin != isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
        if (!_isAdmin && _selectedIndex > 3) {
          _selectedIndex = 0;
        }
      });
    }
  }

  List<Widget> get _currentPages {
    if (_isAdmin) {
      return [
        _homeDashboard,
        _visitPlannerScreen,
        _adminSummaryScreen,
        _notificationScreen,
        _profileScreen,
      ];
    } else {
      return [
        _homeDashboard,
        _visitPlannerScreen,
        _notificationScreen,
        _profileScreen,
      ];
    }
  }

  List<BottomNavigationBarItem> get _navItems {
    if (_isAdmin) {
      return [
        _buildNavItem(Icons.grid_view_rounded, 0),
        _buildNavItem(Icons.calendar_month_rounded, 1), // 🌟 เปลี่ยนไอคอน
        _buildNavItem(Icons.analytics_rounded, 2),
        _buildNavItem(Icons.notifications_rounded, 3),
        _buildNavItem(Icons.person_rounded, 4),
      ];
    } else {
      return [
        _buildNavItem(Icons.grid_view_rounded, 0),
        _buildNavItem(Icons.calendar_month_rounded, 1), // 🌟 เปลี่ยนไอคอน
        _buildNavItem(Icons.notifications_rounded, 2),
        _buildNavItem(Icons.person_rounded, 3),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kDarkBg,
        systemNavigationBarDividerColor: kDarkBg,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
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

        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: kDarkBg,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                bool wasOnHome = _selectedIndex == 0;
                bool wasOnVisitPlanner = _selectedIndex == 1;
                setState(() => _selectedIndex = index);
                if (index == 0) {
                  _homeKey.currentState?.refreshData(isSilent: !wasOnHome);
                } else if (index == 1) {
                  // 🚀 แอบดึงข้อมูลแผนงานล่าสุดสดๆ จากเซิร์ฟเวอร์ทันทีที่กดสลับมาแท็บแผนงาน
                  _visitPlannerKey.currentState?.refreshVisitPlans(
                    isSilent: !wasOnVisitPlanner,
                  );
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
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    Color iconColor = (icon == Icons.analytics_rounded && isSelected)
        ? kPremiumGold
        : (isSelected ? Colors.white : Colors.grey[600]!);

    return BottomNavigationBarItem(
      icon: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Icon(icon, size: 22, color: iconColor),
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

class _HomeDashboardState extends State<_HomeDashboard>
    with TickerProviderStateMixin {
  String _displayName = "...";
  String? _avatarUrl;
  bool _isAdmin = false;

  int _myOrders = 0;
  int _teamOrders = 0;
  int _totalOrders = 0;
  int _systemPlanTotal = 0;
  int _systemPlanCompleted = 0;
  int _systemPlanUnsuccessful = 0;
  bool _hasTeam = false;
  bool _isSystemAdminView = false;
  bool _hasInitializedActivityView = false;

  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _controller;
  late AnimationController _systemHeaderController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _systemHeaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _controller.forward();
    refreshData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _systemHeaderController.dispose();
    super.dispose();
  }

  Future<void> refreshData({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _loadUserProfile();
      await _fetchStats(
        scope: _activityScope,
      ).timeout(const Duration(seconds: 15));
    } on SocketException {
      if (mounted)
        setState(
          () => _errorMessage =
              "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G",
        );
    } on TimeoutException {
      if (mounted)
        setState(
          () => _errorMessage =
              "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง",
        );
    } catch (e) {
      if (mounted)
        setState(
          () => _errorMessage =
              "ไม่สามารถโหลดข้อมูลได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง",
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception("No token");

    final response = await ApiService.post(
      Uri.parse('${AppConfig.baseUrl}/profile'),
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['profile'];
      if (mounted) {
        setState(() {
          _displayName = data['full_name'] ?? "User";
          _avatarUrl = data['avatar_url'];
          _isAdmin = (data['role'] == 'admin');
          _hasTeam = data['team_id'] != null;
          if (!_hasInitializedActivityView) {
            _isSystemAdminView = _isAdmin;
            _hasInitializedActivityView = true;
          }
          widget.onRoleChecked(_isAdmin);
        });
      }
    } else {
      throw Exception("Failed to load profile");
    }
  }

  String? get _activityScope {
    if (!_isSystemAdminView) return null;
    if (_isAdmin) return 'system';
    return _hasTeam ? 'team' : null;
  }

  Future<void> _fetchStats({String? scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) throw Exception("No token");

    final response = await ApiService.post(
      Uri.parse('${AppConfig.baseUrl}/dashboard/stats'),
      body: jsonEncode({'token': token, if (scope != null) 'scope': scope}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final visitPlanStats = data['visitPlanStats'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _myOrders = data['myOrders'] ?? 0;
          _teamOrders = data['teamOrders'] ?? 0;
          _totalOrders = data['totalOrders'] ?? 0;
          _systemPlanTotal = visitPlanStats?['total'] ?? 0;
          _systemPlanCompleted = visitPlanStats?['completed'] ?? 0;
          _systemPlanUnsuccessful = visitPlanStats?['unsuccessful'] ?? 0;
        });
      }
    } else {
      throw Exception("Failed to load stats");
    }
  }

  Future<void> _toggleSystemActivityView() async {
    if (!_hasTeam && _isAdmin) return;
    if (!_hasTeam && !_isAdmin) return;

    final showSystemView = !_isSystemAdminView;
    setState(() => _isSystemAdminView = showSystemView);

    try {
      await _fetchStats(scope: _activityScope);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSystemAdminView = !showSystemView);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปลี่ยนมุมมองข้อมูลได้')),
      );
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
                child: const Center(
                  child: CircularProgressIndicator(color: kLimeGreen),
                ),
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
              onPressed: refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
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
          const Text(
            "Management Tools",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 280;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isNarrow ? 1 : 1.1,
                children: [
                  _buildGlassMenuCard(
                    0,
                    'Lead&Checkin',
                    'ลีด&เช็คอิน',
                    Icons.add_circle_outline_rounded,
                    Colors.blueAccent,
                    () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PurchaseOrderScreen(),
                        ),
                      );
                      if (mounted) {
                        refreshData(isSilent: true);
                        // ถ้ากลับออกมา ให้สั่งแอบรีเฟรชหน้าแผนงานด้วยทันที
                        final homeState = context
                            .findAncestorStateOfType<_HomeScreenState>();
                        homeState?._visitPlannerKey.currentState
                            ?.refreshVisitPlans(isSilent: true);
                      }
                    },
                  ),
                  _buildGlassMenuCard(
                    1,
                    'Price Check',
                    'เช็คราคาสินค้า',
                    Icons.price_check_rounded,
                    Colors.orangeAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PriceCheckScreen(),
                      ),
                    ),
                  ),
                  _buildGlassMenuCard(
                    2,
                    'AI Expert',
                    'AIผู้เชี่ยวชาญ',
                    Icons.auto_awesome_rounded,
                    Colors.purpleAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiChatHubScreen(),
                      ),
                    ),
                  ),
                  _buildGlassMenuCard(
                    3,
                    'AI Search',
                    'ค้นหารูปด้วยAI',
                    Icons.image_search_rounded,
                    Colors.cyanAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AiSearchScreen()),
                    ),
                  ),
                  _buildGlassMenuCard(
                    4,
                    'Pool Project',
                    'โปรเจกต์ทั้งหมด',
                    Icons.workspaces_rounded,
                    Colors.indigoAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PoolProjectScreen(),
                      ),
                    ),
                  ),
                  _buildGlassMenuCard(
                    5,
                    'เช็คการขนส่ง',
                    'ติดตามสถานะ',
                    Icons.local_shipping_rounded,
                    Colors.pinkAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrackingScreen(),
                      ),
                    ),
                  ),
                ],
              );
            },
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
              Text(
                'Good Morning,',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kPremiumGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "ADMIN",
                        style: TextStyle(
                          color: kPremiumGold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
            image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(_avatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
              ? const Icon(Icons.person, color: Colors.white70)
              : null,
        ),
      ],
    );
  }

  Widget _buildPurpleStatsCard() {
    if (_isSystemAdminView) {
      return _buildAdminSystemStatsCard();
    }
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 25,
        horizontal: isNarrow ? 16 : 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kCardPurpleStart, kCardPurpleEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kGlowPurple.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_hasTeam) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _buildScopeToggle(systemView: false, compact: isNarrow),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Me', '$_myOrders'),
              Container(width: 1, height: 40, color: Colors.black12),
              _statItem('Team', '$_teamOrders'),
              Container(width: 1, height: 40, color: Colors.black12),
              _statItem('Total', '$_totalOrders', isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSystemStatsCard() {
    final isNarrow = MediaQuery.sizeOf(context).width < 340;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 18,
        horizontal: isNarrow ? 12 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE8A3), Color(0xFFFFC44D), Color(0xFFC88810)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE9A8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kPremiumGold.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _systemHeaderController,
                builder: (context, child) {
                  final motion = Curves.easeInOut.transform(
                    _systemHeaderController.value,
                  );
                  return Transform.rotate(
                    angle: 0.12 * motion,
                    alignment: Alignment.center,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF4A3100),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SYSTEM ACTIVITY',
                style: TextStyle(
                  color: Color(0xFF4A3100),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_hasTeam)
                _buildScopeToggle(systemView: true, compact: isNarrow)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A3100).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isNarrow ? 'ALL' : 'ALL TEAMS',
                    style: const TextStyle(
                      color: Color(0xFF4A3100),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _adminStatItem('แผนงาน', '$_systemPlanTotal')),
              Container(
                width: 1,
                height: 42,
                color: const Color(0xFF4A3100).withValues(alpha: 0.16),
              ),
              Expanded(
                child: _adminStatItem(
                  'สำเร็จ',
                  '$_systemPlanCompleted',
                  valueColor: const Color(0xFF1E6A3A),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: const Color(0xFF4A3100).withValues(alpha: 0.16),
              ),
              Expanded(
                child: _adminStatItem(
                  'ไม่สำเร็จ',
                  '$_systemPlanUnsuccessful',
                  valueColor: const Color(0xFFA42D24),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: const Color(0xFF4A3100).withValues(alpha: 0.16),
              ),
              Expanded(child: _adminStatItem('Projects', '$_totalOrders')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminStatItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: valueColor ?? const Color(0xFF3D2700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B4700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeToggle({required bool systemView, bool compact = false}) {
    final color = systemView ? const Color(0xFF4A3100) : kPremiumGold;
    final label = systemView
        ? 'TEAM VIEW'
        : (_isAdmin ? 'SYSTEM VIEW' : 'TEAM ACTIVITY');
    final icon = systemView
        ? Icons.groups_rounded
        : (_isAdmin ? Icons.insights_rounded : Icons.groups_rounded);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleSystemActivityView,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassMenuCard(
    int index,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback? onTap,
  ) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
        ),
      ),
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
                SizedBox(
                  width: double.infinity,
                  height: 20,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 15,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
