import 'package:flutter/material.dart';
import '../pool_project_detail_screen.dart';

// สีหลักคงเดิม แต่เพิ่มมิติของสีทองและสีม่วง
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107);
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolOrderCard extends StatelessWidget {
  final Map<String, dynamic> groupedOrder;
  final VoidCallback onRefresh;
  // เพิ่ม Callback สำหรับการกดติดดาว
  final Function(String projectId, bool currentStatus)? onToggleImportant;

  const PoolOrderCard({
    super.key,
    required this.groupedOrder,
    required this.onRefresh,
    this.onToggleImportant,
  });

  IconData _getIconForProjectType(String? projectTypeName) {
    if (projectTypeName == null || projectTypeName.isEmpty) return Icons.receipt_long_rounded;
    final name = projectTypeName.toLowerCase();
    if (name.contains('condominium')) return Icons.apartment_rounded;
    if (name.contains('shopping mall')) return Icons.shopping_bag_rounded;
    if (name.contains('hospital')) return Icons.local_hospital_rounded;
    if (name.contains('private resident')) return Icons.home_rounded;
    if (name.contains('office building')) return Icons.business_rounded;
    if (name.contains('housing estate')) return Icons.cottage_rounded;
    if (name.contains('resort')) return Icons.holiday_village_rounded;
    if (name.contains('hotel')) return Icons.hotel_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final orderData = groupedOrder['order_data'];
    final List<dynamic> items = groupedOrder['order_items'];

    int totalProjects = 0;
    String firstProjectName = '';
    String fallbackAccountName = '';
    String? firstProjectTypeName;

    // ข้อมูลสำหรับระบบ "ติดดาว"
    bool isImportant = false;
    String projectId = '';

    // วนลูปหาข้อมูลโครงการแรกและเช็คสถานะ Important
    for (var item in items) {
      if (item['order_item_projects'] != null) {
        List projectList = item['order_item_projects'];
        totalProjects += projectList.length;

        for (var p in projectList) {
          // ดึงค่า ID และสถานะสำคัญของโครงการแรกมาแสดง/จัดการ
          if (projectId.isEmpty) {
            projectId = p['id'].toString();
            isImportant = p['is_important'] ?? false;
          }

          if (firstProjectName.isEmpty && (p['project_name'] ?? '').toString().trim().isNotEmpty) {
            firstProjectName = p['project_name'];
          }
          if (firstProjectTypeName == null && p['project_types'] != null) {
            final ptName = p['project_types']['name'];
            if (ptName != null && ptName.toString().trim().isNotEmpty) {
              firstProjectTypeName = ptName.toString();
            }
          }
          if (fallbackAccountName.isEmpty) {
            if ((p['account_developer'] ?? '').toString().trim().isNotEmpty) {
              fallbackAccountName = p['account_developer'];
            } else if ((p['account_architecture'] ?? '').toString().trim().isNotEmpty) {
              fallbackAccountName = p['account_architecture'];
            } else if ((p['account_interior'] ?? '').toString().trim().isNotEmpty) {
              fallbackAccountName = p['account_interior'];
            } else if ((p['account_contractor'] ?? '').toString().trim().isNotEmpty) {
              fallbackAccountName = p['account_contractor'];
            }
          }
        }
      }
    }

    if (firstProjectName.isEmpty) firstProjectName = 'ไม่ระบุชื่อโครงการ';

    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
    String displayCompany = orderData['companies']?['name'] ?? '';
    if (displayCompany.trim().isEmpty) {
      displayCompany = fallbackAccountName.isNotEmpty ? fallbackAccountName : 'ไม่ระบุบริษัท/ผู้ติดต่อ';
    }

    String dateStr = '-';
    if (orderData['created_at'] != null) {
      final date = DateTime.parse(orderData['created_at']).toLocal();
      dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}";
    }

    IconData cardIcon = _getIconForProjectType(firstProjectTypeName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(22),
        // ถ้าติดดาว ขอบจะเรืองแสงเป็นสีทองพรีเมียม
        border: Border.all(
          color: isImportant ? kPremiumGold.withOpacity(0.6) : Colors.white.withOpacity(0.08),
          width: isImportant ? 1.5 : 1,
        ),
        boxShadow: isImportant
            ? [
                BoxShadow(
                  color: kPremiumGold.withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background Gradient อ่อนๆ สำหรับรายการสำคัญ
            if (isImportant)
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kPremiumGold.withOpacity(0.05),
                  ),
                ),
              ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PoolProjectDetailScreen(groupedOrderData: groupedOrder)),
                  ).then((_) => onRefresh());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // ส่วนของ Icon ประจำประเภทโครงการ
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isImportant 
                              ? kPremiumGold.withOpacity(0.1) 
                              : kNeonPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isImportant 
                                ? kPremiumGold.withOpacity(0.3) 
                                : kNeonPurple.withOpacity(0.2)
                          ),
                        ),
                        child: Icon(
                          cardIcon, 
                          color: isImportant ? kPremiumGold : kNeonPurple, 
                          size: 28
                        ),
                      ),
                      const SizedBox(width: 16),

                      // ข้อมูลตัวอักษร
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalProjects > 1 ? "$firstProjectName (+อีก ${totalProjects - 1} โครงการ)" : firstProjectName,
                              style: TextStyle(
                                color: isImportant ? kPremiumGold : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            
                            // ชื่อเซลล์
                            Row(
                              children: [
                                const Icon(Icons.person_pin_rounded, size: 14, color: Colors.white54),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    saleName,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // บริษัท/ผู้ติดต่อ
                            Row(
                              children: [
                                Icon(Icons.business_center_rounded, size: 13, color: Colors.grey[500]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    displayCompany,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // วันที่
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month_outlined, color: Colors.white38, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ปุ่มติดดาว (Action Button)
                      // ปุ่มติดดาว (Action Button) คลีนแล้ว!
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (onToggleImportant != null && projectId.isNotEmpty) {
                                    onToggleImportant!(projectId, isImportant);
                                  }
                                },
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: isImportant ? 1.2 : 1.0,
                                  child: Icon(
                                    isImportant ? Icons.star_rounded : Icons.star_border_rounded, 
                                    color: isImportant ? kPremiumGold : Colors.white10,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                            ],
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}