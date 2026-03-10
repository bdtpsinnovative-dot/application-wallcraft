import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/api_service.dart';
import '../../constants.dart';
import 'components/edit_project_dialog.dart';
import 'components/edit_order_info_dialog.dart'; 

const Color kDarkBg = Color(0xFF0F0F11);
const Color kPremiumGold = Color(0xFFFFC107);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> groupedOrderData;
  const PoolProjectDetailScreen({super.key, required this.groupedOrderData});

  @override
  State<PoolProjectDetailScreen> createState() => _PoolProjectDetailScreenState();
}

class _PoolProjectDetailScreenState extends State<PoolProjectDetailScreen> {
  late Map<String, dynamic> orderData;
  late List<dynamic> items;
  bool _isSaving = false;
  bool _isLoadingCategories = true; 
  
  final Set<String> _expandedProjectIds = {};
  List<Map<String, dynamic>> _dynamicCategories = [];
  List<Map<String, dynamic>> _projectTypes = []; // 🌟 เพิ่มบรรทัดนี้

  @override
  void initState() {
    super.initState();
    orderData = widget.groupedOrderData['order_data'] ?? {};
    items = widget.groupedOrderData['order_items'] ?? [];
    
    _fetchCategories();
    _fetchProjectTypes(); // 🌟 เรียกใช้ตรงนี้
  }

  Future<void> _fetchCategories() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/categories'); 
      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> catList = result['data'] ?? [];
        
