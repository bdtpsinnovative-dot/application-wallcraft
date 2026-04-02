import 'package:flutter/material.dart';

class AdminFilterModal extends StatefulWidget {
  final Map<String, dynamic> currentFilters;
  final List<dynamic> projectTypes;
  final List<dynamic> productCategories;
  final List<String> availableTeams;
  final List<String> availablePersons;
  final Function(Map<String, dynamic>) onApply;

  const AdminFilterModal({
    super.key,
    required this.currentFilters,
    required this.projectTypes,
    required this.productCategories,
    required this.availableTeams,
    required this.availablePersons,
    required this.onApply,
  });

  @override
  State<AdminFilterModal> createState() => _AdminFilterModalState();
}

class _AdminFilterModalState extends State<AdminFilterModal> {
  static const Color kDarkBg = Color(0xFF0F0F11);
  static const Color kPremiumGold = Color(0xFFFFC107);
  static const Color kCardDark = Color(0xFF1C1C1E);

  late String _currentFilter;
  late String _selectedTeam;
  late String _selectedPerson;
  late String _selectedSource;
  late String _selectedProjectType;
  late String _selectedProductCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  late TextEditingController _minAreaController;
  late TextEditingController _maxAreaController;

  @override
  void initState() {
    super.initState();
    // โหลดค่าเดิมมาแสดงใน Modal
    _currentFilter = widget.currentFilters['currentFilter'];
    _selectedTeam = widget.currentFilters['selectedTeam'];
    _selectedPerson = widget.currentFilters['selectedPerson'];
    _selectedSource = widget.currentFilters['selectedSource'];
    _selectedProjectType = widget.currentFilters['selectedProjectType'];
    _selectedProductCategory = widget.currentFilters['selectedProductCategory'];
    _startDate = widget.currentFilters['startDate'];
    _endDate = widget.currentFilters['endDate'];
    _minAreaController = TextEditingController(text: widget.currentFilters['minArea']);
    _maxAreaController = TextEditingController(text: widget.currentFilters['maxArea']);
  }

