import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import 'components/add_visit_modal.dart';

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
202:       case 'pending':
203:       default:
204:         color = Colors.amber;
205:         icon = Icons.schedule_rounded;
206:         label = "วางแผน";
207:         break;
208:     }
209:     
210:     return Tooltip(
211:       message: label,
212:       child: Icon(icon, color: color, size: 18),
213:     );
214:   }
215: 
216:   void _showAddModal(DateTime weekStart) {
217:     showModalBottomSheet(
218:       context: context,
219:       isScrollControlled: true,
220:       backgroundColor: Colors.transparent,
221:       builder: (ctx) => AddVisitModal(weekStart: weekStart, onSave: _addPlan, allPlans: _visitPlans),
222:     );
223:   }
224: 
225:   void _showEditModal(Map<String, dynamic> plan) {
226:     final planDate = plan['planned_date'] != null ? DateTime.parse(plan['planned_date']) : DateTime.now();
227:     showModalBottomSheet(
228:       context: context,
229:       isScrollControlled: true,
230:       backgroundColor: Colors.transparent,
231:       builder: (ctx) => AddVisitModal(weekStart: planDate, onSave: _editPlan, initialData: plan, allPlans: _visitPlans),
232:     );
233:   }
234: 
235:   String _formatWeekRange(DateTime start) {
236:     final end = start.add(const Duration(days: 6));
237:     const thaiMonths = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."];
238:     return "${start.day} ${thaiMonths[start.month - 1]} - ${end.day} ${thaiMonths[end.month - 1]}";
239:   }
240: 
241:   bool _isCurrentWeek(DateTime start) {
242:     final now = DateTime.now();
243:     final day = now.weekday;
244:     final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: day - 1));
245:     return start.isAtSameMomentAs(currentMonday);
246:   }
247: 
248:   @override
249:   Widget build(BuildContext context) {
250:     return Scaffold(
        final data = jsonDecode(response.body);

          setState(() {
            _visitPlans = data['visit_plans'] ?? [];
            _generateWeeks(_visitPlans);
            _isLoading = false;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
400:                                     borderRadius: BorderRadius.circular(4),
401:                                   ),
402:                                   child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
403:                                 );
404:                               },
405:                             ),
406:                           ],
407:                         ),
408:                       ),
409:                       Expanded(
410:                         child: weekPlans.isEmpty
411:                           ? Center(
412:                               child: Text(
413:                                 index == 0 
414:                                   ? "ไม่มีแผนงานที่เก่ากว่านี้"
415:                                   : (index == _weeks.length - 1 ? "ไม่มีแผนที่ใหม่กว่านี้\nสามารถสร้างแผนใหม่ได้" : "ไม่มีแผนเข้าพบ"),
416:                                 textAlign: TextAlign.center,
417:                                 style: const TextStyle(color: Colors.white54, fontSize: 13),
418:                               ),
419:                             )
420:                           : ListView.builder(
421:                               padding: const EdgeInsets.all(12),
422:                               itemCount: weekPlans.length,
423:                           itemBuilder: (context, i) {
424:                             final plan = weekPlans[i];
425:                             final compName = plan['companies']?['name'] ?? 'Unknown Company';
426:                             final projName = plan['projects']?['project_name'];
427:                             
428:                             final profile = plan['profiles'] ?? {};
429:                             final userName = "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim();
430:                             final userAvatar = profile['line_picture_url']?.toString() ?? '';
431:                             
432:                             return InkWell(
433:                               onTap: () {
434:                                 _showEditModal(plan);
435:                               },
436:                               borderRadius: BorderRadius.circular(8),
437:                               child: Container(
438:                                 margin: const EdgeInsets.only(bottom: 8),
439:                                 padding: const EdgeInsets.all(12),
440:                                 decoration: BoxDecoration(
441:                                   color: Colors.black38,
442:                                   border: Border.all(color: Colors.white12),
443:                                   borderRadius: BorderRadius.circular(8), // ขอบมนสำหรับ item ด้านใน
444:                                 ),
445:                                 child: Column(
446:                                   crossAxisAlignment: CrossAxisAlignment.start,
447:                                   children: [
448:                                     Row(
449:                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
450:                                       crossAxisAlignment: CrossAxisAlignment.start,
451:                                       children: [
452:                                         Expanded(
453:                                           child: Text(
454:                                             compName,
455:                                             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
456:                                             maxLines: 1,
457:                                             overflow: TextOverflow.ellipsis,
458:                                           ),
459:                                         ),
460:                                         const SizedBox(width: 8),
461:                                         _buildStatusBadge(plan['status']?.toString()),
462:                                       ],
463:                                     ),
464:                                     if (plan['project_concept'] != null && plan['project_concept'].toString().isNotEmpty) ...[
465:                                       const SizedBox(height: 4),
466:                                       Text(
467:                                         plan['project_concept'], 
468:                                         style: const TextStyle(color: Colors.white70, fontSize: 11),
469:                                         maxLines: 1, // แสดงบรรทัดเดียว
470:                                         overflow: TextOverflow.ellipsis,
471:                                       ),
472:                                     ],
473:                                     if (userName.isNotEmpty) ...[
474:                                       const SizedBox(height: 8),
475:                                       Row(
476:                                         children: [
477:                                           CircleAvatar(
478:                                             radius: 10,
479:                                             backgroundColor: Colors.white24,
480:                                             backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
      if (response.statusCode == 200 || response.statusCode == 201) {

      } else {
        if (mounted) setState(() => _isLoading = false);
        debugPrint("Failed to edit plan: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Error editing plan: $e");
      if (mounted) setState(() => _isLoading = false);
80:         if (mounted) {
81:           setState(() {
82:             _visitPlans = data['visit_plans'] ?? [];
83:             _generateWeeks(_visitPlans);
84:             _isLoading = false;
85:           });
86:           
87:           WidgetsBinding.instance.addPostFrameCallback((_) {
88:             if (_pageController.hasClients && _isFirstLoad) {
89:               _isFirstLoad = false;
90:               final now = DateTime.now();
91:               final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
92:               final currentIndex = _weeks.indexWhere((w) => w.isAtSameMomentAs(currentMonday));
93:               if (currentIndex != -1) {
94:                 _pageController.jumpToPage(currentIndex);
95:               }
96:             }
97:           });
98:         }
99:       } else {
100:         throw Exception("Failed to load plans");
101:       }
102:     } catch (e) {
103:       debugPrint("Error: $e");
104:       if (mounted) setState(() => _isLoading = false);
105:     }
106:   }
107: 
108:   Future<void> _fetchRepeatedVisits() async {
109:     setState(() => _isLoadingRepeated = true);
110:     try {
111:       final response = await ApiService.getRepeatedVisits();
112:       if (response.statusCode == 200) {
113:         final data = jsonDecode(response.body);
114:         if (mounted) {
115:           setState(() {
116:             _repeatedVisits = data['repeatedVisits'] ?? [];
117:             _isLoadingRepeated = false;
118:           });
119:         }
120:       } else {
      isScrollControlled: true,

      builder: (ctx) => AddVisitModal(weekStart: weekStart, onSave: _addPlan, allPlans: _visitPlans),
    );
  }

  void _showEditModal(Map<String, dynamic> plan) {
    final planDate = plan['planned_date'] != null ? DateTime.parse(plan['planned_date']) : DateTime.now();
    showModalBottomSheet(
250:     return Scaffold(
251:       backgroundColor: kDarkBg,
252:       body: Stack(
253:         children: [
254:           Positioned(
255:             top: -50,
256:             right: -50,
257:             child: Container(
258:               width: 300,
259:               height: 300,
260:               decoration: BoxDecoration(shape: BoxShape.circle, color: kLimeGreen.withOpacity(0.08)),
261:               child: BackdropFilter(
262:                 filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
263:                 child: Container(color: Colors.transparent),
264:               ),
265:             ),
266:           ),
267:           SafeArea(
268:             child: Column(
269:               crossAxisAlignment: CrossAxisAlignment.start,
270:               children: [
271:                 Padding(
272:                   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
273:                   child: Row(
274:                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
275:                     children: [
276:                       Row(
277:                         children: [
278:                           Container(
279:                             padding: const EdgeInsets.all(8),
280:                             decoration: BoxDecoration(color: kLimeGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
281:                             child: const Icon(Icons.calendar_month_rounded, color: kLimeGreen, size: 22),
282:                           ),
283:                           const SizedBox(width: 12),
284:                           const Column(
285:                             crossAxisAlignment: CrossAxisAlignment.start,
286:                             children: [
287:                               Text("แผนการเข้าพบลูกค้า", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
288:                               Text("Weekly Visit Planner", style: TextStyle(color: Colors.white54, fontSize: 11)),
289:                             ],
290:                           ),
291:                         ],
292:                       ),
293:                       GestureDetector(
294:                         onTap: _fetchVisitPlans,
295:                         child: Container(
296:                           padding: const EdgeInsets.all(8),
297:                           decoration: BoxDecoration(color: kCardDark, border: Border.all(color: kLimeGreen.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
298:                           child: const Icon(Icons.refresh_rounded, color: kLimeGreen, size: 18),
299:                         ),
300:                       )
                            padding: const EdgeInsets.all(8),

                            child: const Icon(Icons.calendar_month_rounded, color: kLimeGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("แผนการเข้าพบลูกค้า", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
30: 
31:   @override
32:   void initState() {
33:     super.initState();
34:     _generateWeeks([]);
35:     _pageController = PageController(initialPage: 1, viewportFraction: 0.85);
36:     _fetchVisitPlans();
37:     _fetchRepeatedVisits();
38:   }
39: 
40:   @override
41:   void dispose() {
42:     _pageController.dispose();
43:     super.dispose();
44:   }
45: 
46:   void _generateWeeks(List<dynamic> plans) {
47:     final now = DateTime.now();
48:     final day = now.weekday;
49:     final monday = now.subtract(Duration(days: day - 1));
50:     final currentMonday = DateTime(monday.year, monday.month, monday.day);
51:     
52:     DateTime minWeek = currentMonday;
53:     DateTime maxWeek = currentMonday;
54: 
55:     for (var p in plans) {
56:       if (p['planned_date'] != null) {
57:         final date = DateTime.parse(p['planned_date']);
58:         final pMonday = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
59:         if (pMonday.isBefore(minWeek)) minWeek = pMonday;
60:         if (pMonday.isAfter(maxWeek)) maxWeek = pMonday;
61:       }
62:     }
63: 
64:     final startBound = minWeek.subtract(const Duration(days: 7));
65:     final endBound = maxWeek.add(const Duration(days: 7));
66: 
67:     _weeks = [];
68:     for (DateTime w = startBound; !w.isAfter(endBound); w = w.add(const Duration(days: 7))) {
69:       _weeks.add(w);
70:     }
71:   }
72: 
73:   Future<void> _fetchVisitPlans() async {
74:     ApiService.clearCache();
75:     setState(() => _isLoading = true);
76:     try {
77:       final response = await ApiService.getWeeklyVisitPlansBoard();
78:       if (response.statusCode == 200) {
79:         final data = jsonDecode(response.body);
80:         if (mounted) {
                    children: [

                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
119:         }
120:       } else {
121:         if (mounted) setState(() => _isLoadingRepeated = false);
122:       }
123:     } catch (e) {
124:       debugPrint("Error fetching repeated visits: $e");
125:       if (mounted) setState(() => _isLoadingRepeated = false);
126:     }
127:   }
128: 
129:   Future<void> _addPlan(Map<String, dynamic> data) async {
130:     Navigator.of(context).pop(); // close modal
131:     setState(() => _isLoading = true);
132:     try {
133:       final response = await ApiService.addVisitPlan(data);
134:       if (response.statusCode == 200 || response.statusCode == 201) {
135:         await _fetchVisitPlans();
136:       } else {
137:         if (mounted) setState(() => _isLoading = false);
138:         debugPrint("Failed to add plan: ${response.statusCode} - ${response.body}");
139:       }
140:     } catch (e) {
141:       debugPrint("Error adding plan: $e");
142:       if (mounted) setState(() => _isLoading = false);
143:     }
144:   }
145: 
146:   Future<void> _deletePlan(String id) async {
147:     setState(() => _isLoading = true);
148:     try {
149:       final response = await ApiService.deleteVisitPlan(id);
150:       if (response.statusCode == 200) {
151:         await _fetchVisitPlans();
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
171:       } else {
172:         if (mounted) setState(() => _isLoading = false);
173:         debugPrint("Failed to edit plan: ${response.statusCode} - ${response.body}");
174:       }
175:     } catch (e) {
176:       debugPrint("Error editing plan: $e");
177:       if (mounted) setState(() => _isLoading = false);
178:     }
179:   }
                            final compName = plan['companies']?['name'] ?? 'Unknown Company';

                            
                            final profile = plan['profiles'] ?? {};
                            final userName = "${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}".trim();
                            final userAvatar = profile['line_picture_url']?.toString() ?? '';
                            
                            return InkWell(
                              onTap: () {
73:   Future<void> _fetchVisitPlans() async {
74:     ApiService.clearCache();
75:     setState(() => _isLoading = true);
76:     try {
77:       final response = await ApiService.getWeeklyVisitPlansBoard();
78:       if (response.statusCode == 200) {
79:         final data = jsonDecode(response.body);
80:         if (mounted) {
81:           setState(() {
82:             _visitPlans = data['visit_plans'] ?? [];
83:             _generateWeeks(_visitPlans);
84:             _isLoading = false;
85:           });
86:           
87:           WidgetsBinding.instance.addPostFrameCallback((_) {
88:             if (_pageController.hasClients && _isFirstLoad) {
89:               _isFirstLoad = false;
90:               final now = DateTime.now();
91:               final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
92:               final currentIndex = _weeks.indexWhere((w) => w.isAtSameMomentAs(currentMonday));
93:               if (currentIndex != -1) {
94:                 _pageController.jumpToPage(currentIndex);
95:               }
96:             }
97:           });
98:         }
99:       } else {
100:         throw Exception("Failed to load plans");
101:       }
102:     } catch (e) {
103:       debugPrint("Error: $e");
104:       if (mounted) setState(() => _isLoading = false);
105:     }
106:   }
107: 
                                        maxLines: 1, // แสดงบรรทัดเดียว

                                      ),
                                    ],
                                    if (userName.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          CircleAvatar(
300:                       )
301:                     ],
302:                   ),
303:                 ),
304:                 Expanded(
305:                   child: _isLoading
306:                       ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
307:                       : SingleChildScrollView(
308:                           child: Column(
309:                             crossAxisAlignment: CrossAxisAlignment.start,
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
          // --- Repeated Visits Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kLimeGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.autorenew_rounded, color: kLimeGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "ผลการเข้าพบซ้ำ (3 เช็คอินขึ้นไป)",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _isLoadingRepeated 
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: kLimeGreen)))
            : _repeatedVisits.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("ไม่มีข้อมูลการเข้าพบซ้ำ", style: TextStyle(color: Colors.white54))))
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: _repeatedVisits.length,
                  itemBuilder: (context, index) {
                    final comp = _repeatedVisits[index];
                    final uniqueProjects = comp['uniqueProjects'] as Map<String, dynamic>? ?? {};
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  comp['name'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kLimeGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${comp['count']} ครั้ง",
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              )
                            ],
                          ),
                          if (uniqueProjects.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 12),
                            Text("${uniqueProjects.length} โปรเจค", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...uniqueProjects.entries.map((e) {
                              String dateStr = '';
                              if (e.value != null) {
                                final d = DateTime.parse(e.value.toString());
                                final months = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."];
                                dateStr = "${d.day} ${months[d.month - 1]} ${(d.year + 543) % 100}";
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.folder_open_rounded, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        e.key,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                    if (dateStr.isNotEmpty)
                                      Text("($dateStr)", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ]
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}
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

