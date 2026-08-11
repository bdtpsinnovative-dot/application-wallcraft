import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import 'components/add_visit_modal.dart';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kLimeGreen = Color(0xFFD2E862);

class VisitPlannerScreen extends StatefulWidget {
  const VisitPlannerScreen({super.key});

  @override
  State<VisitPlannerScreen> createState() => _VisitPlannerScreenState();
}

class _VisitPlannerScreenState extends State<VisitPlannerScreen> {
  bool _isLoading = true;
  List<dynamic> _visitPlans = [];
  late List<DateTime> _weeks;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _generateWeeks();
    _fetchVisitPlans();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _generateWeeks() {
    _weeks = [];
    final now = DateTime.now();
    final day = now.weekday;
    final monday = now.subtract(Duration(days: day - 1));
    final startMonday = DateTime(monday.year, monday.month, monday.day);
    
    // 4 weeks ago to 7 weeks future (12 weeks total)
    for (int i = -4; i <= 7; i++) {
      _weeks.add(startMonday.add(Duration(days: i * 7)));
    }
  }

  Future<void> _fetchVisitPlans() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getWeeklyVisitPlansBoard();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _visitPlans = data['visit_plans'] ?? [];
            _isLoading = false;
          });
          
          // เลื่อนหน้าจอไปสัปดาห์ปัจจุบัน (index 4) ทันทีที่โหลดเสร็จและสร้าง UI แล้ว
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              double offset = 4 * (240.0 + 16.0);
              _scrollController.jumpTo(offset);
            }
          });
        }
      } else {
        throw Exception("Failed to load plans");
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPlan(Map<String, dynamic> data) async {
    Navigator.of(context).pop(); // close modal
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.addVisitPlan(data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchVisitPlans();
      }
    } catch (e) {
      debugPrint("Error adding plan: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePlan(String id) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.deleteVisitPlan(id);
      if (response.statusCode == 200) {
        await _fetchVisitPlans();
      }
    } catch (e) {
      debugPrint("Error deleting plan: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editPlan(Map<String, dynamic> data) async {
    Navigator.of(context).pop(); // close modal
    setState(() => _isLoading = true);
    try {
      // Use ApiService.updateVisitPlan if it exists, otherwise post with ID or patch
      // Since it's Next.js backend, let's assume it accepts patch for updates, or post handles upsert.
      final response = await ApiService.patch(Uri.parse('${AppConfig.baseUrl}/visit-plans/${data['id']}'), body: jsonEncode(data));
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchVisitPlans();
      }
    } catch (e) {
      debugPrint("Error editing plan: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'completed':
        color = Colors.greenAccent;
        icon = Icons.check_circle_rounded;
        label = "เสร็จสิ้น";
        break;
      case 'in_progress':
        color = Colors.lightBlueAccent;
        icon = Icons.autorenew_rounded;
        label = "ดำเนินการ";
        break;
      case 'pending':
      default:
        color = Colors.amber;
        icon = Icons.schedule_rounded;
        label = "วางแผน";
        break;
    }
    
    return Tooltip(
      message: label,
      child: Icon(icon, color: color, size: 18),
    );
  }

  void _showAddModal(DateTime weekStart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddVisitModal(weekStart: weekStart, onSave: _addPlan, allPlans: _visitPlans),
    );
  }

  void _showEditModal(Map<String, dynamic> plan) {
    final planDate = plan['planned_date'] != null ? DateTime.parse(plan['planned_date']) : DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddVisitModal(weekStart: planDate, onSave: _editPlan, initialData: plan, allPlans: _visitPlans),
    );
  }

  String _formatWeekRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const thaiMonths = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."];
    return "${start.day} ${thaiMonths[start.month - 1]} - ${end.day} ${thaiMonths[end.month - 1]}";
  }

  bool _isCurrentWeek(DateTime start) {
    final now = DateTime.now();
    final day = now.weekday;
    final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: day - 1));
    return start.isAtSameMomentAs(currentMonday);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        title: const Text("แผนการเข้าพบลูกค้า (12 สัปดาห์)", style: TextStyle(color: Colors.white, fontSize: 18)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchVisitPlans,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
          : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: _weeks.length,
              itemBuilder: (context, index) {
                final weekStart = _weeks[index];
                final isCurrent = _isCurrentWeek(weekStart);
                
                // Get plans for this week
                final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
                final weekPlans = _visitPlans.where((p) {
                  if (p['planned_date'] == null) return false;
                  final planDate = DateTime.parse(p['planned_date']);
                  return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);
                }).toList();

                return Container(
                  width: MediaQuery.of(context).size.width * 0.88, 
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: kCardDark,
                    border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),
                    borderRadius: BorderRadius.circular(12), // ปรับให้ขอบมนเข้ากับดีไซน์รวมของแอป
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatWeekRange(weekStart),
                              style: TextStyle(
                                color: isCurrent ? kLimeGreen : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: kLimeGreen,
                                child: const Text("สัปดาห์นี้", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: weekPlans.length,
                          itemBuilder: (context, i) {
                            final plan = weekPlans[i];
                            final compName = plan['companies']?['name'] ?? 'Unknown Company';
                            final projName = plan['projects']?['project_name'];
                            
                            return InkWell(
                              onTap: () {
                                _showEditModal(plan);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  border: Border.all(color: Colors.white12),
                                  borderRadius: BorderRadius.circular(8), // ขอบมนสำหรับ item ด้านใน
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            compName,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(plan['status']?.toString()),
                                      ],
                                    ),
                                    if (plan['project_concept'] != null && plan['project_concept'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        plan['project_concept'], 
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        maxLines: 1, // แสดงบรรทัดเดียว
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      InkWell(
                        onTap: () => _showAddModal(weekStart),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white54, size: 18),
                              SizedBox(width: 8),
                              Text("เพิ่มแผนเข้าพบ", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

