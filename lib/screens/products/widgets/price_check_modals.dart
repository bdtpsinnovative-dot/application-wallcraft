import 'package:flutter/material.dart';

const Color kCardDark = Color(0xFF1C1C1E); 
const Color kAccentColor = Color(0xFFC6A87C);

// 1. ฟังก์ชันแสดง Modal เลือกหมวดหมู่
void showCategoryFilterModal({
  required BuildContext context,
  required String selectedCategory,
  required Map<String, List<String>> categoryGroups,
  required Function(String) onCategorySelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true, 
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.75, 
        decoration: const BoxDecoration(
          color: Color(0xFF151517),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Container(
              width: 45, height: 5,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            const Text(
              "SELECT CATEGORY",
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  // ปุ่ม "ทั้งหมด" ปรับให้มี Effect เวลากด
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context); 
                        onCategorySelected('ทั้งหมด');
                      },
                      borderRadius: BorderRadius.circular(16),
                      splashColor: Colors.white.withOpacity(0.1),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedCategory == 'ทั้งหมด' ? kAccentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedCategory == 'ทั้งหมด' ? kAccentColor : Colors.white24),
                        ),
                        child: Text(
                          "แสดงสินค้าทั้งหมด",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selectedCategory == 'ทั้งหมด' ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ...categoryGroups.entries.map((group) {
                    final isGroupSelected = selectedCategory == group.key;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 ปุ่มเลือกหมวดหมู่ใหญ่ที่ปรับปรุงใหม่ให้ดู "น่ากด"
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              onCategorySelected(group.key);
                            },
                            borderRadius: BorderRadius.circular(16),
                            splashColor: kAccentColor.withOpacity(0.2), // แสงตอนกดเป็นสีทอง
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isGroupSelected ? kAccentColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isGroupSelected ? kAccentColor : Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: isGroupSelected ? [
                                  BoxShadow(color: kAccentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                                ] : [],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.layers_outlined, color: isGroupSelected ? Colors.black : Colors.white70, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    "ดูทั้งหมดใน ${group.key}",
                                    style: TextStyle(
                                      color: isGroupSelected ? Colors.black : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  // ไอคอนวงกลมบอกให้รู้ว่ากดได้
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isGroupSelected ? Colors.black26 : Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isGroupSelected ? Icons.check_rounded : Icons.keyboard_arrow_right_rounded, 
                                      color: isGroupSelected ? Colors.black : Colors.white70, 
                                      size: 16
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // ป้ายกำกับ (Chip) หมวดย่อย
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: group.value.map((colName) {
                            final isSelected = selectedCategory == colName;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context); 
                                  onCategorySelected(colName);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? kAccentColor : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? kAccentColor : Colors.transparent),
                                  ),
                                  child: Text(
                                    colName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// 2. ฟังก์ชันแสดงรายละเอียดรุ่นย่อย
void showVariantDetailsModal({
  required BuildContext context,
  required Map<String, dynamic> product,
  required String Function(dynamic) formatPrice,
}) {
  List<Map<String, dynamic>> allVariants = List<Map<String, dynamic>>.from(product['variants']);
  allVariants.sort((a, b) => ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));

  Set<String> uniqueFilms = {'ทั้งหมด'};
  for (var v in allVariants) {
    String filmName = v['film']?.toString().trim() ?? '';
    if (filmName.isNotEmpty) uniqueFilms.add(filmName);
  }
  List<String> filterOptions = uniqueFilms.toList();
  String selectedFilter = 'ทั้งหมด';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          List<Map<String, dynamic>> displayVariants = allVariants.where((v) {
            if (selectedFilter == 'ทั้งหมด') return true;
            return (v['film']?.toString().trim() ?? '') == selectedFilter;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFF151517),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 45, height: 5,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['collection'].toString().toUpperCase(), 
                              style: const TextStyle(color: kAccentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 4),
                            Text(product['name'], 
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (filterOptions.length > 1)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: filterOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        bool isSelected = selectedFilter == filterOptions[index];
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedFilter = filterOptions[index]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? kAccentColor : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(filterOptions[index],
                              style: TextStyle(color: isSelected ? Colors.black : Colors.white70, 
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 20),
                const Divider(color: Colors.white10, height: 1),
                
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayVariants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final v = displayVariants[index];
                      final patternName = v['pattern'] ?? v['color'] ?? 'Standard';
                      
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kCardDark,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 65, height: 65,
                                color: Colors.black38,
                                child: (v['variant_image'] != null)
                                  ? Image.network(v['variant_image'], fit: BoxFit.cover)
                                  : const Icon(Icons.image, color: Colors.white12),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(patternName, 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text("${v['film'] ?? ''}", 
                                    style: TextStyle(color: kAccentColor.withOpacity(0.8), fontSize: 12)),
                                  Text("${v['thickness_mm']}mm | ${v['width_mm']}x${v['length_mm']}mm", 
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                            
                            Text(
                              "฿${formatPrice(v['price'])}",
                              style: const TextStyle(color: kAccentColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
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
      );
    },
  );
}