import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'purchase_order_screen.dart';
import 'ai_image_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // สีหลักของแอป (ปรับเปลี่ยนได้ตาม CI องค์กร)
  final Color primaryColor = const Color(0xFF1E3A8A); // Blue 900
  final Color secondaryColor = const Color(0xFF3B82F6); // Blue 500
  final Color backgroundColor = const Color(0xFFF1F5F9); // Slate 100

  @override
  Widget build(BuildContext context) {
    // ดึงข้อมูล User
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'ผู้ใช้งานทั่วไป';
    final String displayName = email.split('@')[0]; // ดึงชื่อหน้า @ มาแสดง

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // 1. ส่วน Header ด้านบน (Modern Curve Design)
          _buildHeader(context, displayName, email),

          // 2. ส่วนเนื้อหาหลัก (Body)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                const Text(
                  'เมนูการทำงาน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid Menu
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1, // ปรับสัดส่วนการ์ด
                  children: [
                    _MenuCard(
                      title: 'สั่งซื้อสินค้า',
                      subtitle: 'สร้างและติดตาม\nใบสั่งซื้อ',
                      icon: Icons.shopping_cart_checkout_rounded,
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PurchaseOrderScreen()),
                        );
                      },
                    ),
                    _MenuCard(
                      title: 'AI ค้นหารูป',
                      subtitle: 'ค้นหาอัจฉริยะ\nด้วยรูปภาพ',
                      icon: Icons.image_search_rounded,
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AiImageSearchScreen()),
                        );
                      },
                    ),
                    // *ตัวอย่างปุ่ม Placeholder เพื่อให้ Grid สวยงาม*
                    _MenuCard(
                      title: 'รายงาน',
                      subtitle: 'สรุปยอดขาย\nประจำเดือน',
                      icon: Icons.bar_chart_rounded,
                      color: Colors.teal,
                      onTap: () {
                        // ยังไม่ได้ทำหน้า
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming Soon...')));
                      },
                    ),
                    _MenuCard(
                      title: 'โปรไฟล์',
                      subtitle: 'ตั้งค่าบัญชี\nส่วนตัว',
                      icon: Icons.person_rounded,
                      color: Colors.orangeAccent,
                      onTap: () {
                        // ยังไม่ได้ทำหน้า
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget ส่วนหัวด้านบน
  Widget _buildHeader(BuildContext context, String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี, $name 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              // ปุ่ม Logout แบบ Icon เล็กๆ
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// การ์ดเมนูสวยๆ
class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 2,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              // Text Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}