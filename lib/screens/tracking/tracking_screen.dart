// lib/screens/tracking/tracking_screen.dart
import 'package:flutter/material.dart';

// 🌟 แก้ 2 บรรทัดนี้ใหม่ ให้เรียกไฟล์ในโฟลเดอร์เดียวกันตรงๆ เลยจ้ะ
import 'package_tracking_page.dart'; 
import 'stock_management_page.dart';
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kDarkBg = Color(0xFF0F0F11);
    const Color kCardDark = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('จัดการการขนส่งและสต็อก', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 📦 ปุ่มที่ 1: ติดตามพัสดุ
           // 📦 ปุ่มที่ 1: ติดตามพัสดุ
_buildMenuButton(
  context,
  title: "ติดตามพัสดุ",
  subtitle: "เช็คสถานะการส่งสินค้าของลูกค้า",
  icon: Icons.local_shipping_rounded,
  iconColor: Colors.pinkAccent,
  destination: PackageTrackingPage(), // 🚀 ลบ const ออกตรงนี้
),
const SizedBox(height: 16),
// 📦 ปุ่มที่ 2: Stock
_buildMenuButton(
  context,
  title: "Stock Management",
  subtitle: "ตรวจสอบจำนวนสินค้าในคลัง",
  icon: Icons.inventory_2_rounded,
  iconColor: Colors.cyanAccent,
  destination: StockManagementPage(), // 🚀 ลบ const ออกตรงนี้
),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันสร้างปุ่มเมนูสไตล์ Glassmorphism ที่นายชอบครับ
  Widget _buildMenuButton(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget destination,
  }) {
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          // 🚀 กดแล้วเปลี่ยนหน้าจริงตรงนี้ครับนาย
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}