        setState(() {
          _dynamicCategories = catList.map((e) => e as Map<String, dynamic>).toList();
          _isLoadingCategories = false;
        });
      } else {
        throw Exception("โหลดหมวดหมู่ไม่สำเร็จ");
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchProjectTypes() async {
    try {
      // 🌟 แก้จาก '${AppConfig.baseUrl}/v1/project-types' 
      // 🌟 เป็นแบบข้างล่างนี้ครับ
      final url = Uri.parse('${AppConfig.baseUrl}/project-types'); 
      
      debugPrint("Fetching from: $url"); // รอบนี้ url จะสวยงาม ไม่ซ้อนแล้ว
      
      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _projectTypes = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error fetching project types: $e");
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้'), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  // 🌟 ฟังก์ชันเปิดดูรูปภาพแบบเต็มจอ (ซูมได้)
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveData(String projectId, Map<String, dynamic> updatedData) async {
    setState(() => _isSaving = true);
    try {
      final String orderId = orderData['id'] ?? '';
      if (orderId.isEmpty || projectId.isEmpty) throw Exception("Missing ID");

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects');
      final response = await ApiService.patch(
        url, 
        body: jsonEncode({
          "order_id": orderId,
          "order_item_project_id": projectId,
          "project_name": updatedData['project_name'],
          "area_sqm": updatedData['area_sqm'],
          "product_category_id": updatedData['product_category_id'],
          "project_type_id": updatedData['project_type_id'], // 🌟 ส่งค่า project_type_id ไปบันทึก
          "account_developer": updatedData['account_developer'],
          "contact_developer": updatedData['contact_developer'],
          "account_architecture": updatedData['account_architecture'],
          "contact_architecture": updatedData['contact_architecture'],
          "account_interior": updatedData['account_interior'],
          "contact_interior": updatedData['contact_interior'],
          "account_contractor": updatedData['account_contractor'],
          "contact_contractor": updatedData['contact_contractor']
        })
      );

      if (response.statusCode == 200) {
        setState(() {
          for (var item in items) {
            final oipList = item['order_item_projects'] as List?;
            if (oipList != null) {
              for (var p in oipList) {
                if (p['id'] == projectId) {
                  p['project_name'] = updatedData['project_name'];
                  p['area_sqm'] = updatedData['area_sqm']; 
                  p['project_type_id'] = updatedData['project_type_id']; // 🌟 อัปเดตค่า local
                  p['account_developer'] = updatedData['account_developer'];
                  p['contact_developer'] = updatedData['contact_developer'];
                  p['account_architecture'] = updatedData['account_architecture'];
                  p['contact_architecture'] = updatedData['contact_architecture'];
                  p['account_interior'] = updatedData['account_interior'];
                  p['contact_interior'] = updatedData['contact_interior'];
                  p['account_contractor'] = updatedData['account_contractor'];
                  p['contact_contractor'] = updatedData['contact_contractor'];
                  
                  item['product_category_id'] = updatedData['product_category_id'];
                  final matchedCat = _dynamicCategories.firstWhere(
                    (cat) => cat['id'] == updatedData['product_category_id'],
                    orElse: () => {"name": "ประเภทสินค้า"}
                  );
                  item['product_categories'] = {"name": matchedCat['name']};
                }
              }
            }
          }
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตข้อมูลโครงการสำเร็จ!'), backgroundColor: kLimeGreen));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'เกิดข้อผิดพลาดในการบันทึกข้อมูล');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')), 
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4), 
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _saveOrderInfo(String newCustomerName, String newPhone) async {
    try {
      final String orderId = orderData['id'] ?? '';
      if (orderId.isEmpty) throw Exception("Missing Order ID");

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects');
      
      final response = await ApiService.patch(
        url, 
        body: jsonEncode({
          "order_id": orderId,
          "customer_name": newCustomerName,
          "phone": newPhone,
        })
      );

      if (response.statusCode == 200) {
        setState(() {
          orderData['customer_name'] = newCustomerName;
          orderData['phone'] = newPhone;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตข้อมูลลูกค้าสำเร็จ!'), backgroundColor: kLimeGreen));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'เกิดข้อผิดพลาดในการบันทึกข้อมูล');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = orderData['customer_name'] ?? 'ไม่ระบุชื่อลูกค้า';
    final companyName = orderData['companies']?['name'] ?? 'ไม่ระบุชื่อบริษัท';
    final phoneNum = orderData['phone'] ?? '-';
    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
    
    String dateStr = '-';
    if (orderData['created_at'] != null) {
      final date = DateTime.parse(orderData['created_at']).toLocal();
      dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}";
    }

    List<Widget> projectCards = [];
    List<String> allImages = []; // 🌟 ตัวแปรเก็บรูปภาพทั้งหมด

    for (var item in items) {
      final categoryName = item['product_categories']?['name'] ?? 'ไม่ระบุหมวดหมู่';
      final productProjects = item['order_item_projects'] as List? ?? [];
      
      for (var p in productProjects) {
        projectCards.add(_buildProjectCard(p, categoryName));
      }

      // 🌟 ดึงข้อมูลรูปภาพจากคอลัมน์ images (รองรับทั้ง List และ Stringified JSON)
      if (item['images'] != null) {
        if (item['images'] is List) {
          allImages.addAll((item['images'] as List).map((e) => e.toString()).toList());
        } else if (item['images'] is String) {
          try {
            final decoded = jsonDecode(item['images']);
            if (decoded is List) {
              allImages.addAll(decoded.map((e) => e.toString()).toList());
            }
          } catch (_) {}
        }
      }
    }

    final auditLog = orderData['audit_log'];
    double? lat, lng;
    String? deviceName;
    if (auditLog != null) {
      if (auditLog['location'] != null) {
        lat = (auditLog['location']['lat'] as num?)?.toDouble();
        lng = (auditLog['location']['lng'] as num?)?.toDouble();
      }
      if (auditLog['device'] != null) {
        deviceName = "${auditLog['device']['brand'] ?? ''} ${auditLog['device']['model'] ?? ''}";
      }
    }

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text("รายละเอียด Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), 
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(top: -50, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.2)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)))),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.receipt_long_rounded, color: kNeonPurple, size: 20)),
                              const SizedBox(width: 12),
                              const Text("ข้อมูลโครงการ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context, 
                                builder: (context) => EditOrderInfoDialog(
                                  initialCustomerName: orderData['customer_name'] ?? '',
                                  initialPhone: orderData['phone'] ?? '',
                                  onSave: _saveOrderInfo, 
                                )
                              );
                            }, 
                            icon: const Icon(Icons.edit_note_rounded, color: kPremiumGold, size: 26),
                            tooltip: "แก้ไขข้อมูลลูกค้า",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                      const SizedBox(height: 20), const Divider(color: Colors.white12), const SizedBox(height: 16),
                      _buildInfoRow("Customer", ownerName),
                      _buildInfoRow("Company", companyName),
                      _buildInfoRow("Phone / Line", phoneNum),
                      _buildInfoRow("Sale Name", saleName),
                      _buildInfoRow("Date", dateStr),

                      if (lat != null && lng != null) ...[
                        const SizedBox(height: 16), const Divider(color: Colors.white12), const SizedBox(height: 16),
                        Row(children: const [Icon(Icons.security_rounded, color: kNeonPurple, size: 16), SizedBox(width: 6), Text("ความปลอดภัย (Audit Log)", style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, fontSize: 13))]),
                        const SizedBox(height: 16),
                        if (deviceName != null) _buildInfoRow("Device", deviceName),
                        InkWell(
                          onTap: () => _openMap(lat!, lng!),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: kNeonPurple.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: kNeonPurple.withOpacity(0.05)),
                            child: Row(children: [
                              const Icon(Icons.map_rounded, color: kNeonPurple), const SizedBox(width: 12),
                              Expanded(child: Text("ดูพิกัดบนแผนที่: \n$lat, $lng", style: TextStyle(color: Colors.grey[300], fontSize: 13))),
                            ]),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    const Text("รายการโครงการ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text("${projectCards.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 16),

                if (projectCards.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("ไม่มีโปรเจกต์ย่อยในบิลนี้", style: TextStyle(color: Colors.grey))))
                else
                  ...projectCards,

                // 🌟 ส่วนแสดงรูปภาพ (เพิ่มใหม่ด้านล่างสุด)
                if (allImages.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Icon(Icons.photo_library_rounded, color: kNeonPurple, size: 24),
                      const SizedBox(width: 10),
                      const Text("รูปภาพแนบ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text("${allImages.length}", style: const TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120, // ความสูงของกรอบรูปภาพแนวนอน
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: allImages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showFullScreenImage(allImages[index]), // 🌟 แตะเพื่อดูรูปเต็มจอ
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120,
                            decoration: BoxDecoration(
                              color: kCardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                              image: DecorationImage(
                                image: NetworkImage(allImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_isLoadingCategories || _isSaving)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: kNeonPurple))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> pData, String category) {
    final String pId = pData['id'] ?? '';
    final bool isExpanded = _expandedProjectIds.contains(pId);
    final String pName = pData['project_name'] ?? '-';
    final String area = pData['area_sqm']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: kCardDark.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pName, 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4)
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(category, style: const TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 12), const SizedBox(width: 4), Text("$area ตร.ม.", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_isLoadingCategories) return; 
                            showDialog(
                              context: context, 
                              builder: (context) => EditProjectDialog(
                                projectData: pData, 
                                categories: _dynamicCategories, 
                                projectTypes: _projectTypes, // 🌟 ส่ง _projectTypes ลงไปที่ Dialog 
                                onSave: (updatedData) => _saveData(pId, updatedData)
                              )
                            );
                          }, 
                          icon: const Icon(Icons.edit_note_rounded, color: kNeonPurple, size: 24),
                          constraints: const BoxConstraints(), padding: const EdgeInsets.all(6),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (isExpanded) _expandedProjectIds.remove(pId);
                              else _expandedProjectIds.add(pId);
                            });
                          }, 
                          icon: Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kPremiumGold, size: 26),
                          constraints: const BoxConstraints(), padding: const EdgeInsets.all(6),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isExpanded)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_isLoadingCategories) return;
                  showDialog(
                    context: context, 
                    builder: (context) => EditProjectDialog(
                      projectData: pData, 
                      categories: _dynamicCategories, 
                      projectTypes: _projectTypes, // 🌟 ส่ง _projectTypes ลงไปที่ Dialog
                      onSave: (updatedData) => _saveData(pId, updatedData)
                    )
                  );
                },
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      
                      _buildCleanRole("Developer", pData['account_developer'], pData['contact_developer']),
                      _buildCleanRole("Architecture", pData['account_architecture'], pData['contact_architecture']),
                      _buildCleanRole("Interior", pData['account_interior'], pData['contact_interior']),
                      _buildCleanRole("Contractor", pData['account_contractor'], pData['contact_contractor']),
                      
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, color: Colors.grey[600], size: 14),
                          const SizedBox(width: 4),
                          Text("แตะที่นี่เพื่อแก้ไขข้อมูล", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCleanRole(String role, String? acc, String? con) {
    bool hasAcc = acc != null && acc.trim().isNotEmpty;
    bool hasCon = con != null && con.trim().isNotEmpty;
    
    String displayText = '-';
    
    if (hasAcc && hasCon) {
      displayText = '$acc ($con)'; 
    } else if (hasAcc) {
      displayText = acc;
    } else if (hasCon) {
      displayText = con;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100, 
            child: Text(role, style: TextStyle(color: Colors.grey[500], fontSize: 13))
          ),
          Expanded(
            child: Text(
              displayText, 
              style: TextStyle(
                color: displayText == '-' ? Colors.white24 : Colors.white, 
                fontSize: 14, 
                fontWeight: displayText == '-' ? FontWeight.normal : FontWeight.w500,
              )
            ),
          ),
        ],
      ),
    );
  }
}