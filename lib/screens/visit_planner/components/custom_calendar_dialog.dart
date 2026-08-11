import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

const Color kLimeGreen = Color(0xFFD2E862);
const Color kDarkBg = Color(0xFF0F0F11);

class CustomCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final List<dynamic> allPlans;

  const CustomCalendarDialog({
    super.key,
    required this.initialDate,
    required this.allPlans,
  });

  @override
  State<CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<CustomCalendarDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<dynamic>> _eventsMap;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
    _eventsMap = _groupPlansByDate(widget.allPlans);
  }

  Map<DateTime, List<dynamic>> _groupPlansByDate(List<dynamic> plans) {
    Map<DateTime, List<dynamic>> map = {};
    for (var plan in plans) {
      if (plan['planned_date'] != null) {
        DateTime dt = DateTime.parse(plan['planned_date']);
        // Normalize to day level
        DateTime normalizedDate = DateTime(dt.year, dt.month, dt.day);
        if (map[normalizedDate] == null) map[normalizedDate] = [];
        map[normalizedDate]!.add(plan);
      }
    }
    return map;
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    DateTime normalizedDate = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDate] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: kDarkBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("เลือกวันที่เข้าพบ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Colors.white54),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.white54),
                outsideTextStyle: const TextStyle(color: Colors.white24),
                todayDecoration: BoxDecoration(
                  color: kLimeGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold),
                selectedDecoration: const BoxDecoration(
                  color: kLimeGreen,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                markersMaxCount: 1,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      bottom: 8,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: kLimeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            _buildSelectedDayEvents(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedDay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLimeGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("ยืนยัน", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSelectedDayEvents() {
    final events = _getEventsForDay(_selectedDay);
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("ไม่มีแผนงานในวันนี้", style: TextStyle(color: Colors.white54, fontSize: 12)),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: Text("แผนงานในวันนี้:", style: TextStyle(color: kLimeGreen, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: events.map<Widget>((ev) {
                  final companyName = ev['companies']?['name'] ?? 'ไม่มีชื่อบริษัท';
                  final projectName = ev['projects']?['project_name'] ?? '-';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Icon(Icons.circle, color: kLimeGreen, size: 6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(companyName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(projectName, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
