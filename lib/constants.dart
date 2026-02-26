// lib/constants.dart

class AppConfig {

  // ⚠️ Backend ขึ้น Vercel แล้ว ให้เปลี่ยน IP นี้เป็น https://backend-for-ai-h12s.vercel.app/api/v1 นะครับ

  // ⚠️ Backend รันในเครื่อง ที่ TPSWoodden แล้วแล้ว ให้เปลี่ยน IP นี้เป็น http://192.168.9.143:3000/api/v1 นะครับ

  // ⚠️ Backend รันในเครื่อง ที่ Woodden บุณถาวร แล้ว ให้เปลี่ยน IP นี้เป็น http://192.168.1.177:3000/api/v1 นะครับ

  // กรณีเร่งด่วน ใช้ เน็ตมือถือตัวเอง เป็น ฮอตสปอต http://172.20.10.7:3000/api/v1 นะครับ     

  //192.168.31.81 http://192.168.31.81:3000
static String get baseUrl => 'https://backend-for-ai-h12s.vercel.app/api/v1';

  static Uri get loginUrl => Uri.parse('$baseUrl/auth/login');
  static Uri get registerUrl => Uri.parse('$baseUrl/auth/register');
  static Uri get refreshTokenUrl => Uri.parse('$baseUrl/auth/refresh');
  static Uri get chatUrl => Uri.parse('$baseUrl/chat');

  // ✅ เพิ่มบรรทัดนี้: URL สำหรับดึงข้อมูลสินค้า (ส่ง keyword ไปด้วย)
  static Uri productsUrl(String keyword) => Uri.parse('$baseUrl/products?keyword=$keyword');
}