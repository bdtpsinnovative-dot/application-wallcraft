// lib/screens/notifications/NotificationScreen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../constants.dart';
import '../../services/api_service.dart';
import '../orders/order_history_screen.dart';
import '../pool_project/pool_project_detail_screen.dart';

// 🎨 โทนสี Deep Modern Dark
const Color kDarkBg = Color(0xFF090A0F); 
const Color kCardSurface = Color(0xFF15171E); 
const Color kCardInner = Color(0xFF1E202B); 
const Color kPremiumGold = Color(0xFFFFD700); 
const Color kTextPrimary = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFFA0A5B5);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  static List<dynamic>? cachedNotifications;
  
  static void invalidateCache() {
    cachedNotifications = null;
  }

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();

    if (NotificationScreen.cachedNotifications != null) {
      _notifications = List.from(NotificationScreen.cachedNotifications!);
      _isLoading = false;
      _fetchNotifications(isSilent: true);
    } else {
      _fetchNotifications();
    }

    _setupFcmListener();
  }

  void _setupFcmListener() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        _fetchNotifications(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  // 📡 ดึงข้อมูลแจ้งเตือนจาก Server (รองรับ Silent Background Refresh)
  Future<void> _fetchNotifications({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/notifications');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedData = jsonDecode(response.body);
        if (mounted) {
          NotificationScreen.cachedNotifications = fetchedData;
          setState(() {
            _notifications = fetchedData;
            _isLoading = false;
          });
        }
      } else {
        if (!isSilent) throw Exception('Failed: ${response.statusCode}');
      }
    } on SocketException {
      if (!isSilent) _handleError("ขาดการเชื่อมต่ออินเทอร์เน็ต");
    } on TimeoutException {
      if (!isSilent) _handleError("เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป");
    } catch (e) {
      if (!isSilent) _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้");
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMessage = msg;
      _isLoading = false;
    });
  }

  // 🖱️ เวลากดที่แจ้งเตือน (อัปเดตสถานะเป็นอ่านแล้ว + เด้งป๊อปอัพ)
  Future<void> _onNotificationTap(Map<String, dynamic> notif, int index) async {
    final notifId = notif['id'];
    final orderId = notif['order_id'];
    final isRead = notif['is_read'] ?? false;

    // 1. เปลี่ยน UI ให้ดูว่าอ่านแล้วทันที 
    if (!isRead) {
      setState(() {
        _notifications[index]['is_read'] = true;
      });

      // 🌟 2. ยิง API POST ไปบอก Server ให้บันทึกลง Database
      try {
        final url = Uri.parse('${AppConfig.baseUrl}/notifications/read');
        await ApiService.post(url, body: jsonEncode({
          "notification_id": notifId.toString() 
        })); 
      } catch (e) {
        print("❌ เกิดข้อผิดพลาดตอนอัปเดตสถานะ: $e");
      }
    }

    // 3. เด้งป๊อปอัพดูรายละเอียดออเดอร์ หรือ ดูแจ้งเตือนเต็มๆ
    if (orderId != null && mounted) {
      _showOrderDetailsDialog(orderId.toString());
    } else if (mounted) {
      _showGeneralNotificationDialog(notif);
    }
  }

  // 📝 ป๊อปอัพอ่านแจ้งเตือนทั่วไป (เช่น สรุปงานประจำวัน)
  void _showGeneralNotificationDialog(Map<String, dynamic> notif) {
    final title = notif['title'] ?? 'ระบบ';
    final body = notif['body'] ?? 'ไม่มีเนื้อหา';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kCardSurface,
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: BorderSide(color: kPremiumGold.withOpacity(0.3))
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: kPremiumGold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold))
              ),
            ],
          ),
          content: Text(
            body,
            style: const TextStyle(color: kTextPrimary, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด', style: TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🌟 ฟังก์ชันดึงและโชว์ป๊อปอัพ
  Future<void> _showOrderDetailsDialog(String orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(child: CircularProgressIndicator(color: kPremiumGold)),
    );

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/orders/detail?order_id=$orderId'); 
      final response = await ApiService.get(url).timeout(const Duration(seconds: 10));

      Navigator.pop(context); // ปิด Loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) _buildDetailsPopup(context, data);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลออเดอร์นี้')));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โหลดข้อมูลล้มเหลว')));
    }
  }

  void _navigateToPoolProject(BuildContext context, Map<String, dynamic> data) {
    Navigator.pop(context);
    final Map<String, dynamic> groupedData = {
      'order_data': data,
      'order_items': data['order_items'] ?? [],
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoolProjectDetailScreen(groupedOrderData: groupedData),
      ),
    );
  }

  // 🖼️ วาดหน้าต่างป๊อปอัพ
  void _buildDetailsPopup(BuildContext context, Map<String, dynamic> data) {
    final customerName = data['customer_name'] ?? data['companies']?['name'] ?? 'ลูกค้าทั่วไป';
    final creatorName = data['profiles']?['full_name'] ?? 'เพื่อนร่วมทีม';
    
    String projectName = '-';
    String areaSqm = '-';
    String projectNote = '-';
    String queueLevel = '-';
    String projectYear = '-';
    List<dynamic> images = [];
    String productCat = '-';
    String projectType = '-';

    if (data['order_items'] != null && (data['order_items'] as List).isNotEmpty) {
      final firstItem = (data['order_items'] as List)[0];
      images = firstItem['images'] ?? [];
      productCat = firstItem['product_categories']?['name'] ?? '-';
      final projects = firstItem['order_item_projects'] as List?;
      if (projects != null && projects.isNotEmpty) {
        projectType = projects[0]['project_types']?['name'] ?? '-';
        projectName = projects[0]['project_name'] ?? '-';
        areaSqm = projects[0]['area_sqm']?.toString() ?? '-';
        projectNote = projects[0]['project_note'] ?? '-';
        queueLevel = projects[0]['queue_level']?.toString() ?? '-';
        projectYear = projects[0]['project_year']?.toString() ?? '-';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kCardSurface,
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kPremiumGold.withOpacity(0.3))),
          title: Row(
            children: const [
              Icon(Icons.assignment_rounded, color: kPremiumGold, size: 20),
              SizedBox(width: 6),
              Text('สรุปออเดอร์', style: TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ลูกค้า:', customerName),
                
                // 🌟 แถวโครงการดีไซน์เน้นสีทอง กดเปิด Pool Project ได้ทันที
                InkWell(
                  onTap: () => _navigateToPoolProject(context, data),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kPremiumGold.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildDetailRow('โครงการ:', projectName, isGold: true)),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kPremiumGold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _buildDetailRow('พื้นที่ (ตร.ม.):', areaSqm),
                
                const Divider(color: Colors.white10, height: 16, thickness: 1),
                _buildDetailRow('คิวงาน:', queueLevel != '-' ? 'คิวที่ $queueLevel' : '-'),
                _buildDetailRow('พ.ศ.:', projectYear),
                _buildDetailRow('คอมเมนต์:', projectNote),
                const Divider(color: Colors.white10, height: 16, thickness: 1),

                _buildDetailRow('ผู้ทำรายการ:', creatorName),
                
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('รูปภาพแนบ:', style: TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, i) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            image: DecorationImage(image: NetworkImage(images[i]), fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  )
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด', style: TextStyle(color: kTextSecondary, fontSize: 13)),
            ),
            ElevatedButton.icon(
              onPressed: () => _navigateToPoolProject(context, data),
              icon: const Icon(Icons.folder_special_rounded, size: 16),
              label: const Text('เข้าดู Pool Project ➔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPremiumGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isGold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80, 
            child: Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12))
          ),
          Expanded(
            child: Text(
              value, 
              style: TextStyle(
                color: isGold ? kPremiumGold : kTextPrimary, 
                fontSize: 12, 
                fontWeight: isGold ? FontWeight.bold : FontWeight.w600,
                decoration: isGold ? TextDecoration.underline : TextDecoration.none,
              )
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kDarkBg,
        appBar: AppBar(
          backgroundColor: kDarkBg,
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 48,
          title: const Text("การแจ้งเตือน", style: TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          actions: [
            if (_notifications.isNotEmpty)
              IconButton(
                onPressed: _fetchNotifications, 
                icon: const Icon(Icons.refresh_rounded, color: kPremiumGold, size: 20),
                tooltip: 'รีเฟรช',
              )
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
            : _errorMessage != null
                ? _buildErrorState()
                : _notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchNotifications,
                        color: kDarkBg,
                        backgroundColor: kPremiumGold,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(_notifications[index], index);
                          },
                        ),
                      ),
      ),
    );
  }

  // 📝 การ์ดแจ้งเตือนขนาดกะทัดรัด (Compact Style)
  Widget _buildNotificationCard(Map<String, dynamic> notif, int index) {
    final title = notif['title'] ?? 'ระบบ'; 
    final body = notif['body'] ?? 'ไม่มีเนื้อหา'; 
    final isRead = notif['is_read'] ?? false;
    
    final creator = notif['creator'];
    final avatarUrl = creator?['avatar_url']; 
    
    final createdAtStr = notif['created_at'] ?? '';
    String timeDisplay = createdAtStr;
    try {
      if (createdAtStr.isNotEmpty) {
        DateTime dt = DateTime.parse(createdAtStr).toLocal();
        timeDisplay = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.";
      }
    } catch (e) {
      timeDisplay = createdAtStr.toString().substring(0, 10);
    }

    return GestureDetector(
      onTap: () => _onNotificationTap(notif, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRead ? kCardSurface.withOpacity(0.35) : kCardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? Colors.transparent : kPremiumGold.withOpacity(0.25),
            width: isRead ? 1 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kCardInner,
                border: Border.all(color: isRead ? Colors.white.withOpacity(0.05) : kPremiumGold.withOpacity(0.4)),
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                    ? Image.network(
                        avatarUrl, 
                        fit: BoxFit.cover, 
                        errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: kTextSecondary, size: 20)
                      )
                    : const Icon(Icons.person_rounded, color: kPremiumGold, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRead ? kCardInner : kPremiumGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isRead ? kTextSecondary : kPremiumGold, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent, 
                            shape: BoxShape.circle,
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: isRead ? kTextSecondary : kTextPrimary, 
                      fontSize: 13, 
                      height: 1.3,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 11, color: kTextSecondary.withOpacity(0.5)),
                      const SizedBox(width: 3),
                      Text(
                        timeDisplay,
                        style: TextStyle(color: kTextSecondary.withOpacity(0.5), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 30),
          ),
          const SizedBox(height: 14),
          Text(_errorMessage ?? "เกิดข้อผิดพลาด", textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchNotifications, 
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPremiumGold, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle),
            child: Icon(Icons.notifications_off_outlined, color: kTextSecondary.withOpacity(0.4), size: 36),
          ),
          const SizedBox(height: 12),
          const Text("ยังไม่มีการแจ้งเตือน", style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}