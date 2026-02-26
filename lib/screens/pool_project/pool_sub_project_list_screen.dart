import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pool_project_detail_screen.dart'; // ✅ ดึงหน้าแก้ไขมา

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107); 
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolSubProjectListScreen extends StatelessWidget {
  final String refCode;
  final List<dynamic> itemsInOrder;

  const PoolSubProjectListScreen({
    super.key,
    required this.refCode,
    required this.itemsInOrder,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.2)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: kDarkBg.withOpacity(0.9),
                  expandedHeight: 70,
                  toolbarHeight: 70,
                  pinned: true,
                  elevation: 4,
                  centerTitle: true,
                  title: Column(
                    children: [
                      const Text(
                        "โครงการย่อย",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "Order #$refCode",
                        style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.normal, fontSize: 12),
                      ),
                    ],
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context), // กลับไปหน้าแรก
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildProjectCard(context, itemsInOrder[index]);
                      },
                      childCount: itemsInOrder.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ],
        ),
      ),
    );
  }

// ✨ UI ของการ์ดโปรเจกต์ (มีแสดงขนาดพื้นที่ sq.m.)
  Widget _buildProjectCard(BuildContext context, dynamic item) {
    final orderData = item['orders'] ?? {};
    final specificProject = item['specific_project_data'] ?? {}; // ✅ ดึงข้อมูลตารางหลาน
    
    String projectName = item['display_project_name'] ?? 'ไม่มีชื่อโครงการ';
    final customerName = orderData['customer_name'] ?? 'ไม่ระบุชื่อลูกค้า';
    final companyName = orderData['companies']?['name'] ?? '-';
    final productName = item['product_categories']?['name'] ?? 'ไม่ระบุสินค้า';
    
    // ✅ ดึงขนาดพื้นที่ ถ้าไม่มีให้เป็น 0
    final areaSqm = specificProject['area_sqm'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // 🚀 พอกดปุ๊บ ไปหน้า Detail เพื่อดู/แก้ไขข้อมูล
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PoolProjectDetailScreen(itemData: item)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kNeonPurple.withOpacity(0.15), 
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kNeonPurple.withOpacity(0.3))
                  ),
                  child: const Icon(Icons.apartment_rounded, color: kNeonPurple, size: 24), 
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1️⃣ ชื่อโครงการขึ้นมาเป็นอันดับแรก เด่นๆ
                      Text(
                        projectName, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // 2️⃣ ป้ายชื่อสินค้า + ป้ายขนาดพื้นที่
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kPremiumGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              productName,
                              style: const TextStyle(color: kPremiumGold, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ✅ แสดงป้าย sq.m. 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "$areaSqm sq.m.", // ใช้ตัวย่อภาษาอังกฤษ
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 3️⃣ ชื่อลูกค้า/บริษัท
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              companyName != '-' && companyName.isNotEmpty 
                                  ? "$customerName ($companyName)" 
                                  : customerName, 
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }}