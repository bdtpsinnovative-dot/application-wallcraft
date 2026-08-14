//lib/screens/orders/components/project_select_card.dart
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);

class ProjectSelectCard extends StatelessWidget {
  final List<dynamic> projects;
  final List<dynamic> selectedProjects;
  final Function(List<dynamic>) onProjectsChanged;
  final VoidCallback onAddProject;

  const ProjectSelectCard({
    super.key,
    required this.projects,
    required this.selectedProjects,
    required this.onProjectsChanged,
    required this.onAddProject,
  });

  IconData _getIconForProjectType(String? projectTypeName) {
    if (projectTypeName == null || projectTypeName.isEmpty) return Icons.apartment_rounded;
    final name = projectTypeName.toLowerCase();
    if (name.contains('condominium') || name.contains('condo')) return Icons.apartment_rounded;
    if (name.contains('shopping') || name.contains('mall')) return Icons.shopping_bag_rounded;
    if (name.contains('hospital')) return Icons.local_hospital_rounded;
    if (name.contains('private resident') || name.contains('house') || name.contains('home')) return Icons.home_rounded;
    if (name.contains('office building') || name.contains('office')) return Icons.business_rounded;
    if (name.contains('housing estate') || name.contains('housing')) return Icons.cottage_rounded;
    if (name.contains('resort')) return Icons.holiday_village_rounded;
    if (name.contains('hotel')) return Icons.hotel_rounded;
    return Icons.domain_rounded;
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: kPrimaryColor) : null,
      filled: true,
      fillColor: kDarkBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
    );
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map_rounded, color: kPrimaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("โครงการ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
              
              // ปุ่มกดเพิ่มโปรเจกต์ (+)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAddProject,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.add_rounded, color: kPrimaryColor, size: 20),
                  ),
                ),
              )
            ],
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.white.withOpacity(0.1))),
          
          DropdownSearch<dynamic>.multiSelection(
            items: (f, l) => projects,
            selectedItems: selectedProjects,
            itemAsString: (item) => item['project_name'],
            onChanged: (val) => onProjectsChanged(val),
            compareFn: (i, s) => i['id'] == s['id'],
            decoratorProps: DropDownDecoratorProps(
              baseStyle: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputDecoration("เลือก โครงการ...", null),
            ),
            popupProps: PopupPropsMultiSelection.menu(
              // 🚀 เปิดช่องค้นหาตรงนี้เลยครับ!
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "พิมพ์ชื่อเพื่อค้นหา...",
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: kDarkBg, // ใช้สีดำกลืนไปกับ UI
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              menuProps: const MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.all(Radius.circular(20))),
              itemBuilder: (ctx, item, isDisabled, isSelected) {
                final ptName = item['project_type_name'] ?? item['project_types']?['name'];
                final icon = _getIconForProjectType(ptName);
                return ListTile(
                  leading: Icon(icon, color: Colors.white70, size: 18),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['project_name'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item['is_mine'] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.star, color: Colors.amber, size: 15),
                        ),
                    ],
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: kPrimaryColor, size: 18) : null,
                );
              },
              // 🌟 เพิ่ม Empty State กรณีพิมพ์หาแล้วไม่เจอ
              emptyBuilder: (context, searchEntry) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("ไม่พบโครงการ (กด + ด้านบนเพื่อสร้างใหม่)", style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ),
            ),
            dropdownBuilder: (context, selectedItems) {
              if (selectedItems.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8, runSpacing: 8,
                children: selectedItems.map((e) {
                  final ptName = e['project_type_name'] ?? e['project_types']?['name'];
                  final icon = _getIconForProjectType(ptName);
                  return Chip(
                    avatar: Icon(icon, size: 14, color: kCardDark),
                    label: Text(e['project_name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kCardDark)),
                    backgroundColor: kPrimaryColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () {
                      final newList = List<dynamic>.from(selectedProjects)..remove(e);
                      onProjectsChanged(newList);
                    },
                    deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.black54),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}