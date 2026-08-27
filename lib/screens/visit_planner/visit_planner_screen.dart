import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import 'components/add_visit_modal.dart';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kLimeGreen = Color(0xFFD2E862);

class VisitPlannerScreen extends StatefulWidget {
  const VisitPlannerScreen({super.key});

  @override
  State<VisitPlannerScreen> createState() => VisitPlannerScreenState();
}

class VisitPlannerScreenState extends State<VisitPlannerScreen> {
  bool _isLoading = true;
  bool _isLoadingRepeated = true;
  bool _isFirstLoad = true;
  String? _loadErrorMessage;
  List<dynamic> _visitPlans = [];
  List<dynamic> _repeatedVisits = [];
  Set<int> _expandedRepeatedVisits = {};
  late List<DateTime> _weeks;
  late PageController _pageController;
  DateTime? _pendingTargetWeek;
  final ScreenshotController _weekScreenshotController = ScreenshotController();
  bool _isCapturingWeek = false;
  Timer? _overdueRefreshTimer;

  bool _sortByProjectCount = true;
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isAdmin = false;
  String _selectedUserId = 'all';
  String _selectedStatusFilter = 'all';
  List<dynamic> _usersList = [];

  Future<void> _checkAdminAndFetchUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final response = await ApiService.post(
        Uri.parse('${AppConfig.baseUrl}/profile'),
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['profile'];
        if (data != null && data['role'] == 'admin') {
          _isAdmin = true;
        }
      }

