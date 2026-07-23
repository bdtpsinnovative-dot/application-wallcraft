import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; 

// --- Configuration & Theme ---
const Color kCardDark = Color(0xFF1C1C1E);
const Color kNeonPurple = Color(0xFFB52BFF);
const Color kBgDark = Color(0xFF000000);

final List<Color> chartColors = [
  const Color(0xFF3B82F6), const Color(0xFF10B981), 
  const Color(0xFFF59E0B), const Color(0xFF8B5CF6), 
  const Color(0xFFEF4444), const Color(0xFF64748B)
];

// หน้าจอสำหรับเทสต์ (ถ้ามีอยู่แล้วไม่ต้องลบจ้ะ)
class FullDashboardScreen extends StatelessWidget {
  const FullDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sourceData = [const MapEntry('APP', 120), const MapEntry('IMPORT', 80)];
    final teamData = [const MapEntry('Team A', {'count': 45, 'area': 100}), const MapEntry('Team B', {'count': 30, 'area': 50})];
    final personData = [const MapEntry('Somchai', {'count': 45, 'area': 100}), const MapEntry('Wichai', {'count': 38, 'area': 80})];

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        title: const Text("Project Analysis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TrendLineChart(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SourcePieChart(sourceData: sourceData)),
                const SizedBox(width: 16),
                Expanded(child: TeamPieChart(teamData: teamData)),
              ],
            ),
            const SizedBox(height: 16),
            PersonBarChart(personData: personData),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// --- 📈 1. Trend Line Chart ---
class TrendLineChart extends StatelessWidget {
  final List<dynamic>? trendData;
  const TrendLineChart({super.key, this.trendData});

  @override
  Widget build(BuildContext context) {
    List<String> dateLabels = [];
    List<FlSpot> spots = [];

    if (trendData != null && trendData!.isNotEmpty) {
      for (int i = 0; i < trendData!.length; i++) {
        final item = trendData![i];
        final date = item['date'] ?? '';
        final count = (item['count'] ?? 0).toDouble();
        dateLabels.add(date);
        spots.add(FlSpot(i.toDouble(), count));
      }
    } else {
      for (int index = 0; index < 7; index++) {
        DateTime date = DateTime.now().subtract(Duration(days: 6 - index));
        dateLabels.add(DateFormat('dd/MM').format(date));
        spots.add(FlSpot(index.toDouble(), 0));
      }
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text("แนวโน้มโครงการ (รายวัน)", 
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26, 
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < dateLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              dateLabels[index],
                              style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(), 
                          style: const TextStyle(color: Colors.white30, fontSize: 10)
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: const Color(0xFF3B82F6), 
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 🥧 2. Source Pie Chart ---
class SourcePieChart extends StatelessWidget {
  final List<MapEntry<String, dynamic>> sourceData;
  const SourcePieChart({super.key, required this.sourceData});

  @override
  Widget build(BuildContext context) {
    int total = sourceData.fold(0, (sum, item) => sum + (item.value as int));
    
    int appCount = 0;
    int importCount = 0;
    for (var item in sourceData) {
      if (item.key.toUpperCase() == 'APP') appCount = item.value as int;
      if (item.key.toUpperCase() == 'IMPORT') importCount = item.value as int;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardDark, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Text("ที่มาข้อมูล (APP vs IMPORT)", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 25,
                sections: sourceData.map((item) {
                  final isApp = item.key.toUpperCase() == 'APP';
                  return PieChartSectionData(
                    color: isApp ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                    value: item.value.toDouble(),
                    title: total > 0 ? '${(item.value / total * 100).round()}%' : '0%',
                    radius: 28,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ป้ายปุ่มสีแอป APP (น้ำเงิน)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 12, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 4),
                    Text("APP: $appCount งาน", style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // ป้ายปุ่มสี IMPORT (ส้มทอง)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.file_upload_rounded, size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text("IMPORT: $importCount งาน", style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 🥧 3. Team Pie Chart ---
class TeamPieChart extends StatelessWidget {
  final List<MapEntry<String, dynamic>> teamData;
  const TeamPieChart({super.key, required this.teamData});

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มีข้อมูลให้ซ่อนไปเลย
    if (teamData.isEmpty) return const SizedBox();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Text("สัดส่วนทีม", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // 🎯 ส่วนที่ 1: กราฟวงกลม
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 20,
                      sections: List.generate(teamData.length, (i) {
                        return PieChartSectionData(
                          color: chartColors[i % chartColors.length],
                          value: teamData[i].value['count'].toDouble(),
                          // ✅ เอาตัวเลขกลับมาโชว์ในวงกลม
                          title: '${teamData[i].value['count']}', 
                          radius: 35,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 🎯 ส่วนที่ 2: ป้ายบอกชื่อทีม (Legend) ด้านข้าง
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // โชว์สูงสุด 5 ทีมแรก เพื่อไม่ให้ล้นจอ
                    children: List.generate(
                      teamData.length > 5 ? 5 : teamData.length, 
                      (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8, 
                                height: 8, 
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle, 
                                  color: chartColors[index % chartColors.length]
                                )
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  teamData[index].key, 
                                  style: const TextStyle(color: Colors.white70, fontSize: 9), 
                                  overflow: TextOverflow.ellipsis
                                )
                              )
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- 📊 4. Person Bar Chart ---
class PersonBarChart extends StatelessWidget {
  final List<MapEntry<String, dynamic>> personData;
  const PersonBarChart({super.key, required this.personData});

  @override
  Widget build(BuildContext context) {
    // ดึงมาแค่ 5 คนแรก
    final topPersons = personData.take(5).toList();
    
    // คำนวณความสูงของกราฟแกน Y
    double maxY = topPersons.isNotEmpty ? topPersons.first.value['count'].toDouble() * 1.1 : 10;
    if (maxY < 5) maxY = 5; // ล็อกเป้าขั้นต่ำกันกราฟยาวเว่อร์

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top 5 Performance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < topPersons.length) {
                          // ป้องกัน Error กรณีชื่อพนักงานสั้นกว่า 3 ตัวอักษร
                          String name = topPersons[index].key;
                          String shortName = name.length > 3 ? name.substring(0, 3) : name;
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              shortName, 
                              style: const TextStyle(color: Colors.white30, fontSize: 10)
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(), 
                          style: const TextStyle(color: Colors.white10, fontSize: 10)
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(topPersons.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: topPersons[index].value['count'].toDouble(), 
                        color: kNeonPurple,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}