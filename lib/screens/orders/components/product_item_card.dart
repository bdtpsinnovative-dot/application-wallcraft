import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

// 🎨 Palette สี
const Color kCardDark = Color(0xFF1C1C1E);
const Color kInputBg = Color(0xFF2C2C2E);
const Color kPrimaryColor = Color(0xFFFFFFFF);

// --- 1. Class Model ---
class ProductItem {
  String? targetProjectId;
  String? categoryId;
  String? interestLevel;
  String? projectTypeId; // 🌟 1. เพิ่มตัวเก็บค่า "ประเภทโครงการ"
  String? queueLevel;
  TextEditingController projectYearCtrl = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  TextEditingController noteCtrl = TextEditingController();
  List<File> itemImages = [];
  List<String> selectedProjectIds = [];
  Map<String, TextEditingController> projectAreaControllers = {};

  ProductItem({this.categoryId, this.targetProjectId});
}

// --- 2. ตัว Widget การ์ดสินค้า ---
class ProductItemCard extends StatefulWidget {
  final int index;
  final ProductItem item;
  final List<dynamic> productCategories;
  final List<dynamic> projects;
  final List<dynamic>
  projectTypes; // 🌟 2. เพิ่มตัวแปรรับ List ประเภทโครงการจากหน้าหลัก
  final VoidCallback onDelete;
  final bool lockProjectSelection;

  const ProductItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.productCategories,
    required this.projects,
    required this.projectTypes, // 🌟 อย่าลืมส่งค่านี้มาจากหน้าหลักด้วยนะครับ
    required this.onDelete,
    this.lockProjectSelection = false,
  });

  @override
  State<ProductItemCard> createState() => _ProductItemCardState();
}

class _ProductItemCardState extends State<ProductItemCard> {
  @override
  void initState() {
    super.initState();
    _checkAutoSelectProject();
  }

