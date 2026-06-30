// lib/screens/tracking/package_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../services/api_service.dart'; 
import '../../constants.dart';
import 'widgets/admin_add_package_modal.dart'; 

enum DeliveryStatus { inTransit, delivered }
enum DeliveryStatusFilter { all, inTransit, delivered }

class TpsTrackingRecord {
  final int? id; 
  final String refCode;
  final String jkCode;
  final String ctn;
  final String tracking;
  final DeliveryStatus status;

  TpsTrackingRecord({
    this.id,
    required this.refCode,
    required this.jkCode,
    required this.ctn,
    this.tracking = "",
    this.status = DeliveryStatus.inTransit,
  });
}

class DailyBatch {
  final String batchName;
  final String dateString; 
  final DateTime? date; 
  final List<TpsTrackingRecord> records;

  DailyBatch({
    required this.batchName,
    required this.dateString,
    this.date,
    required this.records,
  });
}

class PackageTrackingPage extends StatefulWidget {
  const PackageTrackingPage({super.key});

  @override
  State<PackageTrackingPage> createState() => _PackageTrackingPageState();
}

class _PackageTrackingPageState extends State<PackageTrackingPage> {
  List<DailyBatch> batches = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  DeliveryStatusFilter _selectedTab = DeliveryStatusFilter.all;
  String? _selectedDateFilter;

  // 🌟 [โหมดแอดมิน] ตั้งค่าเริ่มต้นเป็น false ไว้ก่อน 
  bool isAdmin = false; 

  @override
  void initState() {
    super.initState();
    _checkAdminRole(); 
    _fetchTrackingData(); 
  }

