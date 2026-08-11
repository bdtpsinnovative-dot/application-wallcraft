Created At: 2026-08-11T14:58:34+07:00\r
Completed At: 2026-08-11T14:58:34+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 180 to 250\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
180: \r
181:   Widget _buildStatusBadge(String? status) {\r
182:     Color color;\r
183:     IconData icon;\r
184:     String label;\r
185:     switch (status) {\r
186:       case \'completed\':\r
187:         color = Colors.greenAccent;\r
188:         icon = Icons.check_circle_rounded;\r
189:         label = "เสร็จสิ้น";\r
190:         break;\r
191:       case \'in_progress\':\r
192:         color = Colors.lightBlueAccent;\r
  List<dynamic> _visitPlans = [];\r
  late List<DateTime> _weeks;\r
  final ScrollController _scrollController = ScrollController();\r
\r
  @override\r
  void initState() {\r
    super.initState();\r
    _generateWeeks();\r
    _fetchVisitPlans();\r
  }\r
\r
  @override\r
  void dispose() {\r
    _scrollController.dispose();\r
    super.dispose();\r
  }\r
\r
  void _generateWeeks() {\r
    _weeks = [];\r
    final now = DateTime.now();\r
    final day = now.weekday;\r
    final monday = now.subtract(Duration(days: day - 1));\r
    final startMonday = DateTime(monday.year, monday.month, monday.day);\r
    \r
    // 4 weeks ago to 7 weeks future (12 weeks total)\r
    for (int i = -4; i <= 7; i++) {\r
      _weeks.add(startMonday.add(Duration(days: i * 7)));\r
    }\r
  }\r
\r
  Future<void> _fetchVisitPlans() async {\r
    setState(() => _isLoading = true);\r
    try {\r
      final response = await ApiService.getWeeklyVisitPlansBoard();\r
      if (response.statusCode == 200) {\r
        final data = jsonDecode(response.body);\r
        if (mounted) {\r
          setState(() {\r
            _visitPlans = data[\'visit_plans\'] ?? [];\r
            _isLoading = false;\r
          });\r
          \r
          // เลื่อนหน้าจอไปสัปดาห์ปัจจุบัน (index 4) ทันทีที่โหลดเสร็จและสร้าง UI แล้ว\r
          WidgetsBinding.instance.addPostFrameCallback((_) {\r
            if (_scrollController.hasClients) {\r
              double offset = 4 * (240.0 + 16.0);\r
              _scrollController.jumpTo(offset);\r
            }\r
          });\r
        }\r
      } else {\r
        throw Exception("Failed to load plans");\r
      }\r
    } catch (e) {\r
      debugPrint("Error: $e");\r
      if (mounted) setState(() => _isLoading = false);\r
    }\r
  }\r
\r
  Future<void> _addPlan(Map<String, dynamic> data) async {\r
    Navigator.of(context).pop(); // close modal\r
    setState(() => _isLoading = true);\r
    try {\r
      final response = await ApiService.addVisitPlan(data);\r
      if (response.statusCode == 200 || response.statusCode == 201) {\r
        await _fetchVisitPlans();\r
      }\r
    } catch (e) {\r
      debugPrint("Error adding plan: $e");\r
      if (mounted) setState(() => _isLoading = false);\r
    }\r
  }\r
\r
  Future<void> _deletePlan(String id) async {\r
    setState(() => _isLoading = true);\r
    try {\r
      final response = await ApiService.deleteVisitPlan(id);\r
      if (response.statusCode == 200) {\r
        await _fetchVisitPlans();\r
      }\r
+                              );\r
+                            }).toList(),\r
+                          ]\r
+                        ],\r
+                      ),\r
+                    );\r
+                  },\r
+                ),\r
+          const SizedBox(height: 40),\r
+        ],\r
+      ),\r
+    ),\r
+  );\r
+}\r
 }\r
 \r
