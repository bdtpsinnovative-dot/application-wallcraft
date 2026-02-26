// lib/screens/orders/components/customer_info_card.dart
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);

class CustomerInfoCard extends StatelessWidget {
  final List<dynamic> customerTypes;
  final String? selectedCustomerType;
  final Function(String?) onCustomerTypeChanged;
  final GlobalKey<DropdownSearchState<dynamic>> companyDropdownKey;
  final Future<List<dynamic>> Function(String) getCompanies;
  
  // 🔥 ยืนยันให้เป็น String? เพื่อรับ UUID 
  final String? selectedCompany; 
  final Function(String?) onCompanyChanged; 

  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;

  const CustomerInfoCard({
    super.key,
    required this.customerTypes,
    required this.selectedCustomerType,
    required this.onCustomerTypeChanged,
    required this.companyDropdownKey,
    required this.getCompanies,
    required this.selectedCompany,
    required this.onCompanyChanged,
    required this.nameCtrl,
    required this.contactCtrl,
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
                child: const Icon(Icons.person_pin_rounded, color: kPrimaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("ข้อมูลการติดต่อ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Colors.white.withOpacity(0.1))),
          
          // เลือกประเภทลูกค้า
          DropdownButtonFormField<String>(
            value: customerTypes.any((item) => item['id'] == selectedCustomerType) ? selectedCustomerType : null,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kPrimaryColor, size: 28),
            decoration: _inputDecoration("ประเภทลูกค้า *", Icons.category_rounded),
            dropdownColor: kCardDark,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: customerTypes.map((item) => DropdownMenuItem<String>(
              value: item['id'].toString(), // 🌟 ป้องกันกรณี id ไม่ใช่ String
              child: Text(item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
            )).toList(),
            onChanged: onCustomerTypeChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
          
          // เลือกบริษัท
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            child: selectedCustomerType != null 
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: DropdownSearch<dynamic>(
                    key: companyDropdownKey, 
                    items: (filter, loadProps) => getCompanies(filter),
                    itemAsString: (item) => item['name'] ?? '',
                    
                    // 🔥 จุดสำคัญ: ดึง id ออกมาแปลงเป็น String ก่อนส่งกลับไป
                    onChanged: (val) {
                      if (val != null && val is Map && val.containsKey('id')) {
                        onCompanyChanged(val['id'].toString());
                      } else {
                        onCompanyChanged(null);
                      }
                    },
                    
                    compareFn: (i, s) {
                       // 🌟 ปรับ compareFn ให้เทียบค่า String ให้ชัวร์
                       if (i == null || s == null) return false;
                       
                       // กรณี s (selected) ส่งมาเป็น String ID เพียวๆ แล้ว
                       if (s is String) {
                          return i['id'].toString() == s;
                       }
                       // กรณี s (selected) เป็น Map
                       if (s is Map && i is Map) {
                          return i['id'].toString() == s['id'].toString();
                       }
                       return false;
                    },
                    
                    decoratorProps: DropDownDecoratorProps(decoration: _inputDecoration("เลือกบริษัท *", Icons.business_rounded)),
                    
                    dropdownBuilder: (context, selectedItem) {
                      if (selectedItem == null) return const SizedBox.shrink();
                      
                      // 🌟 ดักกรณีที่ selectedItem กลายเป็น String ID ไปแล้ว
                      if (selectedItem is String) {
                          return const Text("เลือกบริษัทแล้ว", style: TextStyle(color: Colors.white, fontSize: 16));
                      }
                      
                      return Text(selectedItem['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16));
                    },
                    
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      menuProps: const MenuProps(backgroundColor: kCardDark, borderRadius: BorderRadius.all(Radius.circular(20))),
                      searchFieldProps: TextFieldProps(
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("ค้นหาชื่อบริษัท...", Icons.search),
                      ),
                      itemBuilder: (ctx, item, isDisabled, isSelected) => ListTile(
                        title: Text(item['name'] ?? '', style: TextStyle(color: isSelected ? kPrimaryColor : Colors.white)),
                        selected: isSelected,
                      ),
                    ),
                  )
                )
              : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          // ชื่อลูกค้า
          TextFormField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("ชื่อลูกค้า", Icons.badge_rounded),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // เบอร์โทร
          TextFormField(
            controller: contactCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("เบอร์โทรศัพท์ & Line ID", Icons.phone_iphone_rounded),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}