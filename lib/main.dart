import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

// ✅ สี Theme
const Color kDarkBg = Color(0xFF0F0F11);
const Color kLimeGreen = Color(0xFFD2E862);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS FoodScan',
      theme: ThemeData(
        scaffoldBackgroundColor: kDarkBg,
        canvasColor: kDarkBg,
        dialogBackgroundColor: const Color(0xFF1C1C1E),
        colorScheme: const ColorScheme.dark(
          primary: kLimeGreen,
          background: kDarkBg,
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
    // ❌ เอา Delay ออกครับ ให้โหลดเร็วที่สุดเท่าที่จะทำได้
    // await Future.delayed(const Duration(milliseconds: 2500)); 

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
      backgroundColor: kDarkBg, // พื้นหลังสีดำ Theme
      body: Center(
        // ✅ แสดงแค่ตัวโหลดธรรมดา สีเขียว (เพื่อให้รู้ว่าแอปไม่ค้าง)
        // ถ้าต้องการจอดำสนิทจริงๆ ให้ลบบรรทัด CircularProgressIndicator ออกครับ
        child: CircularProgressIndicator(color: kLimeGreen),
      ),
    );
  }
}