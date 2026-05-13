import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

// 🌟 Import ชิ้นส่วนที่เราหั่นออกไปเมื่อกี้เข้ามาใช้งาน
import 'widgets/product_card.dart';
import 'widgets/price_check_modals.dart';

const Color kDarkBg = Color(0xFF0F0F11); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kAccentColor = Color(0xFFC6A87C); 

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); 
  
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = false; 
  bool _isLoadingMore = false; 
  bool _hasMore = true; 
  String? _errorMessage; 
  Timer? _debounce; 

  int _currentPage = 1;
  final int _limit = 50; 

  String _selectedCategory = 'ทั้งหมด';

  final Map<String, List<String>> _categoryGroups = {
    'CRAFT STONE': [
      'Tarra Stone', 'Panorama', 'Strength Rock', 'Geoform', 
      'Urban Form', 'Nature Grain', 'Rust', 'Finesse'
    ],
    'LUXE SERIES': [
      'Fabric', 'Leather', 'Metallic', 'Semi Outdoor', 
      'Signature', 'Stone', 'Velvet', 'Wood'
    ],
    'ESSENTIAL SERIES': [
      'Solid Panel', 'Hollow Core Panel', 'Decor Panel', 
      'Accessories', 'Aluminium & LED'
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchProducts('', isRefresh: true); 
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore) {
          _loadMoreProducts();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel(); 
    super.dispose();
  }

  String _formatPrice(dynamic priceData) {
    if (priceData == null) return "0.00";
    double rawPrice = (priceData as num).toDouble(); 
    int roundedPrice = rawPrice.round(); 
    return NumberFormat('#,##0.00').format(roundedPrice); 
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchProducts(_searchController.text, isRefresh: false);
  }

  Future<void> _fetchProducts(String keyword, {bool isRefresh = true}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; 
        _currentPage = 1;
        _hasMore = true;
        _filteredProducts.clear();
      });
    }

    try {
      String urlString = '${AppConfig.baseUrl}/products?keyword=${Uri.encodeComponent(keyword)}&page=$_currentPage&limit=$_limit';
      
      if (_selectedCategory != 'ทั้งหมด') {
        if (_categoryGroups.containsKey(_selectedCategory)) {
          String subItems = _categoryGroups[_selectedCategory]!.join(',');
          urlString += '&collections=${Uri.encodeComponent(subItems)}';
        } else {
          urlString += '&collection=${Uri.encodeComponent(_selectedCategory)}';
        }
      }

      final url = Uri.parse(urlString);
      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        
        if (decodedResponse['success'] == true) {
          final List<dynamic> rawData = decodedResponse['data'];
          
          if (mounted) {
            setState(() {
              if (rawData.length < _limit) {
                _hasMore = false;
              }
              
              if (isRefresh) {
                _filteredProducts = List<Map<String, dynamic>>.from(rawData);
              } else {
                _filteredProducts.addAll(List<Map<String, dynamic>>.from(rawData));
              }
            });
          }
        } else {
          throw "เซิร์ฟเวอร์เกิดข้อผิดพลาด กรุณาลองใหม่";
        }
      } else {
        throw "ไม่สามารถเชื่อมต่อระบบได้ (${response.statusCode})";
      }
    } on SocketException {
      if (mounted) setState(() => _errorMessage = "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G ของคุณ");
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง");
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "เกิดข้อผิดพลาดบางอย่าง: ไม่สามารถดึงข้อมูลได้");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchProducts(query, isRefresh: true); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        title: const Text(
          'เช็คราคาสินค้า',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () {
              // 🌟 เรียกใช้ Modal เลือกหมวดหมู่ที่แยกไฟล์ไว้
              showCategoryFilterModal(
                context: context,
                selectedCategory: _selectedCategory,
                categoryGroups: _categoryGroups,
                onCategorySelected: (newCategory) {
                  if (_selectedCategory != newCategory) {
                    setState(() => _selectedCategory = newCategory);
                    _fetchProducts(_searchController.text, isRefresh: true);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: kCardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged, 
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ชื่อสินค้าเพื่อค้นหา...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _fetchProducts('', isRefresh: true); 
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            if (_selectedCategory != 'ทั้งหมด') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: kAccentColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "หมวดหมู่: $_selectedCategory",
                    style: const TextStyle(color: kAccentColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = 'ทั้งหมด');
                      _fetchProducts(_searchController.text, isRefresh: true);
                    },
                    child: const Text(
                      "ล้างตัวกรอง",
                      style: TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  )
                ],
              ),
            ],
            
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: kAccentColor))
                : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!, 
                            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5), 
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _fetchProducts(_searchController.text, isRefresh: true),
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          )
                        ],
                      ),
                    )
                  : _filteredProducts.isNotEmpty
                    ? ListView.builder(
                        controller: _scrollController, 
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredProducts.length + (_isLoadingMore ? 1 : 0), 
                        itemBuilder: (context, index) {
                          
                          if (index == _filteredProducts.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: kAccentColor)),
                            );
                          }

                          // 🌟 เรียกใช้ ProductCard ที่หั่นแยกไปไว้ในไฟล์อื่น
                          return ProductCard(
                            product: _filteredProducts[index],
                            formatPrice: _formatPrice,
                            onTap: () {
                              showVariantDetailsModal(
                                context: context,
                                product: _filteredProducts[index],
                                formatPrice: _formatPrice,
                              );
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text('ไม่พบสินค้านี้ในระบบ', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}