  Future<void> _checkAdminRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await ApiService.post(
        Uri.parse('${AppConfig.baseUrl}/profile'), 
        body: jsonEncode({'token': token})
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['profile'];
        if (data != null && data['role'] == 'admin') {
          if (mounted) {
            setState(() {
              isAdmin = true; 
            });
          }
        }
      }
    } catch (e) {
      print("Error checking admin role: $e");
    }
  }

  Future<void> _fetchTrackingData({String query = ""}) async {
    setState(() => isLoading = true);

    try {
      final uri = query.isEmpty 
          ? Uri.parse(AppConfig.tpsTrackingUrl.toString()) 
          : Uri.parse('${AppConfig.tpsTrackingUrl}?search=$query');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> recordsList = data['data'];
          _processAndDisplayData(recordsList);
          return;
        }
      }
      
      _loadMockData(query: query);
    } catch (e) {
      _loadMockData(query: query);
    }
  }

  Future<void> _updateBatchStatus(DailyBatch batch) async {
    List<int> pendingIds = batch.records
        .where((r) => r.status != DeliveryStatus.delivered && r.id != null)
        .map((r) => r.id!)
        .toList();

    if (pendingIds.isEmpty) return;

    Navigator.pop(context); 
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? "";

      final response = await http.patch(
        Uri.parse(AppConfig.tpsTrackingUrl.toString()), 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "ids": pendingIds, 
          "status": "delivered"
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ อัปเดตพัสดุทั้งหมด ${pendingIds.length} รายการเป็นจัดส่งสำเร็จแล้ว!'), backgroundColor: Colors.green),
          );
        }
        _fetchTrackingData(); 
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ไม่สามารถอัปเดตได้: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _confirmBatchStatusChange(BuildContext context, DailyBatch batch) async {
    int pendingCount = batch.records.where((r) => r.status != DeliveryStatus.delivered).length;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text("ยืนยันการจัดส่ง", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text("ต้องการเปลี่ยนสถานะพัสดุที่เหลืออีก $pendingCount รายการ ในรอบบิล ${batch.batchName} เป็น 'จัดส่งสำเร็จ' ทั้งหมดใช่หรือไม่?", 
            style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("ยืนยันทั้งหมด", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _updateBatchStatus(batch);
    }
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      final partsSlash = dateStr.split('/');
      if (partsSlash.length == 3) {
        return DateTime(2000 + int.parse(partsSlash[2]), int.parse(partsSlash[1]), int.parse(partsSlash[0]));
      }
    } catch (e) {}
    return null;
  }

  void _processAndDisplayData(List<dynamic> recordsList) {
    Map<String, List<TpsTrackingRecord>> groupedData = {};

    for (var item in recordsList) {
      String dateOnly = item['batchDate']?.toString() ?? '-';
      String batchCode = item['batchCode']?.toString() ?? '-';
      String batchKey = "$dateOnly ($batchCode)";
      
      DeliveryStatus itemStatus = item['status'] == 'delivered' 
          ? DeliveryStatus.delivered 
          : DeliveryStatus.inTransit;

      TpsTrackingRecord record = TpsTrackingRecord(
        id: item['id'], 
        refCode: item['refCode']?.toString() ?? '-',
        jkCode: item['jkCode']?.toString() ?? '-',
        ctn: item['ctn']?.toString() ?? '0',
        tracking: item['trackingNumber']?.toString() ?? '-',
        status: itemStatus,
      );

      if (!groupedData.containsKey(batchKey)) {
        groupedData[batchKey] = [];
      }
      groupedData[batchKey]!.add(record);
    }

    List<DailyBatch> newBatches = groupedData.entries.map((e) {
      String dateStr = e.key.split(' ').first;
      DateTime? pDate = _parseDate(dateStr);
      return DailyBatch(
        batchName: e.key, 
        dateString: dateStr, 
        date: pDate, 
        records: e.value
      );
    }).toList();

    newBatches.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!); 
    });

    setState(() {
      batches = newBatches;
      isLoading = false;
    });
  }

  void _loadMockData({String query = ""}) {
    final List<dynamic> rawMockList = [
      {"id": 1, "batchDate": "2026-06-17", "batchCode": "ADN2026-07", "refCode": "TPS26-038", "jkCode": "0144397", "ctn": 1, "trackingNumber": "95856", "status": "delivered"},
      {"id": 2, "batchDate": "2026-06-17", "batchCode": "ADN2026-07", "refCode": "TPS26-039", "jkCode": "0144373", "ctn": 15, "trackingNumber": "88709", "status": "inTransit"},
    ];
    _processAndDisplayData(rawMockList);
  }

  void _showAvailableDatesFilter(BuildContext context) {
    List<String> uniqueDates = batches.map((b) => b.dateString).toSet().toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("เลือกวันที่จัดส่ง", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              
              ListTile(
                leading: const Icon(Icons.all_inbox_rounded, color: Colors.blueAccent),
                title: const Text("แสดงทั้งหมด", style: TextStyle(color: Colors.white)),
                trailing: _selectedDateFilter == null ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () {
                  setState(() => _selectedDateFilter = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: uniqueDates.length,
                  itemBuilder: (context, index) {
                    String dStr = uniqueDates[index];
                    bool isSelected = _selectedDateFilter == dStr;
                    return ListTile(
                      leading: Icon(Icons.calendar_today_rounded, color: isSelected ? Colors.greenAccent : Colors.white54, size: 20),
                      title: Text(dStr, style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                      onTap: () {
                        setState(() => _selectedDateFilter = dStr);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color kDarkBg = Color(0xFF0F0F11);
    const Color kCardDark = Color(0xFF1C1C1E);

    List<DailyBatch> displayBatches = batches.where((batch) {
      if (_selectedDateFilter != null && batch.dateString != _selectedDateFilter) return false;
      return true;
    }).map((batch) {
      return DailyBatch(
        batchName: batch.batchName,
        dateString: batch.dateString,
        date: batch.date,
        records: batch.records.where((r) {
          if (_selectedTab == DeliveryStatusFilter.all) return true;
          if (_selectedTab == DeliveryStatusFilter.inTransit) return r.status == DeliveryStatus.inTransit;
          return r.status == DeliveryStatus.delivered;
        }).toList(),
      );
    }).where((batch) => batch.records.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text("TPS Tracking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedDateFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.redAccent, size: 24),
              onPressed: () => setState(() => _selectedDateFilter = null),
            ),
          
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: _selectedDateFilter != null ? Colors.greenAccent : Colors.white, size: 26),
            tooltip: 'Filter by Date',
            onPressed: () => _showAvailableDatesFilter(context),
          ),

          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.post_add_rounded, color: Colors.indigoAccent, size: 26),
              tooltip: 'เพิ่มข้อมูลพัสดุใหม่',
              onPressed: () async {
                final bool? isAdded = await showModalBottomSheet<bool>( 
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AdminAddPackageModal(), 
                );

                if (isAdded == true) {
                  _fetchTrackingData(); 
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 ปรับ TextField ให้กว้างเต็มจอ และความสูงลดลง (ผ่าน SizedBox และ isDense)
            SizedBox(
              width: double.infinity,
              height: 42, // ปรับความสูงลงมา
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onSubmitted: (value) => _fetchTrackingData(query: value),
                decoration: InputDecoration(
                  isDense: true, // ทำให้ช่องค้นหาดูเพรียวขึ้น
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _fetchTrackingData(); 
                    },
                  ) : null,
                  filled: true,
                  fillColor: kCardDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Container(
              decoration: BoxDecoration(
                color: kCardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  // 🌟 เพิ่มไอคอนเข้าไปใน Tab แต่ละอัน
                  Expanded(child: _buildSegmentedTab("ทั้งหมด", DeliveryStatusFilter.all, Icons.all_inbox_rounded)),
                  Container(width: 1, height: 24, color: Colors.white10),
                  Expanded(child: _buildSegmentedTab("กำลังจัดส่ง", DeliveryStatusFilter.inTransit, Icons.local_shipping_rounded)),
                  Container(width: 1, height: 24, color: Colors.white10),
                  Expanded(child: _buildSegmentedTab("สำเร็จ", DeliveryStatusFilter.delivered, Icons.check_circle_rounded)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDateFilter != null ? "ข้อมูลวันที่ $_selectedDateFilter" : "TPS Delivery", 
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("Live Database", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : displayBatches.isEmpty
                  ? Center(child: Text(_selectedDateFilter != null ? "ไม่พบพัสดุตามสถานะที่เลือกในวันนี้ครับ" : "ไม่พบข้อมูลพัสดุครับ", style: const TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: displayBatches.length,
                      itemBuilder: (context, index) {
                        return _buildBatchCard(context, displayBatches[index], kCardDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 เพิ่ม parameter รับไอคอนเข้ามาแสดงคู่กับข้อความ
  Widget _buildSegmentedTab(String title, DeliveryStatusFilter status, IconData icon) {
    bool isActive = _selectedTab == status;
    Color activeColor = status == DeliveryStatusFilter.delivered 
        ? Colors.greenAccent 
        : (status == DeliveryStatusFilter.inTransit ? Colors.orangeAccent : Colors.blueAccent);

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? activeColor : Colors.white54),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white54,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchCard(BuildContext context, DailyBatch batch, Color cardColor) {
    bool isBulkDelivery = batch.records.length >= 2;
    bool isAllDelivered = batch.records.every((r) => r.status == DeliveryStatus.delivered);
    Color statusColor = isAllDelivered ? Colors.greenAccent : Colors.orangeAccent;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isBulkDelivery ? Colors.white10 : Colors.transparent, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTrackingDetails(context, batch, isAllDelivered),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12, width: 1))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12, height: 12, 
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: statusColor,
                              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 6)]
                            )
                          ),
                          const SizedBox(width: 10),
                          Text(batch.batchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      if (isBulkDelivery)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 12),
                              const SizedBox(width: 4),
                              Text("${batch.records.length} ชิ้น", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildTableHeader(),
                ...batch.records.map((item) => _buildDataRow(context, item)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text("Ref", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text("JK-TPS", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(flex: 1, child: Text("CTN", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text("Tracking", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, TpsTrackingRecord item) {
    bool hasTracking = item.tracking.isNotEmpty && item.tracking != "-";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: Text(item.refCode, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(item.jkCode, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Expanded(
            flex: 1, 
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text(item.ctn, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            )
          ),
          Expanded(
            flex: 3, 
            child: Container(
              alignment: Alignment.centerRight,
              child: hasTracking 
                  ? Text(item.tracking, style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold))
                  : const Text("-", style: TextStyle(color: Colors.white24, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackingDetails(BuildContext context, DailyBatch batch, bool isAllDelivered) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text("สถานะรอบจัดส่ง TPS", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(batch.batchName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 24),
              Row(
                children: const [
                  Icon(Icons.timeline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("ติดตามสถานะ (Timeline)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildTimelineStep(Icons.inventory_2_rounded, "รับพัสดุเข้าระบบ", true, true),
              _buildTimelineStep(Icons.local_shipping_rounded, "กำลังเดินทางไปยังปลายทาง", true, isAllDelivered),
              _buildTimelineStep(Icons.check_circle_rounded, "จัดส่งสำเร็จเรียบร้อย", isAllDelivered, false, isLast: true),
              
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text("รายการพัสดุในรอบนี้ (${batch.records.length} ชิ้น):", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                child: Column(
                  children: batch.records.map((item) {
                    bool isDelivered = item.status == DeliveryStatus.delivered;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Icon(isDelivered ? Icons.check_circle : Icons.local_shipping, 
                              color: isDelivered ? Colors.greenAccent : Colors.orangeAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(item.refCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Text("${item.ctn} CTN", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (isAdmin && !isAllDelivered) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.15),
                      foregroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.greenAccent, width: 1.5)
                      ),
                    ),
                    icon: const Icon(Icons.verified_rounded, size: 22),
                    label: const Text("ทำรายการ 'จัดส่งสำเร็จ' ทั้งหมด", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () => _confirmBatchStatusChange(context, batch),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineStep(IconData stepIcon, String title, bool isReached, bool isPassed, {bool isLast = false}) {
    Color nodeColor = isReached ? (isLast ? Colors.greenAccent : Colors.orangeAccent) : Colors.white24;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isReached ? nodeColor : Colors.transparent,
                border: Border.all(color: nodeColor, width: 2)
              ),
            ),
            if (!isLast)
              Container(
                width: 2, height: 30,
                color: isPassed ? Colors.orangeAccent : Colors.white12,
              )
          ],
        ),
        const SizedBox(width: 16),
        Icon(stepIcon, color: isReached ? Colors.white70 : Colors.white24, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title, 
            style: TextStyle(
              color: isReached ? Colors.white : Colors.white38, 
              fontSize: 14, 
              fontWeight: isReached ? FontWeight.bold : FontWeight.normal
            )
          )
        ),
      ],
    );
  }
}