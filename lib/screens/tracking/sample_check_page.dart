import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../constants.dart';

const Color kDarkBg = Color(0xFF0F0F11); 
const Color kCardDark = Color(0xFF1C1C1E); 
const Color kLimeGreen = Color(0xFFD2E862); 

class SampleCheckPage extends StatefulWidget {
  const SampleCheckPage({Key? key}) : super(key: key);

  @override
  State<SampleCheckPage> createState() => _SampleCheckPageState();
}

class _SampleCheckPageState extends State<SampleCheckPage> with SingleTickerProviderStateMixin {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdmin = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _checkAdminRole();
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          if (mounted) setState(() => _isAdmin = true);
        }
      }
    } catch (e) {
      debugPrint("Error checking admin role: $e");
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/sample-orders');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          if (mounted) {
            setState(() {
              _orders = jsonResponse['data'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          throw Exception('Failed to load data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/sample-orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'status': newStatus}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('อัปเดตสถานะสำเร็จ', style: TextStyle(color: Colors.black)), backgroundColor: kLimeGreen, behavior: SnackBarBehavior.floating),
          );
        }
        _fetchOrders();
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orangeAccent;
      case 'approved':
        return Colors.blueAccent;
      case 'completed':
        return kLimeGreen;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'รออนุมัติ';
      case 'approved':
        return 'กำลังผลิต';
      case 'completed':
        return 'เสร็จแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return status.toUpperCase();
    }
  }

  List<dynamic> get _filteredOrders {
    if (_tabController.index == 0) return _orders;
    if (_tabController.index == 1) return _orders.where((o) => o['status'] == 'pending').toList();
    if (_tabController.index == 2) return _orders.where((o) => o['status'] == 'approved').toList();
    if (_tabController.index == 3) return _orders.where((o) => o['status'] == 'completed').toList();
    return _orders;
  }

  // สร้างปุ่มเปลี่ยนสถานะด่วนสำหรับ Admin ให้กดได้เลย
  Widget _buildAdminQuickActions(String orderId, String currentStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text('เปลี่ยนสถานะ (แอดมิน):', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickActionBtn(
              icon: Icons.hourglass_empty,
              label: 'รออนุมัติ',
              color: Colors.orangeAccent,
              isActive: currentStatus == 'pending',
              onTap: () => _updateStatus(orderId, 'pending'),
            ),
            _buildQuickActionBtn(
              icon: Icons.handyman,
              label: 'ผลิต',
              color: Colors.blueAccent,
              isActive: currentStatus == 'approved',
              onTap: () => _updateStatus(orderId, 'approved'),
            ),
            _buildQuickActionBtn(
              icon: Icons.check_circle_outline,
              label: 'เสร็จ',
              color: kLimeGreen,
              isActive: currentStatus == 'completed',
              onTap: () => _updateStatus(orderId, 'completed'),
            ),
            _buildQuickActionBtn(
              icon: Icons.cancel_outlined,
              label: 'ปฏิเสธ',
              color: Colors.redAccent,
              isActive: currentStatus == 'rejected',
              onTap: () => _updateStatus(orderId, 'rejected'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon, 
    required String label, 
    required Color color, 
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isActive ? null : onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.2) : kCardDark,
            border: Border.all(color: isActive ? color : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isActive ? color : Colors.white54, size: 18),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  color: isActive ? color : Colors.white54, 
                  fontSize: 10, 
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        actions: [
          IconButton(
            iconSize: 20,
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kLimeGreen,
          labelColor: kLimeGreen,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          isScrollable: false, // 🌟 ปิดการเลื่อน
          indicatorWeight: 3,
          dividerColor: Colors.transparent, // ซ่อนเส้นแบ่งข้างใต้ TabBar
          tabs: const [
            Tab(
              icon: Icon(Icons.list_alt, size: 20),
              text: 'ทั้งหมด',
            ),
            Tab(
              icon: Icon(Icons.hourglass_empty, size: 20),
              text: 'รออนุมัติ',
            ),
            Tab(
              icon: Icon(Icons.handyman, size: 20),
              text: 'กำลังผลิต',
            ),
            Tab(
              icon: Icon(Icons.check_circle_outline, size: 20),
              text: 'เสร็จแล้ว',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kLimeGreen, strokeWidth: 2))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('Error: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCardDark, 
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: _fetchOrders,
                        child: const Text('Try Again', style: TextStyle(fontSize: 13)),
                      )
                    ],
                  ),
                )
              : displayOrders.isEmpty
                  ? const Center(child: Text('ไม่มีประวัติในสถานะนี้', style: TextStyle(color: Colors.white54, fontSize: 13)))
                  : RefreshIndicator(
                      color: kLimeGreen,
                      backgroundColor: kCardDark,
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: displayOrders.length,
                        itemBuilder: (context, index) {
                          final order = displayOrders[index];
                          final companyName = order['companies']?['name'] ?? 'Unknown Company';
                          final projectName = order['projects']?['project_name'] ?? 'Unknown Project';
                          final status = order['status'] ?? 'N/A';
                          final items = order['sample_order_items'] as List<dynamic>? ?? [];

                          String formattedDate = '';
                          if (order['created_at'] != null) {
                            try {
                              final date = DateTime.parse(order['created_at']).toLocal();
                              formattedDate = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
                            } catch (_) {
                              formattedDate = order['created_at'];
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: kCardDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide.none,
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                collapsedIconColor: Colors.white54,
                                iconColor: Colors.white,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        companyName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          projectName, 
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(formattedDate, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                                    ],
                                  ),
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (items.isEmpty)
                                          const Text('-', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                        ...items.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.check_circle_outline, size: 16, color: Colors.white38),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${item['product_name'] ?? '-'}  x${item['qty'] ?? 1}',
                                                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 13),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Color: ${item['color'] ?? '-'} | Series: ${item['series'] ?? '-'}',
                                                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                                                      ),
                                                      Text(
                                                        'Film: ${item['film'] ?? '-'}',
                                                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        if (order['note'] != null && order['note'].toString().isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8.0),
                                            child: Divider(color: Colors.black26, height: 1),
                                          ),
                                          Text('Note: ${order['note']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white54, fontSize: 12)),
                                        ],
                                        
                                        // 🌟 4 ปุ่มสถานะสำหรับแอดมิน กดได้เลยไม่ต้องเข้า Dialog
                                        if (_isAdmin) _buildAdminQuickActions(order['id'], status)
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}