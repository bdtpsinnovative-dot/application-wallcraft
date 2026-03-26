import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

class AdminSummaryScreen extends StatefulWidget {
  const AdminSummaryScreen({super.key});

  @override
  State<AdminSummaryScreen> createState() => _AdminSummaryScreenState();
}

class _AdminSummaryScreenState extends State<AdminSummaryScreen> {
  static const Color kDarkBg = Color(0xFF0F0F11);
  static const Color kPremiumGold = Color(0xFFFFC107);
  static const Color kCardDark = Color(0xFF1C1C1E);
  static const Color kGlowPurple = Color(0xFF4A3080);
  static const Color kNeonPurple = Color(0xFFB52BFF);

  bool _isLoading = true;
  String? _errorMessage;

  // 🌟 ตัวแปรสำหรับการกรองข้อมูล
  String _currentFilter = 'all';
  String _selectedTeam = 'all';
  String _selectedPerson = 'all';
  bool _showTeamLeaderboard = true; // สลับดูทีม/คน

  String _aiInsight = "กำลังวิเคราะห์ข้อมูล...";
  String _totalOrders = "0";
  String _totalArea = "0.00";
  String _importantCount = "0";
  String _timeLabel = "ทั้งหมด";
  
  List<String> _availableTeams = [];
  List<String> _availablePersons = [];
  List<MapEntry<String, dynamic>> _teamLeaderboard = [];
  List<MapEntry<String, dynamic>> _personLeaderboard = []; 
  Map<String, dynamic> _rawStats = {}; 

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSummaryData(); 
  }

  Future<void> _fetchSummaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 🌟 ส่งค่า Filter ทั้ง 3 ตัวไปหา API
      final url = Uri.parse('${AppConfig.baseUrl}/admin/ai-summary?filter=$_currentFilter&team=$_selectedTeam&person=$_selectedPerson');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        Map<String, dynamic> teamsData = data['stats']['team_performance'] ?? {};
        var sortedTeams = teamsData.entries.toList()..sort((a, b) => (b.value as int).compareTo(a.value as int));

        Map<String, dynamic> personsData = data['stats']['person_performance'] ?? {};
        var sortedPersons = personsData.entries.toList()..sort((a, b) => (b.value as int).compareTo(a.value as int));

        if (mounted) {
          setState(() {
            _aiInsight = data['ai_insight'] ?? "ไม่พบข้อความสรุปจาก AI";
            _rawStats = data['stats']; 
            _totalOrders = _rawStats['total_orders'].toString();
            
            double area = double.tryParse(_rawStats['total_area_sqm'].toString()) ?? 0;
            _totalArea = area > 1000 ? "${(area / 1000).toStringAsFixed(1)}K" : area.toStringAsFixed(0);
            
            _importantCount = _rawStats['important_count'].toString();
            _timeLabel = data['time_label'] ?? "ทั้งหมด";
            
            _teamLeaderboard = sortedTeams;
            _personLeaderboard = sortedPersons;
            _availableTeams = List<String>.from(data['available_teams'] ?? []);
            _availablePersons = List<String>.from(data['available_persons'] ?? []);
            
            _chatMessages = [
              {
                "role": "ai", 
                "text": "สวัสดีครับแอดมิน! นี่คือสรุปข้อมูลช่วง $_timeLabel ครับ:\n\n$_aiInsight\n\nมีอะไรให้ผมช่วยเจาะลึกข้อมูลเพิ่มเติมไหมครับ?"
              }
            ];
            
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้");
    }
  }

  void _handleError(String msg) {
    if (mounted) setState(() { _errorMessage = msg; _isLoading = false; });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _sendMessage(StateSetter setModalState) async {
    String text = _chatController.text.trim();
    if (text.isEmpty) return;

    setModalState(() {
      _chatMessages.add({"role": "user", "text": text});
      _isChatLoading = true;
    });
    _chatController.clear();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/admin/ai-summary');
      final historyToSend = _chatMessages.where((msg) => msg['text'] != text).toList();

      final response = await ApiService.post(url, body: jsonEncode({
        "message": text, "stats": _rawStats, "history": historyToSend
      })).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setModalState(() {
          _chatMessages.add({"role": "ai", "text": data['reply'] ?? "ขออภัยครับ ไม่สามารถประมวลผลคำตอบได้"});
          _isChatLoading = false;
        });
      } else {
        throw Exception('API Error');
      }
    } catch (e) {
      setModalState(() {
        _chatMessages.add({"role": "ai", "text": "⚠️ ขัดข้อง: เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ครับ"});
        _isChatLoading = false;
      });
    }
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

// ⚙️ ฟังก์ชันเปิด Modal เลือก Filter (แก้ไขปัญหา Overflow แล้วครับนาย!)
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🌟 เปิดตัวนี้เพื่อให้ Modal ยืดหยุ่นขึ้น
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              // 🌟 เพิ่มการคำนวณ padding เผื่อคีย์บอร์ด หรือหน้าจอที่สั้น
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: kCardDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView( // 🌟 ห่อด้วยตัวนี้เพื่อให้เลื่อนได้ ลายเหลืองดำจะหายไปครับ
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ให้ Column ขนาดเท่ากับเนื้อหา
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ตัวกรองข้อมูล", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // Dropdown ช่วงเวลา
                    const Text("ช่วงเวลา", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildModalDropdown(
                      ["all", "daily", "weekly", "monthly"], 
                      ["ทั้งหมด", "วันนี้", "สัปดาห์นี้", "เดือนนี้"], 
                      _currentFilter, 
                      (val) => setModalState(() => _currentFilter = val!)
                    ),
                    const SizedBox(height: 16),

                    // Dropdown เลือกทีม
                    const Text("เฉพาะทีม", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildModalDropdown(
                      ['all', ..._availableTeams], 
                      ['ทุกทีม', ..._availableTeams], 
                      _selectedTeam, 
                      (val) => setModalState(() { _selectedTeam = val!; _selectedPerson = 'all'; })
                    ),
                    const SizedBox(height: 16),

                    // Dropdown เลือกบุคคล
                    const Text("เฉพาะบุคคล", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildModalDropdown(
                      ['all', ..._availablePersons], 
                      ['ทุกคน', ..._availablePersons], 
                      _selectedPerson, 
                      (val) => setModalState(() { _selectedPerson = val!; _selectedTeam = 'all'; })
                    ),
                    const SizedBox(height: 24),

                    // ปุ่มนำไปใช้ (จะกลับมาสวยงาม ไม่โดนทับแล้วครับ)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPremiumGold, 
                          padding: const EdgeInsets.symmetric(vertical: 16), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _fetchSummaryData();
                        },
                        child: const Text("นำไปใช้", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildModalDropdown(List<String> values, List<String> displays, String currentValue, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: kDarkBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          dropdownColor: kDarkBg,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
          items: List.generate(values.length, (index) {
            return DropdownMenuItem(
              value: values[index],
              child: Text(displays[index], style: const TextStyle(color: Colors.white, fontSize: 14)),
            );
          }),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumGold.withOpacity(0.1)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                            child: const Icon(Icons.analytics_rounded, color: kPremiumGold, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("รายงานสรุป", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              Text("ภาพรวมระบบทั้งหมดโดย AI", style: TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      // 🌟 ปุ่ม Filter รวมที่นายขอครับ!
                      GestureDetector(
                        onTap: _showFilterModal,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kCardDark, border: Border.all(color: kPremiumGold.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.tune_rounded, color: kPremiumGold, size: 22),
                        ),
                      )
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                    : _errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          color: kPremiumGold,
                          backgroundColor: kCardDark,
                          onRefresh: _fetchSummaryData,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildAiInsightBanner(),
                              const SizedBox(height: 24),
                              
                              Text("สถิติ: $_timeLabel", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildStatCard("ออเดอร์", _totalOrders, "รายการ", Icons.receipt_long_rounded, Colors.blueAccent)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildStatCard("พื้นที่รวม", _totalArea, "ตร.ม.", Icons.square_foot_rounded, Colors.orangeAccent)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildStatCard("งานสำคัญ", _importantCount, "งาน", Icons.star_rounded, Colors.redAccent)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildStatCard("ยอดเข้างาน", _totalOrders, "ครั้ง", Icons.groups_rounded, Colors.greenAccent)),
                                ],
                              ),
                              const SizedBox(height: 30),

                              // 🌟 ปุ่มสลับดู ทีม / บุคคล แบบคลีนๆ
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    Expanded(child: _buildTabButton("ผลงานรายทีม", true)),
                                    Expanded(child: _buildTabButton("ผลงานรายบุคคล", false)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLeaderboardList(),
                              const SizedBox(height: 40),
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

  Widget _buildTabButton(String text, bool isTeamTab) {
    bool isSelected = _showTeamLeaderboard == isTeamTab;
    return GestureDetector(
      onTap: () => setState(() => _showTeamLeaderboard = isTeamTab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: isSelected ? kPremiumGold.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(text, style: TextStyle(color: isSelected ? kPremiumGold : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
    );
  }

  Widget _buildAiInsightBanner() {
    return GestureDetector(
      onTap: _showAiChatModal,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kCardDark, kCardDark.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPremiumGold.withOpacity(0.5), width: 1),
          boxShadow: [BoxShadow(color: kPremiumGold.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: kPremiumGold, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("อ่านบทสรุปเชิงลึก", style: TextStyle(color: kPremiumGold.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  const Text("พร้อมพูดคุยถามข้อมูลกับ AI Assistant", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chat_bubble_rounded, color: kPremiumGold, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    List<MapEntry<String, dynamic>> dataList = _showTeamLeaderboard ? _teamLeaderboard : _personLeaderboard;
    if (dataList.isEmpty) return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("ไม่มีข้อมูลแสดงผล", style: TextStyle(color: Colors.white54))));
    return Container(
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: List.generate(dataList.length, (index) {
          final item = dataList[index];
          final isLast = index == dataList.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text("#${index + 1}", style: TextStyle(color: index == 0 ? kPremiumGold : Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Expanded(child: Text(item.key, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                    Text("${item.value} งาน", style: const TextStyle(color: kNeonPurple, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (!isLast) Divider(color: Colors.white.withOpacity(0.05), height: 1),
            ],
          );
        }),
      ),
    );
  }

  void _showAiChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: kDarkBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: kCardDark,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.auto_awesome_rounded, color: kPremiumGold, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text("AI Assistant", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(context))
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
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(top: 8.0, bottom: 20),
                              child: Text("AI กำลังวิเคราะห์...", style: TextStyle(color: kPremiumGold, fontStyle: FontStyle.italic)),
                            ),
                          );
                        }
                        final msg = _chatMessages[index];
                        final isMe = msg['role'] == 'user';
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe ? kGlowPurple : kCardDark,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                              ),
                              border: isMe ? null : Border.all(color: kPremiumGold.withOpacity(0.3)),
                            ),
                            child: Text(msg['text']!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16, 
                      left: 16, right: 16, top: 8
                    ),
                    child: Container(
                      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "พิมพ์ถามข้อมูลเพิ่มเติม...", hintStyle: TextStyle(color: Colors.white30),
                                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              onSubmitted: (_) => _sendMessage(setModalState),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _sendMessage(setModalState),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(color: kPremiumGold, shape: BoxShape.circle),
                              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchSummaryData, 
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('ลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: Colors.black),
          )
        ],
      ),
    );
  }
}