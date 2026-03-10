import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';

// 🎨 Palette สี
const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kLimeGreen = Color(0xFFD2E862);
const Color kCardDark = Color(0xFF1C1C1E);

class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key});

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  File? _image;
  bool _loading = false;
  List<dynamic> _products = [];
  String? _aiAnalysis;

  // 📸 1. สร้างเมนูเด้งให้เลือกระหว่าง "ถ่ายรูป" กับ "แกลเลอรี"
  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // ใช้ Transparent เพื่อทำขอบโค้งสวยๆ
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: kCardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blueAccent),
                  ),
                  title: const Text('ถ่ายรูป (Camera)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                  ),
                  title: const Text('เลือกจากแกลเลอรี (Gallery)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // 📸 2. ฟังก์ชันรับรูป
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _products = [];
        _aiAnalysis = null;
      });
    }
  }

 // 🚀 3. ยิง API ค้นหาด้วย AI (ฉบับปลดล็อก Error Uri)
  Future<void> _searchWithAI() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      int fileSize = await _image!.length();
      print("ขนาดไฟล์ก่อนส่ง: ${fileSize / 1024 / 1024} MB");

      // 🌟 แก้ไขตรงนี้: ลบ Uri.parse() ออก เพราะตัวแปรเป็น Uri อยู่แล้วครับ!
      var request = http.MultipartRequest('POST', AppConfig.aiSearchUrl);
      
      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 413) {
        throw Exception("รูปภาพมีขนาดใหญ่เกินไป (เกินลิมิตเซิร์ฟเวอร์) กรุณาครอปหรือใช้รูปที่เล็กลงครับ");
      }
      
      if (response.statusCode != 200) {
         throw Exception("เซิร์ฟเวอร์ตอบกลับผิดพลาด (รหัส ${response.statusCode})");
      }

      var data = json.decode(response.body);

      setState(() {
        _products = data['products'] ?? [];
        _aiAnalysis = data['ai_analysis'];
      });
      
    } on FormatException catch (_) {
      _showErrorDialog("ระบบขัดข้องชั่วคราว: ไม่สามารถอ่านข้อมูลจากเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้งครับ");
    } on SocketException {
      _showErrorDialog("ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต: ดูเหมือนเน็ตจะหลุดหรือช้าเกินไปครับ");
    } catch (e) {
      _showErrorDialog("ไม่สามารถค้นหาได้: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      setState(() => _loading = false);
    }
  }
  // 💬 ฟังก์ชันโชว์ Error แบบสวยๆ เป็นภาษาคน
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('แจ้งเตือน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ตกลง', style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🔎 4. หน้าต่างดูรายละเอียดสินค้า (โมดูล)
  void _showProductDetails(Map product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: kDarkBg.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // เส้นขีดด้านบน
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 20),
                    width: 50, height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                // รูปภาพสินค้าแบบเต็มๆ
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(image: NetworkImage(product['variant_image']), fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // รายละเอียดสินค้า
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(product['sku'] ?? 'NO SKU', style: const TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text('ความแม่นยำ ${(product['similarity'] * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(product['name'] ?? 'ไม่มีชื่อสินค้า', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(product['description'] ?? 'สินค้าคุณภาพจาก TPS Garden', style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
                        const Spacer(),
                        // ปุ่ม Action
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('ปิดหน้าต่าง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text('AI IMAGE SEARCH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 🌌 Background Glow (ให้เหมือนหน้า Home)
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyanAccent.withOpacity(0.15)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Find your product", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("อัปโหลดรูปภาพเพื่อค้นหาสินค้าที่ใกล้เคียงที่สุดในสต็อก", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 30),

                // 🖼️ กล่องอัปโหลดรูป (Glassmorphism & เปลี่ยนรูปได้)
                GestureDetector(
                  onTap: _loading ? null : _showPickerOptions,
                  child: Container(
                    width: double.infinity,
                    height: 280,
                    decoration: BoxDecoration(
                      color: kCardDark.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: _image != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(26), child: Image.file(_image!, fit: BoxFit.cover)),
                              // โอเวอร์เลย์มืดๆ ขอบล่าง
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)]),
                                ),
                              ),
                              // ปุ่ม "เปลี่ยนรูป" ลอยอยู่ตรงกลางให้เห็นชัดๆ
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.2))),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text('เปลี่ยนรูปภาพ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.cyanAccent, size: 40),
                              ),
                              const SizedBox(height: 16),
                              const Text('แตะเพื่ออัปโหลดรูปภาพ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              const Text('รองรับ Camera & Gallery', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                // 🔍 ปุ่มค้นหาสุดพรีเมียม
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: _image == null
                        ? LinearGradient(colors: [Colors.grey[800]!, Colors.grey[900]!])
                        : const LinearGradient(colors: [Color(0xFF6C4AB6), Color(0xFF4A3080)]),
                    boxShadow: _image != null ? [BoxShadow(color: const Color(0xFF6C4AB6).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))] : [],
                  ),
                  child: ElevatedButton(
                    onPressed: _loading || _image == null ? null : _searchWithAI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _loading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kLimeGreen, strokeWidth: 3)),
                              SizedBox(width: 12),
                              Text('AI is scanning...', style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          )
                        : Text('START SEARCH', style: TextStyle(color: _image == null ? Colors.white54 : kLimeGreen, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                  ),
                ),

                // 💡 กล่องคำแนะนำจาก Gemini (ถ้าหาไม่เจอ)
                if (_aiAnalysis != null && _products.isEmpty) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 16),
                        Expanded(child: Text(_aiAnalysis!, style: const TextStyle(color: Colors.amber, height: 1.6, fontSize: 14))),
                      ],
                    ),
                  ),
                ],

                // 🪵 รายการสินค้าที่เจอ
                if (_products.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const Text("Best Matches", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final score = product['similarity'] * 100;
                      final isHighMatch = score >= 60;

                      return GestureDetector(
                        onTap: () => _showProductDetails(product), // 🚨 กดแล้วเด้งหน้าต่างโชว์ข้อมูล
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                          child: Row(
                            children: [
                              // รูปสินค้าเล็ก
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(product['variant_image'], width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 16),
                              // ข้อมูลสินค้า
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Text('SKU: ${product['sku'] ?? '-'}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    // ป้ายความแม่นยำ
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: isHighMatch ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                      child: Text(
                                        'Match: ${score.toStringAsFixed(1)}%',
                                        style: TextStyle(color: isHighMatch ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}