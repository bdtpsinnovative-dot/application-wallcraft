import 'package:flutter/material.dart';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107); 
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolFilterSheet extends StatefulWidget {
  final String initialSearchQuery;
  final String initialDateRange;
  final List<String> availableCategories;
  final List<String> selectedCategories;
  final List<String> availableSaleNames;
  final List<String> selectedSaleNames;
  final List<String> areaRanges;
  final List<String> selectedAreaRanges;
  final List<String> dateRanges;
  final List<String> availableProjectTypes;
  final List<String> selectedProjectTypes;
  final Function(Map<String, dynamic>) onApply;

  const PoolFilterSheet({
    super.key,
    required this.initialSearchQuery,
    required this.initialDateRange,
    required this.availableCategories,
    required this.selectedCategories,
    required this.availableSaleNames,
    required this.selectedSaleNames,
    required this.areaRanges,
    required this.selectedAreaRanges,
    required this.dateRanges,
    required this.availableProjectTypes,
    required this.selectedProjectTypes,
    required this.onApply,
  });

  @override
  State<PoolFilterSheet> createState() => _PoolFilterSheetState();
}

class _PoolFilterSheetState extends State<PoolFilterSheet> {
  late TextEditingController searchCtrl;
  late String tempDateRange;
  late List<String> tempCategories;
  late List<String> tempSaleNames;
  late List<String> tempAreaRanges;
  late List<String> tempProjectTypes;

  @override
  void initState() {
    super.initState();
    searchCtrl = TextEditingController(text: widget.initialSearchQuery);
    tempDateRange = widget.initialDateRange;
    tempCategories = List.from(widget.selectedCategories);
    tempSaleNames = List.from(widget.selectedSaleNames);
    tempAreaRanges = List.from(widget.selectedAreaRanges);
    tempProjectTypes = List.from(widget.selectedProjectTypes);
  }

  IconData _getIconForProjectType(String? projectTypeName) {
    if (projectTypeName == null || projectTypeName.isEmpty) return Icons.receipt_long_rounded;
    if (projectTypeName.contains('Condominium')) return Icons.apartment_rounded;
    if (projectTypeName.contains('Shopping Mall')) return Icons.shopping_bag_rounded;
    if (projectTypeName.contains('Hospital')) return Icons.local_hospital_rounded;
    if (projectTypeName.contains('Private Resident')) return Icons.home_rounded;
    if (projectTypeName.contains('Office Building')) return Icons.business_rounded;
    if (projectTypeName.contains('Housing Estate')) return Icons.cottage_rounded;
    if (projectTypeName.contains('Resort')) return Icons.holiday_village_rounded;
    if (projectTypeName.contains('Hotel')) return Icons.hotel_rounded;
    return Icons.receipt_long_rounded; 
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      padding: EdgeInsets.only(top: 16, bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 16),
          const Text("ค้นหา & ตัวกรอง", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white12, height: 30),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "ค้นหาชื่อลูกค้า, บริษัท, โครงการ...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.search_rounded, color: kNeonPurple),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kNeonPurple)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildFilterSection(
                    title: "ช่วงเวลา (Date Range)",
                    options: widget.dateRanges,
                    selectedOptions: tempDateRange.isNotEmpty ? [tempDateRange] : [],
                    onSelect: (val) {
                      setState(() {
                        if (tempDateRange == val) tempDateRange = '';
                        else tempDateRange = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildFilterSection(
                    title: "ประเภทโครงการ (Project Type)",
                    options: widget.availableProjectTypes,
                    selectedOptions: tempProjectTypes,
                    iconBuilder: _getIconForProjectType, 
                    onSelect: (val) {
                      setState(() {
                        if (tempProjectTypes.contains(val)) tempProjectTypes.remove(val);
                        else tempProjectTypes.add(val);
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildFilterSection(
                    title: "ประเภทสินค้า (Product)",
                    options: widget.availableCategories,
                    selectedOptions: tempCategories,
                    onSelect: (val) {
                      setState(() {
                        if (tempCategories.contains(val)) tempCategories.remove(val);
                        else tempCategories.add(val);
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  _buildFilterSection(
                    title: "ชื่อเซลล์ (Salesperson)",
                    options: widget.availableSaleNames,
                    selectedOptions: tempSaleNames,
                    onSelect: (val) {
                      setState(() {
                        if (tempSaleNames.contains(val)) tempSaleNames.remove(val);
                        else tempSaleNames.add(val);
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  _buildFilterSection(
                    title: "ขนาดพื้นที่ (Area Sq.m.)",
                    options: widget.areaRanges,
                    selectedOptions: tempAreaRanges,
                    onSelect: (val) {
                      setState(() {
                        if (tempAreaRanges.contains(val)) tempAreaRanges.remove(val);
                        else tempAreaRanges.add(val);
                      });
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: kDarkBg,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[700]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        tempCategories.clear();
                        tempSaleNames.clear();
                        tempAreaRanges.clear();
                        tempProjectTypes.clear(); 
                        tempDateRange = ''; 
                        searchCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                    label: const Text("ล้าง", style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: kNeonPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      widget.onApply({
                        'categories': tempCategories,
                        'saleNames': tempSaleNames,
                        'areaRanges': tempAreaRanges,
                        'projectTypes': tempProjectTypes,
                        'dateRange': tempDateRange,
                        'searchQuery': searchCtrl.text.trim(),
                      });
                      Navigator.pop(context);
                    },
                    child: const Text("ค้นหา", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title, 
    required List<String> options, 
    required List<String> selectedOptions, 
    required Function(String) onSelect,
    IconData? Function(String)? iconBuilder,
  }) {
    if (options.isEmpty) return const SizedBox(); 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: kPremiumGold, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: options.map((option) {
            final isSelected = selectedOptions.contains(option);
            final customIcon = iconBuilder != null ? iconBuilder(option) : null;

            return InkWell(
              onTap: () => onSelect(option),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? kNeonPurple.withOpacity(0.2) : Colors.transparent,
                  border: Border.all(color: isSelected ? kNeonPurple : Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, size: 14, color: kNeonPurple),
                      const SizedBox(width: 6),
                    ] else if (customIcon != null) ...[
                      Icon(customIcon, size: 14, color: Colors.white54),
                      const SizedBox(width: 6),
                    ],
                    Text(option, style: TextStyle(color: isSelected ? kNeonPurple : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}