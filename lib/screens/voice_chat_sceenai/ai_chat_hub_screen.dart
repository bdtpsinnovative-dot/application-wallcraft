import 'package:flutter/material.dart';
import 'dart:math' as math; // สำหรับคำนวณองศาหมุน
import 'ai_voice_chat/text_chat_page.dart'; 
import 'ai_voice_chat/voice_session_page.dart';

class AiChatHubScreen extends StatelessWidget {
  const AiChatHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('DEVELOPER', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                'WALLCRAFT',
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 40), 
              const Text(
                'How can I help you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 32, 
                  height: 1.2
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Wall design consultation',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 40),
              
              // --- 📱 ปุ่ม Text Chat (ความเร็ว 4.5 วินาทีต่อรอบ) ---
              AnimatedEdgeGlowCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Text Chat',
                laserColor: Colors.cyanAccent, 
                // ✅ ตั้งให้หมุน 1 รอบใช้เวลา 4.5 วินาที (วิ่งช้าลง)
                animationDuration: const Duration(milliseconds: 4500), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TextChatPage()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // --- 🎙️ ปุ่ม Voice Session (ความเร็ว 6 วินาทีต่อรอบ) ---
              AnimatedEdgeGlowCard(
                icon: Icons.mic_none_rounded,
                title: 'Voice Session',
                laserColor: Colors.purpleAccent,
                // ✅ ตั้งให้หมุน 1 รอบใช้เวลา 6 วินาที (ช้ากว่าอันแรก และวิ่งไม่พร้อมกัน)
                animationDuration: const Duration(milliseconds: 6000), 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoiceSessionPage()),
                  );
                },
              ),
              
              const SizedBox(height: 60), 
              
              const Text(
                '© 2026 WALLCRAFT EXPERT AI. ALL RIGHTS RESERVED.',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🚀 WIDGET: การ์ดขอบเลเซอร์บางๆ สไตล์ Cyberpunk
// ==========================================
class AnimatedEdgeGlowCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color laserColor;
  final Duration animationDuration; // ✅ เพิ่มตัวรับค่าความเร็ว

  const AnimatedEdgeGlowCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.laserColor,
    required this.animationDuration, // ✅ บังคับใส่ความเร็ว
  });

  @override
  State<AnimatedEdgeGlowCard> createState() => _AnimatedEdgeGlowCardState();
}

class _AnimatedEdgeGlowCardState extends State<AnimatedEdgeGlowCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // ✅ นำความเร็วที่ส่งเข้ามา (widget.animationDuration) มาตั้งค่าให้ Controller
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1️⃣ เลเซอร์วิ่งด้านหลัง
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 2.5,
                    child: Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              widget.laserColor.withOpacity(0.2), // หางเลเซอร์
                              widget.laserColor,                  // ตัวเลเซอร์
                              Colors.white,                       // หัวเลเซอร์
                              Colors.transparent,                 // ตัดจบ
                            ],
                            stops: const [0.0, 0.5, 0.95, 0.98, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // 2️⃣ ตัวการ์ดสีดำด้านใน
            Container(
              margin: const EdgeInsets.all(2.0), // ความหนาของเส้นเลเซอร์
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Icon(widget.icon, color: widget.laserColor, size: 32),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 20,
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}