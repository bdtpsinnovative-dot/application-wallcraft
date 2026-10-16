import 'package:flutter/material.dart';

Widget buildInAppDocView(String url) {
  return Container(
    color: const Color(0xFF161618),
    alignment: Alignment.center,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.description_rounded, color: Colors.white38, size: 48),
        SizedBox(height: 12),
        Text(
          'เปิดเอกสารผ่าน In-App Browser',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );
}

void downloadFileWeb(String url, String filename) {}
