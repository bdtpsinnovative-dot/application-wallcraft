// lib/screens/orders/purchase_order_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart'; 
import 'package:geolocator/geolocator.dart'; 
import 'package:device_info_plus/device_info_plus.dart'; 
import 'dart:async'; 
import '../../constants.dart';
import '../../services/api_service.dart';
import 'order_history_screen.dart';

import 'components/product_item_card.dart';
import 'components/add_project_dialog.dart'; 
import 'components/customer_info_card.dart'; 
import 'components/project_select_card.dart'; 

const Color kDarkBg = Color(0xFF000000); 
const Color kGlowPurple = Color(0xFF111111); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kPrimaryColor = Color(0xFFFFFFFF); 

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _companyDropdownKey = GlobalKey<DropdownSearchState<dynamic>>();
  bool _startAnimation = false;

  String? _selectedCustomerType;
  String? _selectedCompany; 
  
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController(); 
  
  List<dynamic> _selectedProjects = []; 
  List<ProductItem> _orderItems = [ProductItem()];
  
  List<dynamic> _customerTypes = [];
  List<dynamic> _productCategories = [];
  List<dynamic> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _startAnimation = true);
    });
  }

  Future<void> _fetchDropdownData() async {
    final url = Uri.parse('${AppConfig.baseUrl}/orders');
    try {
      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _customerTypes = data['customer_types'] ?? [];
          _productCategories = data['product_categories'] ?? [];
          _projects = data['projects'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<List<dynamic>> _getCompanies(String filter) async {
    if (_selectedCustomerType == null) return [];
    final url = Uri.parse('${AppConfig.baseUrl}/companies?type_id=$_selectedCustomerType&q=$filter');
    try {
      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    return []; 
  }

  Future<bool> _createNewProject(String projectName) async {
    final url = Uri.parse('${AppConfig.baseUrl}/projects');
    try {
      final response = await ApiService.post(
        url,
        body: jsonEncode({'project_name': projectName}),
      );
      if (response.statusCode == 200) {
        final newProject = jsonDecode(response.body);
        setState(() {
          _projects.add(newProject);
          _selectedProjects = List.from(_selectedProjects)..add(newProject);
        });
        return true; 
      }
    } catch (e) { 
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); 
    }
    return false; 
  }

  // 😈 Helper แจ้งเตือนเรื่อง GPS
  void _showSimpleDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("ตกลง", style: TextStyle(color: kPrimaryColor))
          )
        ],
      ),
    );
  }

  // 😈 ฟังก์ชันสายตรวจ: สแกนหาพิกัดที่แม่นยำที่สุด (Radar Algorithm)
  Future<Map<String, dynamic>?> _getAuditData() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. เช็คว่าเปิดสวิตช์ GPS ในเครื่องหรือยัง?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showSimpleDialog("กรุณาเปิด GPS", "คุณต้องเปิดใช้งานตำแหน่งที่ตั้ง (Location) ก่อนทำการบันทึกข้อมูลครับ");
      return null;
    }

    // 2. เช็คสิทธิ์ (Permission)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showSimpleDialog("สิทธิ์ถูกปฏิเสธ", "แอปต้องการสิทธิ์เข้าถึงตำแหน่งเพื่อยืนยันจุดที่บันทึกข้อมูลครับ");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showSimpleDialog("สิทธิ์ถูกปิดกั้นถาวร", "กรุณาเข้าไปเปิดสิทธิ์ตำแหน่ง (Location) ในหน้าตั้งค่าของเครื่องครับ");
      return null;
    }

    // 3. 🎯 เริ่มกระบวนการ "เปิดเรดาร์สแกนหาพิกัดที่ดีที่สุด"
    Position? bestPosition;
    StreamSubscription<Position>? positionStream;
    
    try {
      // เปิดสตรีมดึงพิกัดรัวๆ แบบความแม่นยำสูงสุด (Best)
      positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, // บังคับใช้ชิป GPS ทำงานเต็มกำลัง
          distanceFilter: 0,
        ),
      ).listen((Position position) {
        // อัปเดตพิกัดที่ดีที่สุด (ยิ่งค่า accuracy น้อย ยิ่งแม่นยำ)
        if (bestPosition == null || position.accuracy < bestPosition!.accuracy) {
          bestPosition = position;
        }
      });

      // หน่วงเวลาให้เรดาร์ทำงาน 5 วินาที (แบ่งเช็คทุกๆ 0.1 วินาที)
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        
        // ⚡️ ทางลัด: ถ้าเจอพิกัดที่ความคลาดเคลื่อน <= 15 เมตร (โคตรแม่น) ให้เบรกเลย ไม่ต้องรอครบ 5 วิ
        if (bestPosition != null && bestPosition!.accuracy <= 15.0) {
          break; 
        }
      }

      // ปิดสตรีมเรดาร์เมื่อเสร็จสิ้น
      await positionStream.cancel();

      // ถ้าดึงไม่ได้เลยจริงๆ ให้ใช้ท่าไม้ตายดึงครั้งเดียวเผื่อฟลุ๊ค
      bestPosition ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3)
      );

      // 🚨 เช็คคนโกง: ตรวจจับแอปจำลองพิกัด (Fake GPS)
      if (bestPosition!.isMocked) {
        if (mounted) _showSimpleDialog("ตรวจพบการทุจริต", "กรุณาปิดแอปจำลองตำแหน่ง (Fake GPS) ก่อนบันทึกข้อมูลครับ");
        return null; // บล็อกไม่ให้บันทึก
      }

      // 🚨 เช็คคุณภาพพิกัด: ถ้าคลาดเคลื่อนเกิน 150 เมตร (มักจะเกิดตอนอยู่ในตึกทึบ)
      if (bestPosition!.accuracy > 150.0) {
        if (mounted) _showSimpleDialog("สัญญาณ GPS อ่อนมาก", "ความแม่นยำต่ำเกินไป กรุณาเดินออกไปใกล้หน้าต่างหรือที่โล่งเพื่อบันทึกครับ");
        return null; // บล็อกให้ไปหาที่โล่งๆ ก่อน
      }

      // 4. ดึงข้อมูลเครื่องมือถือ
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          "os": "Android",
          "brand": androidInfo.brand,
          "model": androidInfo.model,
          "version": androidInfo.version.release
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          "os": "iOS",
          "brand": "Apple",
          "model": iosInfo.utsname.machine,
          "version": iosInfo.systemVersion
        };
      }

      return {
        "location": {
          "lat": bestPosition!.latitude,
          "lng": bestPosition!.longitude,
          "accuracy": bestPosition!.accuracy, // เก็บความแม่นยำลงฐานข้อมูลให้พี่ดูด้วย
          "captured_at": DateTime.now().toIso8601String()
        },
        "device": deviceData
      };

    } catch (e) {
      if (positionStream != null) await positionStream.cancel();
      debugPrint("Audit Log Error: $e");
      if (mounted) _showSimpleDialog("เกิดข้อผิดพลาด", "ไม่สามารถดึงตำแหน่งได้ กรุณาลองใหม่อีกครั้ง");
      return null;
    }
  }

  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus(); 
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    // 🚨 1. เรียกสายตรวจทำงาน! ถ้าไม่ให้พิกัด จะหยุดทำรายการทันที
    final auditData = await _getAuditData();
    if (auditData == null) {
      setState(() => _isLoading = false);
      return; // 🛑 เด้งออก ไม่ยิง API
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('user_id'); 
      
      List<Map<String, dynamic>> itemsPayload = [];
      for (var item in _orderItems) {
        List<String> itemImagesBase64 = [];
        for (var f in item.itemImages) {
           itemImagesBase64.add(base64Encode(await f.readAsBytes()));
        }
        
        List<Map<String, dynamic>> projectUsages = [];
        for (var projectId in item.selectedProjectIds) {
           String areaText = item.projectAreaControllers[projectId]?.text ?? "0";
           projectUsages.add({'project_id': projectId, 'area_sqm': areaText});
        }

        itemsPayload.add({
          'product_category_id': item.categoryId,
          'interest_level': item.interestLevel,
          'note': item.noteCtrl.text,
          'project_usage': projectUsages,
          'images': itemImagesBase64,
        });
      }

      final response = await ApiService.post(
        Uri.parse('${AppConfig.baseUrl}/orders'),
        body: jsonEncode({
          'token': token,
          'user_id': userId,
          'customer_type_id': _selectedCustomerType, 
          'company_id': _selectedCompany, 
          'customer_name': _nameCtrl.text,
          'phone': _contactCtrl.text,
          'items': itemsPayload,
          'audit_log': auditData, // 📦 ส่งข้อมูลสายตรวจแนบไปด้วย!
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) { 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [Icon(Icons.check_circle, color: kCardDark), SizedBox(width: 8), Text('บันทึกข้อมูลสำเร็จ', style: TextStyle(color: kCardDark, fontWeight: FontWeight.bold))]), 
              backgroundColor: kPrimaryColor
            )
          );
          
          setState(() {
              _nameCtrl.clear();
              _contactCtrl.clear();
              _selectedCustomerType = null; 
              _selectedCompany = null;      
              _selectedProjects = [];       
              _orderItems = [ProductItem()]; 
          });
        }
      } else { 
        throw "เกิดข้อผิดพลาดในการบันทึกข้อมูล"; 
      }
    } catch (e) { 
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white), 
                const SizedBox(width: 8), 
                Expanded(child: Text(e.toString(), style: const TextStyle(color: Colors.white)))
              ]
            ), 
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        ); 
      }
    } finally { 
      if(mounted) setState(() => _isLoading = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), 
        child: Scaffold(
          backgroundColor: kDarkBg,
          body: Stack(
            children: [
              _isLoading 
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor)) 
                : Column(
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                
                                // 🌟 ส่วนของการ์ดข้อมูลลูกค้า
                                _buildAnimatedCard(
                                  index: 0,
                                  child: CustomerInfoCard(
                                    customerTypes: _customerTypes,
                                    selectedCustomerType: _selectedCustomerType,
                                    companyDropdownKey: _companyDropdownKey,
                                    getCompanies: _getCompanies,
                                    selectedCompany: _selectedCompany,
                                    nameCtrl: _nameCtrl,
                                    contactCtrl: _contactCtrl,
                                    onCustomerTypeChanged: (val) {
                                      setState(() {
                                        _selectedCustomerType = val;
                                        _selectedCompany = null;
                                        _companyDropdownKey.currentState?.clear();
                                      });
                                    },
                                    onCompanyChanged: (val) {
                                      setState(() {
                                        _selectedCompany = val; 
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // 🌟 การ์ดโครงการ
                                _buildAnimatedCard(
                                  index: 1,
                                  child: ProjectSelectCard(
                                    projects: _projects,
                                    selectedProjects: _selectedProjects,
                                    onProjectsChanged: (val) => setState(() => _selectedProjects = val),
                                    onAddProject: () {
                                      FocusScope.of(context).unfocus();
                                      _showAddProjectDialog();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // 🌟 การ์ดสินค้า
                                _buildAnimatedCard(
                                  index: 2,
                                  child: _buildSectionCard(
                                    title: "รายละเอียดสินค้า",
                                    icon: Icons.inventory_2_rounded,
                                    padding: 5,
                                    content: [
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _orderItems.length,
                                        separatorBuilder: (_, __) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          child: Divider(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        itemBuilder: (ctx, index) => ProductItemCard(
                                          index: index,
                                          item: _orderItems[index],
                                          productCategories: _productCategories,
                                          projects: _selectedProjects,
                                          onDelete: () => setState(() => _orderItems.removeAt(index)),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            FocusScope.of(context).unfocus(); 
                                            setState(() => _orderItems.add(ProductItem()));
                                          },
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: kPrimaryColor.withOpacity(0.5), width: 1.5),
                                              borderRadius: BorderRadius.circular(16),
                                              color: kPrimaryColor.withOpacity(0.05),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.add_circle_rounded, color: kPrimaryColor),
                                                SizedBox(width: 8),
                                                Text("เพิ่มรายการสินค้า", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryColor)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // 🎬 ปุ่ม Submit
                                _buildAnimatedCard(
                                  index: 3,
                                  child: ElevatedButton(
                                    onPressed: _submitOrder,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      backgroundColor: kPrimaryColor, 
                                    ),
                                    child: const Center(
                                      child: Text("บันทึก", style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
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

  // ✨ Helpers
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      color: kDarkBg.withOpacity(0.95), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          ),
          const Text("New Record", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen())),
            child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.history_rounded, color: Colors.white, size: 24)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: _startAnimation ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600 + (index * 150)),
        transform: Matrix4.translationValues(0, _startAnimation ? 0 : 50, 0),
        child: child,
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> content, double padding = 24}) {
    return Container(
      width: double.infinity, padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: kPrimaryColor, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
          ]),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.white.withOpacity(0.1))),
          ...content,
        ],
      ),
    );
  }

void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddProjectDialog(
        allProjects: _projects, 
        // ✅ เพิ่ม onSelect เข้าไปเพื่อให้ครบตามที่ Widget ต้องการ
        onSelect: (selectedProject) {
          setState(() {
            // โค้ดสำหรับเพิ่มโปรเจกต์ที่เลือกเข้าไปในรายการ (ปรับแก้ได้ตามโครงสร้างข้อมูลจริง)
            if (!_selectedProjects.contains(selectedProject)) {
              _selectedProjects = List.from(_selectedProjects)..add(selectedProject);
            }
          });
        },
        onSaveNew: (name) async {
          return await _createNewProject(name);
        },
      ),
    );
  }
} // ✅ อย่าลืมเติมปีกกาปิดตัวนี้! มันคือตัวปิดของ class _PurchaseOrderScreenState