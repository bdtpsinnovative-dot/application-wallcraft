// lib/screens/tracking/package_tracking_page.dart
import 'package:flutter/material.dart';

class PackageTrackingPage extends StatelessWidget {
  const PackageTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kDarkBg = Color(0xFF0F0F11);
    const Color kCardDark = Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text("Package Tracking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ช่องค้นหาจำลอง
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter Tracking Number...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: kCardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Deliveries", style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            // รายการพัสดุจำลอง
            Expanded(
              child: ListView(
                children: [
                  _buildTrackingCard(context, "TH-8890123", "In Transit", Icons.local_shipping, Colors.blueAccent),
                  _buildTrackingCard(context, "TH-8890124", "Delivered", Icons.check_circle, Colors.green),
                  _buildTrackingCard(context, "TH-8890125", "Pending Pickup", Icons.inventory, Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard(BuildContext context, String trackNumber, String status, IconData icon, Color statusColor) {
    return Card(
      color: const Color(0xFF1C1C1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          // โค้ดส่วนนี้ทำให้กดโต้ตอบได้จ้ะ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checking details for $trackNumber...'),
              backgroundColor: const Color(0xFF4A3080),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: statusColor),
        ),
        title: Text(trackNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text("Status: $status", style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
      ),
    );
  }
}