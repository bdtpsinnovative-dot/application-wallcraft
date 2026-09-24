// lib/constants.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// URL สำหรับ Production หลักของระบบ
  static const String productionBaseUrl = 'https://www.wallcraftthailand.com/api/v1';

  /// ตัวแปรบันทึกสถานะว่ามีการสลับ Gateway ฉุกเฉินไปยัง Production แล้วหรือยัง
  static bool _hasSwitchedToProduction = false;

  /// ตรวจสอบว่าเป็น Local / Private IP หรือไม่
  static bool isLocalAddress(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('192.168.') ||
        lower.contains('10.') ||
        lower.contains('172.');
  }

  static bool isLocalUrl(Uri uri) {
    return isLocalAddress(uri.host);
  }

  /// สลับ Gateway ไป Production อัตโนมัติทันที
  static void switchToProduction() {
    if (!_hasSwitchedToProduction) {
      _hasSwitchedToProduction = true;
      debugPrint("⚡ [AppConfig] เชื่อมต่อ Local API ไม่ได้ ทำการสลับไป Production อัตโนมัติ: $productionBaseUrl");
    }
  }

  /// รีแมป URI เดิมให้ชี้ไปที่ Active BaseUrl (ใช้ตอนเกิด Failover)
  static Uri remapToActiveBaseUrl(Uri originalUri) {
    final activeBase = Uri.parse(baseUrl);
    final originalPath = originalUri.path;
    String subPath = originalPath;
    const marker = '/api/v1';
    final index = originalPath.indexOf(marker);
    if (index != -1) {
      subPath = originalPath.substring(index + marker.length);
    }
    final newPath = '${activeBase.path}$subPath';
    return originalUri.replace(
      scheme: activeBase.scheme,
      host: activeBase.host,
      port: activeBase.hasPort ? activeBase.port : null,
      path: newPath,
    );
  }

  /// Base URL พร้อมระบบ Auto-Failover อัจฉริยะ
  static String get baseUrl {
    if (_hasSwitchedToProduction) {
      return productionBaseUrl;
    }

    final envUrl = dotenv.env['BASE_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    return productionBaseUrl;
  }

  // เพิ่มต่อท้ายใน class AppConfig
  static Uri get stockUrl => Uri.parse('$baseUrl/stock');
  static Uri get loginUrl => Uri.parse('$baseUrl/auth/login');
  static Uri get registerUrl => Uri.parse('$baseUrl/auth/register');
  static Uri get refreshTokenUrl => Uri.parse('$baseUrl/auth/refresh');
  static Uri get chatUrl => Uri.parse('$baseUrl/chat');
  static Uri get tpsTrackingUrl => Uri.parse('$baseUrl/tps-tracking');
  static Uri productsUrl(String keyword) => Uri.parse('$baseUrl/products?keyword=$keyword');

  static Uri get aiSearchUrl => Uri.parse('$baseUrl/ai-assistant');

  // 🌟 [เพิ่มใหม่] ดึงค่า Supabase จากไฟล์ .env จ้ะ
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}