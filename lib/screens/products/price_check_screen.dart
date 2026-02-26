import 'dart:convert';
import 'dart:async';
import 'dart:io'; // ✅ เพิ่มดักจับเน็ตหลุด (SocketException)
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

const Color kDarkBg = Color(0xFF0F0F11); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kAccentColor = Color(0xFFC6A87C); // สีทอง Tarra Stone

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({super.key});

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = false; 
  String? _errorMessage; // ✅ สร้างตัวแปรเก็บข้อความ Error
  Timer? _debounce; 

  @override
  void initState() {
    super.initState();
    _fetchProducts(''); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); 
    super.dispose();
  }

  // ✨ ปัดเศษเป็นเลขจำนวนเต็ม แล้วโชว์ .00 พร้อมลูกน้ำ
  String _formatPrice(dynamic priceData) {
    if (priceData == null) return "0.00";
    double rawPrice = (priceData as num).toDouble(); 
    int roundedPrice = rawPrice.round(); 
    return NumberFormat('#,##0.00').format(roundedPrice); 
  }

  Future<void> _fetchProducts(String keyword) async {
    // ✅ เคลียร์ค่า Error ทิ้งทุกครั้งที่เริ่มดึงข้อมูลใหม่
    setState(() {
      _isLoading = true;
      _errorMessage = null; 
    });

    try {
      final response = await ApiService.get(AppConfig.productsUrl(keyword));

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        
        if (decodedResponse['success'] == true) {
          final List<dynamic> rawData = decodedResponse['data'];
          
          if (mounted) {
            setState(() {
              _filteredProducts = List<Map<String, dynamic>>.from(rawData);
            });
          }
        } else {
          // กรณี API ส่ง success เป็น false
          throw "เซิร์ฟเวอร์เกิดข้อผิดพลาด กรุณาลองใหม่";
        }
      } else {
        throw "ไม่สามารถเชื่อมต่อระบบได้ (${response.statusCode})";
      }
    } on SocketException {
      // ✅ ดักจับ Error เน็ตหลุดแบบตรงจุด
      if (mounted) {
        setState(() {
          _errorMessage = "ขาดการเชื่อมต่ออินเทอร์เน็ต\nกรุณาตรวจสอบสัญญาณ Wi-Fi หรือ 4G/5G ของคุณ";
        });
      }
    } on TimeoutException {
      // ✅ ดักจับ Error เน็ตช้าเกินไป
      if (mounted) {
        setState(() {
          _errorMessage = "เซิร์ฟเวอร์ใช้เวลาตอบกลับนานเกินไป\nกรุณาลองใหม่อีกครั้ง";
        });
      }
    } catch (e) {
      // ✅ ดักจับ Error อื่นๆ ที่เราคาดไม่ถึง
      print('Fetch Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = "เกิดข้อผิดพลาดบางอย่าง: ไม่สามารถดึงข้อมูลได้";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchProducts(query);
    });
  }

  // ✨ Bottom Sheet (เพิ่มระบบ Filter หมวดหมู่ฟิล์ม)
// ✨ ปรับปรุงโฉมใหม่: Bottom Sheet (เน้นความคลีนและหรูหรา)
  void _showVariantDetails(BuildContext context, Map<String, dynamic> product) {
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // มนกว่าเดิม
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 45, height: 5,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                  ),
                  
                  // Header Section
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

                  // Film Filter
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
                  
                  // รายการรุ่นย่อย
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
                              // 1. รูปสินค้า (มนขึ้นและมีเงาเบาๆ)
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
                              
                              // 2. ข้อมูลชื่อและสเปค
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(patternName, 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    // จัดกลุ่มผิวและขนาดไว้ด้วยกันแบบคลีนๆ
                                    Text("${v['film'] ?? ''}", 
                                      style: TextStyle(color: kAccentColor.withOpacity(0.8), fontSize: 12)),
                                    Text("${v['thickness_mm']}mm | ${v['width_mm']}x${v['length_mm']}mm", 
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                  ],
                                ),
                              ),
                              
                              // 3. ราคา (ตัวใหญ่ ชัดเจน ไม่มี /ชิ้น)
                              Text(
                                "฿${_formatPrice(v['price'])}",
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // 🔍 ช่องค้นหา
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
                            _fetchProducts(''); 
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📋 รายการสินค้า
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: kAccentColor))
                : _errorMessage != null
                  // ✅ ถ้ามี Error (เน็ตหลุด) โชว์ UI สวยๆ ตรงนี้
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
                            onPressed: () => _fetchProducts(_searchController.text),
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
                  // ✅ ถ้าไม่มี Error ก็ทำงานปกติ
                  : _filteredProducts.isNotEmpty
                    ? ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          
                          String priceText = "";
                          if (product['minPrice'] == product['maxPrice']) {
                            priceText = "฿${_formatPrice(product['minPrice'])}";
                          } else {
                            priceText = "฿${_formatPrice(product['minPrice'])} - ฿${_formatPrice(product['maxPrice'])}";
                          }

                          String displayImage = product['image'] ?? '';
                          if (displayImage.isEmpty && product['variants'].isNotEmpty) {
                            displayImage = product['variants'][0]['variant_image'] ?? '';
                          }

                          return GestureDetector(
                            onTap: () => _showVariantDetails(context, product),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16), 
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: kCardDark,
                                borderRadius: BorderRadius.circular(20), 
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 🖼️ รูปภาพ
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.black26, 
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: displayImage.isNotEmpty
                                          ? Image.network(displayImage, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image_rounded, color: Colors.white38))
                                          : const Icon(Icons.image_not_supported_rounded, color: Colors.white38),
                                    ),
                                  ),
                                  const SizedBox(width: 16), 

                                  // 📝 ข้อมูลตรงกลาง 
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (product["collection"].toString().isNotEmpty)
                                          Text(
                                            product["collection"].toString().toUpperCase(),
                                            style: const TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          product["name"],
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        Text(
                                          priceText,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 10),

                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: kAccentColor.withOpacity(0.15), 
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "${product['variants'].length} รุ่นย่อย",
                                            style: const TextStyle(color: kAccentColor, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ➡ ไอคอนลูกศรชี้ขวาสุด
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
                                  ),
                                ],
                              ),
                            ),
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