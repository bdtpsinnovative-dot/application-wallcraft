// lib/screens/tracking/widgets/admin_add_package_modal.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../../constants.dart';

class AdminAddPackageModal extends StatefulWidget {
  const AdminAddPackageModal({super.key});

  @override
  State<AdminAddPackageModal> createState() => _AdminAddPackageModalState();
}

class _AdminAddPackageModalState extends State<AdminAddPackageModal> {
  List<Map<String, String>> tempRecords = [];
  
  late TextEditingController dateCtrl;
  late TextEditingController batchCodeCtrl;
  late TextEditingController refCtrl;
  late TextEditingController jkCtrl;
  late TextEditingController ctnCtrl;
  late TextEditingController trackingCtrl;

  @override
  void initState() {
    super.initState();
    dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    batchCodeCtrl = TextEditingController();
    refCtrl = TextEditingController(text: "TPS");
    jkCtrl = TextEditingController();
    ctnCtrl = TextEditingController(text: "1");
    trackingCtrl = TextEditingController();
  }

  @override
  void dispose() {
    dateCtrl.dispose();
    batchCodeCtrl.dispose();
    refCtrl.dispose();
    jkCtrl.dispose();
    ctnCtrl.dispose();
    trackingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, 
        left: 20, right: 20, top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ADD Trackingz", 
                  style: TextStyle(color: Colors.indigoAccent, fontSize: 18, fontWeight: FontWeight.bold)
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: _buildAdminTextField("วันที่จัดส่ง", dateCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildAdminTextField("รหัสรอบบิล", batchCodeCtrl, hint: "เช่น ADN2026")),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildAdminTextField("Ref Code", refCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildAdminTextField("JK Code", jkCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(flex: 1, child: _buildAdminTextField("CTN", ctnCtrl, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildAdminTextField("Tracking (เว้นได้)", trackingCtrl)),
              ],
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                  foregroundColor: Colors.indigoAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5), width: 1)
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text("เพิ่มลงรายการด้านล่าง", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  if (refCtrl.text.isEmpty || jkCtrl.text.isEmpty) return;
                  setState(() {
                    tempRecords.add({
                      "refCode": refCtrl.text, "jkCode": jkCtrl.text,
                      "ctn": ctnCtrl.text, "tracking": trackingCtrl.text.isEmpty ? "-" : trackingCtrl.text,
                    });
                    refCtrl.text = "TPS"; jkCtrl.clear(); ctnCtrl.text = "1"; trackingCtrl.clear();
                  });
                },
              ),
            ),
            
            // 🌟 ซ่อนส่วนนี้ไว้ และจะโชว์ก็ต่อเมื่อมีรายการใน tempRecords
            if (tempRecords.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("รายการที่เตรียมบันทึก", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                    child: Text("${tempRecords.length} รายการ", style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              // กล่องรายการพัสดุ (ใช้ ConstrainedBox เพื่อไม่ให้ยาวเกินไปถ้าเพิ่มหลายชิ้น)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: const Color(0xFF242426),
                  border: Border.all(color: Colors.white10), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tempRecords.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    var item = tempRecords[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text("${item['refCode']} (${item['jkCode']})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text("${item['ctn']} CTN | Tracking: ${item['tracking']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 22),
                        onPressed: () => setState(() => tempRecords.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white38,
                ),
                // ปิดปุ่มไว้ถ้ายังไม่มีรายการ
                onPressed: tempRecords.isEmpty ? null : () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token') ?? "";

                  final payload = {
                    "token": token,
                    "batchDate": dateCtrl.text,
                    "batchCode": batchCodeCtrl.text,
                    "records": tempRecords,
                  };

                  try {
                    final response = await http.post(
                      AppConfig.tpsTrackingUrl, 
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode(payload),
                    );

                    if (response.statusCode == 201 || response.statusCode == 200) {
                      if (mounted) {
                        Navigator.pop(context, true); 
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จเรียบร้อย'), backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      throw Exception('Failed to save API');
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เกิดข้อผิดพลาด ไม่สามารถบันทึกได้'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text("ยืนยันบันทึกลง Database", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTextField(String label, TextEditingController ctrl, {bool isNumber = false, String hint = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF2C2C2E),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}