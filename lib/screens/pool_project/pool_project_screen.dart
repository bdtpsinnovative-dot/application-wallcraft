import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../services/api_service.dart';
import 'pool_project_detail_screen.dart'; 

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107); 
const Color kNeonPurple = Color(0xFFB52BFF);

class PoolProjectScreen extends StatefulWidget {
  const PoolProjectScreen({super.key});

  @override
  State<PoolProjectScreen> createState() => _PoolProjectScreenState();
}

class _PoolProjectScreenState extends State<PoolProjectScreen> {
  List<dynamic> _allSubProjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<String> _selectedCategories = [];
  List<String> _availableCategories = [];

  List<String> _selectedSaleNames = [];
  List<String> _availableSaleNames = [];

  List<String> _selectedAreaRanges = [];
  final List<String> _areaRanges = [
    'น้อยกว่า 50 sq.m.',
    '50 - 200 sq.m.',
    '201 - 500 sq.m.',
    'มากกว่า 500 sq.m.'
  ];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects?page=1&limit=50');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> rawData = result is List ? result : (result['data'] ?? []);

        List<dynamic> tempProjects = [];
        Set<String> tempCategories = {}; 
        Set<String> tempSaleNames = {};

        for (var item in rawData) {
          final oip = item['order_item_projects'];
          final categoryName = item['product_categories']?['name'] ?? 'ไม่ระบุสินค้า';
          final saleName = item['orders']?['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';

          if (oip != null && oip is List && oip.isNotEmpty) {
            for (var projectRelation in oip) {
              var newItem = Map<String, dynamic>.from(item);
              newItem['display_project_name'] = projectRelation['projects']?['project_name'] ?? 'ไม่ได้ระบุชื่อ';
              newItem['specific_project_data'] = projectRelation;
              tempProjects.add(newItem);
              
              tempCategories.add(categoryName);
              tempSaleNames.add(saleName);
            }
          } else {
            var newItem = Map<String, dynamic>.from(item);
            newItem['display_project_name'] = 'ไม่ได้ระบุโครงการ';
            newItem['specific_project_data'] = {};
            tempProjects.add(newItem);
            
            tempCategories.add(categoryName);
            tempSaleNames.add(saleName);
          }
        }

        setState(() {
          _allSubProjects = tempProjects;
          _availableCategories = tempCategories.toList();
          _availableSaleNames = tempSaleNames.toList();
          
          _selectedCategories.removeWhere((item) => !_availableCategories.contains(item));
          _selectedSaleNames.removeWhere((item) => !_availableSaleNames.contains(item));
          
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } on SocketException {
      setState(() => _errorMessage = "ไม่มีการเชื่อมต่ออินเทอร์เน็ต");
    } on TimeoutException {
      setState(() => _errorMessage = "เซิร์ฟเวอร์ตอบสนองช้าเกินไป");
    } catch (e) {
      setState(() => _errorMessage = "เกิดข้อผิดพลาดในการโหลดข้อมูล");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFilterSheet() {
    List<String> tempCategories = List.from(_selectedCategories);
    List<String> tempSaleNames = List.from(_selectedSaleNames);
    List<String> tempAreaRanges = List.from(_selectedAreaRanges);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75, 
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                color: kCardDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  const Text("ตัวกรองโครงการ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white12, height: 30),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              
                            ],
                          ),
                          const SizedBox(height: 16),

                          _buildFilterSection(
                            title: "ประเภทสินค้า (Product)",
                            options: _availableCategories,
                            selectedOptions: tempCategories,
                            onSelect: (val) {
                              setModalState(() {
                                if (tempCategories.contains(val)) tempCategories.remove(val);
                                else tempCategories.add(val);
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFilterSection(
                            title: "ชื่อเซลล์ (Salesperson)",
                            options: _availableSaleNames,
                            selectedOptions: tempSaleNames,
                            onSelect: (val) {
                              setModalState(() {
                                if (tempSaleNames.contains(val)) tempSaleNames.remove(val);
                                else tempSaleNames.add(val);
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFilterSection(
                            title: "ขนาดพื้นที่ (Area Sq.m.)",
                            options: _areaRanges,
                            selectedOptions: tempAreaRanges,
                            onSelect: (val) {
                              setModalState(() {
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
                          // ✨ เปลี่ยนเป็นปุ่มแบบมีไอคอนถังขยะ
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey[700]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                tempCategories.clear();
                                tempSaleNames.clear();
                                tempAreaRanges.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                            label: const Text("ล้างทั้งหมด", style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: kNeonPurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCategories = List.from(tempCategories);
                                _selectedSaleNames = List.from(tempSaleNames);
                                _selectedAreaRanges = List.from(tempAreaRanges);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text("นำไปใช้", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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

  Widget _buildFilterSection({required String title, required List<String> options, required List<String> selectedOptions, required Function(String) onSelect}) {
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
                      const SizedBox(width: 4),
                    ],
                    Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? kNeonPurple : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasActiveFilter = _selectedCategories.isNotEmpty || _selectedSaleNames.isNotEmpty || _selectedAreaRanges.isNotEmpty;

    final displayProjects = _allSubProjects.where((item) {
      final cat = item['product_categories']?['name'] ?? 'ไม่ระบุสินค้า';
      final sale = item['orders']?['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์';
      final areaStr = item['specific_project_data']?['area_sqm']?.toString() ?? '0';
      final area = double.tryParse(areaStr) ?? 0;

      bool passCat = _selectedCategories.isEmpty || _selectedCategories.contains(cat);
      bool passSale = _selectedSaleNames.isEmpty || _selectedSaleNames.contains(sale);
      
      bool passArea = _selectedAreaRanges.isEmpty;
      if (!passArea) {
        for (String range in _selectedAreaRanges) {
          if (range == 'น้อยกว่า 50 sq.m.' && area < 50) passArea = true;
          else if (range == '50 - 200 sq.m.' && area >= 50 && area <= 200) passArea = true;
          else if (range == '201 - 500 sq.m.' && area > 200 && area <= 500) passArea = true;
          else if (range == 'มากกว่า 500 sq.m.' && area > 500) passArea = true;
        }
      }

      return passCat && passSale && passArea;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.2)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: kDarkBg.withOpacity(0.9),
                  expandedHeight: 70,
                  toolbarHeight: 70,
                  pinned: true,
                  elevation: 4,
                  centerTitle: true,
                  title: const Text(
                    "Pool Projects",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            hasActiveFilter ? Icons.filter_list_alt : Icons.filter_list_rounded,
                            color: hasActiveFilter ? kPremiumGold : Colors.white, 
                            size: 26,
                          ),
                          tooltip: "ตัวกรอง",
                          onPressed: _showFilterSheet,
                        ),
                        if (hasActiveFilter)
                          Positioned(
                            top: 12, right: 12,
                            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                          )
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                
                if (hasActiveFilter && !_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: kPremiumGold, size: 16),
                          const SizedBox(width: 6),
                          Text("พบ ${displayProjects.length} รายการ จากตัวกรอง", style: const TextStyle(color: kPremiumGold, fontSize: 13, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategories.clear();
                                _selectedSaleNames.clear();
                                _selectedAreaRanges.clear();
                              });
                            },
                            // ✨ ใส่ไอคอนถังขยะตรงข้อความแจ้งเตือนด้วย
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 4),
                                
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                if (_isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kNeonPurple)))
                else if (_errorMessage != null)
                  SliverFillRemaining(child: _buildErrorState())
                else if (displayProjects.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text(
                            hasActiveFilter ? "ไม่พบโปรเจกต์ที่ตรงกับตัวกรอง" : "ยังไม่มีโปรเจกต์ในระบบ", 
                            style: const TextStyle(color: Colors.white54, fontSize: 16)
                          ),
                        ],
                      )
                    )
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildProjectCard(context, displayProjects[index]);
                        },
                        childCount: displayProjects.length,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, dynamic item) {
    final orderData = item['orders'] ?? {};
    final specificProject = item['specific_project_data'] ?? {}; 
    
    String projectName = item['display_project_name'] ?? 'ไม่มีชื่อโครงการ';
    final companyName = orderData['companies']?['name'] ?? '';
    final productName = item['product_categories']?['name'] ?? 'ไม่ระบุสินค้า';
    final saleName = orderData['profiles']?['full_name'] ?? 'ไม่ระบุชื่อเซลล์'; 
    final areaSqm = specificProject['area_sqm'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PoolProjectDetailScreen(itemData: item)),
            ).then((_) => _fetchProjects()); 
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kNeonPurple.withOpacity(0.15), 
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kNeonPurple.withOpacity(0.3))
                  ),
                  child: const Icon(Icons.apartment_rounded, color: kNeonPurple, size: 24), 
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "โครงการ $projectName",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kPremiumGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              productName,
                              style: const TextStyle(color: kPremiumGold, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "$areaSqm sq.m.", 
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded, size: 12, color: kPremiumGold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "เซลล์: $saleName", 
                              style: const TextStyle(color: kPremiumGold, fontSize: 12, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(Icons.business_center_rounded, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              companyName.isNotEmpty && companyName != '-' ? companyName : 'ไม่ระบุชื่อบริษัท', 
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: _fetchProjects, 
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text("ลองใหม่")
          )
        ],
      ),
    );
  }
}