import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

// 🎨 Palette สี
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);
const Color kLimeGreen = Color(0xFFD2E862);

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  // 1. ตัวแปรเก็บข้อมูลหลัก
  List<dynamic> _customerTypes = [];
  String? _selectedCustomerType;
  Map<String, dynamic>? _selectedCompany; 
  
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final companyDropdownKey = GlobalKey<DropdownSearchState<dynamic>>();

  // 🚀 โมดูล 1: เพิ่มบริษัท (เด้งกลางจอ AlertDialog)
  void _showAddCompanyDialog() {
    String? tempTypeId = _selectedCustomerType; 
    final companyNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) => AlertDialog(
          backgroundColor: kCardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("เพิ่มบริษัทใหม่", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔽 เลือกประเภทในนี้เลย (กลางจอตามถนัด)
              DropdownButtonFormField<String>(
                value: tempTypeId,
                decoration: _inputDecoration("เลือกประเภทลูกค้า (ถ้ามี)", Icons.category_rounded),
                dropdownColor: kCardDark,
                style: const TextStyle(color: Colors.white),
                items: _customerTypes.map((item) => DropdownMenuItem<String>(
                  value: item['id'].toString(), 
                  child: Text(item['name'], style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (val) => setDiaState(() => tempTypeId = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("ชื่อบริษัท *", Icons.business_rounded),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก", style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                if (companyNameCtrl.text.isNotEmpty) {
                  _addNewCompany(companyNameCtrl.text, tempTypeId); 
                  Navigator.pop(ctx);
                }
              },
              child: const Text("บันทึก", style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 โมดูล 2: เพิ่มประเภทลูกค้าใหม่ (เด้งกลางจอ AlertDialog)
  void _showAddCustomerTypeDialog() {
    final typeNameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("เพิ่มประเภทลูกค้าใหม่", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: typeNameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration("ชื่อประเภทลูกค้า *", Icons.category_rounded),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              if (typeNameCtrl.text.isNotEmpty) {
                _addNewCustomerType(typeNameCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("บันทึก", style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🛠️ API 1: บันทึกบริษัทใหม่
  Future<void> _addNewCompany(String name, String? typeId) async {
    // 🌟 นายเปลี่ยน URL API ตรงนี้ให้เป็นของนายนะครับ
    final url = Uri.parse('https://your-api-url.com/api/v1/companies'); 
    final response = await http.post(
      url, 
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'customer_type_id': typeId}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final newComp = jsonDecode(response.body);
      setState(() {
        _selectedCompany = newComp; // 🌟 เซฟเป็น Map ทั้งก้อน
        if (typeId != null) _selectedCustomerType = typeId;
      });
      // ✅ ใช้ changeSelectedItem สำหรับเวอร์ชันใหม่ของ DropdownSearch
      companyDropdownKey.currentState?.changeSelectedItem(newComp);
    }
  }

  // 🛠️ API 2: บันทึกประเภทลูกค้าใหม่
  Future<void> _addNewCustomerType(String name) async {
    final url = Uri.parse('https://your-api-url.com/api/v1/customer-types');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final newType = jsonDecode(response.body);
      setState(() {
        _customerTypes.add(newType); 
        _selectedCustomerType = newType['id'].toString(); // เลือกให้ทันทีในหน้าหลัก
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: CustomerInfoCard(
          customerTypes: _customerTypes,
          selectedCustomerType: _selectedCustomerType,
          companyDropdownKey: companyDropdownKey,
          getCompanies: (filter) async => [], // 🌟 ใส่ฟังก์ชันดึงข้อมูลบริษัทของนายตรงนี้
          selectedCompany: _selectedCompany, // 🌟 ส่งค่า Map ไปให้ Widget
          nameCtrl: nameCtrl,
          contactCtrl: contactCtrl,
          onAddCustomerType: _showAddCustomerTypeDialog, // 🌟 ปุ่มบวกประเภทลูกค้า (กลางจอ)
          onAddCompany: _showAddCompanyDialog, // 🌟 ปุ่มบวกบริษัท (กลางจอ)
          onCustomerTypeChanged: (val) {
            setState(() {
              _selectedCustomerType = val;
              _selectedCompany = null;
              companyDropdownKey.currentState?.clear();
            });
          },
          onCompanyChanged: (val) {
            setState(() {
              _selectedCompany = val; 
              if (val != null && val['customer_type_id'] != null) {
                _selectedCustomerType = val['customer_type_id'].toString();
              }
            });
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// 🛠️ Widget CustomerInfoCard (ฉบับรองรับบริษัท 1,000+ ชื่อ พร้อมช่องค้นหา)
// -----------------------------------------------------------------------
class CustomerInfoCard extends StatelessWidget {
  final List<dynamic> customerTypes;
  final String? selectedCustomerType;
  final Function(String?) onCustomerTypeChanged;
  final GlobalKey<DropdownSearchState<dynamic>> companyDropdownKey;
  final Future<List<dynamic>> Function(String) getCompanies;
  final Map<String, dynamic>? selectedCompany; 
  final Function(Map<String, dynamic>?) onCompanyChanged;
  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final VoidCallback onAddCustomerType;
  final VoidCallback onAddCompany;

  const CustomerInfoCard({
    super.key, required this.customerTypes, this.selectedCustomerType, required this.onCustomerTypeChanged,
    required this.companyDropdownKey, required this.getCompanies, this.selectedCompany,
    required this.onCompanyChanged, required this.nameCtrl, required this.contactCtrl,
    required this.onAddCustomerType, required this.onAddCompany,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_pin_rounded, color: kPrimaryColor, size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Text("ข้อมูลการติดต่อ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: DropdownSearch<dynamic>(
                  key: companyDropdownKey,
                  items: (filter, loadProps) => getCompanies(filter), 
                  itemAsString: (item) => item['name'] ?? '',
                  selectedItem: selectedCompany,
                  onChanged: (val) => onCompanyChanged(val),
                  compareFn: (i1, i2) => i1?['id'] == i2?['id'],
                  decoratorProps: DropDownDecoratorProps(decoration: _inputDecoration("ค้นหาชื่อบริษัท...", Icons.business_rounded)),
                  popupProps: PopupProps.menu(
                    showSearchBox: true, // 🌟 ช่องค้นหาสำหรับบริษัทจำนวนมาก
                    menuProps: const MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.all(Radius.circular(20))),
                    searchFieldProps: TextFieldProps(
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration("พิมพ์ชื่อบริษัทเพื่อค้นหา...", Icons.search),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildAddBtn(onAddCompany),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: customerTypes.any((item) => item['id'].toString() == selectedCustomerType) ? selectedCustomerType : null,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kPrimaryColor, size: 28),
                  decoration: _inputDecoration("ประเภทลูกค้า (ระบุหรือไม่ก็ได้)", Icons.category_rounded),
                  dropdownColor: kCardDark,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: customerTypes.map((item) => DropdownMenuItem<String>(
                    value: item['id'].toString(), 
                    child: Text(item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                  )).toList(),
                  onChanged: onCustomerTypeChanged,
                ),
              ),
              const SizedBox(width: 12),
              _buildAddBtn(onAddCustomerType),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("ชื่อลูกค้า", Icons.badge_rounded)),
          const SizedBox(height: 16),
          TextFormField(controller: contactCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("เบอร์โทรศัพท์", Icons.phone_iphone_rounded)),
        ],
      ),
    );
  }

  Widget _buildAddBtn(VoidCallback onTap) {
    return Container(
      height: 55, width: 55,
      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: kPrimaryColor.withOpacity(0.3))),
      child: IconButton(icon: const Icon(Icons.add_rounded, color: kPrimaryColor), onPressed: onTap),
    );
  }
}

// 🎨 Helper Decoration
InputDecoration _inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint, hintStyle: TextStyle(fontSize: 15, color: Colors.grey[600]),
    prefixIcon: Icon(icon, size: 22, color: kPrimaryColor),
    filled: true, fillColor: kDarkBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
  );
}