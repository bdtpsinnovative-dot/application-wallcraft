import 'package:flutter/material.dart';

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
  bool isIntExpanded = false;
  bool isContExpanded = false;

  @override
  void initState() {
    super.initState();
    final p = widget.projectData;
    String pName = p['project_name'] ?? 'ไม่มีชื่อโครงการ';

    projectCtrl = TextEditingController(text: pName == 'ไม่มีชื่อโครงการ' ? '' : pName);
    areaCtrl = TextEditingController(text: p['area_sqm']?.toString() ?? '');
    
    selectedCategoryId = p['product_category_id']?.toString(); 
    if (selectedCategoryId != null && !widget.categories.any((c) => c['id'].toString() == selectedCategoryId)) {
      selectedCategoryId = null;
    }

    selectedProjectTypeId = p['project_type_id']?.toString(); 
    if (selectedProjectTypeId != null && !widget.projectTypes.any((t) => t['id'].toString() == selectedProjectTypeId)) {
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
  }

  @override
  void dispose() {
    projectCtrl.dispose(); areaCtrl.dispose();
    accDevCtrl.dispose(); conDevCtrl.dispose();
    accArchCtrl.dispose(); conArchCtrl.dispose();
    accIntCtrl.dispose(); conIntCtrl.dispose();
    accContCtrl.dispose(); conContCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), 
        side: BorderSide(color: kNeonPurple.withOpacity(0.3))
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 Header
            Row(
              children: [
                const Icon(Icons.apartment_rounded, color: kPremiumGold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: projectCtrl,
                    style: const TextStyle(color: kPremiumGold, fontSize: 18, fontWeight: FontWeight.bold),
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
                          child: Text(type['name'].toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedProjectTypeId = val),
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
                          child: Text(cat['name'].toString(), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedCategoryId = val),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 3. ขนาดพื้นที่
                    _buildLabel("ขนาดพื้นที่ (ตร.ม.)"),
                    TextField(
                      controller: areaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration("ระบุพื้นที่"),
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),

                    // 🌟 Role Groups
                    _buildCompactRoleGroup(
                      roleName: "Developer", icon: Icons.business_rounded, 
                      accCtrl: accDevCtrl, conCtrl: conDevCtrl,
                      isExpanded: isDevExpanded, onToggle: () => setState(() => isDevExpanded = !isDevExpanded)
                    ),
                    _buildCompactRoleGroup(
                      roleName: "Architecture", icon: Icons.architecture_rounded, 
                      accCtrl: accArchCtrl, conCtrl: conArchCtrl,
                      isExpanded: isArchExpanded, onToggle: () => setState(() => isArchExpanded = !isArchExpanded)
                    ),
                    _buildCompactRoleGroup(
                      roleName: "Interior", icon: Icons.chair_rounded, 
                      accCtrl: accIntCtrl, conCtrl: conIntCtrl,
                      isExpanded: isIntExpanded, onToggle: () => setState(() => isIntExpanded = !isIntExpanded)
                    ),
                    _buildCompactRoleGroup(
                      roleName: "Contractor", icon: Icons.foundation_rounded, 
                      accCtrl: accContCtrl, conCtrl: conContCtrl,
                      isExpanded: isContExpanded, onToggle: () => setState(() => isContExpanded = !isContExpanded)
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // 🔘 Buttons
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก", style: TextStyle(color: Colors.white38)))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonPurple, 
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
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
                    child: const Text("บันทึกข้อมูล", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      child: Text(text, style: const TextStyle(color: kNeonPurple, fontSize: 13, fontWeight: FontWeight.bold)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildCompactRoleGroup({
    required String roleName, required IconData icon, 
    required TextEditingController accCtrl, required TextEditingController conCtrl,
    required bool isExpanded, required VoidCallback onToggle
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: kNeonPurple.withOpacity(0.7), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(roleName, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14))),
                Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white24),
              ],
            ),
          ),
        ),
        TextField(
          controller: accCtrl, 
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDecoration("ชื่อบริษัท (Account)"),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          TextField(
            controller: conCtrl, 
            style: const TextStyle(color: kLimeGreen, fontSize: 13),
            decoration: _inputDecoration("ผู้ติดต่อ / เบอร์โทร").copyWith(
              fillColor: kLimeGreen.withOpacity(0.05),
            ),
          ),
        ],
        const SizedBox(height: 4),
        const Divider(color: Colors.white10, thickness: 0.5),
      ],
    );
  }
}