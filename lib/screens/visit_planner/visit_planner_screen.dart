import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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
  List<dynamic> _visitPlans = [];
  List<dynamic> _repeatedVisits = [];
  Set<int> _expandedRepeatedVisits = {};
  late List<DateTime> _weeks;
  late PageController _pageController;
  DateTime? _pendingTargetWeek;

  bool _sortByProjectCount = true;
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isAdmin = false;
  String _selectedUserId = 'all';
  List<dynamic> _usersList = [];

  Future<void> _checkAdminAndFetchUsers() async {
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
          _isAdmin = true;
        }
      }

      final usersRes = await ApiService.getUsers();
      if (usersRes.statusCode == 200) {
        final usersData = jsonDecode(usersRes.body);
        if (mounted) {
          setState(() {
            _usersList = usersData['users'] ?? [];
          });
        }
      } else {
        if (mounted) setState(() {});
      }
    } catch(e) {
      debugPrint('Admin check error: $e');
    }
  }

  List<dynamic> get _filteredVisitPlans {
    if (_selectedUserId == 'all') {
      return _visitPlans;
    }
    return _visitPlans.where((p) {
      final uId = p['user_id'] ?? p['profiles']?['id'];
      return uId == _selectedUserId;
    }).toList();
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _filteredVisitPlans.where((plan) {
      if (plan['planned_date'] == null) return false;
      final pDate = DateTime.parse(plan['planned_date']);
      return pDate.year == day.year && pDate.month == day.month && pDate.day == day.day;
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
    _pageController = PageController(initialPage: 1, viewportFraction: 0.85);
    refreshVisitPlans();
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

  Future<void> refreshVisitPlans({DateTime? targetWeek, bool isSilent = false}) async {
    if (!mounted) return;
    ApiService.clearCache();
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final response = await ApiService.getWeeklyVisitPlansBoard();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> plans = data['visit_plans'] ?? [];
        
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        bool needsCron = false;
        final currentWeekStart = _weekStart(today);
        
        for (var plan in plans) {
          if ((plan['status'] == 'pending' || plan['status'] == null) && plan['planned_date'] != null) {
            final pDate = DateTime.parse(plan['planned_date']);
            final planWeekStart = _weekStart(pDate);
            
            // Only auto-cancel if the entire week has passed (plan's week is strictly before current week)
            if (planWeekStart.isBefore(currentWeekStart)) {
              plan['status'] = 'missed';
              needsCron = true;
            }
          }
        }
        
        if (needsCron) {
          // Trigger the backend cron job to officially mark them as unsuccessful and send notifications
          ApiService.triggerDailySummaryCron();
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

  Future<void> _fetchVisitPlans({DateTime? targetWeek}) => refreshVisitPlans(targetWeek: targetWeek);

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
          onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
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
                    final status = plan['status']?.toString();
                    Color markerColor = kLimeGreen;
                    if (status == 'completed' || status == 'success') {
                      markerColor = Colors.green;
                    } else if (status == 'missed' || status == 'failed' || status == 'canceled' || status == 'cancelled') {
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
            selectedDecoration: BoxDecoration(color: kLimeGreen, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
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
              ? const Center(child: Text("เลือกวันที่เพื่อดูแผนงาน", style: TextStyle(color: Colors.white54)))
              : Builder(
                  builder: (context) {
                    final dayPlans = _getEventsForDay(_selectedDay!);
                    if (dayPlans.isEmpty) {
                       return const Center(child: Text("ไม่มีแผนงานในวันนี้", style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: dayPlans.length,
                      itemBuilder: (context, index) {
                        final plan = dayPlans[index];
                        final company = plan['companies'] ?? {};
                        final project = plan['projects'] ?? {};
                        final profile = plan['profiles'] ?? {};
                        
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
                                backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                child: profile['avatar_url'] == null 
                                  ? const Icon(Icons.person, size: 16, color: kLimeGreen) 
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(company['name'] ?? 'Unknown Company', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(project['project_name'] ?? 'No Project', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(plan['status']),
                            ],
                          ),
                        );
                      }
                    );
                  }
                ),
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'กรองแผนงานตามเซลส์',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedUserId != 'all')
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedUserId = 'all';
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
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedUserId == 'all' ? kLimeGreen.withOpacity(0.2) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: _selectedUserId == 'all' ? kLimeGreen : Colors.white70,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'ทั้งหมด (ทุกคน)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      trailing: _selectedUserId == 'all'
                          ? const Icon(Icons.check_circle_rounded, color: kLimeGreen, size: 22)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedUserId = 'all';
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ..._usersList.map((user) {
                      final uId = user['id']?.toString() ?? '';
                      final fullName = user['full_name'] ?? user['username'] ?? 'ไม่มีชื่อ';
                      final avatarUrl = user['avatar_url'];
                      final isSelected = _selectedUserId == uId;
                      
                      return ListTile(
                        leading: avatarUrl != null && avatarUrl.toString().trim().isNotEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? kLimeGreen : Colors.white24,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: NetworkImage(avatarUrl.toString()),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? kLimeGreen.withOpacity(0.2) : Colors.white10,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? kLimeGreen : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : '?',
                                  style: TextStyle(
                                    color: isSelected ? kLimeGreen : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                        title: Text(
                          fullName,
                          style: TextStyle(
                            color: isSelected ? kLimeGreen : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: kLimeGreen, size: 22)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedUserId = uId;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ],
                ),
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
      "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
      "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."
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
                                  color: _selectedUserId == 'all' ? Colors.white54 : kLimeGreen,
                                  fontSize: 11,
                                  fontWeight: _selectedUserId == 'all' ? FontWeight.normal : FontWeight.bold,
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
                                    final currentIndex = _pageController.page?.round() ?? 0;
                                    if (currentIndex >= 0 && currentIndex < _weeks.length) {
                                      _focusedDay = _weeks[currentIndex];
                                      _selectedDay = _focusedDay;
                                    }
                                  }
                                } else {
                                  final targetWeek = _weekStart(_focusedDay);
                                  final targetIndex = _weeks.indexWhere((w) => w.year == targetWeek.year && w.month == targetWeek.month && w.day == targetWeek.day);
                                  if (targetIndex != -1) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (_pageController.hasClients) {
                                        _pageController.jumpToPage(targetIndex);
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
                                border: Border.all(
                                  color: Colors.white24,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _isCalendarView ? Icons.view_carousel_rounded : Icons.calendar_month_rounded,
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
                                final selectedUser = _selectedUserId != 'all'
                                    ? _usersList.firstWhere(
                                        (u) => u['id']?.toString() == _selectedUserId,
                                        orElse: () => null,
                                      )
                                    : null;
                                final avatarUrl = selectedUser?['avatar_url'];

                                if (selectedUser != null && avatarUrl != null && avatarUrl.toString().trim().isNotEmpty) {
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
                                      backgroundImage: NetworkImage(avatarUrl.toString()),
                                      onBackgroundImageError: (_, __) {},
                                    ),
                                  );
                                }

                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _selectedUserId != 'all' ? kLimeGreen.withOpacity(0.2) : kCardDark,
                                    border: Border.all(
                                      color: _selectedUserId != 'all' ? kLimeGreen : Colors.white24,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.filter_list_rounded,
                                    color: _selectedUserId != 'all' ? kLimeGreen : Colors.white70,
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

                                    // Get plans for this week
                                    final endOfWeek = weekStart.add(
                                      const Duration(
                                        days: 6,
                                        hours: 23,
                                        minutes: 59,
                                      ),
                                    );
                                    final weekPlans = _filteredVisitPlans.where((p) {
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
                                                                        const SizedBox(height: 8),
                                                                        const Divider(color: Colors.white12, height: 1),
                                                                        const SizedBox(height: 8),
                                                                        Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Row(
                                                                              children: [
                                                                                const Icon(
                                                                                  Icons.calendar_today_rounded,
                                                                                  size: 12,
                                                                                  color: kLimeGreen,
                                                                                ),
                                                                                const SizedBox(width: 5),
                                                                                Text(
                                                                                  _formatPlanDate(plan['planned_date']),
                                                                                  style: const TextStyle(
                                                                                    color: kLimeGreen,
                                                                                    fontSize: 11,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            if (plan['profiles'] != null && plan['profiles']['full_name'] != null)
                                                                              Flexible(
                                                                                child: Text(
                                                                                  plan['profiles']['full_name'],
                                                                                  style: const TextStyle(
                                                                                    color: Colors.white38,
                                                                                    fontSize: 10,
                                                                                  ),
                                                                                  maxLines: 1,
                                                                                  overflow: TextOverflow.ellipsis,
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
