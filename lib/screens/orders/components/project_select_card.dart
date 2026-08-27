//lib/screens/orders/components/project_select_card.dart
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);

class ProjectSelectCard extends StatelessWidget {
  final List<dynamic> projects;
  final List<dynamic> selectedProjects;
  final List<dynamic>
  projectTypes; // 🌟 รับ List ประเภทโครงการมาด้วยเพื่อ map id -> icon
  final Function(List<dynamic>) onProjectsChanged;
  final VoidCallback onAddProject;

  const ProjectSelectCard({
    super.key,
    required this.projects,
    required this.selectedProjects,
    this.projectTypes = const [],
    required this.onProjectsChanged,
    required this.onAddProject,
  });

  IconData _getIconForProject(dynamic project) {
    if (project == null) return Icons.apartment_rounded;

    // 1. ถ้ามีชื่อประเภทโครงการส่งมาตรงๆ
    String? typeName =
        project['project_type_name'] ?? project['project_types']?['name'];

    // 2. ถ้าไม่มี ให้หาจาก project_type_id ที่ตรงกับ projectTypes list
    if (typeName == null || typeName.isEmpty) {
      final typeId = project['project_type_id']?.toString();
      if (typeId != null && projectTypes.isNotEmpty) {
        final match = projectTypes.firstWhere(
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

    return _getIconByTypeName(typeName);
  }

  IconData _getIconByTypeName(String? typeName) {
    if (typeName == null || typeName.isEmpty) return Icons.apartment_rounded;
    final name = typeName.toLowerCase();
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

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: kPrimaryColor)
          : null,
      filled: true,
      fillColor: kDarkBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
    );
  }

  bool _isValidProject(dynamic project) {
    if (project == null) return false;
    final name = (project['project_name'] ?? '').toString().trim();
    if (name.isEmpty || name == '-') return false;
    final lower = name.toLowerCase();
    if (lower.contains('ไม่ระบุโครงการ') ||
        lower.contains('ไม่มีการระบุโครงการ') ||
        lower.contains('ไม่ระบุชื่อโครงการ') ||
        lower == 'ไม่ระบุ') {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "โครงการ",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          ),

          Row(
            children: [
              Expanded(
                child: DropdownSearch<dynamic>.multiSelection(
                  items: (f, l) => projects.where(_isValidProject).toList(),
                  selectedItems: selectedProjects,
                  itemAsString: (item) => item['project_name'],
                  onChanged: (val) => onProjectsChanged(val),
                  compareFn: (i, s) => i['id'] == s['id'],
                  decoratorProps: DropDownDecoratorProps(
                    baseStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration("เลือก โครงการ...", null),
                  ),
                  popupProps: PopupPropsMultiSelection.menu(
                    // 🚀 เปิดช่องค้นหาตรงนี้เลยครับ!
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "พิมพ์ชื่อเพื่อค้นหา...",
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: kDarkBg, // ใช้สีดำกลืนไปกับ UI
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    menuProps: const MenuProps(
                      backgroundColor: kCardDark,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    itemBuilder: (ctx, item, isDisabled, isSelected) {
                      final icon = _getIconForProject(item);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected
                                  ? kPrimaryColor
                                  : Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['project_name'] ?? '',
                                style: TextStyle(
                                  color: isSelected
                                      ? kPrimaryColor
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item['is_mine'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                            ],
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: kPrimaryColor,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    // 🌟 เพิ่ม Empty State กรณีพิมพ์หาแล้วไม่เจอ
                    emptyBuilder: (context, searchEntry) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "ไม่พบโครงการ (กด + ด้านบนเพื่อสร้างใหม่)",
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  dropdownBuilder: (context, selectedItems) {
                    if (selectedItems.isEmpty) return const SizedBox.shrink();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedItems.map((e) {
                        final icon = _getIconForProject(e);
                        return Chip(
                          avatar: Icon(icon, size: 14, color: kCardDark),
                          label: Text(
                            e['project_name'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kCardDark,
                            ),
                          ),
                          backgroundColor: kPrimaryColor,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onDeleted: () {
                            final newList = List<dynamic>.from(selectedProjects)
                              ..remove(e);
                            onProjectsChanged(newList);
                          },
                          deleteIcon: const Icon(
                            Icons.cancel,
                            size: 16,
                            color: Colors.black54,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildInlineAddButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAddButton() {
    return SizedBox(
      width: 44,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAddProject,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white38),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
