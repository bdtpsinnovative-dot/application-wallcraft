Created At: 2026-08-11T14:58:34+07:00
Completed At: 2026-08-11T14:58:34+07:00
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`
Total Lines: 688
Total Bytes: 33016
Showing lines 180 to 250
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
180: 
181:   Widget _buildStatusBadge(String? status) {
182:     Color color;
183:     IconData icon;
184:     String label;
185:     switch (status) {
186:       case 'completed':
187:         color = Colors.greenAccent;
188:         icon = Icons.check_circle_rounded;
189:         label = "เสร็จสิ้น";
190:         break;
191:       case 'in_progress':
192:         color = Colors.lightBlueAccent;
193:         icon = Icons.autorenew_rounded;
194:         label = "ดำเนินการ";
195:         break;
196:       case 'cancelled':
197:       case 'missed':
198:         color = Colors.redAccent;
199:         icon = Icons.cancel_rounded;
200:         label = "ไม่สำเร็จ";
201:         break;

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

  void _generateWeeks(List<dynamic> plans) {
    final now = DateTime.now();
    final day = now.weekday;
    final monday = now.subtract(Duration(days: day - 1));
    final currentMonday = DateTime(monday.year, monday.month, monday.day);
    
    DateTime minWeek = currentMonday;
    DateTime maxWeek = currentMonday;

    for (var p in plans) {
      if (p['planned_date'] != null) {
        final date = DateTime.parse(p['planned_date']);
        final pMonday = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
        if (pMonday.isBefore(minWeek)) minWeek = pMonday;
        if (pMonday.isAfter(maxWeek)) maxWeek = pMonday;
      }
    }

    final startBound = minWeek.subtract(const Duration(days: 7));
    final endBound = maxWeek.add(const Duration(days: 7));

    _weeks = [];
    for (DateTime w = startBound; !w.isAfter(endBound); w = w.add(const Duration(days: 7))) {
      _weeks.add(w);
    }
  }

  Future<void> _fetchVisitPlans() async {
    ApiService.clearCache();
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getWeeklyVisitPlansBoard();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _visitPlans = data['visit_plans'] ?? [];
            _generateWeeks(_visitPlans);
            _isLoading = false;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients && _isFirstLoad) {
              _isFirstLoad = false;
              final now = DateTime.now();
              final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
              final currentIndex = _weeks.indexWhere((w) => w.isAtSameMomentAs(currentMonday));
              if (currentIndex != -1) {
                _pageController.jumpToPage(currentIndex);
              }
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
        await _fetchVisitPlans();
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint("Failed to add plan: ${response.statusCode} - ${response.body}");
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
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint("Failed to delete plan: ${response.statusCode}");
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
      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint("Failed to edit plan: ${response.statusCode} - ${response.body}");
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
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kLimeGreen.withOpacity(0.08)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: kLimeGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.calendar_month_rounded, color: kLimeGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("แผนการเข้าพบลูกค้า", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("Weekly Visit Planner", style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _fetchVisitPlans,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kCardDark, border: Border.all(color: kLimeGreen.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.refresh_rounded, color: kLimeGreen, size: 18),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
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
                        final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
                        final weekPlans = _visitPlans.where((p) {
                          if (p['planned_date'] == null) return false;
                          final planDate = DateTime.parse(p['planned_date']);
                          return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);
                        }).toList();

                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = (_pageController.page! - index).abs();
                              value = (1 - (value * 0.15)).clamp(0.85, 1.0);
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
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: kCardDark,
                                      border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),
                                      borderRadius: BorderRadius.circular(12),
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
                            Builder(
                              builder: (context) {
                                String label = "";
                                Color bgColor = Colors.transparent;
                                Color textColor = Colors.white;

                                if (isCurrent) {
                                  label = "สัปดาห์นี้";
                                  bgColor = kLimeGreen;
152:       } else {
153:         if (mounted) setState(() => _isLoading = false);
154:         debugPrint("Failed to delete plan: ${response.statusCode}");
155:       }
156:     } catch (e) {
157:       debugPrint("Error deleting plan: $e");
158:       if (mounted) setState(() => _isLoading = false);
159:     }
160:   }
161: 
162:   Future<void> _editPlan(Map<String, dynamic> data) async {
163:     Navigator.of(context).pop(); // close modal
164:     setState(() => _isLoading = true);
165:     try {
166:       // Use ApiService.updateVisitPlan if it exists, otherwise post with ID or patch
167:       // Since it's Next.js backend, let's assume it accepts patch for updates, or post handles upsert.
168:       final response = await ApiService.patch(Uri.parse('${AppConfig.baseUrl}/visit-plans/${data['id']}'), body: jsonEncode(data));
169:       if (response.statusCode == 200 || response.statusCode == 201) {
170:         await _fetchVisitPlans();
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  : (index == _weeks.length - 1 ? "ไม่มีแผนที่ใหม่กว่านี้\nสามารถสร้างแผนใหม่ได้" : "ไม่มีแผนเข้าพบ"),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: weekPlans.length,
                          itemBuilder: (context, i) {
                            final plan = weekPlans[i];
                            final compName = plan['companies']?['name'] ?? 'Unknown Company';
                            final projName = plan['projects']?['project_name'];
                            
                            final profile = plan['profiles'] ?? {};
                            final userName = "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim();
                            final userAvatar = profile['line_picture_url']?.toString() ?? '';
                            
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
                                    if (userName.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Colors.white24,
                                            backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
319:                         final isCurrent = _isCurrentWeek(weekStart);
320:                         
321:                         // Get plans for this week
322:                         final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
323:                         final weekPlans = _visitPlans.where((p) {
324:                           if (p['planned_date'] == null) return false;
325:                           final planDate = DateTime.parse(p['planned_date']);
326:                           return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);
327:                         }).toList();
328: 
329:                         return AnimatedBuilder(
330:                           animation: _pageController,
331:                           builder: (context, child) {
332:                             double value = 1.0;
333:                             if (_pageController.position.haveDimensions) {
334:                               value = (_pageController.page! - index).abs();
335:                               value = (1 - (value * 0.15)).clamp(0.85, 1.0);
336:                             } else {
337:                               value = index == 4 ? 1.0 : 0.85;
338:                             }
339:                             
340:                             return Center(
341:                               child: Transform.scale(
342:                                 scale: value,
343:                                 child: Opacity(
344:                                   opacity: value.clamp(0.5, 1.0),
345:                                   child: Container(
346:                                     width: double.infinity,
347:                                     margin: const EdgeInsets.symmetric(horizontal: 4),
348:                                     decoration: BoxDecoration(
349:                                       color: kCardDark,
350:                                       border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),
351:                                       borderRadius: BorderRadius.circular(12),
352:                                     ),
353:                   child: Column(
354:                     crossAxisAlignment: CrossAxisAlignment.start,
355:                     children: [
356:                       Container(
357:                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
358:                         decoration: BoxDecoration(
359:                           color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,
360:                           borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
361:                         ),
362:                         child: Row(
363:                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
364:                           children: [
365:                             Text(
366:                               _formatWeekRange(weekStart),
367:                               style: TextStyle(
368:                                 color: isCurrent ? kLimeGreen : Colors.white,
369:                                 fontWeight: FontWeight.bold,
370:                               ),
371:                             ),
372:                             Builder(
373:                               builder: (context) {
374:                                 String label = "";
375:                                 Color bgColor = Colors.transparent;
376:                                 Color textColor = Colors.white;
377: 
378:                                 if (isCurrent) {
379:                                   label = "สัปดาห์นี้";
380:                                   bgColor = kLimeGreen;
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.

Created At: 2026-08-11T15:30:39+07:00
Completed At: 2026-08-11T15:30:39+07:00
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`
Total Lines: 688
Total Bytes: 33016
Showing lines 310 to 370
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
310:                             children: [
311:                               const SizedBox(height: 12),
312:                               SizedBox(
313:                     height: 440,
314:                     child: PageView.builder(
315:                       controller: _pageController,
316:                       itemCount: _weeks.length,
317:                       itemBuilder: (context, index) {
318:                         final weekStart = _weeks[index];
319:                         final isCurrent = _isCurrentWeek(weekStart);
320:                         
321:                         // Get plans for this week
322:                         final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
323:                         final weekPlans = _visitPlans.where((p) {
324:                           if (p['planned_date'] == null) return false;
325:                           final planDate = DateTime.parse(p['planned_date']);
326:                           return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);
327:                         }).toList();
328: 
329:                         return AnimatedBuilder(
330:                           animation: _pageController,
331:                           builder: (context, child) {
332:                             double value = 1.0;
333:                             if (_pageController.position.haveDimensions) {
334:                               value = (_pageController.page! - index).abs();
335:                               value = (1 - (value * 0.15)).clamp(0.85, 1.0);
336:                             } else {
337:                               value = index == 4 ? 1.0 : 0.85;
338:                             }
339:                             
340:                             return Center(
341:                               child: Transform.scale(
342:                                 scale: value,
343:                                 child: Opacity(
344:                                   opacity: value.clamp(0.5, 1.0),
345:                                   child: Container(
346:                                     width: double.infinity,
347:                                     margin: const EdgeInsets.symmetric(horizontal: 4),
348:                                     decoration: BoxDecoration(
349:                                       color: kCardDark,
350:                                       border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),
351:                                       borderRadius: BorderRadius.circular(12),
352:                                     ),
353:                   child: Column(
354:                     crossAxisAlignment: CrossAxisAlignment.start,
355:                     children: [
356:                       Container(
357:                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
358:                         decoration: BoxDecoration(
359:                           color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,
360:                           borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
361:                         ),
362:                         child: Row(
363:                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
364:                           children: [
365:                             Text(
366:                               _formatWeekRange(weekStart),
367:                               style: TextStyle(
368:                                 color: isCurrent ? kLimeGreen : Colors.white,
369:                                 fontWeight: FontWeight.bold,
370:                               ),
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.


                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2.0),
                                          child: Icon(Icons.folder, color: Colors.blueAccent, size: 14),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            e.key,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                          _expandedRepeatedVisits.remove(index);
                                        } else {
                                          _expandedRepeatedVisits.add(index);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        isExpanded ? "ซ่อน" : "ดูเพิ่มเติม...",
                                        style: const TextStyle(color: kLimeGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          );
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}
}

