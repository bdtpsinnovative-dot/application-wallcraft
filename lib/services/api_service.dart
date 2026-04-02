// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // 👈 อย่าลืมเช็คว่า AppConfig อยู่ในไฟล์ไหนนะครับ
import 'auth_service.dart'; 

class ApiService {
  
  // ฟังก์ชันสำหรับใส่ Token เข้าไปใน Header อัตโนมัติ
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================================================
  // 🔔 [NEW] ฟังก์ชันส่ง FCM Token ไปอัปเดตที่เซิร์ฟเวอร์
  // ==================================================
  static Future<void> updateFcmToken(String fcmToken) async {
    // 🚩 เปลี่ยน URL ให้ตรงกับที่นายตั้งใน Next.js นะครับ
    final url = Uri.parse('${AppConfig.baseUrl}/profile/fcm'); 
    
    // เราใช้ patch() ที่เราเขียนไว้ด้านล่าง เพราะมันมีระบบจัดการ Token 401 ให้แล้ว
    final response = await patch(
      url, 
      body: jsonEncode({'fcm_token': fcmToken})
    );

    if (response.statusCode == 200) {
      print("🚀 [ApiService] อัปเดต FCM Token สำเร็จ");
    } else {
      print("❌ [ApiService] อัปเดต FCM Token พลาด: ${response.statusCode}");
      throw Exception('Failed to update FCM Token');
    }
  }

  // ==================================================
  // 🟢 GET Method
  // ==================================================
  static Future<http.Response> get(Uri uri) async {
    var headers = await _getHeaders();
    var response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (GET)! กำลังพยายามต่ออายุ...");
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.get(uri, headers: headers);
      }
    }
    return response;
  }

  // ==================================================
  // 🟡 POST Method
  // ==================================================
  static Future<http.Response> post(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (POST)! กำลังพยายามต่ออายุ...");
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.post(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  // ==================================================
  // 🟠 PUT Method
  // ==================================================
  static Future<http.Response> put(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.put(uri, headers: headers, body: body);

    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (PUT)! กำลังพยายามต่ออายุ...");
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.put(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  // ==================================================
  // 🟣 PATCH Method 
  // ==================================================
  static Future<http.Response> patch(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.patch(uri, headers: headers, body: body);

    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (PATCH)! กำลังพยายามต่ออายุ...");
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.patch(uri, headers: headers, body: body);
      }
    }
    return response;
  }
}