// lib/screens/notifications/NotificationScreen.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

// 🎨 โทนสี Deep Modern Dark
const Color kDarkBg = Color(0xFF090A0F); 
const Color kCardSurface = Color(0xFF15171E); 
const Color kCardInner = Color(0xFF1E202B); 
const Color kPremiumGold = Color(0xFFFFD700); 
const Color kTextPrimary = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFFA0A5B5);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  // 📡 ดึงข้อมูลแจ้งเตือนจาก Server
  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/notifications');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> fetchedData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = fetchedData;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } on SocketException {
      _handleError("ขาดการเชื่อมต่ออินเทอร์เน็ต");
    } on TimeoutException {
      _handleError("เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป");
    } catch (e) {
      _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้");
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
        
        // 🌟 ต้องใช้ jsonEncode() ครอบข้อมูลก่อนส่ง
        await ApiService.post(url, body: jsonEncode({
          "notification_id": notifId.toString() 
        })); 
        
        print("✅ แจ้ง Server สำเร็จว่าอ่านแล้ว!");
      } catch (e) {
        print("❌ เกิดข้อผิดพลาดตอนอัปเดตสถานะ: $e");
      }
    }

    // 3. เด้งป๊อปอัพดูรายละเอียดออเดอร์
    if (orderId != null && mounted) {
      _showOrderDetailsDialog(orderId.toString());
    }
  }

  // 🌟 ฟังก์ชันดึงและโชว์ป๊อปอัพ (อัปเกรดแล้ว)
  Future<void> _showOrderDetailsDialog(String orderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(child: CircularProgressIndicator(color: kPremiumGold)),
    );

    try {
      // 🌟 ยิงหา API ใหม่ที่เราเพิ่งสร้าง
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
      Navigator.pop(context); // ปิด Loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โหลดข้อมูลล้มเหลว')));
    }
  }

  // 🖼️ วาดหน้าต่างป๊อปอัพ (ปรับให้รองรับข้อมูลแบบใหม่)
  void _buildDetailsPopup(BuildContext context, Map<String, dynamic> data) {
    final customerName = data['customer_name'] ?? data['companies']?['name'] ?? 'ลูกค้าทั่วไป';
    final creatorName = data['profiles']?['full_name'] ?? 'เพื่อนร่วมทีม';
    
    // พยายามขุดหาชื่อโปรเจกต์และรูปภาพจาก order_items
    String projectName = '-';
    String areaSqm = '-';
    List<dynamic> images = [];
    
    if (data['order_items'] != null && (data['order_items'] as List).isNotEmpty) {
      final firstItem = (data['order_items'] as List)[0];
      images = firstItem['images'] ?? [];
      
      final projects = firstItem['order_item_projects'] as List?;
      if (projects != null && projects.isNotEmpty) {
        projectName = projects[0]['project_name'] ?? '-';
        areaSqm = projects[0]['area_sqm']?.toString() ?? '-';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kCardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kPremiumGold.withOpacity(0.3))),
          title: Row(
            children: const [
              Icon(Icons.assignment_rounded, color: kPremiumGold),
              SizedBox(width: 8),
              Text('สรุปออเดอร์', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('ลูกค้า:', customerName),
                _buildDetailRow('โครงการ:', projectName),
                _buildDetailRow('พื้นที่ (ตร.ม.):', areaSqm),
                _buildDetailRow('ผู้ทำรายการ:', creatorName),
                
                // 🖼️ ถ้ามีรูปให้โชว์เป็นแกลลอรีเล็กๆ
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('รูปภาพแนบ:', style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, i) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
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
              child: const Text('ปิด', style: TextStyle(color: kTextSecondary)),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันช่วยเหลือสำหรับบรรทัดในป๊อปอัพ (วางต่อกันได้เลย)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90, 
            child: Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 14))
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600))
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("การแจ้งเตือน", style: TextStyle(color: kTextPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          actions: [
            if (_notifications.isNotEmpty)
              IconButton(
                onPressed: _fetchNotifications, 
                icon: const Icon(Icons.refresh_rounded, color: kPremiumGold),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  // 📝 การ์ดแจ้งเตือนแบบโชว์รูปโปรไฟล์
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
        timeDisplay = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} เวลา ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.";
      }
    } catch (e) {
      timeDisplay = createdAtStr.toString().substring(0, 10);
    }

    return GestureDetector(
      onTap: () => _onNotificationTap(notif, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isRead ? kCardSurface.withOpacity(0.4) : kCardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? Colors.transparent : kPremiumGold.withOpacity(0.3),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: isRead ? [] : [
            BoxShadow(color: kPremiumGold.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kCardInner,
                border: Border.all(color: isRead ? Colors.white.withOpacity(0.05) : kPremiumGold.withOpacity(0.5)),
                boxShadow: isRead ? [] : [BoxShadow(color: kPremiumGold.withOpacity(0.2), blurRadius: 10)],
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                    ? Image.network(
                        avatarUrl, 
                        fit: BoxFit.cover, 
                        errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: kTextSecondary, size: 28)
                      )
                    : const Icon(Icons.person_rounded, color: kPremiumGold, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRead ? kCardInner : kPremiumGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isRead ? kTextSecondary : kPremiumGold, 
                            fontSize: 11, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent, 
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 6)]
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: TextStyle(
                      color: isRead ? kTextSecondary : kTextPrimary, 
                      fontSize: 16, 
                      height: 1.4,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: kTextSecondary.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: TextStyle(color: kTextSecondary.withOpacity(0.6), fontSize: 12),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 40),
          ),
          const SizedBox(height: 20),
          Text(_errorMessage ?? "เกิดข้อผิดพลาด", textAlign: TextAlign.center, style: const TextStyle(color: kTextSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchNotifications, 
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
            child: const Icon(Icons.notifications_off_rounded, size: 48, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          const Text("ไม่มีการแจ้งเตือนใหม่", style: TextStyle(color: kTextSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}