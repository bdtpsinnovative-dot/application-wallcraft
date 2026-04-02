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

class FullDashboardScreen extends StatelessWidget {
  const FullDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sourceData = [const MapEntry('APP', 120), const MapEntry('IMPORT', 80)];
    final teamData = [const MapEntry('Team A', 45), const MapEntry('Team B', 30)];
    final personData = [const MapEntry('Somchai', 45), const MapEntry('Wichai', 38)];

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

// --- 📈 1. Trend Line Chart (Fix: getTitlesWidget) ---
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> getPastSevenDays() {
      return List.generate(7, (index) {
        DateTime date = DateTime.now().subtract(Duration(days: 6 - index));
        return DateFormat('dd/MM').format(date);
      });
    }

    final dateLabels = getPastSevenDays();

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text("แนวโน้มโครงการ (รายวัน)", 
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
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
                      reservedSize: 30, // เพิ่มพื้นที่ให้ตัวหนังสือ
                      interval: 1,
                      // ✅ ใช้ getTitlesWidget ตามมาตรฐาน
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < dateLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
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
                      reservedSize: 35,
                      // ✅ ใช้ getTitlesWidget คืนค่าเป็น Text Widget
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
                    spots: const [FlSpot(0, 10), FlSpot(1, 15), FlSpot(2, 12), FlSpot(3, 20), FlSpot(4, 35), FlSpot(5, 25), FlSpot(6, 40)],
                    isCurved: true,
                    color: const Color(0xFF3B82F6), 
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.1)),
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
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Text("ที่มาข้อมูล", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 25,
                sections: sourceData.map((item) {
                  final isApp = item.key.toUpperCase() == 'APP';
                  return PieChartSectionData(
                    color: isApp ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                    value: item.value.toDouble(),
                    title: '${(item.value / total * 100).round()}%',
                    radius: 30,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text("APP vs IMPORT", style: TextStyle(color: Colors.white30, fontSize: 9)),
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
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kCardDark, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Text("สัดส่วนทีม", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 25,
                sections: List.generate(teamData.length, (i) {
                  return PieChartSectionData(
                    color: chartColors[i % chartColors.length],
                    value: teamData[i].value.toDouble(),
                    title: '',
                    radius: 30,
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

// --- 📊 4. Person Bar Chart (Fix: getTitlesWidget) ---
class PersonBarChart extends StatelessWidget {
  final List<MapEntry<String, dynamic>> personData;
  const PersonBarChart({super.key, required this.personData});

  @override
  Widget build(BuildContext context) {
    final topPersons = personData.take(5).toList();
    return Container(
      height: 280,
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
                maxY: 60,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      // ✅ ใช้ getTitlesWidget คืนค่าเป็น Padding หุ้ม Text
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < topPersons.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              topPersons[index].key.substring(0, 3), 
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
                      // ✅ ใช้ getTitlesWidget
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
                        toY: topPersons[index].value.toDouble(), 
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