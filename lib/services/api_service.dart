import 'dart:convert';
import 'dart:io'; // 👈 เพิ่มตัวนี้เพื่อเช็ค Platform.isAndroid
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; 
import 'auth_service.dart'; 

class ApiService {
  
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================================================
  // 🔔 ให้ Flutter ยิงกลับไปที่ API Next.js ตามเดิมครับ
  // ==================================================
  static Future<void> updateFcmToken(String fcmToken) async {
    try {
      // 🚩 กลับไปใช้ baseUrl เพื่อวิ่งเข้า Next.js ครับ
      final url = Uri.parse('${AppConfig.baseUrl}/profile/fcm');
      
      final response = await patch(
        url, 
        body: jsonEncode({
          'fcm_token': fcmToken,
          // ส่ง device_type ไปด้วย เผื่อในอนาคต Next.js อยากใช้
          'device_type': Platform.isAndroid ? 'android' : 'ios', 
        })
      );

      if (response.statusCode == 200) {
        print("🚀 [ApiService] อัปเดต FCM Token ผ่าน API สำเร็จ!");
      } else {
        print("❌ [ApiService] อัปเดต FCM Token พลาด: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ [ApiService] Error: $e");
    }
  }

  // --- Method อื่นๆ (get, post, put, patch) คงเดิมไว้ครับ ---
  
  static Future<http.Response> get(Uri uri) async {
    var headers = await _getHeaders();
    var response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.get(uri, headers: headers);
      }
    }
    return response;
  }

  static Future<http.Response> post(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.post(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  static Future<http.Response> patch(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.patch(uri, headers: headers, body: body);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.patch(uri, headers: headers, body: body);
      }
    }
    return response;
  }
}