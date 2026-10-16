//lib/screens/tracking/stock_management_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  _StockManagementPageState createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  List<dynamic> _allStockList = [];
  List<dynamic> _filteredList = [];
  bool _isLoading = true;

  List<String> _seriesNames = [];
  String _selectedSeriesFilter = 'All';

  // 🌟 ธีม Monochrome Dark Luxury (สะอาดตา สไตล์ iOS แท้ ไม่ฉูดฉาด)
  final Color primaryColor = Colors.white;
  final Color bgColor = const Color(0xFF0F0F11);
  final Color cardColor = const Color(0xFF18181B); 
  final Color borderColor = const Color(0xFF27272A);

  @override
  void initState() {
    super.initState();
    fetchStockData();
  }

  Future<void> fetchStockData() async {
    try {
      // ใช้ http.get แบบเดิมที่คุณแก้ไว้
      final response = await http.get(AppConfig.stockUrl);
      // (ถ้ามี Error ตรง Uri.parse ให้เอาออกเหลือแค่ AppConfig.stockUrl เหมือนเดิมนะครับ)
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final data = responseData['data'] as List<dynamic>;

          final seriesSet = data
              .map((item) => item['series']?.toString() ?? '-')
              .where((s) => s != '-')
              .toSet();

          setState(() {
            _allStockList = data;
            _filteredList = data;
            _seriesNames = ['All', ...seriesSet.toList()];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String seriesName) {
    setState(() {
      _selectedSeriesFilter = seriesName;
      if (seriesName == 'All') {
        _filteredList = _allStockList;
      } else {
        _filteredList = _allStockList
            .where((item) => item['series'] == seriesName)
            .toList();
      }
    });
  }

  // จัดกลุ่มตาม Item Name
  Map<String, List<dynamic>> get _groupedStock {
    Map<String, List<dynamic>> grouped = {};
    for (var item in _filteredList) {
      final itemName = item['item_name'] ?? 'Unknown Item';
      if (!grouped.containsKey(itemName)) {
        grouped[itemName] = [];
      }
      grouped[itemName]!.add(item);
    }
    return grouped;
  }

  // หาภาพตัวแทนของกลุ่ม
  String? _getGroupImage(List<dynamic> items) {
    for (var item in items) {
      if (item['catalog_image'] != null && item['catalog_image'].toString().isNotEmpty) {
        return item['catalog_image'].toString();
      }
    }
    return null;
  }

  int get _totalGroups => _groupedStock.keys.length;
  
  int get _totalQuantity {
    return _filteredList.fold(0, (sum, item) {
      final qty = item['qty'];
      if (qty is int) return sum + qty;
      if (qty is String) return sum + (int.tryParse(qty) ?? 0);
      return sum;
    });
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text("Filter by Series", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _seriesNames.length,
                  itemBuilder: (context, index) {
                    final name = _seriesNames[index];
                    final isSelected = name == _selectedSeriesFilter;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      title: Text(name, style: TextStyle(
                        color: isSelected ? primaryColor : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13.5,
                      )),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 18) : null,
                      onTap: () {
                        _applyFilter(name);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupedStock;
    final itemNames = groupedData.keys.toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inventory Master',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: 0.3)),
        actions: [
          _buildFilterButton(),
          const SizedBox(width: 14),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildDashboard(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                    itemCount: itemNames.length,
                    itemBuilder: (context, index) {
                      final itemName = itemNames[index];
                      final itemsInGroup = groupedData[itemName]!;
                      return _buildGroupCard(itemName, itemsInGroup);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterButton() {
    bool hasFilter = _selectedSeriesFilter != 'All';
    return InkWell(
      onTap: _showFilterModal,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasFilter ? Colors.white12 : cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasFilter ? Colors.white38 : borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, color: hasFilter ? Colors.white : Colors.white70, size: 15),
            const SizedBox(width: 5),
            Text(
              hasFilter ? _selectedSeriesFilter : 'Filter',
              style: TextStyle(
                color: hasFilter ? Colors.white : Colors.white70,
                fontWeight: hasFilter ? FontWeight.bold : FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDashItem(Icons.inventory_2_outlined, 'กลุ่มสินค้า', _totalGroups.toString()),
          Container(width: 1, height: 28, color: Colors.white12),
          _buildDashItem(Icons.layers_outlined, 'สต็อกรวม', _totalQuantity.toString()),
        ],
      ),
    );
  }

  Widget _buildDashItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 13),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildGroupCard(String itemName, List<dynamic> items) {
    final String seriesName = items.isNotEmpty ? (items.first['series'] ?? '-') : '-';
    final String? groupImage = _getGroupImage(items);
    
    // คำนวณ QTY คงเหลือรวม
    final int groupTotalQty = items.fold(0, (sum, item) {
      final qty = item['qty'];
      if (qty is int) return sum + qty;
      if (qty is String) return sum + (int.tryParse(qty) ?? 0);
      return sum;
    });

    // 🌟 คำนวณ QTY Pending รวม
    final int groupPendingQty = items.fold(0, (sum, item) {
      final qty = item['pending_qty'];
      if (qty == null) return sum;
      if (qty is int) return sum + qty;
      if (qty is String) return sum + (int.tryParse(qty) ?? 0);
      return sum;
    });

    final bool isOutOfStock = groupTotalQty <= 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              itemName: itemName,
              seriesName: seriesName,
              items: items,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: groupImage != null
                      ? Image.network(
                          groupImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 22),
                        )
                      : const Icon(Icons.image_outlined, color: Colors.white24, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      seriesName,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 🌟 โซนสต็อก & ขนาด (Typography สะอาดตา สไตล์ iOS แท้ ไม่มีกรอบบล็อก)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (groupPendingQty > 0) ...[
                        Text(
                          'รอส่ง $groupPendingQty',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text(
                        'สต็อก ',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        groupTotalQty.toString(),
                        style: TextStyle(
                          color: isOutOfStock ? Colors.redAccent : Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${items.length} ขนาด",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 หน้า Detail
// ============================================================================
class StockDetailScreen extends StatelessWidget {
  final String itemName;
  final String seriesName;
  final List<dynamic> items;

  const StockDetailScreen({
    super.key,
    required this.itemName,
    required this.seriesName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0F0F11);
    const Color cardColor = Color(0xFF18181B);
    const Color borderColor = Color(0xFF27272A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(seriesName, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          
          final h = item['height_mm'] ?? '0';
          final w = item['width_mm'] ?? '0';
          final t = item['thickness_mm'] ?? '0';
          final sizeText = "$h x $w x $t mm";
          
          final qty = item['qty'].toString();
          final int qtyNum = int.tryParse(qty) ?? 0;

          // 🌟 ตัวแปรเก็บยอด Pending
          final pendingQty = item['pending_qty']?.toString() ?? '0';
          final int pendingNum = int.tryParse(pendingQty) ?? 0;

          final bool isOutOfStock = qtyNum <= 0;

          final String? imageUrl = item['catalog_image']?.toString();
          final String sku = item['catalog_sku']?.toString() ?? '-';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 20),
                              )
                            : const Icon(Icons.image_outlined, color: Colors.white24, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.palette_outlined, color: Colors.white38, size: 13),
                              const SizedBox(width: 5),
                              Expanded(child: Text("สี: ${item['color'] ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.straighten_outlined, color: Colors.white38, size: 13),
                              const SizedBox(width: 5),
                              Text("ขนาด: $sizeText", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 13),
                              const SizedBox(width: 5),
                              Text("SKU: $sku", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: borderColor, height: 1),
                ),
                
                // 🌟 Footer QTY & Pending (Typography สะอาดตา สไตล์ iOS แท้ ไม่มีกรอบบล็อก)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("วัสดุ: ${item['material'] ?? '-'}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (pendingNum > 0) ...[
                          const Text("รอส่ง ", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          Text(
                            pendingQty,
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 14),
                        ],
                        const Text(
                          "สต็อก ",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        Text(
                          qty,
                          style: TextStyle(
                            color: isOutOfStock ? Colors.redAccent : Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}