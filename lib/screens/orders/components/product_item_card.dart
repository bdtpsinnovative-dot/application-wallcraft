//lib/screens/orders/components/product_item_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 ตัวนี้แหละที่มาช่วยชีวิต
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;
// 🎨 Palette สี (Theme: Simple Black & White - ขาวดำ ชัดเจน)
const Color kCardDark = Color(0xFF1C1C1E);
const Color kInputBg = Color(0xFF2C2C2E);
const Color kPrimaryColor = Color(0xFFFFFFFF); // ✅ ใช้สีขาวเป็นสีหลัก (High Contrast)

// --- 1. Class Model ---
class ProductItem {
  String? categoryId;
  String? interestLevel;
  TextEditingController noteCtrl = TextEditingController();
  List<File> itemImages = [];
  List<String> selectedProjectIds = [];
  Map<String, TextEditingController> projectAreaControllers = {};

  ProductItem({this.categoryId});
}

// --- 2. ตัว Widget การ์ดสินค้า ---
class ProductItemCard extends StatefulWidget {
  final int index;
  final ProductItem item;
  final List<dynamic> productCategories;
  final List<dynamic> projects; 
  final VoidCallback onDelete;

  const ProductItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.productCategories,
    required this.projects,
    required this.onDelete,
  });

  @override
  State<ProductItemCard> createState() => _ProductItemCardState();
}