  @override
  void dispose() {
    _minAreaController.dispose();
    _maxAreaController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _currentFilter = 'all'; _selectedTeam = 'all'; _selectedPerson = 'all';
      _selectedSource = 'all'; _selectedProjectType = 'all'; _selectedProductCategory = 'all';
      _startDate = null; _endDate = null;
      _minAreaController.clear(); _maxAreaController.clear();
    });
  }

  void _apply() {
    widget.onApply({
      'currentFilter': _currentFilter, 'selectedTeam': _selectedTeam, 'selectedPerson': _selectedPerson,
      'selectedSource': _selectedSource, 'selectedProjectType': _selectedProjectType,
      'selectedProductCategory': _selectedProductCategory, 'startDate': _startDate,
      'endDate': _endDate, 'minArea': _minAreaController.text, 'maxArea': _maxAreaController.text,
    });
    Navigator.pop(context);
  }

  Widget _buildModalDropdown(List<String> values, List<String> displays, String currentValue, Function(String?) onChanged) {
    String safeValue = values.contains(currentValue) ? currentValue : (values.isNotEmpty ? values.first : '');
    if (values.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue, dropdownColor: kDarkBg, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
          items: List.generate(values.length, (index) => DropdownMenuItem(value: values[index], child: Text(displays[index], style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis))),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilterSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white54, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold))]), const SizedBox(height: 16), child]),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> pTypeValues = ['all', ...widget.projectTypes.map((e) => e['id'].toString())];
    List<String> pTypeDisplays = ['ทุกประเภท', ...widget.projectTypes.map((e) => e['name'].toString())];
    List<String> pCatValues = ['all', ...widget.productCategories.map((e) => e['id'].toString())];
    List<String> pCatDisplays = ['ทุกสินค้า', ...widget.productCategories.map((e) => e['name'].toString())];

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(color: kCardDark, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(Icons.tune_rounded, color: kPremiumGold, size: 24), SizedBox(width: 10), Text("ตัวกรองข้อมูลเชิงลึก", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
              TextButton.icon(onPressed: _resetFilters, icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 16), label: const Text("รีเซ็ต", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView( 
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: "ระยะเวลา & แหล่งที่มา", icon: Icons.calendar_month_rounded,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildModalDropdown(["all", "daily", "weekly", "monthly"], ["ทุกช่วงเวลา", "วันนี้", "7 วันล่าสุด", "เดือนนี้"], _currentFilter, (val) => setState(() { _currentFilter = val!; _startDate = null; _endDate = null; }))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildModalDropdown(['all', 'APP', 'IMPORT'], ['ทุกแหล่งที่มา', '📱 ผ่านแอปฯ', '📁 นำเข้าไฟล์'], _selectedSource, (val) => setState(() => _selectedSource = val!))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Align(alignment: Alignment.centerLeft, child: Text("หรือกำหนดวันที่ชัดเจน:", style: TextStyle(color: Colors.white54, fontSize: 12))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                                  if (picked != null) setState(() { _startDate = picked; _currentFilter = 'custom'; });
                                },
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _startDate != null ? kPremiumGold.withOpacity(0.5) : Colors.white10)), child: Center(child: Text(_startDate == null ? "วันเริ่มต้น" : "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}", style: TextStyle(color: _startDate == null ? Colors.white30 : kPremiumGold, fontSize: 14, fontWeight: _startDate != null ? FontWeight.bold : FontWeight.normal)))),
                            )),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("ถึง", style: TextStyle(color: Colors.white54))),
                            Expanded(child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                                  if (picked != null) setState(() { _endDate = picked; _currentFilter = 'custom'; });
                                },
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _endDate != null ? kPremiumGold.withOpacity(0.5) : Colors.white10)), child: Center(child: Text(_endDate == null ? "วันสิ้นสุด" : "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}", style: TextStyle(color: _endDate == null ? Colors.white30 : kPremiumGold, fontSize: 14, fontWeight: _endDate != null ? FontWeight.bold : FontWeight.normal)))),
                            )),
                          ],
                        ),
                      ],
                    )
                  ),
                  _buildFilterSection(
                    title: "ข้อมูลโครงการ & สินค้า", icon: Icons.maps_home_work_rounded,
                    child: Column(
                      children: [
                        _buildModalDropdown(pTypeValues, pTypeDisplays, _selectedProjectType, (val) => setState(() => _selectedProjectType = val!)),
                        const SizedBox(height: 12),
                        _buildModalDropdown(pCatValues, pCatDisplays, _selectedProductCategory, (val) => setState(() => _selectedProductCategory = val!)),
                        const SizedBox(height: 16),
                        const Align(alignment: Alignment.centerLeft, child: Text("ขนาดพื้นที่ (ตร.ม.)", style: TextStyle(color: Colors.white54, fontSize: 12))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _minAreaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: "ขั้นต่ำ", hintStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: kDarkBg, prefixIcon: const Icon(Icons.square_foot_rounded, color: Colors.white24, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold))))),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("-", style: TextStyle(color: Colors.white54))),
                            Expanded(child: TextField(controller: _maxAreaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: "สูงสุด", hintStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: kDarkBg, prefixIcon: const Icon(Icons.square_foot_rounded, color: Colors.white24, size: 18), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold))))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildFilterSection(
                    title: "ทีมงาน & ผู้รับผิดชอบ", icon: Icons.groups_rounded,
                    child: Row(
                      children: [
                        Expanded(child: _buildModalDropdown(['all', ...widget.availableTeams], ['ทุกทีม', ...widget.availableTeams], _selectedTeam, (val) => setState(() { _selectedTeam = val!; _selectedPerson = 'all'; }))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildModalDropdown(['all', ...widget.availablePersons], ['ทุกคน', ...widget.availablePersons], _selectedPerson, (val) => setState(() { _selectedPerson = val!; _selectedTeam = 'all'; }))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity, padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 5),
              onPressed: _apply,
              icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.black),
              label: const Text("ใช้ตัวกรองข้อมูล", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}