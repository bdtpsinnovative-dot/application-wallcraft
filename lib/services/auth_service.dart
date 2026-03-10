// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // ✅ ดึง AppConfig.refreshTokenUrl มาใช้

class AuthService {
  
  // ฟังก์ชันสำหรับ "ต่ออายุ Token"
  static Future<bool> tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    // ถ้าไม่มี Refresh Token (เช่น ไม่เคยล็อกอิน) ก็จบเลย
    if (refreshToken == null) return false; 

    print("🔄 กำลังพยายามต่ออายุ Token ผ่าน Backend...");

    try {
      final response = await http.post(
        AppConfig.refreshTokenUrl, // ✅ ยิงไปที่ /auth/refresh ใน Next.js ของพี่
        headers: {
          'Content-Type': 'application/json',
          // ❌ ไม่ต้องส่ง apikey แล้ว เพราะเราคุยกับ Server เราเอง!
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 🌟 ดักจับทั้ง 2 รูปแบบ เผื่อว่า Backend ของพี่ส่งแบบก้อน session หรือส่งตรงๆ
        final accessToken = data['session']?['access_token'] ?? data['access_token'];
        final newRefreshToken = data['session']?['refresh_token'] ?? data['refresh_token'];
        
        if (accessToken != null) {
          // ✅ บันทึก Token ชุดใหม่ลงเครื่อง (ทับของเก่า)
          await prefs.setString('auth_token', accessToken);
          
          // 🌟 สำคัญ: ต้องเก็บ Refresh Token ตัวใหม่ทับของเก่าเสมอ
          if (newRefreshToken != null) {
            await prefs.setString('refresh_token', newRefreshToken);
          }
          
          print("✅ ต่ออายุสำเร็จ! ลุยต่อได้");
          return true;
        }
      } else {
        print("❌ ต่ออายุไม่ผ่าน (Session อาจหมดอายุถาวร): ${response.body}");
        // เคลียร์ทิ้งเฉพาะตอนที่มั่นใจว่า Token เน่าจริงๆ
        if (response.statusCode == 400 || response.statusCode == 401) {
            await prefs.clear();
        }
      }
    } catch (e) {
      print("🔴 Error while refreshing token: $e");
    }
    
    return false; // ถ้ามาถึงตรงนี้แปลว่าล้มเหลว
  }
}