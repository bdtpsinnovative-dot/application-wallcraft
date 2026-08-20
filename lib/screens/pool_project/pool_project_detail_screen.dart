//lib/screens/pool_project/pool_project_detail_screen.dart
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../services/api_service.dart';
import '../../constants.dart';
import 'components/edit_project_dialog.dart';
import 'components/edit_order_info_dialog.dart'; 
import 'components/project_history_modal.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  List<Map<String, dynamic>> _projectTypes = []; 
  bool _isUploadingImage = false;
  
  // 🌟 State สำหรับรูปภาพที่รออัปโหลด
  List<String> _pendingImages = [];

  final ImagePicker _picker = ImagePicker();

  String _relationName(dynamic relation) {
    if (relation is Map) {
      return relation['name']?.toString().trim() ?? '';
    }
    if (relation is List && relation.isNotEmpty && relation.first is Map) {
      return relation.first['name']?.toString().trim() ?? '';
    }
    return '';
  }

  String get _cacheKey => 'pending_images_${orderData['id']}';

  Future<void> _loadPendingImages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pendingImages = prefs.getStringList(_cacheKey) ?? [];
    });
  }

  Future<void> _savePendingImagesList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKey, _pendingImages);
  }

  Future<void> _showPickImageOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('เลือกจากแกลเลอรี', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('ถ่ายรูปใหม่', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() => _isUploadingImage = true);

        // 1. บีบอัดเป็น WebP
        final File file = File(image.path);
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final String targetPath = "${appDocDir.path}/pending_${orderData['id']}_${DateTime.now().millisecondsSinceEpoch}.webp";
        
        var result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, 
          targetPath,
          quality: 60,
          format: CompressFormat.webp, 
          minWidth: 1080,
          minHeight: 1080
        );

        if (result == null) throw Exception("Compress Failed");

        // 2. เก็บเข้า State และ SharedPreferences
        setState(() {
          _pendingImages.add(result.path);
        });
        await _savePendingImagesList();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('พักรูปภาพสำเร็จ กดปุ่ม "บันทึก" เพื่ออัปโหลด'), backgroundColor: kLimeGreen)
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _uploadPendingImages() async {
    if (_pendingImages.isEmpty) return;
    
    setState(() => _isUploadingImage = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("No token");

      int successCount = 0;
      List<String> failedImages = [];

      for (String imagePath in _pendingImages) {
        final File file = File(imagePath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);

        final body = jsonEncode({
          'order_id': orderData['id'],
          'order_item_project_id': (items.isNotEmpty && items[0]['order_item_projects'] != null && (items[0]['order_item_projects'] as List).isNotEmpty) ? items[0]['order_item_projects'][0]['id'] : null,
          'new_image_base64': base64Image,
        });

        final url = Uri.parse('${AppConfig.baseUrl}/poolprojects');
        final response = await ApiService.patch(url, body: body);

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          final String? newImageUrl = resData['new_image_url'];
          
          if (newImageUrl != null && items.isNotEmpty) {
            if (items[0]['images'] == null) {
               items[0]['images'] = [newImageUrl];
            } else if (items[0]['images'] is List) {
               (items[0]['images'] as List).add(newImageUrl);
            } else if (items[0]['images'] is String) {
               try {
                 final decoded = jsonDecode(items[0]['images']);
                 if (decoded is List) {
                   decoded.add(newImageUrl);
                   items[0]['images'] = decoded;
                 }
               } catch (_) {}
            }
          }
          successCount++;
          // ลบไฟล์ท้องถิ่นเมื่ออัปสำเร็จ
          try { await file.delete(); } catch (_) {}
        } else {
          failedImages.add(imagePath);
        }
      }

      setState(() {
        _pendingImages = failedImages;
      });
      await _savePendingImagesList();

      if (mounted) {
        if (failedImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปโหลดรูปภาพทั้งหมดสำเร็จ ✨'), backgroundColor: kLimeGreen));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปโหลดสำเร็จ $successCount รูป, ไม่สำเร็จ ${failedImages.length} รูป'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปโหลดไม่สำเร็จ: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (_pendingImages.isNotEmpty) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('รูปภาพยังไม่ถูกบันทึก', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'คุณมีรูปภาพที่พักไว้และยังไม่ได้อัปโหลด\nหากออกตอนนี้รูปจะถูกพักไว้ในเครื่องเท่านั้น\n\nต้องการออกหรือไม่?', 
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                        ),
                        child: const Text('ออกไปก่อน', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                          _uploadPendingImages();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLimeGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('บันทึกรูป', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      );
      return shouldPop ?? false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    orderData = widget.groupedOrderData['order_data'] ?? {};
    items = widget.groupedOrderData['order_items'] ?? [];
    
    _fetchCategories();
    _fetchProjectTypes(); 
    _loadPendingImages();
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
      final url = Uri.parse('${AppConfig.baseUrl}/project-types'); 
      
      debugPrint("Fetching from: $url");
      
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

  void _showFullScreenImage(int initialIndex, List<String> images) {
    final PageController pageController = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: pageController,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                  ),
                );
              },
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
          "project_type_id": updatedData['project_type_id'], 
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
                  p['project_type_id'] = updatedData['project_type_id']; 
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

Future<void> _saveOrderInfo(String newCustomerName, String newPhone, String newNote) async {
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
          "note": newNote, // 🌟 ยิง Note ไปพร้อมกันเลย
        })
      );

      if (response.statusCode == 200) {
        setState(() {
          orderData['customer_name'] = newCustomerName;
          orderData['phone'] = newPhone;
          // 🌟 อัปเดต Note ให้เปลี่ยนตามทันที
          for (var item in items) {
            item['note'] = newNote; 
          }
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตข้อมูลบิลสำเร็จ!'), backgroundColor: kLimeGreen));
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
    final orderCustomerTypeName = _relationName(orderData['customer_types']);
    final companyCustomerTypeName = _relationName(orderData['companies']?['customer_types']);
    final customerTypeName = orderCustomerTypeName.isNotEmpty
        ? orderCustomerTypeName
        : (companyCustomerTypeName.isNotEmpty ? companyCustomerTypeName : '-');
    final phoneNum = orderData['phone'] ?? '-';
    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
    
    String dateStr = '-';
    if (orderData['created_at'] != null) {
      final date = DateTime.parse(orderData['created_at']).toLocal();
      dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}";
    }

    // 🌟 ดึงข้อมูล Note
    String orderNote = '-';
    List<String> allNotes = [];
    for (var item in items) {
      if (item['note'] != null && item['note'].toString().trim().isNotEmpty) {
        allNotes.add(item['note'].toString().trim());
      }
    }
    if (allNotes.isNotEmpty) {
      orderNote = allNotes.toSet().join('\n\n'); // 🌟 เปลี่ยนการเชื่อมให้เว้นบรรทัด 1 ครั้งให้ดูสวยขึ้น
    }

    List<Widget> projectCards = [];
    List<String> allImages = [];

    for (var item in items) {
      final categoryName = item['product_categories']?['name'] ?? 'ไม่ระบุหมวดหมู่';
      final categoryId = (item['product_category_id'] ?? item['product_categories']?['id'])?.toString(); 
      final productProjects = item['order_item_projects'] as List? ?? [];
      for (var p in productProjects) {
        projectCards.add(_buildProjectCard(p, categoryName, categoryId)); // ✅ เติมเข้าไปเรียบร้อย!
      }

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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: kDarkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), 
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.pop(context);
              }
            }
          ),
          title: const Text("รายละเอียด Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), 
          centerTitle: true,
        // 🌟 ย้ายมาไว้ตรงนี้ครับนาย (อยู่ใน AppBar)
        actions: [
          if (orderData['admin_edits'] != null && (orderData['admin_edits'] as List).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded, color: kPremiumGold), 
              tooltip: "ดูประวัติการแก้ไข",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ProjectHistoryModal(
                    adminEdits: orderData['admin_edits'] as List<dynamic>,
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned(top: -50, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.2)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)))),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
                                  initialNote: orderNote, // 🌟 ส่งตัวแปร orderNote ที่ดึงไว้แล้วเข้าไป
                                  onSave: _saveOrderInfo, 
                                )
                              );
                            }, 
                            icon: const Icon(Icons.edit_note_rounded, color: kPremiumGold, size: 26),
                            tooltip: "แก้ไขข้อมูลบิล",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                      const SizedBox(height: 20), const Divider(color: Colors.white12), const SizedBox(height: 16),
                      _buildInfoRow("Customer", ownerName),
                      _buildInfoRow("Company", companyName),
                      _buildInfoRow("Customer Type", customerTypeName),
                      _buildInfoRow("Phone / Line", phoneNum),
                      _buildInfoRow("Sale Name", saleName),
                      _buildInfoRow("Date", dateStr),

                      // 🌟 เปลี่ยนมาใช้ฟังก์ชันที่สร้างขึ้นมาใหม่สำหรับ Note โดยเฉพาะ
                      _buildNoteBox("Note", orderNote), 

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

                const SizedBox(height: 30),
                Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: kNeonPurple, size: 24),
                    const SizedBox(width: 10),
                    const Text("รูปภาพแนบ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (allImages.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text("${allImages.length}", style: const TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold))),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120, 
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allImages.length + _pendingImages.length + 1,
                    itemBuilder: (context, index) {
                      if (index < allImages.length) {
                        return GestureDetector(
                          onTap: () => _showFullScreenImage(index, allImages), 
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
                      } else if (index < allImages.length + _pendingImages.length) {
                        final pendingIndex = index - allImages.length;
                        final pendingPath = _pendingImages[pendingIndex];
                        return Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: kCardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange, width: 2), // กรอบสีส้มให้รู้ว่ายังไม่ได้อัปโหลด
                                image: DecorationImage(
                                  image: FileImage(File(pendingPath)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 16,
                              child: GestureDetector(
                                onTap: () async {
                                  setState(() => _pendingImages.removeAt(pendingIndex));
                                  await _savePendingImagesList();
                                  try { await File(pendingPath).delete(); } catch (_) {}
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return GestureDetector(
                          onTap: _showPickImageOptions,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24), 
                            ),
                            child: const Center(
                              child: Icon(Icons.add, color: Colors.white54, size: 40), 
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_isLoadingCategories || _isSaving || _isUploadingImage)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: kNeonPurple))),
        ],
      ),
      floatingActionButton: _pendingImages.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: _uploadPendingImages,
            backgroundColor: kLimeGreen,
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.black),
            label: Text("บันทึก ${_pendingImages.length} รูป", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        : null,
    ));
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

  // 🌟 ฟังก์ชันจัดการ Note ฉบับปรับปรุง ให้กล่องข้อความกางเต็มจอ ไม่เหลือที่ว่างฝั่งซ้าย
  Widget _buildNoteBox(String title, String note) {
    if (note == '-' || note.trim().isEmpty) {
      return _buildInfoRow(title, "-");
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column( // 🌟 เปลี่ยนจาก Row เป็น Column เพื่อให้อยู่บน-ล่าง
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. หัวข้อ (คำว่า Note)
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 8), // เว้นระยะห่างนิดนึง
          
          // 2. กล่องข้อความ (กางเต็มความกว้าง)
          Container(
            width: double.infinity, // 🌟 บังคับให้กล่องกว้างเต็มพื้นที่
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(
              color: kNeonPurple.withOpacity(0.08), 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: kNeonPurple.withOpacity(0.3)), 
            ),
            child: Text(
              note,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14, 
                height: 1.6, 
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildProjectCard(Map<String, dynamic> pData, String category, String? categoryId) {
    final String pId = pData['id'] ?? '';
    final String pName = pData['project_name'] ?? '-';
    final String area = pData['area_sqm']?.toString() ?? '0';
    final String projectType = pData['project_types']?['name'] ?? '-';
    final String quarter = pData['queue_level']?.toString() ?? '-';
    final String projectYear = pData['project_year']?.toString() ?? '-';

    // 🌟 2. ประกอบร่าง! เอาข้อมูลเดิมมาเพิ่ม หมวดหมู่สินค้า เข้าไป
    Map<String, dynamic> dataForDialog = Map<String, dynamic>.from(pData);
    dataForDialog['product_category_id'] = categoryId;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: kCardDark.withOpacity(0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // ขยับเนื้อหาให้ชิดซ้ายขวามากขึ้น แต่คงความสูงไว้
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pName, 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4) // เพิ่มขนาดฟอนต์นิดนึง
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (_isLoadingCategories) return; 
                        showDialog(
                          context: context, 
                          builder: (context) => EditProjectDialog(
                            projectData: dataForDialog,
                            categories: _dynamicCategories, 
                            projectTypes: _projectTypes, 
                            onSave: (updatedData) => _saveData(pId, updatedData)
                          )
                        );
                      }, 
                      icon: const Icon(Icons.edit_note_rounded, color: kNeonPurple, size: 24),
                      constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 16), // เพิ่มช่องว่าง
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(category, style: const TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold))),
                    if (projectType != '-')
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(projectType, style: const TextStyle(color: kNeonPurple, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (quarter != '-')
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text("Q$quarter", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                    if (projectYear != '-')
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text("ค.ศ. $projectYear", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 12), const SizedBox(width: 4), Text("$area ตร.ม.", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))])),
                  ],
                ),
              ],
            ),
          ),
          
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_isLoadingCategories) return;
                showDialog(
                  context: context, 
                  builder: (context) => EditProjectDialog(
                    projectData: dataForDialog, 
                    categories: _dynamicCategories, 
                    projectTypes: _projectTypes, 
                    onSave: (updatedData) => _saveData(pId, updatedData)
                  )
                );
              },
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), // ชิดขอบซ้ายขวามากขึ้น
                child: Column(
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16), // เพิ่มช่องว่าง
                    
                    _buildCleanRole("Developer", pData['account_developer'], pData['contact_developer']),
                    _buildCleanRole("Architecture", pData['account_architecture'], pData['contact_architecture']),
                    _buildCleanRole("Interior", pData['account_interior'], pData['contact_interior']),
                    _buildCleanRole("Contractor", pData['account_contractor'], pData['contact_contractor']),
                    
                    const SizedBox(height: 4),
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
    
    // 🌟 ถ้าไม่มีข้อมูลทั้งสองช่อง ไม่ต้องแสดงเลย (ซ่อนไปเลย)
    if (!hasAcc && !hasCon) {
      return const SizedBox.shrink();
    }
    
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
