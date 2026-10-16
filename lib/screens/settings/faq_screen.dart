// lib/screens/settings/faq_screen.dart
import 'package:flutter/material.dart';

const Color kLimeGreen = Color(0xFFD2E862);

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ทั้งหมด';
  String _searchQuery = '';

  final List<String> _categories = [
    'ทั้งหมด',
    'เช็คอิน & ลีด',
    'แผนงาน',
    'สต็อก & PI',
    'แก้ปัญหา',
  ];

  late final List<Map<String, dynamic>> _allFaqs = [
    {
      'category': 'เช็คอิน & ลีด',
      'icon': Icons.add_location_alt_rounded,
      'iconColor': Colors.blueAccent,
      'question': 'วิธีเช็คอินและบันทึกลีดลูกค้าทำอย่างไร?',
      'summary': 'ขั้นตอนการปักหมุด GPS และบันทึกข้อมูลหน้างานลูกค้า',
      'content': [
        '1. ไปที่หน้าหลัก แตะปุ่ม "ลีด & เช็คอิน" (Lead & Checkin)',
        '2. กดปุ่ม "เช็คอินสถานที่" เพื่อให้ระบบดึงพิกัด GPS อัตโนมัติ (กรุณาเปิด GPS ในมือถือ)',
        '3. ถ่ายรูปหน้าร้านหรือหน้างานลูกค้าเพื่อยืนยันการเข้าพบจริง',
        '4. กรอกข้อมูลชื่อลูกค้า เบอร์โทร ประเภทโครงการ และรายละเอียดที่พูดคุย',
        '5. กดปุ่ม "บันทึกข้อมูล" ข้อมูลจะถูกซิงก์เข้าระบบส่วนกลางทันที',
      ],
      'tip': '💡 แนะนำให้เปิด GPS ก่อนกดเข้าหน้าเช็คอิน 3-5 วินาที เพื่อให้ได้พิกัดที่แม่นยำที่สุดครับ',
    },
    {
      'category': 'เช็คอิน & ลีด',
      'icon': Icons.gps_off_rounded,
      'iconColor': Colors.redAccent,
      'question': 'ระบบแจ้งว่า "ไม่พบพิกัด GPS" หรือดึงตำแหน่งไม่ได้?',
      'summary': 'วิธีแก้ไขเมื่อเปิดใช้งาน GPS ไม่สำเร็จ',
      'content': [
        '1. ตรวจสอบว่าเปิด "Location Services" ในการตั้งค่าของเครื่องโทรศัพท์แล้วหรือยัง',
        '2. สำหรับ iOS: ไปที่ Settings > Wallcraft > Location > เลือก "While Using the App" และเปิด "Precise Location"',
        '3. สำหรับ Android: ไปที่ การตั้งค่า > แอป > Wallcraft > การอนุญาต > ตำแหน่ง > เลือก "อนุญาตขณะใช้แอป"',
        '4. หากยังดึงไม่ได้ ให้ลองสลับเป็น Airplane Mode 5 วินาที แล้วปิด เพื่อรีเซ็ตตัวรับสัญญาณ GPS',
      ],
      'tip': '⚠️ หากอยู่ในอาคารทึบหรือชั้นใต้ดิน สัญญาณดาวเทียมอาจอ่อน ให้เดินเข้าใกล้บริเวณหน้าต่างหรือประตูครับ',
    },
    {
      'category': 'แผนงาน',
      'icon': Icons.calendar_month_rounded,
      'iconColor': kLimeGreen,
      'question': 'การวางแผนงานและบันทึกผลการเข้าพบลูกค้า (Visit Planner)',
      'summary': 'วิธีสร้างตารางนัดหมายและการสรุปผลการเข้าพบ',
      'content': [
        '1. แตะแท็บที่ 2 (ไอคอนปฏิทิน) ที่แถบเมนูด้านล่าง',
        '2. แตะเลือกวันที่ต้องการนัดหมายบนปฏิทิน แล้วกดปุ่ม "+ เพิ่มแผนงาน"',
        '3. เลือกลูกค้า กำหนดเวลา วัตถุประสงค์การเข้าพบ แล้วกดบันทึก',
        '4. เมื่อถึงวันนัดหมาย หลังเข้าพบลูกค้าเสร็จ ให้กดที่การ์ดแผนงานนั้น',
        '5. เลือกสถานะ "สำเร็จ" หรือ "ไม่สำเร็จ" พร้อมระบุเหตุผลและสิ่งที่ตกลงกับลูกค้า',
      ],
      'tip': '📊 ข้อมูลผลการเข้าพบจะสรุปขึ้นแดชบอร์ดผู้บริหารอัตโนมัติ ช่วยให้ทีมเห็นความคืบหน้าแบบเรียลไทม์',
    },
    {
      'category': 'สต็อก & PI',
      'icon': Icons.inventory_2_rounded,
      'iconColor': Colors.cyanAccent,
      'question': 'การเช็คสต็อกสินค้า และความหมายของแต่ละยอด',
      'summary': 'ทำความเข้าใจยอดสต็อกคงเหลือ ยอดจอง และสต็อกพร้อมขาย',
      'content': [
        '1. เข้าเมนู "Stock Management" บนหน้าหลัก',
        '2. พิมพ์ชื่อซีรีส์ เช่น "VENICE", "VERONA", "SLAB" หรือใช้ตัวกรองด้านบน',
        '3. ความหมายของข้อมูลสต็อก:',
        '   • สต็อกคงเหลือ (Balance): จำนวนสินค้าทั้งหมดที่มีอยู่ในคลังจริง',
        '   • ยอดจอง (Reserved): จำนวนสินค้าที่ติดจองในออเดอร์ของลูกค้ารายอื่น',
        '   • พร้อมขาย (Available): จำนวนสินค้าสุทธิที่สามารถเปิดออเดอร์ขายได้ทันที',
      ],
      'tip': '🔍 สามารถแตะที่ชื่อซีรีส์เพื่อดูประวัติและรายละเอียดสเปกสินค้าเพิ่มเติมได้ครับ',
    },
    {
      'category': 'สต็อก & PI',
      'icon': Icons.receipt_long_rounded,
      'iconColor': const Color(0xFFB388FF),
      'question': 'วิธีค้นหาและเปิดดูเอกสารใบสั่งซื้อ PI (PI Records)',
      'summary': 'การติดตามสถานะออเดอร์ ตัวกรองเซลล์ และการดาวน์โหลด PDF',
      'content': [
        '1. เข้าเมนู "รายการสั่งซื้อ PI" จากหน้าหลัก',
        '2. พิมพ์ค้นหาด้วย "เลขที่ PI" หรือ "ชื่อลูกค้า" ในช่องค้นหา',
        '3. แตะปุ่ม "ตัวกรอง" เพื่อเลือกดูตาม Brand, สถานะเอกสาร, หรือ "เซลล์ผู้ดูแล"',
        '4. แตะที่การ์ดรายการเพื่อดูรายละเอียดสินค้าและยอดเงิน',
        '5. กดปุ่ม "ดูไฟล์เอกสาร" เพื่อเปิดพรีวิวไฟล์ PDF หรือกดปุ่ม "แชร์" เพื่อส่งให้ลูกค้าทาง LINE',
      ],
      'tip': '📄 หากเปิดไฟล์ PDF แล้วหน้าจอขาว ให้กดปุ่มรีเฟรชหรือกด "เปิดในเบราว์เซอร์" เพื่อดาวน์โหลดลงเครื่องได้ครับ',
    },
    {
      'category': 'แก้ปัญหา',
      'icon': Icons.notifications_off_rounded,
      'iconColor': Colors.amberAccent,
      'question': 'ไม่ได้รับการแจ้งเตือน หรือแจ้งเตือนไม่เด้งเตือน?',
      'summary': 'วิธีตรวจสอบและตั้งค่าเปิดรับการแจ้งเตือน',
      'content': [
        '1. ไปที่แท็บ "Account & Settings" (แท็บขวาสุด)',
        '2. ดูที่หัวข้อ "การตั้งค่าระบบ" > "การแจ้งเตือน"',
        '3. ตรวจสอบว่าไม่ได้เลือก "ปิดการแจ้งเตือน" (แนะนำให้เลือก "ทุกทีม" หรือ "เฉพาะทีมตัวเอง")',
        '4. ตรวจสอบการตั้งค่ามือถือว่าไม่ได้เปิดโหมด Do Not Disturb (ห้ามรบกวน)',
        '5. ตรวจสอบว่าแอปได้รับสิทธิ์ส่งการแจ้งเตือนในการตั้งค่าของระบบเครื่อง',
      ],
      'tip': '🔔 หากยังไม่ได้รับแจ้งเตือน ให้ลองกดปุ่มรีเฟรชที่มุมขวาบนของหน้า Settings สักหนึ่งครั้งครับ',
    },
    {
      'category': 'แก้ปัญหา',
      'icon': Icons.cleaning_services_rounded,
      'iconColor': Colors.tealAccent,
      'question': 'แอปโหลดช้า ค้าง หรือรูปภาพไม่อัปเดต แก้ไขอย่างไร?',
      'summary': 'วิธีใช้ฟังก์ชันล้างแคช (Clear Cache) เพื่อเพิ่มความเร็ว',
      'content': [
        '1. ไปที่แท็บ "Account & Settings" (แท็บขวาสุด)',
        '2. แตะที่เมนู "ล้างแคชในเครื่อง (Storage)" ในหมวดการตั้งค่าระบบ',
        '3. กดยืนยัน "ล้างแคชทันที"',
        '4. ระบบจะลบไฟล์รูปภาพชั่วคราวและหน่วยความจำที่ตกค้างออกทั้งหมด (ไม่มีผลกระทบต่อข้อมูลสำคัญของคุณ)',
        '5. ปิดแอปและเปิดใหม่ แอปจะโหลดข้อมูลสดใหม่และทำงานได้เร็วขึ้นอย่างเห็นได้ชัด',
      ],
      'tip': '🧹 แนะนำให้ล้างแคชสัปดาห์ละ 1 ครั้ง หากมีการเปิดดูรูปภาพสินค้าหรือรูปหน้างานจำนวนมากครับ',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFaqs {
    return _allFaqs.where((item) {
      final matchesCategory =
          _selectedCategory == 'ทั้งหมด' || item['category'] == _selectedCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          (item['question'] as String).toLowerCase().contains(q) ||
          (item['summary'] as String).toLowerCase().contains(q) ||
          ((item['content'] as List<String>).join(' ')).toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final faqs = _filteredFaqs;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161618),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ศูนย์ช่วยเหลือ & คู่มือการใช้งาน",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔍 แถบค้นหา
          Container(
            color: const Color(0xFF161618),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ค้นหาคำถาม หรือขั้นตอนการใช้งาน...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // 🏷️ หมวดหมู่ Filter Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kLimeGreen
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? kLimeGreen : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 📄 รายการคำถาม ExpansionTiles
          Expanded(
            child: faqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่พบคำถามที่ค้นหา',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: faqs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = faqs[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF161618),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (item['iconColor'] as Color)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['iconColor'] as Color,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['question'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                item['summary'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                            iconColor: kLimeGreen,
                            collapsedIconColor: Colors.grey[500],
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                  top: 4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 12),
                                    ...((item['content'] as List<String>).map(
                                      (step) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          step,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    )),
                                    if (item['tip'] != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(
                                          item['tip'] as String,
                                          style: const TextStyle(
                                            color: kLimeGreen,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
