//lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ เพิ่มตัวนี้
import 'firebase_options.dart'; // ✅ เพิ่มตัวนี้ (ไฟล์ที่นายรัน flutterfire generate มา)
import 'services/notification_service.dart'; // ✅ เพิ่มตัวนี้
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

const Color kDarkBg = Color(0xFF0F0F11);
const Color kLimeGreen = Color(0xFFD2E862);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    
    // 🔥 ปลุกพลัง Firebase ตรงนี้ครับนาย
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 🔔 ตั้งค่าพื้นฐาน Notification (ขอสิทธิ์)
    await NotificationService.initNotification();
    
    print("✅ Load .env and Firebase success");
  } catch (e) {
    print("❌ Error initializing: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallcraft', //
      theme: ThemeData(
        scaffoldBackgroundColor: kDarkBg,
        canvasColor: kDarkBg,
        dialogBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: const ColorScheme.dark(
          primary: kLimeGreen,
          surface: Color(0xFF1C1C1E),
          onPrimary: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const CheckAuth(),
    );
  }
}

class CheckAuth extends StatefulWidget {
  const CheckAuth({super.key});

  @override
  State<CheckAuth> createState() => _CheckAuthState();
}

class _CheckAuthState extends State<CheckAuth> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (mounted) {
      if (token != null && token.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kDarkBg,
      body: Center(
        child: CircularProgressIndicator(color: kLimeGreen),
      ),
    );
  }
}