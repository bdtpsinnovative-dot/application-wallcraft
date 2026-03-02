import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/api_service.dart';
import '../../constants.dart';
import 'dart:convert';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolProjectDetailScreen extends StatefulWidget {
  final dynamic itemData;
  const PoolProjectDetailScreen({super.key, required this.itemData});

  @override
  State<PoolProjectDetailScreen> createState() => _PoolProjectDetailScreenState();
}

class _PoolProjectDetailScreenState extends State<PoolProjectDetailScreen> {
  late Map<String, dynamic> currentData;
  bool _isSaving = false;
  bool _isRefreshing = false; 
  bool _isRolesExpanded = false; 

  @override
  void initState() {
    super.initState();
    currentData = Map<String, dynamic>.from(widget.itemData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  // --- จุดที่แก้ไขครับพี่ ---
  Future<void> _openMap(double lat, double lng) async {
    // ใช้รูปแบบ URL มาตรฐานของ Google Maps ที่รับค่าพิกัด
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      // สั่งให้เปิดผ่านแอปภายนอก (Google Maps หรือ Browser)
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
  // -----------------------

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);

    try {
      final specificProject = currentData['specific_project_data'] ?? {};
      final String orderItemProjectId = specificProject['id'] ?? '';

      if (orderItemProjectId.isEmpty) return; 

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects?page=1&limit=50');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> rawData = result is List ? result : (result['data'] ?? []);
        
        final updatedItem = rawData.firstWhere(
          (item) {
            final oip = item['order_item_projects'];
            if (oip != null && oip is List) {
              return oip.any((p) => p['id'] == orderItemProjectId);
            }
            return false;
          },
          orElse: () => null,
        );

        if (updatedItem != null) {
          final oip = (updatedItem['order_item_projects'] as List).firstWhere((p) => p['id'] == orderItemProjectId);
          
          if (mounted) {
            setState(() {
              currentData = Map<String, dynamic>.from(updatedItem);
              currentData['display_project_name'] = oip['projects']?['project_name'] ?? 'ไม่มีชื่อโครงการ';
              currentData['specific_project_data'] = oip;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โหลดข้อมูลใหม่ไม่สำเร็จ'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showEditDialog() {
    final orderData = currentData['orders'] ?? {};
    final specificProject = currentData['specific_project_data'] ?? {};

    TextEditingController ownerCtrl = TextEditingController(text: orderData['customer_name'] ?? '');
    TextEditingController projectCtrl = TextEditingController(text: currentData['display_project_name'] ?? '');

    TextEditingController devCtrl = TextEditingController(text: specificProject['developer_name'] ?? '');
    TextEditingController designCtrl = TextEditingController(text: specificProject['designer_name'] ?? '');
    TextEditingController archCtrl = TextEditingController(text: specificProject['architect_name'] ?? '');
    TextEditingController interiorCtrl = TextEditingController(text: specificProject['interior_name'] ?? '');
    TextEditingController builderCtrl = TextEditingController(text: specificProject['home_builder_name'] ?? '');
    TextEditingController turnkeyCtrl = TextEditingController(text: specificProject['turnkey_th_name'] ?? '');
    TextEditingController inhouseCtrl = TextEditingController(text: specificProject['inhouse_designer_name'] ?? '');

    bool isDialogExpanded = false; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kCardDark,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: kNeonPurple.withOpacity(0.5))),
              title: const Text("แก้ไขข้อมูล", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.55, 
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      _buildLargeTextField(controller: ownerCtrl, label: "Owner (เจ้าของโครงการ)", icon: Icons.person_outline_rounded),
                      const SizedBox(height: 15),
                      _buildLargeTextField(controller: projectCtrl, label: "Project name", icon: Icons.business_center_outlined),
                      const SizedBox(height: 25), 
                      InkWell(
                        onTap: () => setStateDialog(() => isDialogExpanded = !isDialogExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("รายชื่อผู้เกี่ยวข้อง 7 บทบาท", style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, fontSize: 14)),
                              Icon(isDialogExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kNeonPurple, size: 24),
                            ],
                          ),
                        ),
                      ),
                      if (isDialogExpanded) ...[
                        const SizedBox(height: 10),
                        _buildLargeTextField(controller: devCtrl, label: "Developer", icon: Icons.business_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: designCtrl, label: "Designer", icon: Icons.brush_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: archCtrl, label: "Architect", icon: Icons.architecture_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: interiorCtrl, label: "Interior", icon: Icons.chair_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: builderCtrl, label: "Home Builder", icon: Icons.foundation_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: turnkeyCtrl, label: "Turnkey-TH", icon: Icons.handyman_rounded),
                        const SizedBox(height: 15),
                        _buildLargeTextField(controller: inhouseCtrl, label: "Inhouse Designer", icon: Icons.badge_rounded),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kNeonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  onPressed: () async {
                    Navigator.pop(context); 
                    _saveData(
                      ownerCtrl.text, projectCtrl.text,
                      devCtrl.text, designCtrl.text, archCtrl.text,
                      interiorCtrl.text, builderCtrl.text, turnkeyCtrl.text, inhouseCtrl.text
                    ); 
                  },
                  child: const Text("บันทึก"),
                )
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildLargeTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: Colors.grey[400]), prefixIcon: Icon(icon, color: kNeonPurple),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[600]!)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kNeonPurple)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Future<void> _saveData(String newOwner, String newProject, String dev, String design, String arch, String interior, String builder, String turnkey, String inhouse) async {
    setState(() => _isSaving = true);

    try {
      final orderData = currentData['orders'] ?? {};
      final specificProject = currentData['specific_project_data'] ?? {};

      final String orderId = orderData['id'] ?? '';
      final String projectId = specificProject['projects']?['id'] ?? '';
      final String orderItemProjectId = specificProject['id'] ?? ''; 

      if (orderId.isEmpty || orderItemProjectId.isEmpty) throw Exception("ไม่พบ ID สำหรับการอัปเดต");

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects');
      final response = await ApiService.patch(
        url, 
        body: jsonEncode({
          "order_id": orderId,
          "project_id": projectId,
          "order_item_project_id": orderItemProjectId,
          "customer_name": newOwner,
          "project_name": newProject,
          "developer_name": dev,
          "designer_name": design,
          "architect_name": arch,
          "interior_name": interior,
          "home_builder_name": builder,
          "turnkey_th_name": turnkey,
          "inhouse_designer_name": inhouse
        })
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          currentData['orders']['customer_name'] = newOwner;
          currentData['display_project_name'] = newProject;
          
          currentData['specific_project_data']['developer_name'] = dev;
          currentData['specific_project_data']['designer_name'] = design;
          currentData['specific_project_data']['architect_name'] = arch;
          currentData['specific_project_data']['interior_name'] = interior;
          currentData['specific_project_data']['home_builder_name'] = builder;
          currentData['specific_project_data']['turnkey_th_name'] = turnkey;
          currentData['specific_project_data']['inhouse_designer_name'] = inhouse;
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย!'), backgroundColor: kLimeGreen));
      } else {
        throw Exception("Failed to save: ${response.body}");
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderData = currentData['orders'] ?? {};
    final specificProject = currentData['specific_project_data'] ?? {}; 

    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
    String dateStr = '-';
    if (currentData['created_at'] != null) {
      final date = DateTime.parse(currentData['created_at']).toLocal();
      dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}";
    }

    final ownerName = orderData['customer_name'] ?? 'ไม่ระบุชื่อลูกค้า';
    String projectName = currentData['display_project_name'] ?? '-';
    final productName = currentData['product_categories']?['name'] ?? 'ไม่ระบุรายการสินค้า';
    
    final areaSqm = specificProject['area_sqm'] ?? 0;
    
    final devName = specificProject['developer_name'] ?? '-';
    final designName = specificProject['designer_name'] ?? '-';
    final archName = specificProject['architect_name'] ?? '-';
    final intName = specificProject['interior_name'] ?? '-';
    final builderName = specificProject['home_builder_name'] ?? '-';
    final turnkeyName = specificProject['turnkey_th_name'] ?? '-';
    final inhouseName = specificProject['inhouse_designer_name'] ?? '-';

    final auditLog = orderData['audit_log'];
    double? lat;
    double? lng;
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
        title: const Text("รายละเอียดโครงการ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), 
        centerTitle: true,
        actions: [
          _isRefreshing 
            ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kNeonPurple, strokeWidth: 2)))
            : IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _refreshData,
                tooltip: "รีเฟรชข้อมูล",
              ),
        ],
      ),
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
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kCardDark, borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8), 
                            decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.business_rounded, color: kNeonPurple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0), 
                              child: Text(projectName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), const Divider(color: Colors.white12), const SizedBox(height: 16),
                      
                      _buildDetailRow("Sale name", saleName),
                      _buildDetailRow("Date", dateStr),
                      _buildDetailRow("รายการสินค้า (Product)", productName),
                      _buildDetailRow("Area (พื้นที่)", "$areaSqm sq.m."), 
                      _buildDetailRow("Owner (เจ้าของโครงการ)", ownerName),

                      if (lat != null && lng != null) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            const Icon(Icons.security_rounded, color: kNeonPurple, size: 16),
                            const SizedBox(width: 6),
                            const Text("ข้อมูลความปลอดภัย (Audit Log)", style: TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (deviceName != null && deviceName.trim().isNotEmpty)
                          _buildDetailRow("อุปกรณ์ที่บันทึกข้อมูล", deviceName),
                        
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [kNeonPurple.withOpacity(0.15), Colors.transparent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: kNeonPurple.withOpacity(0.3), width: 1),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openMap(lat!, lng!),
                              splashColor: kNeonPurple.withOpacity(0.2),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: kNeonPurple.withOpacity(0.2), blurRadius: 8)],
                                      ),
                                      child: const Icon(Icons.map_rounded, color: kNeonPurple, size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("เปิดดูตำแหน่งบนแผนที่", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.gps_fixed_rounded, size: 12, color: Colors.grey[400]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}", 
                                                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'monospace', letterSpacing: 0.5),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12),
                      ],

                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => setState(() => _isRolesExpanded = !_isRolesExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("ดูรายชื่อผู้เกี่ยวข้อง 7 บทบาท", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 13)),
                              Icon(_isRolesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey[400], size: 20),
                            ],
                          ),
                        ),
                      ),

                      if (_isRolesExpanded) ...[
                        const SizedBox(height: 15),
                        _buildDetailRow("Developer", devName),
                        _buildDetailRow("Designer", designName),
                        _buildDetailRow("Architect", archName),
                        _buildDetailRow("Interior", intName),
                        _buildDetailRow("Home Builder", builderName),
                        _buildDetailRow("Turnkey-TH", turnkeyName),
                        _buildDetailRow("Inhouse Designer", inhouseName),
                      ],
                    ],
                  ),
                ),
                
                Positioned(
                  top: -16, right: -10,
                  child: _isSaving
                      ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kNeonPurple, strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: kNeonPurple, size: 28),
                          onPressed: _showEditDialog, tooltip: "แก้ไขข้อมูล", padding: const EdgeInsets.all(12), 
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}