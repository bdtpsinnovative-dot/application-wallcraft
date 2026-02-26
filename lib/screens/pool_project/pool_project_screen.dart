import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../services/api_service.dart';
import 'pool_sub_project_list_screen.dart'; // ✅ นำเข้าหน้าใหม่ที่กำลังจะสร้าง

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107); 
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolProjectScreen extends StatefulWidget {
  const PoolProjectScreen({super.key});

  @override
  State<PoolProjectScreen> createState() => _PoolProjectScreenState();
}

class _PoolProjectScreenState extends State<PoolProjectScreen> {
  Map<String, List<dynamic>> _groupedProjects = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects?page=1&limit=50');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> rawData = result is List ? result : (result['data'] ?? []);

        Map<String, List<dynamic>> tempGrouped = {};

        for (var item in rawData) {
          final orderData = item['orders'] ?? {};
          final String orderId = orderData['id'] ?? 'unknown_order';
          
          final oip = item['order_item_projects'];

          if (oip != null && oip is List && oip.isNotEmpty) {
            for (var projectRelation in oip) {
              var newItem = Map<String, dynamic>.from(item);
              newItem['display_project_name'] = projectRelation['projects']?['project_name'] ?? 'ไม่มีชื่อโครงการ';
              newItem['specific_project_data'] = projectRelation;
              tempGrouped.putIfAbsent(orderId, () => []).add(newItem);
            }
          } else {
            var newItem = Map<String, dynamic>.from(item);
            newItem['display_project_name'] = 'ไม่ได้ระบุโครงการ';
            newItem['specific_project_data'] = {};
            tempGrouped.putIfAbsent(orderId, () => []).add(newItem);
          }
        }

        setState(() {
          _groupedProjects = tempGrouped;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } on SocketException {
      setState(() => _errorMessage = "ไม่มีการเชื่อมต่ออินเทอร์เน็ต");
    } on TimeoutException {
      setState(() => _errorMessage = "เซิร์ฟเวอร์ตอบสนองช้าเกินไป");
    } catch (e) {
      setState(() => _errorMessage = "เกิดข้อผิดพลาดในการโหลดข้อมูล");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  title: const Text(
                    "Pool Projects",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (_isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kNeonPurple)))
                else if (_errorMessage != null)
                  SliverFillRemaining(child: _buildErrorState())
                else if (_groupedProjects.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text("ไม่พบโปรเจกต์", style: TextStyle(color: Colors.white70))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          String orderId = _groupedProjects.keys.elementAt(index);
                          List<dynamic> itemsInOrder = _groupedProjects[orderId]!;
                          return _buildOrderCard(orderId, itemsInOrder); // ✅ เปลี่ยนมาเรียกการ์ดออเดอร์
                        },
                        childCount: _groupedProjects.length,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// ✨ สร้างเป็นการ์ด 1 Order ต่อ 1 ชิ้น
  Widget _buildOrderCard(String orderId, List<dynamic> itemsInOrder) {
    final orderData = itemsInOrder[0]['orders'] ?? {};
    final String refCode = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase();
    
    // ✅ ดึงชื่อลูกค้าและชื่อบริษัท
    final customerName = orderData['customer_name'] ?? 'ไม่ระบุชื่อลูกค้า';
    final companyName = orderData['companies']?['name'] ?? ''; 
    
    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
    
    String timeStr = '';
    if (orderData['created_at'] != null) {
      final date = DateTime.parse(orderData['created_at']).toLocal();
      timeStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PoolSubProjectListScreen(
                  refCode: refCode,
                  itemsInOrder: itemsInOrder,
                ),
              ),
            ).then((_) => _fetchProjects());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1️⃣ ชื่อเซลล์ผู้บันทึก
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.badge_rounded, color: kPremiumGold, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              saleName, 
                              style: const TextStyle(color: kPremiumGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis, 
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                  ],
                ),
                const SizedBox(height: 14),
                
                // 2️⃣ ชื่อลูกค้า
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "ลูกค้า: $customerName", 
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                // 3️⃣ ชื่อบริษัท (แสดงบรรทัดใหม่ เฉพาะกรณีที่มีข้อมูล)
                if (companyName.isNotEmpty && companyName != '-') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 16, color: Colors.grey[500]), // ไอคอนตึกสวยๆ
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          companyName, 
                          style: TextStyle(color: Colors.grey[400], fontSize: 13), // สีดรอปลงมานิดนึงให้ดูมีมิติ
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                
                // 4️⃣ ส่วนท้าย (จำนวนโครงการย่อย + เวลา)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kNeonPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${itemsInOrder.length} โครงการย่อย",
                        style: const TextStyle(color: kNeonPurple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: _fetchProjects, 
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text("ลองใหม่")
          )
        ],
      ),
    );
  }
}