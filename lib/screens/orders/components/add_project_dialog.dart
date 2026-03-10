// lib/screens/orders/components/add_project_dialog.dart
import 'package:flutter/material.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);
const Color kLimeGreen = Color(0xFFD2E862); // 🌟 สีเขียวต้นแบบของพี่

class AddProjectDialog extends StatefulWidget {
  final List<dynamic> allProjects;
  final Function(dynamic) onSelect;
  final Future<bool> Function(String) onSaveNew;

  const AddProjectDialog({
    super.key,
    required this.allProjects,
    required this.onSelect,
    required this.onSaveNew,
  });

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  List<dynamic> _suggestedProjects = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // 🌟 เริ่มต้นไม่ต้องโชว์อะไรเลย พี่จะได้ไม่รำคาญรูปตึก
    _suggestedProjects = []; 
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _suggestedProjects = [];
      } else {
        // 🔍 จะโชว์รายชื่อก็ต่อเมื่อพิมพ์แล้วมีชื่อที่ "คล้ายกัน" เท่านั้น
        _suggestedProjects = widget.allProjects
            .where((p) => p['name'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text("เพิ่มโครงการใหม่", 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 📝 ช่องกรอกชื่อโครงการ (จุดประสงค์หลักของพี่)
            TextField(
              controller: _nameCtrl,
              onChanged: _onSearchChanged,
              autofocus: true, // เปิดมาให้พิมพ์ได้เลย
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "พิมพ์ชื่อโครงการที่ต้องการเพิ่ม...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.edit_note_rounded, color: kLimeGreen),
                filled: true,
                fillColor: kDarkBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLimeGreen, width: 1.5)),
              ),
            ),
            
            // 📜 รายชื่อโครงการที่มีอยู่แล้ว (ถ้าพิมพ์แล้วชื่อซ้ำ จะขึ้นมาเตือนตรงนี้)
            if (_suggestedProjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("  โครงการที่มีชื่อใกล้เคียงกัน:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestedProjects.length,
                  itemBuilder: (ctx, i) {
                    final proj = _suggestedProjects[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.history_rounded, color: Colors.white38, size: 18),
                      title: Text(proj['name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      trailing: const Text("เลือกใช้", style: TextStyle(color: kLimeGreen, fontSize: 12)),
                      onTap: () => widget.onSelect(proj), // ถ้าขี้เกียจเพิ่มใหม่ ก็จิ้มอันเดิมได้
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ยกเลิก", style: TextStyle(color: Colors.white54)),
        ),
        // 🚀 ปุ่มบันทึกอันใหญ่ๆ กลางจอ
        ElevatedButton(
          onPressed: isSaving ? null : () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            setState(() => isSaving = true);
            bool success = await widget.onSaveNew(_nameCtrl.text.trim());
            if (success && mounted) Navigator.pop(context);
            if (!success && mounted) setState(() => isSaving = false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kLimeGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: isSaving 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Text("บันทึกโครงการ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}