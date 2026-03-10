import 'dart:convert';
import 'dart:async'; 
import 'dart:io';    
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart'; 
import '../../services/api_service.dart'; 

const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kPremiumGold = Color(0xFFFFC107); 
const Color kNeonPurple = Color(0xFFB52BFF);

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isFirstLoading = true; 
  bool _isLoadingMore = false; 
  bool _hasMore = true; 
  int _page = 1; 
  final int _limit = 20; 
  
  String? _errorMessage; 

  bool _showSearchBar = false;
  String _searchText = "";
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController(); 

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _fetchOrders(); 
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (_isLoadingMore) return; 

    try {
      if (_page == 1) {
        setState(() {
          _isFirstLoading = true;
          _errorMessage = null; 
        });
      } else {
        setState(() => _isLoadingMore = true);
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id'); 
      
      if (userId == null) throw Exception("User ID not found");

      final url = Uri.parse('${AppConfig.baseUrl}/orders/history?userId=$userId&page=$_page&limit=$_limit');
      
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> newOrders = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            if (_page == 1) {
              _orders = newOrders; 
            } else {
              _orders.addAll(newOrders); 
            }
            
            _page++; 
            _isFirstLoading = false;
            _isLoadingMore = false;
            
            if (newOrders.length < _limit) {
              _hasMore = false;
            }
          });
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } on SocketException {
      _handleError("ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G");
    } on TimeoutException {
      _handleError("เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง");
    } catch (e) {
      _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้\nกรุณาลองใหม่อีกครั้ง");
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    
    if (_page == 1) {
      setState(() => _errorMessage = msg);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white), 
              const SizedBox(width: 10), 
              Expanded(child: Text(msg.replaceAll('\n', ' '), style: const TextStyle(color: Colors.white)))
            ]
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onRefresh() {
    setState(() {
      _page = 1;
      _hasMore = true;
      _orders.clear();
      _errorMessage = null; 
    });
    _fetchOrders();
  }

  List<dynamic> get _filteredOrders {
    if (_searchText.isEmpty) return _orders;
    return _orders.where((order) {
      final customerName = order['customer_name']?.toString().toLowerCase() ?? '';
      final companyName = order['companies']?['name']?.toString().toLowerCase() ?? '';
      final searchLower = _searchText.toLowerCase();
      return customerName.contains(searchLower) || companyName.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayOrders = _filteredOrders;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: kDarkBg,
        body: Stack(
          children: [
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.3)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            Column(
              children: [
                _buildHeader(context),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showSearchBar 
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (val) => setState(() => _searchText = val),
                          decoration: InputDecoration(
                            hintText: "ค้นหาชื่อโครงการ หรือลูกค้า...",
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: const Icon(Icons.search, color: kPremiumGold),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchText = "");
                              },
                            ),
                            filled: true,
                            fillColor: kCardDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: kPremiumGold, width: 1.5)),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                ),

                Expanded(
                  child: _isFirstLoading
                      ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                      : _errorMessage != null && _orders.isEmpty
                          ? _buildErrorState()
                          : displayOrders.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  onRefresh: () async => _onRefresh(), 
                                  color: kPremiumGold,
                                  backgroundColor: kCardDark,
                                  child: ListView.builder(
                                    controller: _scrollController, 
                                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                                    physics: const AlwaysScrollableScrollPhysics(), 
                                    itemCount: displayOrders.length + (_hasMore ? 1 : 0), 
                                    itemBuilder: (ctx, i) {
                                      if (i == displayOrders.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: SizedBox(
                                              width: 24, height: 24,
                                              child: CircularProgressIndicator(color: kPremiumGold, strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      }
                                      return _buildProjectGroup(displayOrders[i]); 
                                    },
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
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onRefresh, 
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPremiumGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      color: kDarkBg.withOpacity(0.95),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            )
          else
            const SizedBox(width: 40),

          const Text("Project History", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchText = "";
                  _searchCtrl.clear();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _showSearchBar ? kPremiumGold : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showSearchBar ? Icons.close_rounded : Icons.search_rounded,
                color: _showSearchBar ? Colors.black : Colors.white70, 
                size: 24
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
            child: Icon(Icons.history_edu_rounded, size: 60, color: Colors.white.withOpacity(0.2)),
          ),
          const SizedBox(height: 20),
          const Text("ยังไม่มีข้อมูลโครงการ", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProjectGroup(dynamic order) {
    String dateStr = order['created_at'] ?? '-';
    try {
      if (order['created_at'] != null) {
        final date = DateTime.parse(order['created_at']).toLocal(); 
        dateStr = "${date.day}/${date.month}/${date.year + 543}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} น.";
      }
    } catch (e) { debugPrint("Date Error: $e"); }

    final String orderId = order['id'] ?? '';
    final String refCode = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : 'N/A';
    final customerName = order['customer_name'] ?? 'ไม่ระบุลูกค้า';
    final companyName = order['companies']?['name'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🌟 หัวข้อโครงการ (Project Header)
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_rounded, color: kPremiumGold, size: 20), 
                  const SizedBox(width: 8),
                  Text(
                    "Project: #$refCode",
                    style: const TextStyle(color: kPremiumGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1), 
                  ),
                ],
              ),
              Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),

        // 🌟 การ์ดรายละเอียดโครงการ 
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 ข้อมูลลูกค้า (✅ แก้กลับให้ถูกต้องแล้ว)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.person_rounded, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName, 
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // 🏢 ชื่อบริษัท
              if (companyName != '-' && companyName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.business_center_rounded, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        companyName, 
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (order['order_items'] != null && (order['order_items'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
                const SizedBox(height: 12),
                
                // 📦 รายการสินค้าและโปรเจกต์ย่อย
                ...(order['order_items'] as List<dynamic>).map((item) {
                  final productName = item['product_categories']?['name'] ?? 'ไม่ระบุสินค้า';
                  final projects = item['order_item_projects'] as List<dynamic>? ?? [];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.inventory_2_rounded, color: kNeonPurple, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(productName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              
                              if (projects.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                ...projects.map((proj) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            // ✅ ใส่โค้ดโปรเจกต์ตรงนี้ถึงจะถูกที่ครับ!
                                            "${proj['project_name'] ?? 'ไม่ระบุโครงการย่อย'} (${proj['area_sqm'] ?? 0} ตร.ม.)",
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList()
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text("ไม่ได้ระบุโครงการย่อย", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                                )
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else ...[
                 const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text("ไม่มีรายการสินค้า", style: TextStyle(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.italic)),
                 )
              ]
            ],
          ),
        ),
      ],
    );
  }
}