import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/api_service.dart';

// ✨ นำเข้า Widget ที่เราแยกไฟล์ออกมา
import 'widgets/summary_stat_card.dart';
import 'widgets/admin_charts.dart';
import 'widgets/admin_filter_modal.dart';
import 'widgets/ai_chat_modal.dart';

class AdminSummaryScreen extends StatefulWidget {
  const AdminSummaryScreen({super.key});

  @override
  State<AdminSummaryScreen> createState() => _AdminSummaryScreenState();
}

class _AdminSummaryScreenState extends State<AdminSummaryScreen> {
  static const Color kDarkBg = Color(0xFF0F0F11);
  static const Color kPremiumGold = Color(0xFFFFC107);
  static const Color kCardDark = Color(0xFF1C1C1E);
  static const Color kNeonPurple = Color(0xFFB52BFF);

  bool _isLoading = true;
  String? _errorMessage;

  String _currentFilter = 'all';
  String _selectedTeam = 'all';
  String _selectedPerson = 'all';
  String _selectedSource = 'all';
  String _selectedProjectType = 'all';
  String _selectedProductCategory = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _minAreaController = TextEditingController();
  final TextEditingController _maxAreaController = TextEditingController();

  bool _showTeamLeaderboard = true; 

  String _aiInsight = "กำลังวิเคราะห์ข้อมูล...";
  String _totalProjects = "0"; 
  String _totalCheckins = "0"; 
  String _totalArea = "0.00";
  String _importantCount = "0";
  String _timeLabel = "ทั้งหมด";
  
  List<String> _availableTeams = [];
  List<String> _availablePersons = [];
  List<dynamic> _projectTypes = []; 
  List<dynamic> _productCategories = []; 
  
  // 🎯 เปลี่ยน Type มารองรับ dynamic (เพราะ API จะส่งเป็น Object {count, area})
  List<MapEntry<String, dynamic>> _teamLeaderboard = [];
  List<MapEntry<String, dynamic>> _personLeaderboard = []; 
  List<MapEntry<String, dynamic>> _sourceLeaderboard = []; 

  Map<String, dynamic> _rawStats = {}; 

  @override
  void initState() {
    super.initState();
    _fetchSummaryData(); 
  }

  @override
  void dispose() {
    _minAreaController.dispose();
    _maxAreaController.dispose();
    super.dispose();
  }

  Future<void> _fetchSummaryData() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      String urlStr = '${AppConfig.baseUrl}/admin/ai-summary?filter=$_currentFilter'
          '&team=$_selectedTeam&person=$_selectedPerson&source=$_selectedSource'
          '&project_type_id=$_selectedProjectType&product_category_id=$_selectedProductCategory';
      
      if (_startDate != null) urlStr += '&start_date=${_startDate!.toIso8601String().split('T')[0]}';
      if (_endDate != null) urlStr += '&end_date=${_endDate!.toIso8601String().split('T')[0]}';
      if (_minAreaController.text.isNotEmpty) urlStr += '&min_area=${_minAreaController.text}';
      if (_maxAreaController.text.isNotEmpty) urlStr += '&max_area=${_maxAreaController.text}';

      final url = Uri.parse(urlStr);
      final response = await ApiService.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 🎯 ดึงข้อมูลแล้วเรียงตาม count
        Map<String, dynamic> teamsData = data['stats']['team_performance'] ?? {};
        var sortedTeams = teamsData.entries.toList()..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
        
        Map<String, dynamic> personsData = data['stats']['person_performance'] ?? {};
        var sortedPersons = personsData.entries.toList()..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
        
        Map<String, dynamic> sourceData = data['stats']['source_performance'] ?? {};
        var sortedSource = sourceData.entries.toList();

        if (mounted) {
          setState(() {
            _aiInsight = data['ai_insight'] ?? "ไม่พบข้อความสรุปจาก AI";
            _rawStats = data['stats']; 
            _totalProjects = _rawStats['total_orders'].toString(); 
            _totalCheckins = _rawStats['total_checkins']?.toString() ?? _totalProjects;
            
            double area = double.tryParse(_rawStats['total_area_sqm'].toString()) ?? 0;
            _totalArea = area > 1000 ? "${(area / 1000).toStringAsFixed(1)}K" : area.toStringAsFixed(0);
            
            _importantCount = _rawStats['important_count'].toString();
            _timeLabel = data['time_label'] ?? "ทั้งหมด";
            
            _teamLeaderboard = sortedTeams;
            _personLeaderboard = sortedPersons;
            _sourceLeaderboard = sortedSource; 
            
            _availableTeams = List<String>.from(data['available_teams'] ?? []);
            _availablePersons = List<String>.from(data['available_persons'] ?? []);
            _projectTypes = data['project_types'] ?? [];
            _productCategories = data['product_categories'] ?? [];
            
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      _handleError("ไม่สามารถโหลดข้อมูลได้ในขณะนี้");
    }
  }

  void _handleError(String msg) {
    if (mounted) setState(() { _errorMessage = msg; _isLoading = false; });
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminFilterModal(
        currentFilters: {
          'currentFilter': _currentFilter, 'selectedTeam': _selectedTeam, 'selectedPerson': _selectedPerson,
          'selectedSource': _selectedSource, 'selectedProjectType': _selectedProjectType,
          'selectedProductCategory': _selectedProductCategory, 'startDate': _startDate,
          'endDate': _endDate, 'minArea': _minAreaController.text, 'maxArea': _maxAreaController.text,
        },
        projectTypes: _projectTypes, productCategories: _productCategories,
        availableTeams: _availableTeams, availablePersons: _availablePersons,
        onApply: (newFilters) {
          setState(() {
            _currentFilter = newFilters['currentFilter']; _selectedTeam = newFilters['selectedTeam']; _selectedPerson = newFilters['selectedPerson'];
            _selectedSource = newFilters['selectedSource']; _selectedProjectType = newFilters['selectedProjectType'];
            _selectedProductCategory = newFilters['selectedProductCategory']; _startDate = newFilters['startDate'];
            _endDate = newFilters['endDate']; _minAreaController.text = newFilters['minArea']; _maxAreaController.text = newFilters['maxArea'];
          });
          _fetchSummaryData();
        },
      )
    );
  }

