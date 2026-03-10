import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:math' as math;
import '../../../../constants.dart';
import '../../../../services/api_service.dart'; 

class VoiceSessionPage extends StatefulWidget {
  const VoiceSessionPage({super.key});

  @override
  State<VoiceSessionPage> createState() => _VoiceSessionPageState();
}

class _VoiceSessionPageState extends State<VoiceSessionPage> with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late AnimationController _animationController;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isThinking = false;
  bool _showTextLog = false;
  
  // ✅ ตัวแปรเก็บรหัสประจำเครื่อง
  String _currentUserId = "";

  // สถานะไมค์
  String _micStatus = "พร้อมคุย"; 
  String _currentWords = ""; 
  String _aiResponseText = "แตะไมค์เพื่อเริ่มคุยได้เลยครับ"; 

  final List<String> _chatHistory = [];
  Timer? _silenceTimer; 

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initUserId(); // ✅ เรียกใช้ฟังก์ชันสร้าง/ดึง ID ประจำเครื่อง
    _initSpeech();
    _initTts();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _animationController.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  // ✅ ฟังก์ชันใหม่: จัดการสร้างและจำ User ID ไว้ในเครื่อง
  Future<void> _initUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('user_id');

    // ถ้าไม่มีรหัส หรือเป็นคำว่า guest เฉยๆ ให้สร้างใหม่ให้ไม่ซ้ำกัน
    if (savedId == null || savedId == 'guest') {
      savedId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
      await prefs.setString('user_id', savedId);
    }
    
    setState(() {
      _currentUserId = savedId!;
    });
    debugPrint("🟢 ใช้งาน User ID: $_currentUserId");
  }

  void _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
             if (!_isThinking && _isListening && mounted) {
                // จัดการผ่าน Timer แทน
             }
          }
        },
        onError: (val) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _micStatus = "Error: ${val.errorMsg}";
            });
          }
        },
      );
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  void _initTts() async {
    await _flutterTts.setLanguage("th-TH");
    await _flutterTts.setPitch(0.7); 
    await _flutterTts.setSpeechRate(0.6);

    try {
      var voices = await _flutterTts.getVoices;
      List<dynamic> thaiVoices = voices.where((v) => v['locale'] == 'th-TH').toList();
      
      for (var voice in thaiVoices) {
        if (voice['name'].toString().toLowerCase().contains('male')) {
          await _flutterTts.setVoice({"name": voice["name"], "locale": "th-TH"});
          break; 
        }
      }
    } catch (e) {
      debugPrint("หาเสียงผู้ชายไม่เจอ ใช้เสียง default แทน");
    }

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _stopAIVoice() async {
    await _flutterTts.stop(); 
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _micStatus = "หยุดเสียงแล้ว";
      });
    }
  }

  void _startListening() async {
    if (_isSpeaking) await _flutterTts.stop();
    _silenceTimer?.cancel(); 

    setState(() {
      _isListening = true;
      _currentWords = ""; 
      _micStatus = "กำลังฟัง...";
    });

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _currentWords = val.recognizedWords;
        });

        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 2500), () {
          if (_isListening) {
            _stopListeningAndSend();
          }
        });
      },
      localeId: 'th_TH', 
      cancelOnError: false,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      pauseFor: const Duration(seconds: 5), 
    );
  }

  void _stopListeningAndSend() async {
    _silenceTimer?.cancel();
    await _speech.stop();
    setState(() => _isListening = false);

    if (_currentWords.trim().isNotEmpty) {
      _sendToAI(_currentWords);
    } else {
      setState(() => _micStatus = "ไม่ได้ยินเสียง (ลองใหม่)");
    }
  }

  Future<void> _sendToAI(String userMessage) async {
    setState(() {
      _isThinking = true;
      _micStatus = "กำลังคิด...";
    });

    try {
      // ✅ ส่งไปแค่ ID ประจำเครื่อง และ คำถามล่าสุด ไม่ต้องต่อ String ประวัติแล้ว
      final response = await ApiService.post(
        AppConfig.chatUrl, 
        body: jsonEncode({
          "userId": _currentUserId, // ✅ ใช้ ID ประจำเครื่องที่เราสร้างไว้
          "message": userMessage    // ✅ ส่งคำถามเพียวๆ
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiReply = data['ai_reply'] ?? data['reply'] ?? "ขออภัย ระบบตอบกลับผิดพลาด";

        if (mounted) {
          setState(() {
            _aiResponseText = aiReply;
            _chatHistory.add("ลูกค้า: $userMessage");
            _chatHistory.add("AI: $aiReply");
            _isThinking = false;
            _micStatus = "ตอบกลับแล้ว";
          });
        }
        _flutterTts.speak(aiReply);
      } else {
        setState(() {
          _isThinking = false;
          _micStatus = "Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isThinking = false;
        _micStatus = "Connect Error";
      });
      debugPrint("API Error: $e");
    }
  }

  // ✅ ลบฟังก์ชัน _buildPromptWithHistory ออกไปเลย เพราะไม่ได้ใช้แล้วครับ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("WallCraft AI", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_showTextLog ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
            onPressed: () => setState(() => _showTextLog = !_showTextLog),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 20, left: 0, right: 0,
            child: Text(
              "สถานะ: $_micStatus",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),

          Positioned.fill(
            bottom: 150,
            child: Center(
              child: _showTextLog ? _buildTextLogView() : _buildAnimationView(),
            ),
          ),

          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Column(
              children: [
                if (_isThinking) const Text("AI กำลังคิด...", style: TextStyle(color: Colors.cyanAccent)),
                
                if (_isListening) 
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20),
                     child: Text(
                       _currentWords.isEmpty ? "กำลังฟัง..." : "$_currentWords", 
                       textAlign: TextAlign.center,
                       style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   
                const SizedBox(height: 10),

                AnimatedOpacity(
                  opacity: _isSpeaking ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _isSpeaking 
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: _stopAIVoice,
                          icon: const Icon(Icons.volume_off_rounded, color: Colors.redAccent, size: 18),
                          label: const Text("หยุดเสียง AI", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            backgroundColor: Colors.redAccent.withOpacity(0.05),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ) 
                    : const SizedBox(height: 38), 
                ),
                
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListeningAndSend(); 
                    } else {
                      _startListening(); 
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isListening ? 90 : 80,
                    width: _isListening ? 90 : 80,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.6),
                          blurRadius: _isListening ? 30 : 15,
                        )
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic, 
                      color: Colors.white,
                      size: _isListening ? 45 : 40,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _isListening ? "แตะเพื่อส่ง" : "แตะเพื่อเริ่มคุย", 
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(), 
      padding: const EdgeInsets.symmetric(vertical: 20), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSpeaking)
            CustomPaint(
              painter: PulseWavePainter(_animationController),
              child: Container(
                width: 200, height: 200,
                alignment: Alignment.center,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purpleAccent.withOpacity(0.2),
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: const Icon(Icons.graphic_eq, color: Colors.white, size: 50),
                ),
              ),
            )
          else if (_isThinking)
             const SizedBox(
               width: 80, height: 80,
               child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 6),
             )
          else
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.1),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.headset_mic, color: Colors.white54, size: 60),
            ),
            
          const SizedBox(height: 40),
  
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _isThinking ? 0.0 : 1.0,
              child: Text(
                _aiResponseText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70, 
                  fontSize: 16, 
                  height: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextLogView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        _chatHistory.join('\n\n'), // ✅ เปลี่ยนให้แสดงประวัติแชททั้งหมดในหน้า Log ได้ถูกต้อง
        textAlign: TextAlign.left,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

class PulseWavePainter extends CustomPainter {
  final Animation<double> _animation;
  PulseWavePainter(this._animation) : super(repaint: _animation);
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0;
    for (int i = 0; i < 3; i++) {
      double progress = (_animation.value + (i * 0.33)) % 1.0;
      paint.color = Colors.cyanAccent.withOpacity(1.0 - progress);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), progress * (size.width / 2), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}