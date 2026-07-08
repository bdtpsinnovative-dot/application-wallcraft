import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../services/api_service.dart';
import '../../../constants.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107);
const Color kNeonPurple = Color(0xFFB52BFF);
const Color kLimeGreen = Color(0xFFD2E862);

class EditProjectDialog extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> projectTypes;
  final Future<void> Function(Map<String, dynamic> updatedData) onSave;

  const EditProjectDialog({
    super.key,
    required this.projectData,
    required this.categories,
    required this.projectTypes,
    required this.onSave,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  late TextEditingController projectCtrl;
  late TextEditingController areaCtrl;
  String? selectedCategoryId;
  String? selectedProjectTypeId;

  late TextEditingController accDevCtrl;
  late TextEditingController conDevCtrl;
  late TextEditingController accArchCtrl;
  late TextEditingController conArchCtrl;
  late TextEditingController accIntCtrl;
  late TextEditingController conIntCtrl;
  late TextEditingController accContCtrl;
  late TextEditingController conContCtrl;

  bool isDevExpanded = false;
  bool isArchExpanded = false;
  List<String> activeRoles = [];
  final List<String> allRoles = [
    "Developer",
    "Architecture",
    "Interior",
    "Contractor",
  ];
  List<dynamic> _customerTypes = [];

  final GlobalKey<DropdownSearchState<dynamic>> searchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchCustomerTypes();
    final p = widget.projectData;
    String pName = p['project_name'] ?? 'ไม่มีชื่อโครงการ';

    projectCtrl = TextEditingController(
      text: pName == 'ไม่มีชื่อโครงการ' ? '' : pName,
    );
    areaCtrl = TextEditingController(text: p['area_sqm']?.toString() ?? '');

    selectedCategoryId = p['product_category_id']?.toString();
    if (selectedCategoryId != null &&
        !widget.categories.any(
          (c) => c['id'].toString() == selectedCategoryId,
        )) {
      selectedCategoryId = null;
    }

    selectedProjectTypeId = p['project_type_id']?.toString();
    if (selectedProjectTypeId != null &&
        !widget.projectTypes.any(
          (t) => t['id'].toString() == selectedProjectTypeId,
        )) {
      selectedProjectTypeId = null;
    }

    accDevCtrl = TextEditingController(text: p['account_developer'] ?? '');
    conDevCtrl = TextEditingController(text: p['contact_developer'] ?? '');
    accArchCtrl = TextEditingController(text: p['account_architecture'] ?? '');
    conArchCtrl = TextEditingController(text: p['contact_architecture'] ?? '');
    accIntCtrl = TextEditingController(text: p['account_interior'] ?? '');
    conIntCtrl = TextEditingController(text: p['contact_interior'] ?? '');
    accContCtrl = TextEditingController(text: p['account_contractor'] ?? '');
    conContCtrl = TextEditingController(text: p['contact_contractor'] ?? '');

    // 🌟 Check active roles
    if (accDevCtrl.text.isNotEmpty || conDevCtrl.text.isNotEmpty)
      activeRoles.add("Developer");
    if (accArchCtrl.text.isNotEmpty || conArchCtrl.text.isNotEmpty)
      activeRoles.add("Architecture");
    if (accIntCtrl.text.isNotEmpty || conIntCtrl.text.isNotEmpty)
      activeRoles.add("Interior");
    if (accContCtrl.text.isNotEmpty || conContCtrl.text.isNotEmpty)
      activeRoles.add("Contractor");
  }

  Future<void> _fetchCustomerTypes() async {
    try {
      final res = await ApiService.get(
        Uri.parse('${AppConfig.baseUrl}/orders'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _customerTypes = data['customer_types'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching customer types: $e");
    }
  }

  Future<List<dynamic>> _getCompanies(String filter) async {
    final url = Uri.parse('${AppConfig.baseUrl}/companies?q=$filter');
    try {
      final response = await ApiService.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Error searching companies: $e");
    }
    return [];
  }

  void _onCompanySelected(dynamic company) {
    if (company == null) return;

    String roleName = "Unknown";
    if (company['customer_types'] != null &&
        company['customer_types']['name'] != null) {
      roleName = company['customer_types']['name'];
    } else {
      final typeId = company['customer_type_id']?.toString();
      if (typeId != null) {
        final matched = _customerTypes.firstWhere(
          (t) => t['id'].toString() == typeId,
          orElse: () => null,
        );
        if (matched != null) roleName = matched['name'] ?? "Unknown";
      }
    }

    String mappedRole = "";
    String lowerRole = roleName.toLowerCase();
    if (lowerRole.contains('dev') || lowerRole.contains('เจ้าของ'))
      mappedRole = "Developer";
    else if (lowerRole.contains('arch') ||
        lowerRole.contains('สถาปนิก') ||
        lowerRole.contains('ออกแบบ'))
      mappedRole = "Architecture";
    else if (lowerRole.contains('int') ||
        lowerRole.contains('มัณฑนากร') ||
        lowerRole.contains('ตกแต่ง'))
      mappedRole = "Interior";
    else if (lowerRole.contains('cont') || lowerRole.contains('รับเหมา'))
      mappedRole = "Contractor";

    if (mappedRole.isEmpty) {
      mappedRole = "Developer"; // Default if not found
    }

    setState(() {
      if (!activeRoles.contains(mappedRole)) {
        activeRoles.add(mappedRole);
      }
      if (mappedRole == "Developer") {
        accDevCtrl.text = company['name'] ?? '';
      } else if (mappedRole == "Architecture") {
        accArchCtrl.text = company['name'] ?? '';
      } else if (mappedRole == "Interior") {
        accIntCtrl.text = company['name'] ?? '';
      } else if (mappedRole == "Contractor") {
        accContCtrl.text = company['name'] ?? '';
      }

      // 🌟 เคลียร์ช่องค้นหาเพื่อให้กดค้นหาบริษัทถัดไปได้ทันที
      Future.delayed(const Duration(milliseconds: 100), () {
        searchKey.currentState?.clear();
      });
    });
  }

  @override
  void dispose() {
    projectCtrl.dispose();
    areaCtrl.dispose();
    accDevCtrl.dispose();
    conDevCtrl.dispose();
    accArchCtrl.dispose();
    conArchCtrl.dispose();
    accIntCtrl.dispose();
    conIntCtrl.dispose();
    accContCtrl.dispose();
    conContCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: kNeonPurple.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 Header
            Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  color: kPremiumGold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: projectCtrl,
                    style: const TextStyle(
                      color: kPremiumGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: "ชื่อโครงการ",
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // ให้ชิดซ้าย
                  children: [
                    // 🌟 1. ประเภทโครงการ
                    _buildLabel("ประเภทโครงการ"),
                    DropdownButtonFormField<String>(
                      isExpanded: true, // ป้องกันการเบียดจนล้น
                      value: selectedProjectTypeId,
                      dropdownColor: kCardDark,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration("เลือกประเภทโครงการ"),
                      items: widget.projectTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type['id'].toString(),
                          child: Text(
                            type['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => selectedProjectTypeId = val),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 2. หมวดหมู่สินค้า
                    _buildLabel("ประเภทสินค้า (Category)"),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      dropdownColor: kCardDark,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration("เลือกหมวดหมู่สินค้า"),
                      items: widget.categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['id'].toString(),
                          child: Text(
                            cat['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => selectedCategoryId = val),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 3. ขนาดพื้นที่
                    _buildLabel("ขนาดพื้นที่ (ตร.ม.)"),
                    TextField(
                      controller: areaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration("ระบุพื้นที่"),
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),

                    // 🌟 Role Groups
                    if (activeRoles.contains("Developer"))
                      _buildCompactRoleGroup(
                        roleName: "Developer",
                        icon: Icons.business_rounded,
                        accCtrl: accDevCtrl,
                        conCtrl: conDevCtrl,
                      ),
                    if (activeRoles.contains("Architecture"))
                      _buildCompactRoleGroup(
                        roleName: "Architecture",
                        icon: Icons.architecture_rounded,
                        accCtrl: accArchCtrl,
                        conCtrl: conArchCtrl,
                      ),
                    if (activeRoles.contains("Interior"))
                      _buildCompactRoleGroup(
                        roleName: "Interior",
                        icon: Icons.chair_rounded,
                        accCtrl: accIntCtrl,
                        conCtrl: conIntCtrl,
                      ),
                    if (activeRoles.contains("Contractor"))
                      _buildCompactRoleGroup(
                        roleName: "Contractor",
                        icon: Icons.foundation_rounded,
                        accCtrl: accContCtrl,
                        conCtrl: conContCtrl,
                      ),

                    // 🌟 เพิ่มประเภทลูกค้า (บทบาท) โดยการค้นหาบริษัท
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      child: DropdownSearch<dynamic>(
                        key: searchKey,
                        items: (filter, loadProps) => _getCompanies(filter),
                        itemAsString: (item) => item['name'] ?? '',
                        onChanged: _onCompanySelected,
                        compareFn: (i1, i2) => i1?['id'] == i2?['id'],
                        suffixProps: const DropdownSuffixProps(
                          dropdownButtonProps: DropdownButtonProps(
                            isVisible: false,
                          ),
                        ),
                        decoratorProps: DropDownDecoratorProps(
                          decoration: _inputDecoration("ค้นหาบริษัท").copyWith(
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: kLimeGreen,
                              size: 20,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: kLimeGreen.withOpacity(0.3),
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                        ),
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          menuProps: const MenuProps(
                            backgroundColor: kCardDark,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          searchFieldProps: TextFieldProps(
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                _inputDecoration(
                                  "พิมพ์ชื่อบริษัทเพื่อค้นหา...",
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: kPremiumGold,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // 🔘 Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "ยกเลิก",
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSave({
                        "project_name": projectCtrl.text,
                        "area_sqm": double.tryParse(areaCtrl.text) ?? 0,
                        "product_category_id": selectedCategoryId,
                        "project_type_id": selectedProjectTypeId,
                        "account_developer": accDevCtrl.text,
                        "contact_developer": conDevCtrl.text,
                        "account_architecture": accArchCtrl.text,
                        "contact_architecture": conArchCtrl.text,
                        "account_interior": accIntCtrl.text,
                        "contact_interior": conIntCtrl.text,
                        "account_contractor": accContCtrl.text,
                        "contact_contractor": conContCtrl.text,
                      });
                    },
                    child: const Text(
                      "บันทึกข้อมูล",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 🌟 ฟังก์ชันสร้าง Label แบบ Premium
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: kNeonPurple,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🌟 ฟังก์ชันสร้าง InputDecoration แบบมาตรฐานเดียวกัน
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white12, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildCompactRoleGroup({
    required String roleName,
    required IconData icon,
    required TextEditingController accCtrl,
    required TextEditingController conCtrl,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: kNeonPurple.withOpacity(0.7), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  roleName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextField(
          controller: accCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDecoration("ชื่อบริษัท (Account)"),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: conCtrl,
          style: const TextStyle(color: kLimeGreen, fontSize: 13),
          decoration: _inputDecoration(
            "ผู้ติดต่อ / เบอร์โทร",
          ).copyWith(fillColor: kLimeGreen.withOpacity(0.05)),
        ),
        const SizedBox(height: 12),
        const Divider(color: Colors.white10, thickness: 0.5),
      ],
    );
  }
}
