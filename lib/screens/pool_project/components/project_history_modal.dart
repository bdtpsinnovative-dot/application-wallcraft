import 'package:flutter/material.dart';

class ProjectHistoryModal extends StatelessWidget {
  final List<dynamic> adminEdits;

  const ProjectHistoryModal({super.key, required this.adminEdits});

  static const Color kDarkBg = Color(0xFF0F0F11);
  static const Color kCardDark = Color(0xFF1C1C1E);
  static const Color kNeonPurple = Color(0xFFB52BFF);
  static const Color kPremiumGold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    // เรียงลำดับจากเวลาล่าสุดขึ้นก่อน
    final sortedEdits = List<dynamic>.from(adminEdits)
      ..sort((a, b) => DateTime.parse(b['edited_at']).compareTo(DateTime.parse(a['edited_at'])));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // สูง 75% ของจอ
      decoration: const BoxDecoration(
        color: kDarkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 🌟 Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.history_rounded, color: kNeonPurple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text("ประวัติการแก้ไขข้อมูล", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),

          // 🌟 รายการ History
          Expanded(
            child: sortedEdits.isEmpty
                ? const Center(child: Text("ไม่มีประวัติการแก้ไข", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: sortedEdits.length,
                    itemBuilder: (context, index) {
                      final edit = sortedEdits[index];
                      final DateTime date = DateTime.parse(edit['edited_at']).toLocal();
                      final String dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}";
                      final String timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";
                      
                      final String editorName = edit['editor_name'] ?? 'Unknown Admin';
                      final String details = edit['details'] ?? 'แก้ไขข้อมูล';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kCardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // แถวบน: ชื่อคนแก้ + เวลา
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.manage_accounts_rounded, color: kPremiumGold, size: 16),
                                    const SizedBox(width: 6),
                                    Text(editorName, style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                Text("$dateStr $timeStr", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 12),
                            // รายละเอียดว่าแก้อะไรไปบ้าง
                            ...details.replaceFirst('แก้ไข: ', '').split(', ').map((d) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(margin: const EdgeInsets.only(top: 6, right: 8), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                                    Expanded(child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}