  void _openAiChatModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiChatModal(
        rawStats: _rawStats,
        timeLabel: _timeLabel,
        initialAiInsight: _aiInsight,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          Positioned(top: -50, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumGold.withOpacity(0.1)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent)))),
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
                          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.analytics_rounded, color: kPremiumGold, size: 28)),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text("รายงานสรุป", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text("Enterprise Insight", style: TextStyle(color: Colors.white54, fontSize: 13))],
                          ),
                        ],
                      ),
                      GestureDetector(onTap: _openFilterModal, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kCardDark, border: Border.all(color: kPremiumGold.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.tune_rounded, color: kPremiumGold, size: 22)))
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                    : _errorMessage != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          color: kPremiumGold, backgroundColor: kCardDark, onRefresh: _fetchSummaryData,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildAiInsightBanner(),
                              const SizedBox(height: 24),
                              Text("สถิติประจำช่วง: $_timeLabel", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Expanded(child: SummaryStatCard(title: "จำนวนโครงการ", value: _totalProjects, unit: "โครงการ", icon: Icons.business_center_rounded, color: Colors.blueAccent)),
                                  const SizedBox(width: 16),
                                  Expanded(child: SummaryStatCard(title: "พื้นที่รวม", value: _totalArea, unit: "ตร.ม.", icon: Icons.square_foot_rounded, color: Colors.orangeAccent)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: SummaryStatCard(title: "โครงการสำคัญ", value: _importantCount, unit: "โครงการ", icon: Icons.star_rounded, color: Colors.redAccent)),
                                  const SizedBox(width: 16),
                                  Expanded(child: SummaryStatCard(title: "เช็คอิน", value: _totalCheckins, unit: "ครั้ง", icon: Icons.location_on_rounded, color: Colors.greenAccent)),
                                ],
                              ),
                              const SizedBox(height: 24),

                              const TrendLineChart(),
                              const SizedBox(height: 16),
                              SourcePieChart(sourceData: _sourceLeaderboard),
                              const SizedBox(height: 16),
                              TeamPieChart(teamData: _teamLeaderboard),
                              const SizedBox(height: 16),
                              PersonBarChart(personData: _personLeaderboard),
                              const SizedBox(height: 30),

                              Container(
                                padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [Expanded(child: _buildTabButton("ตารางอันดับทีม", true)), Expanded(child: _buildTabButton("ตารางบุคคล", false))]),
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
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? kPremiumGold.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(text, style: TextStyle(color: isSelected ? kPremiumGold : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)))),
    );
  }

  Widget _buildAiInsightBanner() {
    return GestureDetector(
      onTap: _openAiChatModal,
      child: Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [kCardDark, kCardDark.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: kPremiumGold.withOpacity(0.4)), boxShadow: [BoxShadow(color: kPremiumGold.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: kPremiumGold, size: 24)),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("อ่านบทสรุปเชิงลึก", style: TextStyle(color: kPremiumGold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)), SizedBox(height: 4), Text("พร้อมพูดคุยถามข้อมูลกับ AI Assistant", style: TextStyle(color: Colors.white70, fontSize: 12))])),
            const Icon(Icons.arrow_forward_ios_rounded, color: kPremiumGold, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList() {
    List<MapEntry<String, dynamic>> dataList = _showTeamLeaderboard ? _teamLeaderboard : _personLeaderboard;
    if (dataList.isEmpty) return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("ไม่มีข้อมูล", style: TextStyle(color: Colors.white54))));
    
    return Container(
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: List.generate(dataList.length, (index) {
          final item = dataList[index];
          // 🎯 ดึงข้อมูลจาก API ที่เราแก้ใหม่
          final count = item.value['count']; 
          final area = (item.value['area'] as num).toStringAsFixed(1); 

          return ListTile(
            leading: Text("#${index + 1}", style: TextStyle(color: index == 0 ? kPremiumGold : Colors.grey[600], fontWeight: FontWeight.bold)),
            title: Text(item.key, style: const TextStyle(color: Colors.white, fontSize: 14)),
            // 🎯 แก้ไขให้แสดง 2 บรรทัด (จำนวนโครงการ และ ตร.ม.)
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("$count โครงการ", style: const TextStyle(color: kNeonPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("$area ตร.ม.", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _fetchSummaryData, style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: Colors.black), child: const Text("ลองใหม่"))
        ],
      ),
    );
  }
}