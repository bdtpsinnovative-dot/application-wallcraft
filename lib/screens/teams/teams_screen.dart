//lib/screens/teams/teams_screen.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🌟 1. เพิ่ม Import Firebase
import '../notifications/NotificationScreen.dart';
import '../../constants.dart'; 
import '../../services/api_service.dart'; 

// 🎨 โทนสีใหม่: Deep Modern Dark
const Color kDarkBg = Color(0xFF090A0F); 
const Color kCardSurface = Color(0xFF15171E); 
const Color kCardInner = Color(0xFF1E202B); 
const Color kPremiumGold = Color(0xFFFFD700); 
const Color kGlowPurple = Color(0xFF8A2BE2);
const Color kTextPrimary = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFFA0A5B5);

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<dynamic> _teams = [];
  bool _isFirstLoading = true; 
  String? _errorMessage; 

  String _searchText = "";
  final TextEditingController _searchCtrl = TextEditingController();
  
  bool _hasUnreadNotifications = false; // 🌟 2. เริ่มต้นให้ไม่มีจุดแดงก่อน
  StreamSubscription<RemoteMessage>? _fcmSubscription; // 🌟 3. ตัวรับสัญญาณแจ้งเตือน

  @override
  void initState() {
    super.initState();
    _fetchTeams(); 
    _setupNotificationListener(); // 🌟 4. เรียกใช้ฟังก์ชันดักฟังแจ้งเตือนตอนเปิดหน้า
  }

  // 🌟 ฟังก์ชันใหม่: ดักฟังแจ้งเตือน Real-time
  void _setupNotificationListener() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        setState(() {
          _hasUnreadNotifications = true; // พอมีออเดอร์เข้าปุ๊บ จุดแดงเด้งปั๊บ!
        });
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel(); // 🌟 อย่าลืมปิดการรับสัญญาณตอนออกจากหน้า
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    setState(() {
      _isFirstLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/teams');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedTeams = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _teams = fetchedTeams;
            _isFirstLoading = false;
          });
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } on SocketException {
      _handleError("ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G");
    } on TimeoutException {
      _handleError("เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง");
    } catch (e) {
      _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง");
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMessage = msg;
      _isFirstLoading = false;
    });
  }

  void _onRefresh() {
    setState(() {
      _teams.clear();
      _searchText = "";
      _searchCtrl.clear();
    });
    _fetchTeams();
  }

  List<dynamic> get _filteredTeams {
    if (_searchText.isEmpty) return _teams;
    final searchLower = _searchText.toLowerCase();
    
    return _teams.map((team) {
      final teamNameMatch = (team['team_name']?.toString().toLowerCase() ?? '').contains(searchLower);
      final filteredMembers = (team['members'] as List).where((member) {
        return (member['full_name']?.toString().toLowerCase() ?? '').contains(searchLower);
      }).toList();

      if (teamNameMatch || filteredMembers.isNotEmpty) {
        return {
          ...team,
          'members': teamNameMatch ? team['members'] : filteredMembers,
        };
      }
      return null;
    }).where((team) => team != null).toList();
  }

  List<Map<String, dynamic>> get _flatMembers {
    List<Map<String, dynamic>> allMembers = [];
    
    for (var team in _filteredTeams) {
      final teamName = team['team_name'] ?? 'ไม่ระบุชื่อทีม';
      final isMyTeam = team['is_my_team'] == true;
      final members = team['members'] as List<dynamic>? ?? [];

      for (var member in members) {
        if (member is Map<String, dynamic>) {
          allMembers.add({
            ...member,
            'team_name': teamName,
            'is_my_team': isMyTeam,
          });
        } else if (member is Map) {
          allMembers.add({
            for (var key in member.keys) key.toString(): member[key],
            'team_name': teamName,
            'is_my_team': isMyTeam,
          });
        }
      }
    }

    allMembers.sort((a, b) {
      if (a['is_my_team'] == true && b['is_my_team'] != true) return -1;
      if (a['is_my_team'] != true && b['is_my_team'] == true) return 1;
      return (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString());
    });

    return allMembers;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -50, left: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.15)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
              ),
            ),
            Positioned(
              bottom: -100, right: -50,
              child: Container(
                width: 400, height: 400,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumGold.withOpacity(0.08)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kCardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: kTextPrimary, fontSize: 15),
                        onChanged: (val) => setState(() => _searchText = val),
                        decoration: InputDecoration(
                          hintText: "ค้นหารายชื่อพนักงาน หรือ ทีม...",
                          hintStyle: TextStyle(color: kTextSecondary.withOpacity(0.5), fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: kPremiumGold, size: 22),
                          suffixIcon: _searchText.isNotEmpty 
                            ? IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchText = "");
                                },
                              ) 
                            : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _isFirstLoading
                        ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                        : _errorMessage != null && _teams.isEmpty
                            ? _buildErrorState() 
                            : _flatMembers.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: () async => _onRefresh(), 
                                    color: kDarkBg,
                                    backgroundColor: kPremiumGold,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), 
                                      itemCount: _flatMembers.length,
                                      itemBuilder: (context, index) {
                                        return _buildUserCard(_flatMembers[index]);
                                      },
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

Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // ❌ เอา if (Navigator.canPop(context)) และปุ่มย้อนกลับออกไปเลยครับ เพราะนี่คือหน้าหลัก
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Directory", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kTextPrimary, letterSpacing: 0.5)),
                  SizedBox(height: 4),
                  Text("รายชื่อพนักงานทั้งหมด", style: TextStyle(fontSize: 13, color: kTextSecondary)),
                ],
              ),
            ],
          ),
          
          // 🔔 กระดิ่งแจ้งเตือน
          GestureDetector(
            onTap: () {
              // 1. จุดแดงหายไป
              setState(() => _hasUnreadNotifications = false); 
              
              // 2. กดแล้วให้ Push ไปหน้า NotificationScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kCardSurface, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05))),
                  child: const Icon(Icons.notifications_outlined, color: kTextPrimary, size: 22),
                ),
                if (_hasUnreadNotifications)
                  Positioned(
                    top: 10, right: 12,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle,
                        border: Border.all(color: kCardSurface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> member) {
    final fullName = member['full_name'] ?? 'ไม่มีชื่อ';
    final role = member['role'] ?? 'user';
    final phone = member['phone_number'] ?? 'ไม่มีเบอร์โทร';
    final avatarUrl = member['avatar_url']; 
    final teamName = member['team_name'] ?? 'ไม่ระบุชื่อทีม';
    final isMyTeam = member['is_my_team'] == true;
    final isAdmin = role == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyTeam ? kPremiumGold.withOpacity(0.3) : Colors.white.withOpacity(0.05), 
          width: isMyTeam ? 1.5 : 1
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Row(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kCardInner,
              border: Border.all(color: isAdmin ? kPremiumGold : Colors.white.withOpacity(0.1), width: isAdmin ? 2 : 1),
              boxShadow: isAdmin ? [BoxShadow(color: kPremiumGold.withOpacity(0.2), blurRadius: 10)] : [],
            ),
            child: ClipOval(
              child: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                  ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: kTextSecondary, size: 28))
                  : Icon(Icons.person_rounded, color: isAdmin ? kPremiumGold : kTextSecondary, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(fullName, style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPremiumGold, 
                          borderRadius: BorderRadius.circular(6), 
                          boxShadow: [BoxShadow(color: kPremiumGold.withOpacity(0.3), blurRadius: 4)]
                        ),
                        child: const Text("ADMIN", style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMyTeam ? kPremiumGold.withOpacity(0.1) : kGlowPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isMyTeam ? kPremiumGold.withOpacity(0.3) : kGlowPurple.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspaces_rounded, size: 10, color: isMyTeam ? kPremiumGold : kGlowPurple),
                          const SizedBox(width: 4),
                          Text(
                            teamName, 
                            style: TextStyle(color: isMyTeam ? kPremiumGold : kGlowPurple, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 13, color: kTextSecondary),
                    const SizedBox(width: 4),
                    Text(phone, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kCardInner, 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05))
            ),
            child: const Icon(Icons.call_rounded, color: kTextPrimary, size: 18),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 40),
          ),
          const SizedBox(height: 20),
          Text(_errorMessage ?? "เกิดข้อผิดพลาด", textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh, 
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPremiumGold, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.02)),
            child: const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          const Text("ไม่พบข้อมูลที่ค้นหา", style: TextStyle(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}