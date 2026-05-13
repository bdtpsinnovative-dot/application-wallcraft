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

  // 🌟 ธีม Dark Luxury / High-Tech
  final Color primaryColor = const Color(0xFF00E5FF); // Neon Cyan
  final Color bgColor = const Color(0xFF0A0A0C); // Deep Dark
  final Color cardColor = const Color(0xFF16161A); 
  final Color borderColor = const Color(0xFF2A2A35);

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text("Filter by Series", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(name, style: TextStyle(
                        color: isSelected ? primaryColor : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                      onTap: () {
                        _applyFilter(name);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
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
        title: const Text('Inventory Master', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 0.5)),
        actions: [
          _buildFilterButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildDashboard(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasFilter ? primaryColor.withOpacity(0.1) : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFilter ? primaryColor.withOpacity(0.5) : borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded, color: hasFilter ? primaryColor : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(hasFilter ? _selectedSeriesFilter : 'Filter',
              style: TextStyle(color: hasFilter ? primaryColor : Colors.white70, fontWeight: hasFilter ? FontWeight.bold : FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDashItem(Icons.inventory_2_outlined, 'SKU Groups', _totalGroups.toString()),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildDashItem(Icons.layers_outlined, 'Total Balance', _totalQuantity.toString(), valueColor: primaryColor),
        ],
      ),
    );
  }

  Widget _buildDashItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
    Color qtyColor = isOutOfStock ? Colors.redAccent : Colors.greenAccent;

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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: groupImage != null
                      ? Image.network(
                          groupImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white24),
                        )
                      : const Icon(Icons.image_outlined, color: Colors.white24, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itemName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: primaryColor.withOpacity(0.2))),
                      child: Text(seriesName, style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 🌟 โซนตัวเลข (โชว์ Pending ถ้ามี และ Balance)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (groupPendingQty > 0) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("PENDING", style: TextStyle(color: Colors.orangeAccent.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        Text(groupPendingQty.toString(), style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14), // ดันให้ตรงกับ Balance
                      ],
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("BALANCE", style: TextStyle(color: qtyColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text(groupTotalQty.toString(), style: TextStyle(color: qtyColor, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text("${items.length} sizes", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                        ],
                      )
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
    const Color bgColor = Color(0xFF0A0A0C);
    const Color cardColor = Color(0xFF16161A);
    const Color borderColor = Color(0xFF2A2A35);
    const Color primaryColor = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(seriesName, style: const TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
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

          final bool isLowStock = qtyNum < 10 && qtyNum > 0;
          final bool isOutOfStock = qtyNum <= 0;

          Color qtyColor = Colors.greenAccent;
          if (isOutOfStock) qtyColor = Colors.redAccent;
          else if (isLowStock) qtyColor = Colors.orangeAccent;

          final String? imageUrl = item['catalog_image']?.toString();
          final String sku = item['catalog_sku']?.toString() ?? '-';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white24),
                              )
                            : const Icon(Icons.image_outlined, color: Colors.white24, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.palette_outlined, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text("สี: ${item['color'] ?? '-'}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.straighten_outlined, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text("ขนาด: $sizeText", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text("SKU: $sku", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: borderColor, height: 1),
                ),
                
                // 🌟 Footer QTY & Pending
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("วัสดุ: ${item['material'] ?? '-'}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🌟 โชว์ Badge สีส้มถ้ายอด Pending มากกว่า 0
                        if (pendingNum > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Text("PENDING ", style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(pendingQty, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // ยอด Balance คงเหลือ
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: qtyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: qtyColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Text("BALANCE ", style: TextStyle(color: qtyColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(qty, style: TextStyle(color: qtyColor, fontSize: 18, fontWeight: FontWeight.w800)),
                            ],
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