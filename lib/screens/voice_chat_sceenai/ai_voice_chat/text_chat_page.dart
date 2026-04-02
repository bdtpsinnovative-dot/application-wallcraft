// lib/screens/voice_chat_sceenai/ai_voice_chat/text_chat_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // ยังคง import ไว้ใช้สำหรับ Type Response
import 'package:shared_preferences/shared_preferences.dart'; // ✅ 1. เพิ่ม SharedPrefs เพื่อดึง UserID
import '../../../../constants.dart';
import '../../../../services/api_service.dart'; // ✅ 2. เพิ่ม ApiService

class TextChatPage extends StatefulWidget {
  const TextChatPage({super.key});

  @override
  State<TextChatPage> createState() => _TextChatPageState();
}

class _TextChatPageState extends State<TextChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // เพิ่มตัวช่วยเลื่อนจอลงล่างสุด
  
  // ข้อความเริ่มต้น
  final List<Map<String, String>> _messages = [
    {'role': 'assistant', 'content': 'ผมคือ AI ของแบรนด์ Wallcraft'}
  ];
  
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    String userMessage = _controller.text;

    setState(() {
      _messages.add({"role": "user", "content": userMessage});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom(); // เลื่อนจอลง

    try {
      // ✅ 1. ดึง UserID จริงจากเครื่อง
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'guest'; // ถ้าไม่มีให้เป็น guest
      
      final url = AppConfig.chatUrl;
      print("Sending to: $url (User: $userId)"); 

      // ✅ 2. ใช้ ApiService.post แทน http.post
      // (ระบบจะจัดการ Header และ Token Auto-Refresh ให้เอง)
      final response = await ApiService.post(
        url,
        body: jsonEncode({
          'userId': userId, // ส่ง userId จริงๆ ไป
          'message': userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          // รับค่าตอบกลับ (รองรับทั้ง key 'ai_reply' และ 'reply')
          String reply = data['ai_reply'] ?? data['reply'] ?? "No response content";
          _messages.add({"role": "assistant", "content": reply});
        });
        _scrollToBottom(); // เลื่อนจอลงเมื่อ AI ตอบ
      } else {
        _showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
      _showError("Connection Failed. (Is Next.js running?)");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    // หน่วงเวลานิดนึงเพื่อให้ UI วาดเสร็จก่อนค่อยเลื่อน
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // พื้นหลังดำตามธีม
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Text Chat', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white12,
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- ส่วนแสดงรายการข้อความ ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // ✅ ใส่ Controller
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueGrey.shade800 : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      m['content'] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // --- Loading Indicator ---
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent, 
                color: Colors.purpleAccent,
              ),
            ),

          // --- ช่องพิมพ์ข้อความ ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF222222),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _isLoading ? null : _sendMessage,
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