class _ProductItemCardState extends State<ProductItemCard> {
  
Future<void> _showImageSourceModal() async {
    // ✅ 1. ท่าไม้ตาย: สั่งหุบแป้นพิมพ์แบบเด็ดขาดลึกถึงระดับ OS
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    // รอให้แป้นพิมพ์ลงสนิทจริงๆ ก่อนโชว์ BottomSheet
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: 180,
        decoration: const BoxDecoration(
          color: kCardDark, // พื้นหลังเข้ม
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPickIcon(Icons.camera_alt_rounded, "Camera", () async {
              // ✅ 2. ปิด Bottom Sheet ก่อน
              Navigator.pop(ctx);
              
              // 🌟 3. จุดสำคัญที่สุด: ต้องหน่วงเวลาให้ Bottom Sheet รูดปิดสนิทก่อนเปิดกล้อง!
              await Future.delayed(const Duration(milliseconds: 350));
              
              // 4. พอจอโล่งคลีน ค่อยเรียกกล้อง
              final p = await picker.pickImage(source: ImageSource.camera);
              if (p != null) await _processImage(File(p.path));
            }),
            _buildPickIcon(Icons.photo_library_rounded, "Gallery", () async {
              // ✅ 2. ปิด Bottom Sheet ก่อน
              Navigator.pop(ctx);
              
              // 🌟 3. หน่วงเวลารอ Bottom Sheet ปิดสนิท
              await Future.delayed(const Duration(milliseconds: 350));
              
              // 4. ค่อยเรียกอัลบั้ม
              final l = await picker.pickMultiImage();
              for (var p in l) {
                await _processImage(File(p.path));
              }
            }),
          ],
        ),
      ),
    );
  }

  // ✅ 2. แก้ฟังก์ชันนี้เพื่อดักบั๊กตอนแอปตื่นจาก Background
  Future<void> _processImage(File f) async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(dir.path, "${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}.webp");
      
      var result = await FlutterImageCompress.compressAndGetFile(
        f.absolute.path, targetPath, 
        minWidth: 1024, minHeight: 1024, quality: 70, format: CompressFormat.webp
      );
      
      // 🌟 หัวใจอยู่ตรงนี้! ต้องเช็ค mounted เสมอ
      // เพราะหลังจากเปิดกล้องแล้วกลับมา หน้าจออาจจะกำลัง Refresh ตัวเองอยู่
      if (result != null && mounted) {
        setState(() {
          widget.item.itemImages.add(File(result.path));
        });
      }
    } catch (e) {
      debugPrint("Compress Image Error: $e");
    }
  }

  // ✨ Decoration ธีมขาว-ดำ (แก้ไข Error ซ้ำแล้วครับ)
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label, // ✅ เหลือบรรทัดเดียวแล้วครับ
      labelStyle: const TextStyle(color: Colors.grey), // Label สีเทา
      prefixIcon: Icon(icon, size: 22, color: kPrimaryColor), // ไอคอนสีขาว
      filled: true, 
      fillColor: kInputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      // ✅ เพิ่มเส้นขอบสีขาวจางๆ ให้มองเห็นช่องง่ายขึ้น
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
    );
  }

  Widget _buildPickIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: kPrimaryColor), // ขอบสีขาว
          ),
          child: Icon(icon, color: kPrimaryColor, size: 30), // ไอคอนสีขาว
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ครอบด้วย Container เพื่อแยกแต่ละ Item ให้ชัดเจนขึ้น
      padding: const EdgeInsets.all(16), // เพิ่ม Padding ให้เนื้อหาไม่ติดขอบ
      decoration: BoxDecoration(
        color: kCardDark, // ใช้สีการ์ดทึบ
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: Item #1 + Delete Button
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("สินค้าที่ #${widget.index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 18)),
          if (widget.index > 0) 
            IconButton(
              onPressed: widget.onDelete, 
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28) // ปุ่มลบสีแดงชัดๆ
            )
        ]),
        const SizedBox(height: 16),

        // Dropdown เลือกสินค้า
        DropdownButtonFormField<String>(
          value: widget.item.categoryId,
          isExpanded: true,
          decoration: _inputDecoration("หมวดหมู่สินค้า", Icons.shopping_bag_outlined),
          dropdownColor: kCardDark,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: widget.productCategories.map((item) => DropdownMenuItem<String>(
            value: item['id'], 
            child: Text(item['name'] ?? '-', overflow: TextOverflow.ellipsis)
          )).toList(),
          onChanged: (val) => setState(() => widget.item.categoryId = val),
          validator: (v) => v == null ? 'Required' : null,
        ),
        const SizedBox(height: 16),

        // Dropdown ระดับความสนใจ
        DropdownButtonFormField<String>(
          value: widget.item.interestLevel,
          isExpanded: true,
          decoration: _inputDecoration("ระดับความชอบ", Icons.star_border_rounded),
          dropdownColor: kCardDark,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: [
            "สนใจมาก (มีโครงการที่อยากใช้)",
            "สนใจมาก (แต่ยังไม่มีโครงการ)",
            "สนใจปานกลาง",
            "ติดตามงาน",
            "สนใจน้อย (รูปแบบสินค้า)",
            "สนใจน้อย (โครงการที่ทำมีงบจำกัด)",
          ].map((level) => DropdownMenuItem<String>(
            value: level,
            child: Text(level, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (val) => setState(() => widget.item.interestLevel = val),
        ),
        const SizedBox(height: 16),

        // Note Field
        TextFormField(
          controller: widget.item.noteCtrl,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.white), // ตัวหนังสือใหญ่ขึ้น
          decoration: InputDecoration(
            labelText: "โน๊ต",
            labelStyle: const TextStyle(color: Colors.grey),
            hintText: "พิมพ์รายละเอียดเพิ่มเติม...",
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            alignLabelWithHint: true,
            
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 45), 
              child: Icon(Icons.edit_note_rounded, size: 24, color: kPrimaryColor),
            ),
            
            filled: true,
            fillColor: kInputBg,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          ),
        ),
        const SizedBox(height: 24),
        
        // ส่วนจัดการโครงการและพื้นที่ (Checkbox)
        if (widget.projects.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black, // พื้นหลังดำตัดกับการ์ด
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                  Text("การใช้งานในโครงการ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  Text("จำนวน / ตร.ม.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
                const SizedBox(height: 16),

                // Loop สร้าง Checkbox
                ...widget.projects.map((p) {
                  String pid = p['id'];
                  bool isChecked = widget.item.selectedProjectIds.contains(pid);
                  widget.item.projectAreaControllers.putIfAbsent(pid, () => TextEditingController());

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(children: [
                      SizedBox(
                        width: 28, height: 28, // Checkbox ใหญ่ขึ้น
                        child: Checkbox(
                          value: isChecked,
                          activeColor: kPrimaryColor, // สีขาว
                          checkColor: Colors.black, // ติ๊กสีดำ
                          side: const BorderSide(color: Colors.grey, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                widget.item.selectedProjectIds.add(pid);
                              } else {
                                widget.item.selectedProjectIds.remove(pid);
                                widget.item.projectAreaControllers[pid]?.clear();
                              }
                            });
                          },
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        p['project_name'],
                        style: TextStyle(fontSize: 15, color: isChecked ? kPrimaryColor : Colors.grey, fontWeight: isChecked ? FontWeight.bold : FontWeight.normal),
                      )),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80, height: 45, 
                        child: TextFormField(
                          controller: widget.item.projectAreaControllers[pid],
                          enabled: isChecked,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "0", 
                            hintStyle: TextStyle(color: Colors.grey.shade700),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            filled: true, 
                            fillColor: isChecked ? kInputBg : Colors.transparent,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimaryColor)),
                          ),
                        )
                      ),
                    ]),
                  );
                }).toList(),
              ],
            ),
          ),

        const SizedBox(height: 24),
        
        // ส่วนแสดงรูปภาพ (Gallery)
        Row(children: const [
          Icon(Icons.photo_library_outlined, size: 20, color: Colors.white), 
          SizedBox(width: 8), 
          Text("รูปภาพสินค้า", style: TextStyle(fontSize: 15, color: Colors.white))
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 100, // เพิ่มความสูง
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.item.itemImages.length + 1,
            itemBuilder: (c, i) {
              if (i == widget.item.itemImages.length) {
                return GestureDetector(
                  onTap: _showImageSourceModal,
                  child: Container(
                    width: 100, 
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: kInputBg, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5, style: BorderStyle.solid)
                    ), 
                    child: const Icon(Icons.add_a_photo_rounded, color: kPrimaryColor, size: 30)
                  )
                );
              }
              return Stack(children: [
                Container(
                  width: 100, 
                  margin: const EdgeInsets.only(right: 12), 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    image: DecorationImage(image: FileImage(widget.item.itemImages[i]), fit: BoxFit.cover)
                  )
                ),
                Positioned(
                  top: 4, right: 16, 
                  child: GestureDetector(
                    onTap: () => setState(() => widget.item.itemImages.removeAt(i)), 
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white)
                    )
                  )
                )
              ]);
            },
          ),
        ),
      ]),
    );
  }
}