import 'dart:convert';
import 'dart:ui';
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
  bool _isLoadingRepeated = true;
  bool _isFirstLoad = true;
  List<dynamic> _visitPlans = [];
  List<dynamic> _repeatedVisits = [];
  Set<int> _expandedRepeatedVisits = {};
  late List<DateTime> _weeks;
  late PageController _pageController;
  DateTime? _pendingTargetWeek;

  @override
  void initState() {
    super.initState();
    _generateWeeks([]);
    _pageController = PageController(initialPage: 1, viewportFraction: 0.85);
    _fetchVisitPlans();
    _fetchRepeatedVisits();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _weekStart(DateTime value) {
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  void _generateWeeks(List<dynamic> plans, {DateTime? ensureWeek}) {
    final now = DateTime.now();
    final currentMonday = _weekStart(now);
    DateTime minWeek = currentMonday;
    DateTime maxWeek = currentMonday;

    for (var p in plans) {
      final date = _parseDate(p['planned_date']);
      if (date != null) {
        final pMonday = _weekStart(date);
        if (pMonday.isBefore(minWeek)) minWeek = pMonday;
        if (pMonday.isAfter(maxWeek)) maxWeek = pMonday;
      }
    }

    if (ensureWeek != null) {
      final targetMonday = _weekStart(ensureWeek);
      if (targetMonday.isBefore(minWeek)) minWeek = targetMonday;
      if (targetMonday.isAfter(maxWeek)) maxWeek = targetMonday;
    }

    final startBound = minWeek.subtract(const Duration(days: 7));
    final endBound = maxWeek.add(const Duration(days: 7));

    _weeks = [];
    for (
      DateTime w = startBound;
      !w.isAfter(endBound);
      w = w.add(const Duration(days: 7))
    ) {
      _weeks.add(w);
    }
  }

  void _queueWeekFocus(DateTime? targetWeek) {
    if (targetWeek != null) {
      _pendingTargetWeek = _weekStart(targetWeek);
    } else if (_isFirstLoad) {
      _pendingTargetWeek = _weekStart(DateTime.now());
    }

    if (_pendingTargetWeek == null) return;
    _schedulePendingWeekFocus();
  }

  void _schedulePendingWeekFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingTargetWeek == null) return;
      if (!_pageController.hasClients) {
        _schedulePendingWeekFocus();
        return;
      }

      final targetIndex = _weeks.indexWhere(
        (week) => week.isAtSameMomentAs(_pendingTargetWeek!),
      );
      if (targetIndex == -1) return;

      _pendingTargetWeek = null;
      _isFirstLoad = false;
      final currentPage = _pageController.position.haveDimensions
          ? _pageController.page?.round()
          : null;
      if (currentPage != targetIndex) {
        _pageController.jumpToPage(targetIndex);
      }
    });
  }

  Future<void> _fetchVisitPlans({DateTime? targetWeek}) async {
    if (!mounted) return;
    ApiService.clearCache();
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getWeeklyVisitPlansBoard();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> plans = data['visit_plans'] ?? [];
        
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        for (var plan in plans) {
          if ((plan['status'] == 'pending' || plan['status'] == null) && plan['planned_date'] != null) {
            final pDate = DateTime.parse(plan['planned_date']);
            final planDay = DateTime(pDate.year, pDate.month, pDate.day);
            if (planDay.isBefore(today)) {
              plan['status'] = 'unsuccessful';
              ApiService.patch(
                Uri.parse('${AppConfig.baseUrl}/visit-plans/${plan['id']}'),
                body: jsonEncode({'status': 'unsuccessful'}),
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _visitPlans = plans;
            _generateWeeks(_visitPlans, ensureWeek: targetWeek);
            _isLoading = false;
          });
          _queueWeekFocus(targetWeek);
        }
      } else {
        throw Exception("Failed to load plans");
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRepeatedVisits() async {
    setState(() => _isLoadingRepeated = true);
    try {
      final response = await ApiService.getRepeatedVisits();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _repeatedVisits = data['repeatedVisits'] ?? [];
            _isLoadingRepeated = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRepeated = false);
      }
    } catch (e) {
      debugPrint("Error fetching repeated visits: $e");
      if (mounted) setState(() => _isLoadingRepeated = false);
    }
  }

  Future<void> _addPlan(Map<String, dynamic> data) async {
    Navigator.of(context).pop(); // close modal
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.addVisitPlan(data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        DateTime? targetDate;
        targetDate = _parseDate(data['planned_date']);
        await _fetchVisitPlans(targetWeek: targetDate);
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint(
          "Failed to add plan: ${response.statusCode} - ${response.body}",
        );
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
      final response = await ApiService.patch(
        Uri.parse('${AppConfig.baseUrl}/visit-plans/${data['id']}'),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        DateTime? targetDate;
        targetDate = _parseDate(data['planned_date']);
        await _fetchVisitPlans(targetWeek: targetDate);
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint(
          "Failed to edit plan: ${response.statusCode} - ${response.body}",
        );
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
      case 'unsuccessful':
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        label = "ไม่สำเร็จ";
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
      builder: (ctx) => AddVisitModal(
        weekStart: weekStart,
        onSave: _addPlan,
        allPlans: _visitPlans,
      ),
    );
  }

  void _showEditModal(Map<String, dynamic> plan) {
    final planDate = plan['planned_date'] != null
        ? DateTime.parse(plan['planned_date'])
        : DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddVisitModal(
        weekStart: planDate,
        onSave: _editPlan,
        initialData: plan,
        allPlans: _visitPlans,
      ),
    );
  }

  String _formatWeekRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    const thaiMonths = [
      "ม.ค.",
      "ก.พ.",
      "มี.ค.",
      "เม.ย.",
      "พ.ค.",
      "มิ.ย.",
      "ก.ค.",
      "ส.ค.",
      "ก.ย.",
      "ต.ค.",
      "พ.ย.",
      "ธ.ค.",
    ];
    return "${start.day} ${thaiMonths[start.month - 1]} - ${end.day} ${thaiMonths[end.month - 1]}";
  }

  bool _isCurrentWeek(DateTime start) {
    final now = DateTime.now();
    final day = now.weekday;
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: day - 1));
    return start.isAtSameMomentAs(currentMonday);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kLimeGreen.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kLimeGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: kLimeGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "แผนการเข้าพบลูกค้า",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Weekly Visit Planner",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          _fetchVisitPlans();
                          _fetchRepeatedVisits();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kCardDark,
                            border: Border.all(
                              color: kLimeGreen.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: kLimeGreen,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kLimeGreen),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 440,
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _weeks.length,
                                  itemBuilder: (context, index) {
                                    final weekStart = _weeks[index];
                                    final isCurrent = _isCurrentWeek(weekStart);

                                    // Get plans for this week
                                    final endOfWeek = weekStart.add(
                                      const Duration(
                                        days: 6,
                                        hours: 23,
                                        minutes: 59,
                                      ),
                                    );
                                    final weekPlans = _visitPlans.where((p) {
                                      if (p['planned_date'] == null)
                                        return false;
                                      final planDate = DateTime.parse(
                                        p['planned_date'],
                                      );
                                      return planDate.isAfter(
                                            weekStart.subtract(
                                              const Duration(seconds: 1),
                                            ),
                                          ) &&
                                          planDate.isBefore(endOfWeek);
                                    }).toList();

                                    return AnimatedBuilder(
                                      animation: _pageController,
                                      builder: (context, child) {
                                        double value = 1.0;
                                        if (_pageController
                                            .position
                                            .haveDimensions) {
                                          value =
                                              (_pageController.page! - index)
                                                  .abs();
                                          value = (1 - (value * 0.15)).clamp(
                                            0.85,
                                            1.0,
                                          );
                                        } else {
                                          value = index == 4 ? 1.0 : 0.85;
                                        }

                                        return Center(
                                          child: Transform.scale(
                                            scale: value,
                                            child: Opacity(
                                              opacity: value.clamp(0.5, 1.0),
                                              child: Container(
                                                width: double.infinity,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: kCardDark,
                                                  border: Border.all(
                                                    color: isCurrent
                                                        ? kLimeGreen
                                                        : Colors.white12,
                                                    width: isCurrent ? 2 : 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isCurrent
                                                            ? kLimeGreen
                                                                  .withAlpha(25)
                                                            : Colors.black26,
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    11,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            _formatWeekRange(
                                                              weekStart,
                                                            ),
                                                            style: TextStyle(
                                                              color: isCurrent
                                                                  ? kLimeGreen
                                                                  : Colors
                                                                        .white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          Builder(
                                                            builder: (context) {
                                                              String label = "";
                                                              Color
                                                              bgColor = Colors
                                                                  .transparent;
                                                              Color textColor =
                                                                  Colors.white;

                                                              if (isCurrent) {
                                                                label =
                                                                    "สัปดาห์นี้";
                                                                bgColor =
                                                                    kLimeGreen;
                                                                textColor =
                                                                    Colors
                                                                        .black;
                                                              } else if (weekStart
                                                                  .isBefore(
                                                                    DateTime.now(),
                                                                  )) {
                                                                label =
                                                                    "ที่ผ่านมา";
                                                                bgColor = Colors
                                                                    .white12;
                                                                textColor =
                                                                    Colors
                                                                        .white54;
                                                              } else {
                                                                label =
                                                                    "ล่วงหน้า";
                                                                bgColor = Colors
                                                                    .blueAccent
                                                                    .withAlpha(
                                                                      25,
                                                                    );
                                                                textColor = Colors
                                                                    .blueAccent;
                                                              }

                                                              if (label.isEmpty)
                                                                return const SizedBox.shrink();

                                                              return Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      bgColor,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  label,
                                                                  style: TextStyle(
                                                                    color:
                                                                        textColor,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: weekPlans.isEmpty
                                                          ? Center(
                                                              child: Text(
                                                                index == 0
                                                                    ? "ไม่มีแผนงานที่เก่ากว่านี้"
                                                                    : (index ==
                                                                              _weeks.length - 1
                                                                          ? "ไม่มีแผนที่ใหม่กว่านี้\nสามารถสร้างแผนใหม่ได้"
                                                                          : "ไม่มีแผนเข้าพบ"),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            )
                                                          : ListView.builder(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              itemCount:
                                                                  weekPlans
                                                                      .length,
                                                              itemBuilder: (context, i) {
                                                                final plan =
                                                                    weekPlans[i];
                                                                final compName =
                                                                    plan['companies']?['name'] ??
                                                                    'Unknown Company';

                                                                return InkWell(
                                                                  onTap: () {
                                                                    _showEditModal(
                                                                      plan,
                                                                    );
                                                                  },
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                  child: Container(
                                                                    margin:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              8,
                                                                        ),
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          12,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .black38,
                                                                      border: Border.all(
                                                                        color: Colors
                                                                            .white12,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                compName,
                                                                                style: const TextStyle(
                                                                                  color: Colors.white,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 13,
                                                                                ),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            _buildStatusBadge(
                                                                              plan['status']?.toString(),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        if (plan['project_concept'] !=
                                                                                null &&
                                                                            plan['project_concept'].toString().isNotEmpty) ...[
                                                                          const SizedBox(
                                                                            height:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            plan['project_concept'],
                                                                            style: const TextStyle(
                                                                              color: Colors.white70,
                                                                              fontSize: 11,
                                                                            ),
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
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
                                                      onTap: () =>
                                                          _showAddModal(
                                                            weekStart,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration:
                                                            const BoxDecoration(
                                                              border: Border(
                                                                top: BorderSide(
                                                                  color: Colors
                                                                      .white12,
                                                                ),
                                                              ),
                                                            ),
                                                        child: const Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons.add,
                                                              color: Colors
                                                                  .white54,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              "เพิ่มแผนเข้าพบ",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white54,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ), // Ends Column
                                              ), // Ends Container
                                            ), // Ends Opacity
                                          ), // Ends Transform.scale
                                        ); // Ends Center
                                      }, // Ends builder
                                    ); // Ends AnimatedBuilder
                                  }, // Ends itemBuilder
                                ), // Ends PageView.builder
                              ), // Ends SizedBox
                              const SizedBox(height: 24),
                              // --- Repeated Visits Section ---
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: kLimeGreen.withAlpha(38),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.autorenew_rounded,
                                        color: kLimeGreen,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "ผลการเข้าพบซ้ำ (3 เช็คอินขึ้นไป)",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _isLoadingRepeated
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: kLimeGreen,
                                        ),
                                      ),
                                    )
                                  : _repeatedVisits.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: Text(
                                          "ไม่มีข้อมูลการเข้าพบซ้ำ",
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      itemCount: _repeatedVisits.length,
                                      itemBuilder: (context, index) {
                                        final comp = _repeatedVisits[index];
                                        final uniqueProjects =
                                            comp['uniqueProjects']
                                                as Map<String, dynamic>? ??
                                            {};
                                        bool isExpanded =
                                            _expandedRepeatedVisits.contains(
                                              index,
                                            );
                                        final allProjects = uniqueProjects
                                            .entries
                                            .toList();
                                        final displayProjects = isExpanded
                                            ? allProjects
                                            : allProjects.take(2).toList();

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: kCardDark,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.white12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      comp['name'] ?? 'Unknown',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: kLimeGreen,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      "${comp['count']} ครั้ง",
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (uniqueProjects
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                const Divider(
                                                  color: Colors.white12,
                                                  height: 1,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  "${uniqueProjects.length} โปรเจค",
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                ...displayProjects.map((e) {
                                                  String dateStr = '';
                                                  if (e.value != null) {
                                                    final d = DateTime.parse(
                                                      e.value.toString(),
                                                    );
                                                    final months = [
                                                      "ม.ค.",
                                                      "ก.พ.",
                                                      "มี.ค.",
                                                      "เม.ย.",
                                                      "พ.ค.",
                                                      "มิ.ย.",
                                                      "ก.ค.",
                                                      "ส.ค.",
                                                      "ก.ย.",
                                                      "ต.ค.",
                                                      "พ.ย.",
                                                      "ธ.ค.",
                                                    ];
                                                    dateStr =
                                                        "${d.day} ${months[d.month - 1]} ${(d.year + 543) % 100}";
                                                  }

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 6.0,
                                                        ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .folder_open_rounded,
                                                          color:
                                                              Colors.blueAccent,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            e.key,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        ),
                                                        if (dateStr.isNotEmpty)
                                                          Text(
                                                            "($dateStr)",
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white38,
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                                if (allProjects.length > 2)
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        if (isExpanded) {
                                                          _expandedRepeatedVisits
                                                              .remove(index);
                                                        } else {
                                                          _expandedRepeatedVisits
                                                              .add(index);
                                                        }
                                                      });
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4.0,
                                                          ),
                                                      child: Text(
                                                        isExpanded
                                                            ? "ซ่อน"
                                                            : "ดูเพิ่มเติม...",
                                                        style: const TextStyle(
                                                          color: kLimeGreen,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
