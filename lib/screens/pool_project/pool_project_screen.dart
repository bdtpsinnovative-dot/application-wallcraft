import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../services/api_service.dart';

import 'components/pool_order_card.dart'; 
import 'components/pool_filter_sheet.dart'; 

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
  List<Map<String, dynamic>> _groupedOrders = [];
  List<Map<String, dynamic>> _displayedOrders = [];
  
  bool _isLoading = true;
  bool _isLoadingMore = false; 
  bool _hasMoreData = true; // 🌟 เพิ่มตัวนี้เพื่อจัดการ Pagination แบบใหม่
  String? _errorMessage;

  int _currentPage = 1;
  final int _limit = 150;
  String _selectedScope = 'all'; 
  
  List<String> _selectedCategories = [];
  List<String> _availableCategories = [];
  List<String> _selectedSaleNames = [];
  List<String> _availableSaleNames = [];
  List<String> _selectedAreaRanges = [];
  List<String> _selectedProjectTypes = [];
  List<String> _availableProjectTypes = [];

  String _searchQuery = '';
  String _selectedDateRange = ''; 
  bool _selectedIsImportant = false; 
  
  final List<String> _dateRanges = ['7 วันล่าสุด', '14 วันล่าสุด', '30 วันล่าสุด'];
  final List<String> _areaRanges = ['น้อยกว่า 50 sq.m.', '50 - 200 sq.m.', '201 - 500 sq.m.', 'มากกว่า 500 sq.m.'];

  @override
  void initState() {
    super.initState();
    _fetchFilterOptions(); 
    _fetchProjects(isRefresh: true);
  }

  Future<void> _fetchFilterOptions() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects/filters');
      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _availableCategories = List<String>.from(result['categories'] ?? []);
          _availableProjectTypes = List<String>.from(result['projectTypes'] ?? []);
          _availableSaleNames = List<String>.from(result['saleNames'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading filter options: $e');
    }
  }

  Future<void> _handleToggleImportant(String projectId, bool currentStatus, String orderId) async {
    try {
      final String bodyData = jsonEncode({
        'order_id': orderId,
        'order_item_project_id': projectId,
        'is_important': !currentStatus,
      });

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects'); 
      final response = await ApiService.patch(url, body: bodyData);

      if (response.statusCode == 200) {
        _fetchProjects(isRefresh: true); 
        
        if (!currentStatus) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ติดดาวโครงการนี้แล้ว ✨'),
              backgroundColor: kPremiumGold,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        throw Exception('อัปเดตสถานะไม่สำเร็จ (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Toggle Error: $e'); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถอัปเดตสถานะได้')),
      );
    }
  }

  Future<void> _fetchProjects({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { _isLoading = true; _currentPage = 1; _errorMessage = null; _hasMoreData = true; });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'limit': _limit.toString(),
        'scope': _selectedScope,
        'search': _searchQuery,
      };

      if (_selectedCategories.isNotEmpty) queryParams['categories'] = _selectedCategories.join(',');
      if (_selectedSaleNames.isNotEmpty) queryParams['sales'] = _selectedSaleNames.join(',');
      if (_selectedProjectTypes.isNotEmpty) queryParams['types'] = _selectedProjectTypes.join(',');
      if (_selectedAreaRanges.isNotEmpty) queryParams['areas'] = _selectedAreaRanges.join(',');
      if (_selectedDateRange.isNotEmpty) queryParams['dateRange'] = _selectedDateRange;
      if (_selectedIsImportant) queryParams['isImportant'] = 'true';

      final url = Uri.parse('${AppConfig.baseUrl}/poolprojects').replace(queryParameters: queryParams);
      
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List<dynamic> rawData = result['data'] ?? [];

        List<Map<String, dynamic>> currentList = isRefresh ? [] : List.from(_groupedOrders);
        
        // 🌟 หัวใจสำคัญ: แตกข้อมูล แยก 1 โปรเจกต์ ให้เป็น 1 การ์ดเดี่ยวๆ
        for (var item in rawData) {
          final orderInfo = item['orders'];
          if (orderInfo == null) continue;

          final projectList = item['order_item_projects'] as List<dynamic>? ?? [];
          
          for (var p in projectList) {
            // สร้างจำลองให้โครงสร้างเหมือนเดิม แต่ยัดไส้แค่โปรเจกต์เดียว
            currentList.add({
              'order_data': orderInfo,
              'order_items': [
                {
                  ...item, 
                  'order_item_projects': [p], 
                }
              ]
            });
          }
        }

        setState(() {
          _groupedOrders = currentList;
          // เช็คว่าถ้า API ส่งข้อมูลมาเต็ม limit แปลว่าน่าจะมีหน้าต่อไป
          _hasMoreData = rawData.length == _limit; 
          
          _applyFilters(); 
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } on SocketException {
      setState(() { _errorMessage = "ไม่มีการเชื่อมต่ออินเทอร์เน็ต"; _isLoading = false; _isLoadingMore = false; });
    } on TimeoutException {
      setState(() { _errorMessage = "เซิร์ฟเวอร์ตอบสนองช้าเกินไป"; _isLoading = false; _isLoadingMore = false; });
    } catch (e) {
      setState(() { _errorMessage = "เกิดข้อผิดพลาดในการโหลดข้อมูล"; _isLoading = false; _isLoadingMore = false; });
    }
  }

  void _applyFilters() {
    setState(() {
      _displayedOrders = List.from(_groupedOrders);
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PoolFilterSheet(
        initialSearchQuery: _searchQuery,
        initialDateRange: _selectedDateRange,
        initialIsImportant: _selectedIsImportant,
        availableCategories: _availableCategories,
        selectedCategories: _selectedCategories,
        availableSaleNames: _availableSaleNames,
        selectedSaleNames: _selectedSaleNames,
        areaRanges: _areaRanges,
        selectedAreaRanges: _selectedAreaRanges,
        dateRanges: _dateRanges,
        availableProjectTypes: _availableProjectTypes,
        selectedProjectTypes: _selectedProjectTypes,
        onApply: (newFilters) {
          setState(() {
            _selectedCategories = newFilters['categories'];
            _selectedSaleNames = newFilters['saleNames'];
            _selectedAreaRanges = newFilters['areaRanges'];
            _selectedProjectTypes = newFilters['projectTypes'];
            _selectedDateRange = newFilters['dateRange'];
            _searchQuery = newFilters['searchQuery'];
            _selectedIsImportant = newFilters['isImportant'] ?? false; 
            _fetchProjects(isRefresh: true);
          });
        },
      ),
    );
  }

  Widget _buildScopeTab(String title, String scopeValue, IconData icon) {
    bool isSelected = _selectedScope == scopeValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedScope != scopeValue) {
            setState(() => _selectedScope = scopeValue);
            _fetchProjects(isRefresh: true); 
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kNeonPurple.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? kNeonPurple : Colors.transparent, width: 1)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? kNeonPurple : Colors.grey[500]),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: isSelected ? kNeonPurple : Colors.grey[500], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasActiveFilter = _selectedCategories.isNotEmpty || _selectedSaleNames.isNotEmpty || _selectedAreaRanges.isNotEmpty || _selectedProjectTypes.isNotEmpty || _selectedDateRange.isNotEmpty || _searchQuery.isNotEmpty || _selectedIsImportant;
    
    // 🌟 เปลี่ยนมาใช้ตัวแปร _hasMoreData ในการเช็คปุ่มโหลดข้อมูลเพิ่ม
    bool hasMoreData = _hasMoreData;

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
                  expandedHeight: 70, toolbarHeight: 70, pinned: true, elevation: 4, centerTitle: true,
                  title: const Text("Pool Orders", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
                          tooltip: "ค้นหา & ตัวกรอง",
                          onPressed: _showFilterSheet,
                        ),
                        if (hasActiveFilter)
                          Positioned(top: 12, right: 12, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: () {
                         setState(() {
                            _selectedCategories.clear();
                            _selectedSaleNames.clear();
                            _selectedAreaRanges.clear();
                            _selectedProjectTypes.clear();
                            _selectedDateRange = ''; 
                            _searchQuery = '';
                            _selectedIsImportant = false; 
                         });
                         _fetchProjects(isRefresh: true);
                      },
                    ),
                  ],
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          _buildScopeTab('ทั้งหมด', 'all', Icons.public_rounded),
                          _buildScopeTab('ทีมของฉัน', 'team', Icons.groups_rounded),
                          _buildScopeTab('ของฉัน', 'mine', Icons.person_rounded),
                        ],
                      ),
                    ),
                  ),
                ),

                if (!_isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: kPremiumGold, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              // 🌟 ไม่ต้องลูปนับแล้ว เพราะจำนวนในลิสต์ตอนนี้ = จำนวนโปรเจกต์เป๊ะๆ!
                              hasActiveFilter 
                                  ? "พบ ${_displayedOrders.length} โครงการ (จากตัวกรอง)" 
                                  : "กำลังแสดง ${_groupedOrders.length} โครงการ",
                              style: const TextStyle(color: kPremiumGold, fontSize: 13, fontWeight: FontWeight.w500)
                            )
                          ),
                          if (hasActiveFilter)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategories.clear();
                                  _selectedSaleNames.clear();
                                  _selectedAreaRanges.clear();
                                  _selectedProjectTypes.clear();
                                  _selectedDateRange = ''; 
                                  _searchQuery = '';
                                  _selectedIsImportant = false;
                                  _applyFilters();
                                  _fetchProjects(isRefresh: true);
                                });
                              },
                              child: Row(
                                children: const [
                                  Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 4),
                                  Text("ล้าง", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  ),

                if (_isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kNeonPurple)))
                else if (_errorMessage != null)
                  SliverFillRemaining(child: _buildErrorState())
                else if (_displayedOrders.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text(hasActiveFilter ? "ไม่พบโครงการที่ค้นหา" : "ยังไม่มีโครงการในหมวดหมู่นี้", style: const TextStyle(color: Colors.white54, fontSize: 16)),
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
                          if (index == _displayedOrders.length) {
                            if (!hasMoreData || hasActiveFilter) return const SizedBox(); 
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 20, bottom: 40),
                              child: Center(
                                child: _isLoadingMore 
                                  ? const CircularProgressIndicator(color: kNeonPurple)
                                  : OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kNeonPurple, 
                                        side: BorderSide(color: kNeonPurple.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                      ),
                                      onPressed: () {
                                        setState(() => _currentPage++); 
                                        _fetchProjects(isRefresh: false); 
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 20),
                                      label: const Text("โหลดข้อมูลเพิ่ม")
                                    ),
                              ),
                            );
                          }
                          
                          return PoolOrderCard(
                            groupedOrder: _displayedOrders[index],
                            onRefresh: () => _fetchProjects(isRefresh: true),
                            onToggleImportant: (projectId, currentStatus) {
                              final orderId = _displayedOrders[index]['order_data']['id'].toString();
                              _handleToggleImportant(projectId, currentStatus, orderId);
                            },
                          );
                          
                        },
                        childCount: _displayedOrders.length + (hasMoreData && !hasActiveFilter ? 1 : 0),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage ?? "เกิดข้อผิดพลาด", style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: kNeonPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _fetchProjects(isRefresh: true), 
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text("ลองใหม่")
          )
        ],
      ),
    );
  }
}