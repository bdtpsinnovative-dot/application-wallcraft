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

    InputDecoration _inputDecoration(String hint, IconData? icon) {
        return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: Colors.grey[600]),
        prefixIcon: icon != null ? Icon(icon, size: 22, color: kPrimaryColor) : null,
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
                    child: const Icon(Icons.map_rounded, color: kPrimaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text("โครงการ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                
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
                        child: const Icon(Icons.add_rounded, color: kPrimaryColor, size: 22),
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
                decoratorProps: DropDownDecoratorProps(decoration: _inputDecoration("เลือก โครงการ...", null)),
                popupProps: PopupPropsMultiSelection.menu(
                menuProps: const MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.all(Radius.circular(20))),
                itemBuilder: (ctx, item, isDisabled, isSelected) => ListTile(
                    title: Text(item['project_name'], style: const TextStyle(color: Colors.white)),
                    trailing: isSelected ? const Icon(Icons.check, color: kPrimaryColor) : null,
                ),
                ),
                dropdownBuilder: (context, selectedItems) {
                if (selectedItems.isEmpty) return const SizedBox.shrink();
                return Wrap(
                    spacing: 8, runSpacing: 8,
                    children: selectedItems.map((e) => Chip(
                    label: Text(e['project_name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kCardDark)),
                    backgroundColor: kPrimaryColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () {
                        final newList = List<dynamic>.from(selectedProjects)..remove(e);
                        onProjectsChanged(newList);
                    },
                    deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.black54),
                    )).toList(),
                );
                },
            ),
            ],
        ),
        );
    }
    }