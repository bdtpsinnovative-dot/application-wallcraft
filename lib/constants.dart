// lib/constants.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ดึงค่าจาก .env ถ้าหาไฟล์ไม่เจอ จะใช้ localhost เป็นตัวกันเหนียว (Fallback)
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000/api/v1';

  static Uri get loginUrl => Uri.parse('$baseUrl/auth/login');
  static Uri get registerUrl => Uri.parse('$baseUrl/auth/register');
  static Uri get refreshTokenUrl => Uri.parse('$baseUrl/auth/refresh');
  static Uri get chatUrl => Uri.parse('$baseUrl/chat');

  // URL สำหรับดึงข้อมูลสินค้า (ส่ง keyword ไปด้วย)
  static Uri productsUrl(String keyword) => Uri.parse('$baseUrl/products?keyword=$keyword');
}