// lib/constants.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000/api/v1';

  static Uri get loginUrl => Uri.parse('$baseUrl/auth/login');
  static Uri get registerUrl => Uri.parse('$baseUrl/auth/register');
  static Uri get refreshTokenUrl => Uri.parse('$baseUrl/auth/refresh');
  static Uri get chatUrl => Uri.parse('$baseUrl/chat');

  static Uri productsUrl(String keyword) => Uri.parse('$baseUrl/products?keyword=$keyword');

  // 🤖 เพิ่มบรรทัดนี้เข้าไปครับ เพื่อให้ AI Search รู้จักทางไปหา Backend
  // 🤖 แก้ให้มันวิ่งไปที่ /api/v1/ai-assistant ตามโครงสร้างใหม่ของเฮียเลยครับ
  static Uri get aiSearchUrl => Uri.parse('$baseUrl/ai-assistant');
}