[diff_block_end]\r
\r
Please note that the above snippet only shows the MODIFIED lines from the last change. It shows up to 3 lines of unchanged lines before and after the modified lines. The actual file contents may have many more lines not shown.\r
\r
เรียบร้อยแล้วครับนาย! จัดให้เต็มระบบเลยครับ\r
\r
ผมทำการสร้าง API ในส่วนหลังบ้านเพื่อให้แอปมือถือดึงข้อมูล "ผลการเข้าพบซ้ำ" ได้รวดเร็วที่สุด และจัดการแก้ไขโค้ดแอป Flutter ในไฟล์ `visit_planner_screen.dart` ตามที่นายต้องการเป๊ะๆ ครับ:\r
1. การ์ดแผนงานถูกย่อขนาดให้เล็กลง (ความสูงอยู่ที่ 440 กำลังพอดี) ทำให้เห็นพื้นที่ด้านล่าง\r
2. ลิสต์ **"ผลการเข้าพบซ้ำ (3 เช็คอินขึ้นไป)"** ต่อท้ายอยู่ด้านล่างการ์ด พร้อมดีไซน์พื้นหลังการ์ดสีเข้มเท่ๆ และไอคอนที่เข้ากันสุดๆ ครับ\r
3. มีการแสดงวันที่ที่โปรเจคนั้นๆ เข้ามาด้วยในวงเล็บเหมือนที่เว็บเลยครับ\r
\r
นายสามารถอ่านสรุปการปรับแก้ที่ผมทำไปได้ที่นี่เลยครับ 👉 [สรุปรายละเอียดการทำงาน (Walkthrough)](file:///C:/Users/Por%20Woodden/.gemini/antigravity/brain/441cd301-8f6d-4505-868d-d78b6a0b13a9/walkthrough.md)\r
\r
ตอนนี้นายลองเซฟแล้ว **Restart / Hot Reload** ตัวแอปบน Android Emulator ดูผลลัพธ์หน้าจอได้เลยครับผม! ติดตรงไหนหรืออยากให้ขยาย/หดการ์ดเพิ่มขึ้น บอกผมได้ตลอดเลยครับ!\r
\r
Created At: 2026-08-11T13:35:58+07:00\r
Completed At: 2026-08-11T13:35:58+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 480\r
Total Bytes: 21122\r
Showing lines 210 to 230\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
210:     return Scaffold(\r
211:       backgroundColor: kDarkBg,\r
212:       appBar: AppBar(\r
213:         backgroundColor: kDarkBg,\r
214:         title: const Text("แผนการเข้าพบลูกค้า (12 สัปดาห์)", style: TextStyle(color: Colors.white, fontSize: 18)),\r
215:         elevation: 0,\r
216:         actions: [\r
217:           IconButton(\r
218:             icon: const Icon(Icons.refresh, color: Colors.white),\r
219:             onPressed: _fetchVisitPlans,\r
220:           )\r
221:         ],
463:                                     ),\r
464:                                     if (plan[\'project_concept\'] != null && plan[\'project_concept\'].toString().isNotEmpty) ...[\r
465:                                       const SizedBox(height: 4),\r
466:                                       Text(\r
467:                                         plan[\'project_concept\'], \r
468:                                         style: const TextStyle(color: Colors.white70, fontSize: 11),\r
469:                                         maxLines: 1, // แสดงบรรทัดเดียว\r
470:                                         overflow: TextOverflow.ellipsis,\r
471:                                       ),\r
472:                                     ],\r
473:                                     if (userName.isNotEmpty) ...[\r
474:                                       const SizedBox(height: 8),\r
475:                                       Row(\r
476:                                         children: [\r
477:                                           CircleAvatar(\r
478:                                             radius: 10,\r
479:                                             backgroundColor: Colors.white24,\r
480:                                             backgroundImage: userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r
Created At: 2026-08-11T14:59:17+07:00\r
Completed At: 2026-08-11T14:59:17+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 80 to 120\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
80:         if (mounted) {\r
81:           setState(() {\r

  Widget _buildStatusBadge(String? status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'completed':
89:               _isFirstLoad = false;\r
90:               final now = DateTime.now();\r
91:               final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));\r
92:               final currentIndex = _weeks.indexWhere((w) => w.isAtSameMomentAs(currentMonday));\r
93:               if (currentIndex != -1) {\r
94:                 _pageController.jumpToPage(currentIndex);\r
95:               }\r
96:             }\r
97:           });\r
98:         }\r
99:       } else {\r
100:         throw Exception("Failed to load plans");\r
101:       }\r
102:     } catch (e) {\r
103:       debugPrint("Error: $e");\r
104:       if (mounted) setState(() => _isLoading = false);\r
105:     }\r
106:   }\r
107: \r
108:   Future<void> _fetchRepeatedVisits() async {\r
109:     setState(() => _isLoadingRepeated = true);\r
110:     try {\r
111:       final response = await ApiService.getRepeatedVisits();\r
112:       if (response.statusCode == 200) {\r
113:         final data = jsonDecode(response.body);\r
114:         if (mounted) {\r
115:           setState(() {\r
116:             _repeatedVisits = data[\'repeatedVisits\'] ?? [];\r
117:             _isLoadingRepeated = false;\r
118:           });\r
119:         }\r
120:       } else {\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r
Created At: 2026-08-11T14:59:36+07:00\r
Completed At: 2026-08-11T14:59:36+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 250 to 300\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
250:     return Scaffold(\r
251:       backgroundColor: kDarkBg,\r
252:       body: Stack(\r
253:         children: [\r
254:           Positioned(\r
255:             top: -50,\r
256:             right: -50,\r
257:             child: Container(\r
258:               width: 300,\r
259:               height: 300,\r
260:               decoration: BoxDecoration(shape: BoxShape.circle, color: kLimeGreen.withOpacity(0.08)),\r
261:               child: BackdropFilter(\r
262:                 filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),\r
263:                 child: Container(color: Colors.transparent),\r
264:               ),\r
265:             ),\r
266:           ),\r
267:           SafeArea(\r
268:             child: Column(\r
269:               crossAxisAlignment: CrossAxisAlignment.start,\r
270:               children: [\r
271:                 Padding(\r
272:                   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),\r
273:                   child: Row(\r
274:                     mainAxisAlignment: MainAxisAlignment.spaceBetween,\r
275:                     children: [\r
276:                       Row(\r
277:                         children: [\r
278:                           Container(\r
279:                             padding: const EdgeInsets.all(8),\r
280:                             decoration: BoxDecoration(color: kLimeGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),\r
281:                             child: const Icon(Icons.calendar_month_rounded, color: kLimeGreen, size: 22),\r
282:                           ),\r
283:                           const SizedBox(width: 12),\r
284:                           const Column(\r
285:                             crossAxisAlignment: CrossAxisAlignment.start,\r
286:                             children: [\r
287:                               Text("แผนการเข้าพบลูกค้า", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),\r
288:                               Text("Weekly Visit Planner", style: TextStyle(color: Colors.white54, fontSize: 11)),\r
289:                             ],\r
290:                           ),\r
291:                         ],\r
292:                       ),\r
293:                       GestureDetector(\r
294:                         onTap: _fetchVisitPlans,\r
295:                         child: Container(\r
296:                           padding: const EdgeInsets.all(8),\r
297:                           decoration: BoxDecoration(color: kCardDark, border: Border.all(color: kLimeGreen.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),\r
298:                           child: const Icon(Icons.refresh_rounded, color: kLimeGreen, size: 18),\r
299:                         ),\r
300:                       )\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r
Created At: 2026-08-11T14:59:42+07:00\r
Completed At: 2026-08-11T14:59:42+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 30 to 80\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
30: \r
31:   @override\r
32:   void initState() {\r
33:     super.initState();\r
34:     _generateWeeks([]);\r
35:     _pageController = PageController(initialPage: 1, viewportFraction: 0.85);\r
36:     _fetchVisitPlans();\r
37:     _fetchRepeatedVisits();\r
38:   }\r
39: \r
40:   @override\r
41:   void dispose() {\r
42:     _pageController.dispose();\r
43:     super.dispose();\r
44:   }\r
45: \r
46:   void _generateWeeks(List<dynamic> plans) {\r
47:     final now = DateTime.now();\r
48:     final day = now.weekday;\r
49:     final monday = now.subtract(Duration(days: day - 1));\r
50:     final currentMonday = DateTime(monday.year, monday.month, monday.day);\r
51:     \r
52:     DateTime minWeek = currentMonday;\r
53:     DateTime maxWeek = currentMonday;\r
                              SizedBox(
55:     for (var p in plans) {\r
                    child: PageView.builder(
57:         final date = DateTime.parse(p[\'planned_date\']);\r
58:         final pMonday = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));\r
                      itemBuilder: (context, index) {
60:         if (pMonday.isAfter(maxWeek)) maxWeek = pMonday;\r
61:       }\r
62:     }\r
63: \r
64:     final startBound = minWeek.subtract(const Duration(days: 7));\r
65:     final endBound = maxWeek.add(const Duration(days: 7));\r
66: \r
67:     _weeks = [];\r
68:     for (DateTime w = startBound; !w.isAfter(endBound); w = w.add(const Duration(days: 7))) {\r
69:       _weeks.add(w);\r
70:     }\r
71:   }\r
72: \r
73:   Future<void> _fetchVisitPlans() async {\r
74:     ApiService.clearCache();\r
75:     setState(() => _isLoading = true);\r
76:     try {\r
77:       final response = await ApiService.getWeeklyVisitPlansBoard();\r
78:       if (response.statusCode == 200) {\r
79:         final data = jsonDecode(response.body);\r
80:         if (mounted) {\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
                            return Center(
                              child: Transform.scale(
Completed At: 2026-08-11T15:30:01+07:00\r
                                child: Opacity(
Total Lines: 688\r
                                  child: Container(
Showing lines 119 to 179\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
119:         }\r
120:       } else {\r
121:         if (mounted) setState(() => _isLoadingRepeated = false);\r
122:       }\r
123:     } catch (e) {\r
                  child: Column(
125:       if (mounted) setState(() => _isLoadingRepeated = false);\r
                    children: [
                      Container(
128: \r
129:   Future<void> _addPlan(Map<String, dynamic> data) async {\r
130:     Navigator.of(context).pop(); // close modal\r
131:     setState(() => _isLoading = true);\r
132:     try {\r
133:       final response = await ApiService.addVisitPlan(data);\r
134:       if (response.statusCode == 200 || response.statusCode == 201) {\r
                          children: [
136:       } else {\r
137:         if (mounted) setState(() => _isLoading = false);\r
138:         debugPrint("Failed to add plan: ${response.statusCode} - ${response.body}");\r
139:       }\r
140:     } catch (e) {\r
141:       debugPrint("Error adding plan: $e");\r
142:       if (mounted) setState(() => _isLoading = false);\r
143:     }\r
                              builder: (context) {
145: \r
146:   Future<void> _deletePlan(String id) async {\r
147:     setState(() => _isLoading = true);\r
148:     try {\r
                                if (isCurrent) {
150:       if (response.statusCode == 200) {\r
                                  bgColor = kLimeGreen;\r
152:       } else {\r
153:         if (mounted) setState(() => _isLoading = false);\r
154:         debugPrint("Failed to delete plan: ${response.statusCode}");\r
155:       }\r
156:     } catch (e) {\r
157:       debugPrint("Error deleting plan: $e");\r
158:       if (mounted) setState(() => _isLoading = false);\r
159:     }\r
160:   }\r
161: \r
162:   Future<void> _editPlan(Map<String, dynamic> data) async {\r
163:     Navigator.of(context).pop(); // close modal\r
164:     setState(() => _isLoading = true);\r
165:     try {\r
166:       // Use ApiService.updateVisitPlan if it exists, otherwise post with ID or patch\r
167:       // Since it\'s Next.js backend, let\'s assume it accepts patch for updates, or post handles upsert.\r
168:       final response = await ApiService.patch(Uri.parse(\'${AppConfig.baseUrl}/visit-plans/${data[\'id\']}\'), body: jsonEncode(data));\r
169:       if (response.statusCode == 200 || response.statusCode == 201) {\r
170:         await _fetchVisitPlans();\r
                                    borderRadius: BorderRadius.circular(4),\r
                                  ),\r
                                  child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),\r
                                );\r
                              },\r
                            ),\r
                          ],\r
                        ),\r
                      ),\r
                      Expanded(\r
                        child: weekPlans.isEmpty\r
                          ? Center(\r
                              child: Text(\r
                                index == 0 \r
                                  ? "ไม่มีแผนงานที่เก่ากว่านี้"\r
                                  : (index == _weeks.length - 1 ? "ไม่มีแผนที่ใหม่กว่านี้\
                                textAlign: TextAlign.center,\r
                                style: const TextStyle(color: Colors.white54, fontSize: 13),\r
                              ),\r
                            )\r
                          : ListView.builder(\r
76:     try {\r
77:       final response = await ApiService.getWeeklyVisitPlansBoard();\r
78:       if (response.statusCode == 200) {\r
79:         final data = jsonDecode(response.body);\r
80:         if (mounted) {\r
81:           setState(() {\r
82:             _visitPlans = data[\'visit_plans\'] ?? [];\r
83:             _generateWeeks(_visitPlans);\r
84:             _isLoading = false;\r
85:           });\r
86:           \r
87:           WidgetsBinding.instance.addPostFrameCallback((_) {\r
88:             if (_pageController.hasClients && _isFirstLoad) {\r
89:               _isFirstLoad = false;\r
90:               final now = DateTime.now();\r
91:               final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));\r
92:               final currentIndex = _weeks.indexWhere((w) => w.isAtSameMomentAs(currentMonday));\r
93:               if (currentIndex != -1) {\r
94:                 _pageController.jumpToPage(currentIndex);\r
95:               }\r
96:             }\r
97:           });\r
98:         }\r
99:       } else {\r
100:         throw Exception("Failed to load plans");\r
101:       }\r
102:     } catch (e) {\r
103:       debugPrint("Error: $e");\r
104:       if (mounted) setState(() => _isLoading = false);\r
105:     }\r
106:   }\r
107: \r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r
Created At: 2026-08-11T15:30:21+07:00\r
Completed At: 2026-08-11T15:30:21+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 300 to 380\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
300:                       )\r
301:                     ],\r
302:                   ),\r
303:                 ),\r
304:                 Expanded(\r
305:                   child: _isLoading\r
306:                       ? const Center(child: CircularProgressIndicator(color: kLimeGreen))\r
307:                       : SingleChildScrollView(\r
308:                           child: Column(\r
309:                             crossAxisAlignment: CrossAxisAlignment.start,\r
310:                             children: [\r
311:                               const SizedBox(height: 12),\r
312:                               SizedBox(\r
313:                     height: 440,\r
314:                     child: PageView.builder(\r
315:                       controller: _pageController,\r
316:                       itemCount: _weeks.length,\r
317:                       itemBuilder: (context, index) {\r
318:                         final weekStart = _weeks[index];\r
319:                         final isCurrent = _isCurrentWeek(weekStart);\r
320:                         \r
321:                         // Get plans for this week\r
322:                         final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));\r
323:                         final weekPlans = _visitPlans.where((p) {\r
324:                           if (p[\'planned_date\'] == null) return false;\r
325:                           final planDate = DateTime.parse(p[\'planned_date\']);\r
326:                           return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);\r
327:                         }).toList();\r
328: \r
329:                         return AnimatedBuilder(\r
330:                           animation: _pageController,\r
331:                           builder: (context, child) {\r
332:                             double value = 1.0;\r
333:                             if (_pageController.position.haveDimensions) {\r
334:                               value = (_pageController.page! - index).abs();\r
335:                               value = (1 - (value * 0.15)).clamp(0.85, 1.0);\r
336:                             } else {\r
337:                               value = index == 4 ? 1.0 : 0.85;\r
338:                             }\r
339:                             \r
340:                             return Center(\r
341:                               child: Transform.scale(\r
342:                                 scale: value,\r
343:                                 child: Opacity(\r
344:                                   opacity: value.clamp(0.5, 1.0),\r
345:                                   child: Container(\r
346:                                     width: double.infinity,\r
347:                                     margin: const EdgeInsets.symmetric(horizontal: 4),\r
348:                                     decoration: BoxDecoration(\r
349:                                       color: kCardDark,\r
350:                                       border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),\r
351:                                       borderRadius: BorderRadius.circular(12),\r
352:                                     ),\r
353:                   child: Column(\r
354:                     crossAxisAlignment: CrossAxisAlignment.start,\r
355:                     children: [\r
356:                       Container(\r
357:                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\r
358:                         decoration: BoxDecoration(\r
359:                           color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,\r
360:                           borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),\r
361:                         ),\r
362:                         child: Row(\r
363:                           mainAxisAlignment: MainAxisAlignment.spaceBetween,\r
364:                           children: [\r
365:                             Text(\r
366:                               _formatWeekRange(weekStart),\r
367:                               style: TextStyle(\r
368:                                 color: isCurrent ? kLimeGreen : Colors.white,\r
369:                                 fontWeight: FontWeight.bold,\r
370:                               ),\r
371:                             ),\r
372:                             Builder(\r
373:                               builder: (context) {\r
374:                                 String label = "";\r
375:                                 Color bgColor = Colors.transparent;\r
376:                                 Color textColor = Colors.white;\r
377: \r
378:                                 if (isCurrent) {\r
379:                                   label = "สัปดาห์นี้";\r
380:                                   bgColor = kLimeGreen;\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r
Created At: 2026-08-11T15:30:39+07:00\r
Completed At: 2026-08-11T15:30:39+07:00\r
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`\r
Total Lines: 688\r
Total Bytes: 33016\r
Showing lines 310 to 370\r
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.\r
310:                             children: [\r
311:                               const SizedBox(height: 12),\r
312:                               SizedBox(\r
313:                     height: 440,\r
314:                     child: PageView.builder(\r
315:                       controller: _pageController,\r
316:                       itemCount: _weeks.length,\r
317:                       itemBuilder: (context, index) {\r
318:                         final weekStart = _weeks[index];\r
319:                         final isCurrent = _isCurrentWeek(weekStart);\r
320:                         \r
321:                         // Get plans for this week\r
322:                         final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));\r
323:                         final weekPlans = _visitPlans.where((p) {\r
324:                           if (p[\'planned_date\'] == null) return false;\r
325:                           final planDate = DateTime.parse(p[\'planned_date\']);\r
326:                           return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);\r
327:                         }).toList();\r
328: \r
329:                         return AnimatedBuilder(\r
330:                           animation: _pageController,\r
331:                           builder: (context, child) {\r
332:                             double value = 1.0;\r
333:                             if (_pageController.position.haveDimensions) {\r
334:                               value = (_pageController.page! - index).abs();\r
335:                               value = (1 - (value * 0.15)).clamp(0.85, 1.0);\r
336:                             } else {\r
337:                               value = index == 4 ? 1.0 : 0.85;\r
338:                             }\r
339:                             \r
340:                             return Center(\r
341:                               child: Transform.scale(\r
342:                                 scale: value,\r
343:                                 child: Opacity(\r
344:                                   opacity: value.clamp(0.5, 1.0),\r
345:                                   child: Container(\r
346:                                     width: double.infinity,\r
347:                                     margin: const EdgeInsets.symmetric(horizontal: 4),\r
348:                                     decoration: BoxDecoration(\r
349:                                       color: kCardDark,\r
350:                                       border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),\r
351:                                       borderRadius: BorderRadius.circular(12),\r
352:                                     ),\r
353:                   child: Column(\r
354:                     crossAxisAlignment: CrossAxisAlignment.start,\r
355:                     children: [\r
356:                       Container(\r
357:                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\r
358:                         decoration: BoxDecoration(\r
359:                           color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,\r
360:                           borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),\r
361:                         ),\r
362:                         child: Row(\r
363:                           mainAxisAlignment: MainAxisAlignment.spaceBetween,\r
364:                           children: [\r
365:                             Text(\r
366:                               _formatWeekRange(weekStart),\r
367:                               style: TextStyle(\r
368:                                 color: isCurrent ? kLimeGreen : Colors.white,\r
369:                                 fontWeight: FontWeight.bold,\r
370:                               ),\r
The above content does NOT show the entire file contents. If you need to view any lines of the file which were not shown to complete your task, call this tool again to view those lines.\r
\r

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

