// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // ✅ Import ไฟล์ constants ที่เราเพิ่งแก้

class AuthService {
  
  // ฟังก์ชันสำหรับ "ต่ออายุ Token"
  static Future<bool> tryRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    // ถ้าไม่มี Refresh Token (เช่น ไม่เคยล็อกอิน) ก็จบเลย
    if (refreshToken == null) return false; 

    print("🔄 กำลังพยายามต่ออายุ Token...");

    try {
      final response = await http.post(
        AppConfig.refreshTokenUrl, // ✅ เรียกใช้ URL จาก constants
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['session'] != null) {
          // ✅ บันทึก Token ชุดใหม่ลงเครื่อง (ทับของเก่า)
          await prefs.setString('auth_token', data['session']['access_token']);
          
          // สำคัญ: Supabase จะหมุนเวียน Refresh Token ด้วย ต้องเก็บตัวใหม่เสมอ
          if (data['session']['refresh_token'] != null) {
            await prefs.setString('refresh_token', data['session']['refresh_token']);
          }
          
          print("✅ ต่ออายุสำเร็จ! ลุยต่อได้");
          return true;
        }
      } else {
        print("❌ ต่ออายุไม่ผ่าน (Session อาจหมดอายุถาวร): ${response.body}");
        // ตรงนี้อาจจะสั่งให้ Logout หรือเด้งไปหน้า Login
        await prefs.clear();
      }
    } catch (e) {
      print("🔴 Error while refreshing token: $e");
    }
    
    return false; // ถ้ามาถึงตรงนี้แปลว่าล้มเหลว
  }
}