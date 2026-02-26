// lib/screens/orders/components/add_project_dialog.dart
import 'package:flutter/material.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);

class AddProjectDialog extends StatefulWidget {
  final List<dynamic> allProjects; // รับโครงการทั้งหมดมาจากหน้าหลัก
  final Function(dynamic) onSelect; // เมื่อเลือกโครงการที่มีอยู่
  final Future<bool> Function(String) onSaveNew; // เมื่อจะสร้างโครงการใหม่

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
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _filteredProjects = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _filteredProjects = widget.allProjects; // เริ่มต้นให้เห็นทั้งหมด
  }

  void _filterProjects(String query) {
    setState(() {
      _filteredProjects = widget.allProjects
          .where((p) => p['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      title: const Text("Select Project", 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔍 ช่องค้นหา / พิมพ์ชื่อใหม่
            TextField(
              controller: _searchCtrl,
              onChanged: _filterProjects,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search or enter new project...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: kPrimaryColor),
                filled: true,
                fillColor: kDarkBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            
            // 📜 รายการผลลัพธ์
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250), // จำกัดความสูง List
              child: _filteredProjects.isEmpty 
                ? _buildAddNewState() // ถ้าหาไม่เจอ ให้โชว์ปุ่มสร้างใหม่
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredProjects.length,
                    itemBuilder: (ctx, i) {
                      final proj = _filteredProjects[i];
                      return ListTile(
                        leading: const Icon(Icons.apartment, color: Colors.white70),
                        title: Text(proj['name'] ?? '', style: const TextStyle(color: Colors.white)),
                        onTap: () => widget.onSelect(proj), // เลือกโครงการนี้
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text("No project found", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: isSaving ? null : () async {
            if (_searchCtrl.text.trim().isEmpty) return;
            setState(() => isSaving = true);
            bool success = await widget.onSaveNew(_searchCtrl.text.trim());
            if (success && mounted) Navigator.pop(context);
            if (!success && mounted) setState(() => isSaving = false);
          },
          icon: isSaving 
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add, color: Colors.black),
          label: const Text("Create as new project", style: TextStyle(color: Colors.black)),
          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
        )
      ],
    );
  }
}