  @override
  void didUpdateWidget(ProductItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projects.length != oldWidget.projects.length) {
      _checkAutoSelectProject();
    }
  }

  final Set<String> _seenProjectIds = {};

  void _checkAutoSelectProject() {
    bool changed = false;
    for (var project in widget.projects) {
      String? projectId = project['id']?.toString();
      if (projectId != null && !_seenProjectIds.contains(projectId)) {
        _seenProjectIds.add(projectId);
        // Auto-select because it's the first time we see this project in this card
        if (!widget.item.selectedProjectIds.contains(projectId)) {
          widget.item.selectedProjectIds.add(projectId);
          widget.item.projectAreaControllers.putIfAbsent(
            projectId,
            () => TextEditingController(),
          );
          changed = true;
        }
      }
    }

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _showImageSourceModal() async {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom,
        ),
        height: 180,
        decoration: const BoxDecoration(
          color: kCardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPickIcon(Icons.camera_alt_rounded, "Camera", () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 350));
              final p = await picker.pickImage(source: ImageSource.camera);
              if (p != null) await _processImage(File(p.path));
            }),
            _buildPickIcon(Icons.photo_library_rounded, "Gallery", () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 350));
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

  Future<void> _processImage(File f) async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        "${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}.webp",
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        f.absolute.path,
        targetPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: 70,
        format: CompressFormat.webp,
      );

      if (result != null && mounted) {
        setState(() {
          widget.item.itemImages.add(File(result.path));
        });
      }
    } catch (e) {
      debugPrint("Compress Image Error: $e");
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, size: 20, color: kPrimaryColor),
      filled: true,
      fillColor: kInputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),

      // 👇 3 บรรทัดที่เพิ่มเข้ามาเพื่อให้ขอบแดงทำงานได้สมบูรณ์
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
      ),
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPickIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: kPrimaryColor),
            ),
            child: Icon(icon, color: kPrimaryColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForProject(dynamic project) {
    if (project == null) return Icons.apartment_rounded;

    // 1. ถ้ามีชื่อประเภทโครงการส่งมาตรงๆ
    String? typeName =
        project['project_type_name'] ?? project['project_types']?['name'];

    // 2. ถ้าไม่มี ให้หาจาก project_type_id ที่ตรงกับ projectTypes list
    if (typeName == null || typeName.isEmpty) {
      final typeId = project['project_type_id']?.toString();
      if (typeId != null && widget.projectTypes.isNotEmpty) {
        final match = widget.projectTypes.firstWhere(
          (pt) => pt['id']?.toString() == typeId,
          orElse: () => null,
        );
        if (match != null) {
          typeName = match['name']?.toString();
        }
      }
    }

    // 3. ถ้ายังไม่มี ให้ตรวจจับจาก Keyword ในชื่อโครงการ
    if (typeName == null || typeName.isEmpty) {
      final pName = (project['project_name'] ?? '').toString().toLowerCase();
      if (pName.contains('condominium') ||
          pName.contains('condo') ||
          pName.contains('คอนโด'))
        return Icons.apartment_rounded;
      if (pName.contains('mall') ||
          pName.contains('shopping') ||
          pName.contains('ห้าง') ||
          pName.contains('เซ็นทรัล') ||
          pName.contains('central') ||
          pName.contains('เดอะมอลล์'))
        return Icons.shopping_bag_rounded;
      if (pName.contains('hospital') ||
          pName.contains('รพ') ||
          pName.contains('โรงพยาบาล'))
        return Icons.local_hospital_rounded;
      if (pName.contains('hotel') ||
          pName.contains('โรงแรม') ||
          pName.contains('อินน์') ||
          pName.contains('inn'))
        return Icons.hotel_rounded;
      if (pName.contains('resort') || pName.contains('รีสอร์ท'))
        return Icons.holiday_village_rounded;
      if (pName.contains('house') ||
          pName.contains('home') ||
          pName.contains('บ้าน') ||
          pName.contains('resident') ||
          pName.contains('เรสซิเดนซ์'))
        return Icons.home_rounded;
      if (pName.contains('office') ||
          pName.contains('สำนักงาน') ||
          pName.contains('ตึก') ||
          pName.contains('tower') ||
          pName.contains('ทาวเวอร์'))
        return Icons.business_rounded;
      if (pName.contains('village') ||
          pName.contains('หมู่บ้าน') ||
          pName.contains('estate'))
        return Icons.cottage_rounded;
      return Icons.apartment_rounded;
    }

    return _getIconForProjectType(typeName);
  }

  IconData _getIconForProjectType(String? projectTypeName) {
    if (projectTypeName == null || projectTypeName.isEmpty)
      return Icons.apartment_rounded;
    final name = projectTypeName.toLowerCase();
    if (name.contains('condominium') ||
        name.contains('condo') ||
        name.contains('คอนโด'))
      return Icons.apartment_rounded;
    if (name.contains('shopping') ||
        name.contains('mall') ||
        name.contains('ห้าง'))
      return Icons.shopping_bag_rounded;
    if (name.contains('hospital') || name.contains('พยาบาล'))
      return Icons.local_hospital_rounded;
    if (name.contains('private resident') ||
        name.contains('resident') ||
        name.contains('house') ||
        name.contains('home') ||
        name.contains('บ้าน'))
      return Icons.home_rounded;
    if (name.contains('office building') ||
        name.contains('office') ||
        name.contains('สำนักงาน'))
      return Icons.business_rounded;
    if (name.contains('housing estate') ||
        name.contains('housing') ||
        name.contains('หมู่บ้าน'))
      return Icons.cottage_rounded;
    if (name.contains('resort') || name.contains('รีสอร์ท'))
      return Icons.holiday_village_rounded;
    if (name.contains('hotel') || name.contains('โรงแรม'))
      return Icons.hotel_rounded;
    return Icons.domain_rounded;
  }

  Widget _buildLockedProjectUsage(dynamic project) {
    final projectId = project['id'].toString();
    final projectName = project['project_name']?.toString() ?? '-';
    final projectIcon = _getIconForProject(project);
    final areaController = widget.item.projectAreaControllers.putIfAbsent(
      projectId,
      () => TextEditingController(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(projectIcon, color: kPrimaryColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'โครงการที่เลือก',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      projectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_rounded,
                color: kPrimaryColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'จำนวนพื้นที่',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: TextFormField(
              controller: areaController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey.shade700),
                suffixText: 'ตร.ม.',
                suffixStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                filled: true,
                fillColor: kInputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "สินค้าที่ #${widget.index + 1}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                  fontSize: 16,
                ),
              ),
              if (widget.index > 0)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: widget.item.categoryId,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            isExpanded: true,
            decoration: _inputDecoration(
              "หมวดหมู่สินค้า *",
              Icons.shopping_bag_outlined,
            ),
            dropdownColor: kCardDark,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: widget.productCategories
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['id'],
                    child: Text(
                      item['name'] ?? '-',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => widget.item.categoryId = val),
            validator: (v) =>
                v == null ? 'กรุณาระบุหมวดหมู่สินค้าด้วยครับ' : null,
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: widget.item.interestLevel,
            isExpanded: true,
            decoration: _inputDecoration(
              "ระดับความชอบ",
              Icons.star_border_rounded,
            ),
            dropdownColor: kCardDark,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items:
                [
                      "สนใจมาก (มีโครงการที่อยากใช้)",
                      "สนใจมาก (แต่ยังไม่มีโครงการ)",
                      "สนใจปานกลาง",
                      "ติดตามงาน",
                      "สนใจน้อย (รูปแบบสินค้า)",
                      "สนใจน้อย (โครงการที่ทำมีงบจำกัด)",
                    ]
                    .map(
                      (level) => DropdownMenuItem<String>(
                        value: level,
                        child: Text(
                          level,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => widget.item.interestLevel = val),
          ),
          const SizedBox(height: 16),

          // 🌟 3. เพิ่ม Dropdown ประเภทโครงการ (Project Type) พร้อมไอคอนจาก Pool Project
          if (widget.projectTypes.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: widget.item.projectTypeId,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              isExpanded: true,
              decoration: _inputDecoration(
                "ประเภทโครงการ *",
                Icons.domain_rounded,
              ),
              dropdownColor: kCardDark,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: widget.projectTypes.map((item) {
                final typeName = item['name'] ?? '-';
                final icon = _getIconForProjectType(typeName);
                return DropdownMenuItem<String>(
                  value: item['id']?.toString(),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: kPrimaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          typeName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) =>
                  setState(() => widget.item.projectTypeId = val),
              validator: (v) =>
                  v == null ? 'กรุณาระบุประเภทโครงการด้วยครับ' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.item.queueLevel,
                    isExpanded: true,
                    decoration: _inputDecoration(
                      "Quarter",
                      Icons.date_range_rounded,
                    ),
                    dropdownColor: kCardDark,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Q1')),
                      DropdownMenuItem(value: '2', child: Text('Q2')),
                      DropdownMenuItem(value: '3', child: Text('Q3')),
                      DropdownMenuItem(value: '4', child: Text('Q4')),
                    ],
                    onChanged: (val) =>
                        setState(() => widget.item.queueLevel = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownSearch<String>(
                    selectedItem: widget.item.projectYearCtrl.text,
                    items: (filter, loadProps) {
                      final currentYear = DateTime.now().year;
                      final searchYear = int.tryParse(filter.trim());

                      // ค้นหาปีอนาคตใด ๆ ได้ แต่รับเฉพาะปี 4 หลักและไม่ย้อนหลัง
                      if (searchYear != null &&
                          searchYear >= currentYear &&
                          searchYear <= 9999) {
                        return [searchYear.toString()];
                      }

                      // รายการเริ่มต้นแสดงปีปัจจุบันไปข้างหน้า 100 ปี
                      return List.generate(
                        101,
                        (index) => (currentYear + index).toString(),
                      );
                    },
                    onChanged: (value) {
                      if (value != null) {
                        setState(
                          () => widget.item.projectYearCtrl.text = value,
                        );
                      }
                    },
                    decoratorProps: DropDownDecoratorProps(
                      baseStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        "ค.ศ. (คาดการณ์)",
                        Icons.event_rounded,
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      constraints: const BoxConstraints(maxHeight: 260),
                      menuProps: const MenuProps(
                        backgroundColor: kCardDark,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      itemBuilder: (context, item, isSelected, isFocused) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: widget.item.noteCtrl,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: "โน๊ต",
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              hintText: "พิมพ์รายละเอียดเพิ่มเติม...",
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 45),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: kPrimaryColor,
                ),
              ),
              filled: true,
              fillColor: kInputBg,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (widget.projects.isNotEmpty)
            widget.lockProjectSelection && widget.projects.length == 1
                ? _buildLockedProjectUsage(widget.projects.first)
                : Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "การใช้งานในโครงการ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "จำนวน / ตร.ม.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ...widget.projects.map((p) {
                          final String pid = p['id'].toString();
                          bool isChecked = widget.item.selectedProjectIds
                              .contains(pid);
                          widget.item.projectAreaControllers.putIfAbsent(
                            pid,
                            () => TextEditingController(),
                          );
                          final icon = _getIconForProject(p);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: widget.lockProjectSelection
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: kPrimaryColor,
                                          size: 23,
                                        )
                                      : Checkbox(
                                          value: isChecked,
                                          activeColor: kPrimaryColor,
                                          checkColor: Colors.black,
                                          side: const BorderSide(
                                            color: Colors.grey,
                                            width: 1.5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                widget.item.selectedProjectIds
                                                    .add(pid);
                                              } else {
                                                widget.item.selectedProjectIds
                                                    .remove(pid);
                                                widget
                                                    .item
                                                    .projectAreaControllers[pid]
                                                    ?.clear();
                                                if (widget
                                                    .item
                                                    .selectedProjectIds
                                                    .isEmpty) {
                                                  widget.item.projectTypeId =
                                                      null;
                                                }
                                              }
                                            });
                                          },
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  icon,
                                  size: 16,
                                  color: isChecked
                                      ? kPrimaryColor
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p['project_name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isChecked
                                          ? kPrimaryColor
                                          : Colors.grey,
                                      fontWeight: isChecked
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 80,
                                  height: 45,
                                  child: TextFormField(
                                    controller:
                                        widget.item.projectAreaControllers[pid],
                                    enabled: isChecked,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "0",
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                      filled: true,
                                      fillColor: isChecked
                                          ? kInputBg
                                          : Colors.transparent,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: kPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

          const SizedBox(height: 24),

          Row(
            children: const [
              Icon(Icons.photo_library_outlined, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "รูปภาพสินค้า",
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
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
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: kPrimaryColor,
                        size: 30,
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        image: DecorationImage(
                          image: FileImage(widget.item.itemImages[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 16,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => widget.item.itemImages.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
