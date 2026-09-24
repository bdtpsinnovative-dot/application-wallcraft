import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

// 🎨 Palette สี
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPrimaryColor = Color(0xFFFFFFFF);
const Color kDarkBg = Color(0xFF000000);
const Color kLimeGreen = Color(0xFFD2E862);

// -----------------------------------------------------------------------
// 🛠️ Widget CustomerInfoCard (ฉบับรองรับบริษัท 1,000+ ชื่อ พร้อมช่องค้นหา)
// -----------------------------------------------------------------------
class CustomerInfoCard extends StatelessWidget {
  final List<dynamic> customerTypes;
  final String? selectedCustomerType;
  final Function(String?) onCustomerTypeChanged;
  final GlobalKey<DropdownSearchState<dynamic>> companyDropdownKey;
  final Future<List<dynamic>> Function(String) getCompanies;
  final Map<String, dynamic>? selectedCompany;
  final Function(dynamic) onCompanyChanged;
  final TextEditingController nameCtrl;
  final TextEditingController contactCtrl;
  final VoidCallback onAddCustomerType;
  final VoidCallback onAddCompany;

  const CustomerInfoCard({
    super.key,
    required this.customerTypes,
    this.selectedCustomerType,
    required this.onCustomerTypeChanged,
    required this.companyDropdownKey,
    required this.getCompanies,
    this.selectedCompany,
    required this.onCompanyChanged,
    required this.nameCtrl,
    required this.contactCtrl,
    required this.onAddCustomerType,
    required this.onAddCompany,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomerTypeLocked = selectedCompany != null &&
        selectedCompany!['customer_type_id'] != null &&
        selectedCompany!['customer_type_id'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
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
                  Icons.person_pin_rounded,
                  color: kPrimaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "ข้อมูลการติดต่อ",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'บริษัท *',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownSearch<dynamic>(
                  key: companyDropdownKey,
                  items: (filter, loadProps) => getCompanies(filter),
                  itemAsString: (item) => item?['name']?.toString() ?? '',
                  selectedItem: selectedCompany,
                  onChanged: (val) {
                    if (val == null) {
                      onCompanyChanged(null);
                    } else if (val is Map) {
                      onCompanyChanged(Map<String, dynamic>.from(val));
                    } else {
                      onCompanyChanged(val);
                    }
                  },
                  compareFn: (i1, i2) {
                    if (i1 == null && i2 == null) return true;
                    if (i1 == null || i2 == null) return false;
                    final id1 = i1['id']?.toString();
                    final id2 = i2['id']?.toString();
                    if (id1 != null && id2 != null) return id1 == id2;
                    return i1['name'] == i2['name'];
                  },
                  decoratorProps: DropDownDecoratorProps(
                    baseStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(
                      "ค้นหา/เลือกบริษัท",
                      Icons.business_rounded,
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true, // 🌟 ช่องค้นหาสำหรับบริษัทจำนวนมาก
                    disableFilter:
                        true, // 🌟 ให้ใช้ผลลัพธ์และการเรียงลำดับตามพิกัด/ความถี่จาก _getCompanies โดยตรง
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 60,
                      maxWidth: MediaQuery.of(context).size.width - 60,
                      maxHeight: 350,
                    ),
                    menuProps: const MenuProps(
                      backgroundColor: kCardDark,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    searchFieldProps: TextFieldProps(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _inputDecoration(
                        "พิมพ์ชื่อบริษัทเพื่อค้นหา...",
                        Icons.search,
                      ),
                    ),
                    itemBuilder: (context, item, isSelected, isFocused) {
                      if (item == null) return const SizedBox();

                      bool isVisitPlan = item['is_visit_plan'] == true;
                      bool isVisitPlanOverdue =
                          item['is_visit_plan_overdue'] == true;
                      bool isPipeline = item['is_pipeline'] == true;
                      bool isNearby = item['is_nearby'] == true;
                      bool isTeam =
                          item['is_team'] == true && item['is_mine'] != true;
                      bool isGlobal =
                          item['is_global'] == true && item['is_mine'] != true;
                      bool isMine =
                          item['is_mine'] == true ||
                          (isPipeline && !isTeam && !isGlobal);
                      bool isGeneral =
                          item['is_general'] == true ||
                          (!isPipeline && !isVisitPlan);
                      final planDate = DateTime.tryParse(
                        item['visit_plan_data']?['planned_date']?.toString() ??
                            '',
                      );
                      final visitPlanDateLabel = planDate == null
                          ? ''
                          : '${planDate.day}/${planDate.month}/${(planDate.year + 543) % 100}';

                      int projCount = isPipeline && item['projects'] != null
                          ? (item['projects'] as List).length
                          : 0;

                      // 🌟 ไอคอนนำหน้าบอกประเภทบริษัททันที (ของเรา / ของทีม / ส่วนกลาง / แผนงาน / ทั่วไป)
                      IconData leadingIcon = Icons.domain_outlined;
                      Color leadingColor = Colors.white30;
                      if (isVisitPlan) {
                        leadingIcon = isVisitPlanOverdue
                            ? Icons.warning_rounded
                            : Icons.calendar_month_rounded;
                        leadingColor = isVisitPlanOverdue
                            ? Colors.redAccent
                            : Colors.greenAccent;
                      } else if (isMine) {
                        leadingIcon = Icons.business_rounded;
                        leadingColor = Colors.amber;
                      } else if (isTeam) {
                        leadingIcon = Icons.people_alt_rounded;
                        leadingColor = Colors.orangeAccent;
                      } else if (isGlobal) {
                        leadingIcon = Icons.public_rounded;
                        leadingColor = Colors.tealAccent;
                      }

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
                          color: isVisitPlan
                              ? (isVisitPlanOverdue
                                    ? Colors.redAccent.withOpacity(0.14)
                                    : Colors.green.withOpacity(0.1))
                              : (isPipeline
                                    ? Colors.indigo.withOpacity(0.08)
                                    : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              leadingIcon,
                              color: leadingColor,
                              size: isGeneral ? 15 : 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? kLimeGreen
                                      : (isVisitPlanOverdue
                                            ? Colors.redAccent
                                            : (isGeneral
                                                  ? Colors.white70
                                                  : Colors.white)),
                                  fontWeight: (isPipeline || isVisitPlan)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isNearby && isPipeline && projCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.amber.withOpacity(0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              Positioned(
                                                top: 2,
                                                child: Icon(
                                                  Icons.location_on,
                                                  color: Colors.redAccent,
                                                  size: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          "$projCount",
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else ...[
                                  if (isVisitPlan)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isVisitPlanOverdue
                                                    ? Colors.redAccent
                                                    : Colors.greenAccent)
                                                .withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        visitPlanDateLabel,
                                        style: TextStyle(
                                          color: isVisitPlanOverdue
                                              ? Colors.redAccent
                                              : Colors.greenAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (isNearby)
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.redAccent,
                                        size: 12,
                                      ),
                                    ),
                                  if (isPipeline && projCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "$projCount",
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildInlineAddButton(onAddCompany),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value:
                      customerTypes.any(
                        (item) => item['id'].toString() == selectedCustomerType,
                      )
                      ? selectedCustomerType
                      : null,
                  isExpanded: true,
                  icon: Icon(
                    isCustomerTypeLocked
                        ? Icons.lock_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isCustomerTypeLocked
                        ? Colors.white54
                        : kPrimaryColor,
                    size: isCustomerTypeLocked ? 18 : 24,
                  ),
                  decoration: _inputDecoration(
                    isCustomerTypeLocked
                        ? "ประเภทลูกค้า (ตามบริษัท)"
                        : (selectedCompany != null
                              ? "เลือกประเภทลูกค้า (บริษัทนี้ยังไม่มีประเภท)"
                              : "ประเภทลูกค้า (ระบุหรือไม่ก็ได้)"),
                    Icons.category_rounded,
                  ),
                  dropdownColor: kCardDark,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: customerTypes
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item['id'].toString(),
                          child: Text(
                            item['name'] ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isCustomerTypeLocked
                      ? null
                      : onCustomerTypeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration("ชื่อลูกค้า", Icons.badge_rounded),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: contactCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration(
              "เบอร์โทรศัพท์",
              Icons.phone_iphone_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInlineAddButton(VoidCallback onTap) {
  return SizedBox(
    width: 44,
    height: 48,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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

// 🎨 Helper Decoration
InputDecoration _inputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
    prefixIcon: Icon(icon, size: 20, color: kPrimaryColor),
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
