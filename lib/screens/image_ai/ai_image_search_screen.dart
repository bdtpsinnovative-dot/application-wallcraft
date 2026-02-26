// lib/screens/image_ai/ai_image_search_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 🎨 Palette สีมาตรฐานของเรา
const Color kDarkBg = Color(0xFF0F0F11);
const Color kGlowPurple = Color(0xFF4A3080);
const Color kCardDark = Color(0xFF1C1C1E);
const Color kLimeGreen = Color(0xFFD2E862);

class AiImageSearchScreen extends StatefulWidget {
  const AiImageSearchScreen({super.key});

  @override
  State<AiImageSearchScreen> createState() => _AiImageSearchScreenState();
}

class _AiImageSearchScreenState extends State<AiImageSearchScreen> with SingleTickerProviderStateMixin {
  File? _image;
  bool _isAnalyzing = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    // แอนิเมชันเส้นสแกน AI
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 90);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isAnalyzing = true;
      });

      // 🧠 จำลองการประมวลผลของ AI (3 วินาที)
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showResultSheet();
      }
    }
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: kCardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.auto_awesome, color: kLimeGreen, size: 32),
            const SizedBox(height: 12),
            const Text("AI Analysis Result", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("We found similar products in your inventory.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            // รายการจำลองที่ AI หาเจอ
            _buildResultItem("Premium Material A1", "98% Match"),
            const SizedBox(height: 12),
            _buildResultItem("Industrial Pipe v2", "85% Match"),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String title, String match) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          Text(match, style: const TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold)),
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
          // 🌌 Background Glow
          Positioned(
            top: -50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kGlowPurple.withOpacity(0.2)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container(color: Colors.transparent)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                
                // 🚧 เพิ่มป้ายเตือนตรงนี้ครับ!
                _buildWarningBanner(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildImagePreview(),
                        const SizedBox(height: 40),
                        if (!_isAnalyzing) _buildActionButtons(),
                        if (_isAnalyzing) _buildAnalyzingText(),
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

  // --------------------------------------------------------
  // 🚧 ฟังก์ชันสร้างป้ายเตือน
  // --------------------------------------------------------
  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: const Text(
              "Demo Mode : หน้านี้เป็นเพียงการจำลองระบบ AI เท่านั้น ยังไม่สามารถค้นหาสินค้าได้จริง",
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text("AI Smart Search", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // กรอบเลนส์ AI
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _isAnalyzing ? kLimeGreen : Colors.white.withOpacity(0.1), width: 2),
              color: kCardDark,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_search_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text("No Image Selected", style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
            ),
          ),

          // ⚡️ Scanning Animation (เส้นเลเซอร์)
          if (_isAnalyzing)
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: 280 * _scanController.value,
                  child: Container(
                    width: 260,
                    height: 2,
                    decoration: BoxDecoration(
                      color: kLimeGreen,
                      boxShadow: [
                        BoxShadow(color: kLimeGreen.withOpacity(0.8), blurRadius: 15, spreadRadius: 2),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildMainBtn(Icons.camera_alt_rounded, "Take a Photo", () => _pickImage(ImageSource.camera)),
        const SizedBox(height: 16),
        _buildSecondaryBtn(Icons.photo_library_rounded, "Upload from Gallery", () => _pickImage(ImageSource.gallery)),
      ],
    );
  }

  Widget _buildAnalyzingText() {
    return Column(
      children: const [
        CircularProgressIndicator(color: kLimeGreen),
        SizedBox(height: 20),
        Text("AI Engine Analyzing...", style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        SizedBox(height: 8),
        Text("Identifying objects and materials", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildMainBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: kLimeGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kLimeGreen.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 24),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}