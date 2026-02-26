// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
        print("🔄 ยิง Request ซ้ำอีกรอบ...");
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
        print("🔄 ยิง Request ซ้ำอีกรอบ...");
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
    
    // 1. ยิงรอบแรก
    var response = await http.put(uri, headers: headers, body: body);

    // 2. ถ้าเจอ 401
    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (PUT)! กำลังพยายามต่ออายุ...");
      
      bool refreshed = await AuthService.tryRefreshToken();
      
      if (refreshed) {
        headers = await _getHeaders();
        print("🔄 ยิง Request (PUT) ซ้ำอีกรอบ...");
        
        // 3. ยิงซ้ำ
        response = await http.put(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  // ==================================================
  // 🟣 PATCH Method (เพิ่มเข้ามาให้อยู่ในคลาสอย่างถูกต้อง)
  // ==================================================
  static Future<http.Response> patch(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    
    // 1. ยิงรอบแรก
    var response = await http.patch(uri, headers: headers, body: body);

    // 2. ถ้าเจอ 401 (Token หมดอายุ)
    if (response.statusCode == 401) {
      print("⚠️ Token หมดอายุ (PATCH)! กำลังพยายามต่ออายุ...");
      
      bool refreshed = await AuthService.tryRefreshToken();
      
      if (refreshed) {
        headers = await _getHeaders();
        print("🔄 ยิง Request (PATCH) ซ้ำอีกรอบ...");
        
        // 3. ยิงซ้ำ
        response = await http.patch(uri, headers: headers, body: body);
      }
    }
    return response;
  }
} // ✅ ปิดคลาส ApiService ตรงนี้ครับ