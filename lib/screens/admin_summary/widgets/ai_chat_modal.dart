import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../constants.dart';
import '../../../services/api_service.dart';
class AiChatModal extends StatefulWidget {
  final Map<String, dynamic> rawStats;
  final String timeLabel;
  final String initialAiInsight;

  const AiChatModal({
    super.key,
    required this.rawStats,
    required this.timeLabel,
    required this.initialAiInsight,
  });

  @override
  State<AiChatModal> createState() => _AiChatModalState();
}

class _AiChatModalState extends State<AiChatModal> {
  static const Color kDarkBg = Color(0xFF0F0F11);
  static const Color kPremiumGold = Color(0xFFFFC107);
  static const Color kCardDark = Color(0xFF1C1C1E);
  static const Color kGlowPurple = Color(0xFF4A3080);

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;

  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _chatMessages = [
      {
        "role": "ai", 
        "text": "สวัสดีครับแอดมิน! นี่คือสรุปข้อมูลโครงการช่วง ${widget.timeLabel} ครับ:\n\n${widget.initialAiInsight}"
      }
    ];
    _initSpeech();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (val) => print('STT Error: $val'),
      onStatus: (val) => print('STT Status: $val'),
    );
    if (mounted) setState(() {});
  }

  void _listen() async {
    if (!_isListening && _speechEnabled) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (val) => setState(() => _chatController.text = val.recognizedWords),
        localeId: 'th_TH', 
      );
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage() async {
    String text = _chatController.text.trim();
    if (text.isEmpty) return;

    if (_isListening) {
      setState(() => _isListening = false);
      _speechToText.stop();
    }

    setState(() {
      _chatMessages.add({"role": "user", "text": text});
      _isChatLoading = true;
    });
    _chatController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/admin/ai-summary');
      final historyToSend = _chatMessages.where((msg) => msg['text'] != text).toList();

      final response = await ApiService.post(url, body: jsonEncode({
        "message": text, "stats": widget.rawStats, "history": historyToSend
      })).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chatMessages.add({"role": "ai", "text": data['reply'] ?? "ขออภัยประมวลผลไม่ได้"});
          _isChatLoading = false;
        });
      } else {
        throw Exception('API Error');
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({"role": "ai", "text": "⚠️ ขัดข้อง: เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ครับ"});
        _isChatLoading = false;
      });
    }
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: kCardDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: kPremiumGold, size: 20)), const SizedBox(width: 12), const Text("AI Assistant", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _chatMessages.length && _isChatLoading) {
                  return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 8.0, bottom: 20), child: Text("AI กำลังวิเคราะห์...", style: TextStyle(color: kPremiumGold, fontStyle: FontStyle.italic))));
                }
                final msg = _chatMessages[index];
                final isMe = msg['role'] == 'user';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMe ? kGlowPurple : kCardDark,
                      borderRadius: BorderRadius.circular(16).copyWith(bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16), bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16)),
                      border: isMe ? null : Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: Text(msg['text']!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 8),
            child: Container(
              decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _chatController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "ถาม AI...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14)), onSubmitted: (_) => _sendMessage())),
                  IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: kPremiumGold), onPressed: _listen),
                  IconButton(icon: const Icon(Icons.send, color: kPremiumGold), onPressed: _sendMessage)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}