      final usersRes = await ApiService.getUsers();
      if (usersRes.statusCode == 200) {
        final usersData = jsonDecode(usersRes.body);
        final sortedUsers = List<dynamic>.from(usersData['users'] ?? []);
        sortedUsers.sort((a, b) {
          final countA = (a['order_count'] as num?)?.toInt() ?? 0;
          final countB = (b['order_count'] as num?)?.toInt() ?? 0;
          final countCompare = countB.compareTo(countA);
          if (countCompare != 0) return countCompare;
          final nameA = a['full_name']?.toString() ?? '';
          final nameB = b['full_name']?.toString() ?? '';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        if (mounted) {
          setState(() {
            _usersList = sortedUsers;
          });
        }
      } else {
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Admin check error: $e');
    }
  }

  List<dynamic> get _filteredVisitPlans {
    return _visitPlans.where((p) {
      final userMatches =
          _selectedUserId == 'all' ||
          (p['user_id'] ?? p['profiles']?['id']) == _selectedUserId;
      final statusMatches =
          _selectedStatusFilter == 'all' ||
          _statusFilterKey(p) == _selectedStatusFilter;
      return userMatches && statusMatches;
    }).toList();
  }

  String _statusFilterKey(dynamic plan) {
    switch (_effectivePlanStatus(plan)) {
      case 'completed':
      case 'success':
        return 'completed';
      case 'in_progress':
        return 'in_progress';
      case 'missed':
      case 'failed':
      case 'canceled':
      case 'cancelled':
        return 'unsuccessful';
      case 'overdue':
        return 'overdue';
      default:
        return 'pending';
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _filteredVisitPlans.where((plan) {
      if (plan['planned_date'] == null) return false;
      final pDate = DateTime.parse(plan['planned_date']);
      return pDate.year == day.year &&
          pDate.month == day.month &&
          pDate.day == day.day;
    }).toList();
  }

  void _sortRepeatedVisits() {
    if (_sortByProjectCount) {
      _repeatedVisits.sort((a, b) {
        final aCount = (a['uniqueProjects'] as Map?)?.length ?? 0;
        final bCount = (b['uniqueProjects'] as Map?)?.length ?? 0;
        return bCount.compareTo(aCount);
      });
    } else {
      _repeatedVisits.sort((a, b) {
        final aCount = a['visit_count'] as int? ?? 0;
        final bCount = b['visit_count'] as int? ?? 0;
        return bCount.compareTo(aCount);
      });
    }
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortByProjectCount = prefs.getBool('sortByProjectCount') ?? true;
    });
    _sortRepeatedVisits();
  }

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    _checkAdminAndFetchUsers();
    _generateWeeks([]);
    _pageController = PageController(initialPage: 1, viewportFraction: 0.96);
    _overdueRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    refreshVisitPlans();
    _fetchRepeatedVisits();
  }

  @override
  void dispose() {
    _overdueRefreshTimer?.cancel();
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) return _asMap(value.first);
    return <String, dynamic>{};
  }

  String _assignedSalesNameForPlan(dynamic plan) {
    final directName = plan['assigned_name']?.toString().trim();
    if (directName != null && directName.isNotEmpty) return directName;

    final profileName = _asMap(
      plan['profiles'],
    )['full_name']?.toString().trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;

    return 'ไม่ระบุผู้รับผิดชอบ';
  }

  String _planTimeRange(dynamic plan) {
    final start = plan['start_time']?.toString().trim();
    final end = plan['end_time']?.toString().trim();
    if (start == null || start.isEmpty || end == null || end.isEmpty) {
      return 'ไม่ระบุเวลา';
    }
    String shortTime(String value) =>
        value.length >= 5 ? value.substring(0, 5) : value;
    return '${shortTime(start)} - ${shortTime(end)} น.';
  }

  bool _isPlanOverdue(dynamic plan) {
    if (plan['status']?.toString() != 'pending') return false;
    final plannedDate = _parseDate(plan['planned_date']);
    if (plannedDate == null) return false;

    final day = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);
    final rawEndTime = plan['end_time']?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(rawEndTime);
    final deadline = match == null
        ? day.add(const Duration(hours: 23, minutes: 59, seconds: 59))
        : DateTime(
            day.year,
            day.month,
            day.day,
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
          );
    return DateTime.now().isAfter(deadline);
  }

  String _effectivePlanStatus(dynamic plan) {
    final status = plan['status']?.toString() ?? 'pending';
    return status == 'pending' && _isPlanOverdue(plan) ? 'overdue' : status;
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

  Future<void> refreshVisitPlans({
    DateTime? targetWeek,
    bool isSilent = false,
  }) async {
    if (!mounted) return;
    ApiService.clearCache();
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final response = await ApiService.getWeeklyVisitPlansBoard();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> plans = data['visit_plans'] ?? [];
        // Keep the app safe even when an older backend instance still returns
        // soft-deleted plans; the canonical filter also lives on the API.
        plans = plans
            .where(
              (plan) =>
                  plan is Map &&
                  plan['is_deleted'] != true &&
                  plan['status'] != 'deleted',
            )
            .toList();

        if (mounted) {
          setState(() {
            _visitPlans = plans;
            _loadErrorMessage = null;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadErrorMessage = 'ไม่สามารถโหลดข้อมูลแผนงานได้';
        });
      }
    }
  }

  Future<void> _fetchVisitPlans({DateTime? targetWeek}) =>
      refreshVisitPlans(targetWeek: targetWeek);

  Future<void> _fetchRepeatedVisits() async {
    setState(() => _isLoadingRepeated = true);
    try {
      final response = await ApiService.getRepeatedVisits();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _repeatedVisits = data['repeatedVisits'] ?? [];
            _sortRepeatedVisits();
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

  Future<void> _refreshPlannerData() async {
    await Future.wait([
      refreshVisitPlans(isSilent: true),
      _fetchRepeatedVisits(),
    ]);

    if (mounted && _loadErrorMessage != null && _visitPlans.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text('ไม่มีอินเทอร์เน็ต จึงยังใช้ข้อมูลเดิม')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _addPlan(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.addVisitPlan(
        data,
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 || response.statusCode == 201) {
        DateTime? targetDate;
        targetDate = _parseDate(data['planned_date']);
        await _fetchVisitPlans(targetWeek: targetDate);
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() => _isLoading = false);
        await _showPlanSaveError(_getPlanSaveError(response));
      }
    } on TimeoutException {
      if (mounted) setState(() => _isLoading = false);
      await _showPlanSaveError(
        'เชื่อมต่อเซิร์ฟเวอร์นานเกินไป ข้อมูลที่กรอกยังอยู่ กรุณาตรวจสอบอินเทอร์เน็ตแล้วกดบันทึกใหม่',
      );
    } catch (e) {
      debugPrint("Error adding plan: $e");
      if (mounted) setState(() => _isLoading = false);
      await _showPlanSaveError(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ข้อมูลที่กรอกยังอยู่ กรุณาตรวจสอบอินเทอร์เน็ตแล้วกดบันทึกใหม่',
      );
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
    setState(() => _isLoading = true);
    try {
      // Use ApiService.updateVisitPlan if it exists, otherwise post with ID or patch
      final response = await ApiService.patch(
        Uri.parse(
          '${AppConfig.baseUrl}/visit-plans?id=${Uri.encodeQueryComponent(data['id'].toString())}',
        ),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 || response.statusCode == 201) {
        DateTime? targetDate;
        targetDate = _parseDate(data['planned_date']);
        await _fetchVisitPlans(targetWeek: targetDate);
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() => _isLoading = false);
        await _showPlanSaveError(_getPlanSaveError(response));
      }
    } on TimeoutException {
      if (mounted) setState(() => _isLoading = false);
      await _showPlanSaveError(
        'เชื่อมต่อเซิร์ฟเวอร์นานเกินไป ข้อมูลที่แก้ไขยังอยู่ กรุณาตรวจสอบอินเทอร์เน็ตแล้วกดบันทึกใหม่',
      );
    } catch (e) {
      debugPrint("Error editing plan: $e");
      if (mounted) setState(() => _isLoading = false);
      await _showPlanSaveError(
        'แก้ไขไม่สำเร็จ ข้อมูลเดิมยังอยู่ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
      );
    }
  }

  String _getPlanSaveError(dynamic response) {
    try {
      final decoded = jsonDecode(response.body);
      final code = decoded is Map ? decoded['code']?.toString() : null;
      if (code == 'VISIT_PLAN_TIME_COLUMNS_MISSING' ||
          code == 'VISIT_PLAN_REQUIRED_COLUMNS_MISSING') {
        return 'ฐานข้อมูลยังไม่มีคอลัมน์ที่จำเป็น (start_time, end_time หรือ client_request_id) กรุณารันไฟล์ SQL migration ก่อน แล้วลองบันทึกใหม่';
      }
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])
          : null;
      if (message != null && message.toString().trim().isNotEmpty) {
        final code = decoded is Map ? decoded['code']?.toString() : null;
        final details = decoded is Map ? decoded['details']?.toString() : null;
        final detailText =
            details != null &&
                details.isNotEmpty &&
                details != message.toString()
            ? '\nรายละเอียดระบบ: $details'
            : '';
        final codeText = code != null && code.isNotEmpty ? '\nรหัส: $code' : '';
        return '${message.toString()}$codeText$detailText\nข้อมูลที่กรอกยังอยู่ กรุณาแก้ไขหรือลองใหม่';
      }
    } catch (_) {}
    return 'บันทึกไม่สำเร็จ (รหัส ${response.statusCode})\nข้อมูลที่กรอกยังอยู่ กรุณาตรวจสอบข้อมูลและลองใหม่';
  }

  Future<void> _showPlanSaveError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kCardDark,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text(
              'บันทึกไม่สำเร็จ',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'ปิด และลองบันทึกใหม่',
              style: TextStyle(color: kLimeGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          eventLoader: _getEventsForDay,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox();
              return Positioned(
                bottom: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(4).map((event) {
                    final plan = event as Map<String, dynamic>;
                    final status = _effectivePlanStatus(plan);
                    Color markerColor = kLimeGreen;
                    if (status == 'completed' || status == 'success') {
                      markerColor = Colors.green;
                    } else if (status == 'missed' ||
                        status == 'failed' ||
                        status == 'canceled' ||
                        status == 'cancelled') {
                      markerColor = Colors.redAccent;
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: markerColor,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          calendarStyle: const CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: kLimeGreen,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: TextStyle(color: Colors.white),
            weekendTextStyle: TextStyle(color: Colors.white70),
            outsideTextStyle: TextStyle(color: Colors.white38),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.white54),
            weekendStyle: TextStyle(color: Colors.white54),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _selectedDay == null
              ? const Center(
                  child: Text(
                    "เลือกวันที่เพื่อดูแผนงาน",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Builder(
                  builder: (context) {
                    final dayPlans = _getEventsForDay(_selectedDay!);
                    if (dayPlans.isEmpty) {
                      return const Center(
                        child: Text(
                          "ไม่มีแผนงานในวันนี้",
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _refreshPlannerData,
                      color: kLimeGreen,
                      backgroundColor: kCardDark,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: dayPlans.length,
                        itemBuilder: (context, index) {
                          final plan = dayPlans[index];
                          final company = _asMap(plan['companies']);
                          final profile = _asMap(plan['profiles']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: kLimeGreen.withOpacity(0.2),
                                  backgroundImage: profile['avatar_url'] != null
                                      ? NetworkImage(profile['avatar_url'])
                                      : null,
                                  child: profile['avatar_url'] == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 16,
                                          color: kLimeGreen,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company['name'] ?? 'Unknown Company',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _assignedSalesNameForPlan(plan),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _planTimeRange(plan),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(_effectivePlanStatus(plan)),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<dynamic> _plansForWeek(DateTime weekStart) {
    final endOfWeek = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );

    return _filteredVisitPlans.where((plan) {
      final planDate = _parseDate(plan['planned_date']);
      if (planDate == null) return false;
      return !planDate.isBefore(weekStart) && !planDate.isAfter(endOfWeek);
    }).toList();
  }

  Future<void> _captureWeekPlan(
    DateTime weekStart,
    List<dynamic> weekPlans,
  ) async {
    if (_isCapturingWeek) return;

    setState(() => _isCapturingWeek = true);
    try {
      final captureWidth = MediaQuery.of(context).size.width - 32;
      final imageBytes = await _weekScreenshotController.captureFromLongWidget(
        InheritedTheme.captureAll(
          context,
          Material(
            color: kDarkBg,
            child: SizedBox(
              width: captureWidth,
              child: _buildWeekCaptureContent(weekStart, weekPlans),
            ),
          ),
        ),
        context: context,
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2,
      );

      final weekLabel =
          '${weekStart.year}${weekStart.month.toString().padLeft(2, '0')}${weekStart.day.toString().padLeft(2, '0')}';
      await Gal.putImageBytes(imageBytes, name: 'weekly_visit_plan_$weekLabel');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกรูปแผนงานลงเครื่องแล้ว'),
          backgroundColor: kLimeGreen,
        ),
      );

      final directory = await getTemporaryDirectory();
      final imageFile = File(
        '${directory.path}/weekly_visit_plan_$weekLabel.png',
      );
      await imageFile.writeAsBytes(imageBytes);
      await Share.shareXFiles([
        XFile(imageFile.path),
      ], text: 'แผนการเข้าพบลูกค้า ${_formatWeekRange(weekStart)}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สร้างภาพแผนงานไม่สำเร็จ: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturingWeek = false);
    }
  }

  Widget _buildWeekCaptureContent(DateTime weekStart, List<dynamic> weekPlans) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: kDarkBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kLimeGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: kLimeGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'แผนการเข้าพบลูกค้า',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLimeGreen.withOpacity(0.35)),
            ),
            child: Text(
              _formatWeekRange(weekStart),
              style: const TextStyle(
                color: kLimeGreen,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (weekPlans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'ไม่มีแผนเข้าพบในสัปดาห์นี้',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ...weekPlans.map(_buildWeekCapturePlanCard),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Wallcraft · Weekly Visit Planner',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCapturePlanCard(dynamic plan) {
    final company = _asMap(plan['companies']);
    final companyName = company['name']?.toString().trim();
    final concept = plan['project_concept']?.toString().trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  companyName == null || companyName.isEmpty
                      ? 'ไม่ระบุบริษัท'
                      : companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildCaptureStatusBadge(_effectivePlanStatus(plan)),
            ],
          ),
          if (concept != null && concept.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              concept,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCaptureMeta(
                Icons.calendar_today_rounded,
                _formatPlanDate(plan['planned_date']),
                kLimeGreen,
              ),
              _buildCaptureMeta(
                Icons.person_outline_rounded,
                _assignedSalesNameForPlan(plan),
                Colors.white54,
              ),
              _buildCaptureMeta(
                Icons.schedule_rounded,
                _planTimeRange(plan),
                Colors.white54,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureMeta(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 11),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureStatusBadge(String? status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'completed':
        color = Colors.greenAccent;
        icon = Icons.check_circle_rounded;
        label = 'เสร็จสิ้น';
        break;
      case 'in_progress':
        color = Colors.lightBlueAccent;
        icon = Icons.autorenew_rounded;
        label = 'ดำเนินการ';
        break;
      case 'cancelled':
      case 'missed':
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        label = 'ไม่สำเร็จ';
        break;
      case 'overdue':
        color = Colors.redAccent;
        icon = Icons.warning_rounded;
        label = 'เลยกำหนด';
        break;
      case 'pending':
      default:
        color = Colors.amber;
        icon = Icons.schedule_rounded;
        label = 'วางแผน';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
      case 'cancelled':
      case 'missed':
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        label = "ไม่สำเร็จ";
        break;
      case 'overdue':
        color = Colors.redAccent;
        icon = Icons.warning_rounded;
        label = "เลยกำหนด";
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
      builder: (context) => AddVisitModal(
        weekStart: weekStart,
        onSave: _addPlan,
        allPlans: _visitPlans,
        isAdmin: _isAdmin,
        adminUsersList: _usersList,
        initialData: null,
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
        isAdmin: _isAdmin,
        adminUsersList: _usersList,
      ),
    );
  }

  void _showUserFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'กรองแผนงาน',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedUserId != 'all' ||
                        _selectedStatusFilter != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedUserId = 'all';
                            _selectedStatusFilter = 'all';
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'รีเซ็ต',
                          style: TextStyle(color: kLimeGreen, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              StatefulBuilder(
                builder: (context, setSheetState) {
                  const statusFilters = [
                    ('all', 'ทั้งหมด', Icons.apps_rounded, Colors.white70),
                    ('pending', 'วางแผน', Icons.schedule_rounded, Colors.amber),
                    (
                      'in_progress',
                      'ดำเนินการ',
                      Icons.autorenew_rounded,
                      Colors.lightBlueAccent,
                    ),
                    (
                      'completed',
                      'สำเร็จ',
                      Icons.check_circle_rounded,
                      Colors.greenAccent,
                    ),
                    (
                      'unsuccessful',
                      'ไม่สำเร็จ',
                      Icons.cancel_rounded,
                      Colors.redAccent,
                    ),
                    (
                      'overdue',
                      'เลยกำหนด',
                      Icons.warning_rounded,
                      Colors.deepOrangeAccent,
                    ),
                  ];

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'สถานะแผนงาน',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: statusFilters.map((filter) {
                            final isSelected =
                                _selectedStatusFilter == filter.$1;
                            return ChoiceChip(
                              label: Text(filter.$2),
                              avatar: Icon(filter.$3, size: 16),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedStatusFilter = filter.$1;
                                });
                                setSheetState(() {});
                              },
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: Colors.white10,
                              selectedColor: filter.$4,
                              side: BorderSide(
                                color: isSelected ? filter.$4 : Colors.white24,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ผู้รับผิดชอบ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final namedUsers = _usersList.where((u) {
                    final name = (u['full_name'] ?? u['username'] ?? '')
                        .toString()
                        .trim();
                    return name.isNotEmpty && name != 'ไม่มีชื่อ';
                  }).toList();

                  final namelessCount = _usersList.length - namedUsers.length;

                  return Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedUserId == 'all'
                                  ? kLimeGreen.withOpacity(0.2)
                                  : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              color: _selectedUserId == 'all'
                                  ? kLimeGreen
                                  : Colors.white70,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'ทั้งหมด (ทุกคน)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          trailing: _selectedUserId == 'all'
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: kLimeGreen,
                                  size: 22,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedUserId = 'all';
                            });
                            Navigator.pop(context);
                          },
                        ),
                        ...namedUsers.map((user) {
                          final uId = user['id']?.toString() ?? '';
                          final fullName =
                              (user['full_name'] ?? user['username'] ?? '')
                                  .toString()
                                  .trim();
                          final avatarUrl = user['avatar_url'];
                          final isSelected = _selectedUserId == uId;

                          return ListTile(
                            leading:
                                avatarUrl != null &&
                                    avatarUrl.toString().trim().isNotEmpty
                                ? Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? kLimeGreen
                                            : Colors.white24,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.white10,
                                      backgroundImage: NetworkImage(
                                        avatarUrl.toString(),
                                      ),
                                      onBackgroundImageError: (_, __) {},
                                    ),
                                  )
                                : Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? kLimeGreen.withOpacity(0.2)
                                          : Colors.white10,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? kLimeGreen
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      fullName.isNotEmpty
                                          ? fullName
                                                .substring(0, 1)
                                                .toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: isSelected
                                            ? kLimeGreen
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                            title: Text(
                              fullName,
                              style: TextStyle(
                                color: isSelected ? kLimeGreen : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: kLimeGreen,
                                    size: 22,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedUserId = uId;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                        if (namelessCount > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 16.0,
                            ),
                            child: Center(
                              child: Text(
                                "(ซ่อนบัญชีไม่มีชื่อ $namelessCount บัญชี)",
                                style: const TextStyle(
                                  color: Colors.white30,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
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

  String _formatPlanDate(dynamic dateValue) {
    if (dateValue == null) return "";
    final date = _parseDate(dateValue);
    if (date == null) return "";
    const thaiDays = ["จ.", "อ.", "พ.", "พฤ.", "ศ.", "ส.", "อา."];
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
    final dayName = thaiDays[date.weekday - 1];
    final monthName = thaiMonths[date.month - 1];
    return "$dayName ${date.day} $monthName";
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

  Widget _buildOfflineState() {
    return RefreshIndicator(
      onRefresh: _refreshPlannerData,
      color: kLimeGreen,
      backgroundColor: kCardDark,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const SizedBox(height: 70),
          const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 54),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'ไม่มีอินเทอร์เน็ต',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'เชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่อีกครั้ง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: _refreshPlannerData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kLimeGreen,
                side: const BorderSide(color: kLimeGreen),
              ),
            ),
          ),
        ],
      ),
    );
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "แผนการเข้าพบลูกค้า",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _selectedUserId == 'all'
                                    ? "Weekly Visit Planner"
                                    : "ดูของ: ${_usersList.firstWhere((u) => u['id']?.toString() == _selectedUserId, orElse: () => {'full_name': 'เซลส์'})['full_name'] ?? 'เซลส์'}",
                                style: TextStyle(
                                  color: _selectedUserId == 'all'
                                      ? Colors.white54
                                      : kLimeGreen,
                                  fontSize: 11,
                                  fontWeight: _selectedUserId == 'all'
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (!_isCalendarView) {
                                  if (_pageController.hasClients) {
                                    final currentIndex =
                                        _pageController.page?.round() ?? 0;
                                    if (currentIndex >= 0 &&
                                        currentIndex < _weeks.length) {
                                      _focusedDay = _weeks[currentIndex];
                                      _selectedDay = _focusedDay;
                                    }
                                  }
                                } else {
                                  final targetWeek = _weekStart(_focusedDay);
                                  final targetIndex = _weeks.indexWhere(
                                    (w) =>
                                        w.year == targetWeek.year &&
                                        w.month == targetWeek.month &&
                                        w.day == targetWeek.day,
                                  );
                                  if (targetIndex != -1) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (_pageController.hasClients) {
                                            _pageController.jumpToPage(
                                              targetIndex,
                                            );
                                          }
                                        });
                                  }
                                }
                                _isCalendarView = !_isCalendarView;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kCardDark,
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _isCalendarView
                                    ? Icons.view_carousel_rounded
                                    : Icons.calendar_month_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showUserFilterDialog,
                            child: Builder(
                              builder: (context) {
                                final hasActiveFilter =
                                    _selectedUserId != 'all' ||
                                    _selectedStatusFilter != 'all';
                                final selectedUser = _selectedUserId != 'all'
                                    ? _usersList.firstWhere(
                                        (u) =>
                                            u['id']?.toString() ==
                                            _selectedUserId,
                                        orElse: () => null,
                                      )
                                    : null;
                                final avatarUrl = selectedUser?['avatar_url'];

                                if (selectedUser != null &&
                                    avatarUrl != null &&
                                    avatarUrl.toString().trim().isNotEmpty) {
                                  return Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: kLimeGreen,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white10,
                                      backgroundImage: NetworkImage(
                                        avatarUrl.toString(),
                                      ),
                                      onBackgroundImageError: (_, __) {},
                                    ),
                                  );
                                }

                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: hasActiveFilter
                                        ? kLimeGreen.withOpacity(0.2)
                                        : kCardDark,
                                    border: Border.all(
                                      color: hasActiveFilter
                                          ? kLimeGreen
                                          : Colors.white24,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.filter_list_rounded,
                                    color: hasActiveFilter
                                        ? kLimeGreen
                                        : Colors.white70,
                                    size: 18,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kLimeGreen),
                        )
                      : _loadErrorMessage != null && _visitPlans.isEmpty
                      ? _buildOfflineState()
                      : _isCalendarView
                      ? _buildCalendarView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _weeks.length,
                                itemBuilder: (context, index) {
                                  final weekStart = _weeks[index];
                                  final isCurrent = _isCurrentWeek(weekStart);

                                  final weekPlans = _plansForWeek(weekStart);

                                  return AnimatedBuilder(
                                    animation: _pageController,
                                    builder: (context, child) {
                                      double value = 1.0;
                                      if (_pageController
                                          .position
                                          .haveDimensions) {
                                        value = (_pageController.page! - index)
                                            .abs();
                                        value = (1 - (value * 0.15)).clamp(
                                          0.85,
                                          1.0,
                                        );
                                      } else {
                                        // Keep the first visible weekly card full-size
                                        // before PageView has measured its dimensions.
                                        value = 1.0;
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
                                                    horizontal: 2,
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
                                                                : Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                                                  Colors.black;
                                                            } else if (weekStart
                                                                .isBefore(
                                                                  DateTime.now(),
                                                                )) {
                                                              label =
                                                                  "ที่ผ่านมา";
                                                              bgColor = Colors
                                                                  .white12;
                                                              textColor = Colors
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
                                                                    vertical: 4,
                                                                  ),
                                                              decoration:
                                                                  BoxDecoration(
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
                                                                  fontSize: 10,
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
                                                                            _weeks.length -
                                                                                1
                                                                        ? "ไม่มีแผนที่ใหม่กว่านี้\nสามารถสร้างแผนใหม่ได้"
                                                                        : "ไม่มีแผนเข้าพบ"),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white54,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                            ),
                                                          )
                                                        : RefreshIndicator(
                                                            onRefresh:
                                                                _refreshPlannerData,
                                                            color: kLimeGreen,
                                                            backgroundColor:
                                                                kCardDark,
                                                            child: ListView.builder(
                                                              physics:
                                                                  const AlwaysScrollableScrollPhysics(),
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
                                                                              _effectivePlanStatus(
                                                                                plan,
                                                                              ),
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
                                                                        const SizedBox(
                                                                          height:
                                                                              8,
                                                                        ),
                                                                        const Divider(
                                                                          color:
                                                                              Colors.white12,
                                                                          height:
                                                                              1,
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              8,
                                                                        ),
                                                                        Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Row(
                                                                              children: [
                                                                                const Icon(
                                                                                  Icons.calendar_today_rounded,
                                                                                  size: 12,
                                                                                  color: kLimeGreen,
                                                                                ),
                                                                                const SizedBox(
                                                                                  width: 5,
                                                                                ),
                                                                                Text(
                                                                                  _formatPlanDate(
                                                                                    plan['planned_date'],
                                                                                  ),
                                                                                  style: const TextStyle(
                                                                                    color: kLimeGreen,
                                                                                    fontSize: 11,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            Flexible(
                                                                              child: Text(
                                                                                'เซล: ${_assignedSalesNameForPlan(plan)}',
                                                                                style: const TextStyle(
                                                                                  color: Colors.white38,
                                                                                  fontSize: 10,
                                                                                ),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(
                                                                              width: 8,
                                                                            ),
                                                                            Text(
                                                                              _planTimeRange(
                                                                                plan,
                                                                              ),
                                                                              style: const TextStyle(
                                                                                color: Colors.white38,
                                                                                fontSize: 10,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                  ),
                                                  Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                          border: Border(
                                                            top: BorderSide(
                                                              color: Colors
                                                                  .white12,
                                                            ),
                                                          ),
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: InkWell(
                                                            onTap: () =>
                                                                _showAddModal(
                                                                  weekStart,
                                                                ),
                                                            child: const SizedBox(
                                                              height: 48,
                                                              child: Row(
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
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    'เพิ่มแผนเข้าพบ',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white54,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Tooltip(
                                                          message:
                                                              'แคปแผนทั้งสัปดาห์',
                                                          child: InkWell(
                                                            onTap:
                                                                _isCapturingWeek
                                                                ? null
                                                                : () => _captureWeekPlan(
                                                                    weekStart,
                                                                    weekPlans,
                                                                  ),
                                                            borderRadius:
                                                                const BorderRadius.only(
                                                                  bottomRight:
                                                                      Radius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                            child: SizedBox(
                                                              width: 52,
                                                              height: 48,
                                                              child: Center(
                                                                child:
                                                                    _isCapturingWeek
                                                                    ? const SizedBox(
                                                                        width:
                                                                            18,
                                                                        height:
                                                                            18,
                                                                        child: CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2,
                                                                          color:
                                                                              kLimeGreen,
                                                                        ),
                                                                      )
                                                                    : const Icon(
                                                                        Icons
                                                                            .camera_alt_outlined,
                                                                        color:
                                                                            kLimeGreen,
                                                                        size:
                                                                            20,
                                                                      ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                            /*
                              // --- Repeated Visits Section (Hidden for now) ---
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: kLimeGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: kLimeGreen.withOpacity(0.3)),
                                      ),
                                      child: const Icon(
                                        Icons.apartment_rounded,
                                        color: kLimeGreen,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "ผลการเข้าพบซ้ำ",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message: _sortByProjectCount ? "เรียงตามจำนวนครั้ง (ค่าเริ่มต้น)" : "เรียงตามจำนวนโปรเจค",
                                      child: GestureDetector(
                                        onTap: () async {
                                          final prefs = await SharedPreferences.getInstance();
                                          setState(() {
                                            _sortByProjectCount = !_sortByProjectCount;
                                            _sortRepeatedVisits();
                                          });
                                          prefs.setBool('sortByProjectCount', _sortByProjectCount);
                                        },
                                        child: Container(
                                          width: 80,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Stack(
                                            children: [
                                              AnimatedAlign(
                                                duration: const Duration(milliseconds: 250),
                                                curve: Curves.easeInOut,
                                                alignment: _sortByProjectCount ? Alignment.centerRight : Alignment.centerLeft,
                                                child: Container(
                                                  width: 40,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: kLimeGreen.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: kLimeGreen.withOpacity(0.5)),
                                                  ),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.sort_rounded,
                                                        color: !_sortByProjectCount ? kLimeGreen : Colors.white54,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.sort_by_alpha_rounded,
                                                        color: _sortByProjectCount ? kLimeGreen : Colors.white54,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
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
                                                  const Icon(
                                                    Icons.domain_rounded,
                                                    color: Colors.orangeAccent,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      comp['name'] ?? 'Unknown',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
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
                                                            maxLines: 1, overflow: TextOverflow.ellipsis, style:
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
                              */
                          ],
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
