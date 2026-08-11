+          // --- Repeated Visits Section ---
+          Padding(
+            padding: const EdgeInsets.symmetric(horizontal: 16.0),
+            child: Row(
+              children: [
+                Container(
+                  padding: const EdgeInsets.all(6),
+                  decoration: BoxDecoration(
+                    color: kLimeGreen.withOpacity(0.15),
+                    borderRadius: BorderRadius.circular(8),
+                  ),
+                  child: const Icon(Icons.autorenew_rounded, color: kLimeGreen, size: 20),
+                ),
+                const SizedBox(width: 12),
+                const Text(
+                  "ผลการเข้าพบซ้ำ (3 เช็คอินขึ้นไป)",
+                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
+                ),
+              ],
+            ),
+          ),
+          const SizedBox(height: 12),
+          _isLoadingRepeated 
+            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: kLimeGreen)))
+            : _repeatedVisits.isEmpty
+              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("ไม่มีข้อมูลการเข้าพบซ้ำ", style: TextStyle(color: Colors.white54))))
+              : ListView.builder(
+                  physics: const NeverScrollableScrollPhysics(),
+                  shrinkWrap: true,
+                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
+                  itemCount: _repeatedVisits.length,
+                  itemBuilder: (context, index) {
+                    final comp = _repeatedVisits[index];
+                    final uniqueProjects = comp['uniqueProjects'] as Map<String, dynamic>? ?? {};
+                    
+                    return Container(
+                      margin: const EdgeInsets.only(bottom: 12),
+                      padding: const EdgeInsets.all(16),
+                      decoration: BoxDecoration(
+                        color: kCardDark,
+                        borderRadius: BorderRadius.circular(12),
+                        border: Border.all(color: Colors.white12),
+                      ),
+                      child: Column(
+                        crossAxisAlignment: CrossAxisAlignment.start,
+                        children: [
+                          Row(
+                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
+                            children: [
+                              Expanded(
+                                child: Text(
+                                  comp['name'] ?? 'Unknown',
+                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
+                                ),
+                              ),
+                              const SizedBox(width: 12),
+                              Container(
+                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
+                                decoration: BoxDecoration(
+                                  color: kLimeGreen,
+                                  borderRadius: BorderRadius.circular(20),
+                                ),
+                                child: Text(
+                                  "${comp['count']} ครั้ง",
+                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
+                                ),
+                              )
+                            ],
+                          ),
+                          if (uniqueProjects.isNotEmpty) ...[
+                            const SizedBox(height: 12),
+                            const Divider(color: Colors.white12, height: 1),
+                            const SizedBox(height: 12),
+                            Text("${uniqueProjects.length} โปรเจค", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
+                            const SizedBox(height: 8),
+                            ...uniqueProjects.entries.map((e) {
+                              String dateStr = '';
+                              if (e.value != null) {
+                                final d = DateTime.parse(e.value.toString());
+                                final months = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."];
+                                dateStr = "${d.day} ${months[d.month - 1]} ${(d.year + 543) % 100}";
+                              }
+                              
+                              return Padding(
+                                padding: const EdgeInsets.only(bottom: 6.0),
+                                child: Row(
+                                  crossAxisAlignment: CrossAxisAlignment.start,
+                                  children: [
+                                    const Icon(Icons.folder_open_rounded, color: Colors.blueAccent, size: 16),
+                                    const SizedBox(width: 8),
+                                    Expanded(
+                                      child: Text(
+                                        e.key,
+                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
+                                      ),
+                                    ),
+                                    if (dateStr.isNotEmpty)
+                                      Text("($dateStr)", style: const TextStyle(color: Colors.white38, fontSize: 11)),
+                                  ],
+                                ),
+                              );
+                            }).toList(),
+                          ]
+                        ],
+                      ),
+                    );
+                  },
+                ),
+          const SizedBox(height: 40),
+        ],
+      ),
+    ),
+  );
+}
 }
 
[diff_block_end]

Please note that the above snippet only shows the MODIFIED lines from the last change. It shows up to 3 lines of unchanged lines before and after the modified lines. The actual file contents may have many more lines not shown.

เรียบร้อยแล้วครับนาย! จัดให้เต็มระบบเลยครับ

ผมทำการสร้าง API ในส่วนหลังบ้านเพื่อให้แอปมือถือดึงข้อมูล "ผลการเข้าพบซ้ำ" ได้รวดเร็วที่สุด และจัดการแก้ไขโค้ดแอป Flutter ในไฟล์ `visit_planner_screen.dart` ตามที่นายต้องการเป๊ะๆ ครับ:
1. การ์ดแผนงานถูกย่อขนาดให้เล็กลง (ความสูงอยู่ที่ 440 กำลังพอดี) ทำให้เห็นพื้นที่ด้านล่าง
2. ลิสต์ **"ผลการเข้าพบซ้ำ (3 เช็คอินขึ้นไป)"** ต่อท้ายอยู่ด้านล่างการ์ด พร้อมดีไซน์พื้นหลังการ์ดสีเข้มเท่ๆ และไอคอนที่เข้ากันสุดๆ ครับ
3. มีการแสดงวันที่ที่โปรเจคนั้นๆ เข้ามาด้วยในวงเล็บเหมือนที่เว็บเลยครับ

นายสามารถอ่านสรุปการปรับแก้ที่ผมทำไปได้ที่นี่เลยครับ 👉 [สรุปรายละเอียดการทำงาน (Walkthrough)](file:///C:/Users/Por%20Woodden/.gemini/antigravity/brain/441cd301-8f6d-4505-868d-d78b6a0b13a9/walkthrough.md)

ตอนนี้นายลองเซฟแล้ว **Restart / Hot Reload** ตัวแอปบน Android Emulator ดูผลลัพธ์หน้าจอได้เลยครับผม! ติดตรงไหนหรืออยากให้ขยาย/หดการ์ดเพิ่มขึ้น บอกผมได้ตลอดเลยครับ!

Created At: 2026-08-11T13:35:58+07:00
Completed At: 2026-08-11T13:35:58+07:00
File Path: `file:///C:/app_test/hello_app/lib/screens/visit_planner/visit_planner_screen.dart`
Total Lines: 480
Total Bytes: 21122
Showing lines 210 to 230
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
210:     return Scaffold(
211:       backgroundColor: kDarkBg,
212:       appBar: AppBar(
213:         backgroundColor: kDarkBg,
214:         title: const Text("แผนการเข้าพบลูกค้า (12 สัปดาห์)", style: TextStyle(color: Colors.white, fontSize: 18)),
215:         elevation: 0,
216:         actions: [
217:           IconButton(
218:             icon: const Icon(Icons.refresh, color: Colors.white),
219:             onPressed: _fetchVisitPlans,
220:           )
221:         ],