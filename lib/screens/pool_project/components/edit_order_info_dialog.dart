import 'package:flutter/material.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107);
const Color kNeonPurple = Color(0xFFB52BFF);

class EditOrderInfoDialog extends StatefulWidget {
  final String initialCustomerName;
  final String initialPhone;
  final Future<void> Function(String customerName, String phone) onSave;

  const EditOrderInfoDialog({
    super.key,
    required this.initialCustomerName,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<EditOrderInfoDialog> createState() => _EditOrderInfoDialogState();
}

class _EditOrderInfoDialogState extends State<EditOrderInfoDialog> {
  late TextEditingController customerCtrl;
  late TextEditingController phoneCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ถ้าแสดงคำว่า 'ไม่ระบุชื่อลูกค้า' ให้เคลียร์เป็นช่องว่างเวลาแก้ไข
    customerCtrl = TextEditingController(
      text: widget.initialCustomerName.contains('ไม่ระบุ') ? '' : widget.initialCustomerName
    );
    phoneCtrl = TextEditingController(
      text: widget.initialPhone == '-' ? '' : widget.initialPhone
    );
  }

  @override
  void dispose() {
    customerCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCardDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), 
        side: BorderSide(color: kNeonPurple.withOpacity(0.3))
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        // 🌟 เพิ่ม SingleChildScrollView ตรงนี้เพื่อป้องกันปัญหาลายเหลืองดำตอนคีย์บอร์ดเด้ง
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), 
                    child: const Icon(Icons.manage_accounts_rounded, color: kNeonPurple, size: 20)
                  ),
                  const SizedBox(width: 12),
                  const Text("แก้ไขข้อมูลลูกค้า", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),

              // 1. ช่องกรอกชื่อลูกค้า
              const Text("ชื่อลูกค้า (Customer)", style: TextStyle(color: kPremiumGold, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: customerCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "กรอกชื่อลูกค้า",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeonPurple, width: 1)),
                ),
              ),
              const SizedBox(height: 16),

              // 2. ช่องกรอกเบอร์โทร / Line
              const Text("เบอร์โทร / Line", style: TextStyle(color: kPremiumGold, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "กรอกเบอร์โทรหรือ Line ID",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeonPurple, width: 1)),
                ),
              ),
              
              const SizedBox(height: 24),

              // ปุ่มบันทึก
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context), 
                      child: const Text("ยกเลิก", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonPurple, foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                      ),
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        await widget.onSave(customerCtrl.text, phoneCtrl.text);
                        if (context.mounted) {
                          setState(() => _isLoading = false);
                          Navigator.pop(context);
                        }
                      },
                      child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("บันทึกข้อมูล", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}