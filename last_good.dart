    final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: day - 1));
    return start.isAtSameMomentAs(currentMonday);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        title: const Text("แผนการเข้าพบลูกค้า (12 สัปดาห์)", style: TextStyle(color: Colors.white, fontSize: 18)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchVisitPlans,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kLimeGreen))
          : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              itemCount: _weeks.length,
              itemBuilder: (context, index) {
                final weekStart = _weeks[index];
                final isCurrent = _isCurrentWeek(weekStart);
                
                // Get plans for this week
                final endOfWeek = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
                final weekPlans = _visitPlans.where((p) {
                  if (p['planned_date'] == null) return false;
                  final planDate = DateTime.parse(p['planned_date']);
                  return planDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && planDate.isBefore(endOfWeek);
                }).toList();

                return Container(
                  width: MediaQuery.of(context).size.width * 0.88, 
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: kCardDark,
                    border: Border.all(color: isCurrent ? kLimeGreen : Colors.white12, width: isCurrent ? 2 : 1),
                    borderRadius: BorderRadius.circular(12), // ปรับให้ขอบมนเข้ากับดีไซน์รวมของแอป
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent ? kLimeGreen.withOpacity(0.1) : Colors.black26,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatWeekRange(weekStart),
                              style: TextStyle(
                                color: isCurrent ? kLimeGreen : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: kLimeGreen,
                                child: const Text("สัปดาห์นี้", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: weekPlans.length,
                          itemBuilder: (context, i) {
                            final plan = weekPlans[i];
                            final compName = plan['companies']?['name'] ?? 'Unknown Company';
                            final projName = plan['projects']?['project_name'];
                            
                            return InkWell(
                              onTap: () {
                                _showEditModal(plan);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  border: Border.all(color: Colors.white12),
                                  borderRadius: BorderRadius.circular(8), // ขอบมนสำหรับ item ด้านใน
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            compName,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(plan['status']?.toString()),
                                      ],
                                    ),
                                    if (plan['project_concept'] != null && plan['project_concept'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        plan['project_concept'], 
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        maxLines: 1, // แสดงบรรทัดเดียว
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      InkWell(
                        onTap: () => _showAddModal(weekStart),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white54, size: 18),
                              SizedBox(width: 8),
                              Text("เพิ่มแผนเข้าพบ", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

