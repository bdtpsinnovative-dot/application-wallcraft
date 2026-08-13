// lib/services/notification_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart' as main_app;
import '../constants.dart';
import '../screens/pool_project/pool_project_detail_screen.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotification() async {
    // 1. ขอสิทธิ์แจ้งเตือน
    NotificationSettings settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print("❌ การแจ้งเตือนถูกปฏิเสธ (User Denied)");
      // ใน iOS ถ้าสิทธิ์ถูกปฏิเสธ บางครั้งเราไม่ควรพยายามดึง Token ต่อ
      return; 
    }

    // 2. ตั้งค่า Foreground สำหรับ iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. ตั้งค่า Initialization (ไอคอนขาวดำ สไตล์มินิมอล)
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("Notification Payload: ${response.payload}");
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            handleNotificationTap(data);
          } catch (e) {
            print("Error parsing payload: $e");
          }
        }
      },
    );

    // 4. จัดการ Token ทันทีที่เปิดแอป
    String? token = await getFcmToken();
    if (token != null) {
      await uploadTokenToServer(token);
    }

    // 🌟 4.1 ดักฟังกรณี Firebase แอบเปลี่ยน Token กลางคัน จะได้ส่งไปอัปเดตอัตโนมัติ
    _fcm.onTokenRefresh.listen((newToken) {
      uploadTokenToServer(newToken);
    });

    // 5. ดักฟังข้อความตอนเปิดแอปอยู่ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 แจ้งเตือนเข้า: ${message.notification?.title}");
      _showLocalNotification(message);
    });

    // 6. ดักฟังการแท็บตอนอยู่ Background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationTap(message.data);
    });
  }

  static String resolveTitle(RemoteMessage message) {
    final notificationTitle = message.notification?.title;
    if (notificationTitle != null && notificationTitle.isNotEmpty) {
      return notificationTitle;
    }

    final dataTitle = message.data['title'] ?? message.data['Title'] ?? message.data['title_th'];
    if (dataTitle != null && dataTitle.toString().trim().isNotEmpty) {
      return dataTitle.toString();
    }

    return 'WallCraft';
  }

  static String resolveBody(RemoteMessage message) {
    final notificationBody = message.notification?.body;
    if (notificationBody != null && notificationBody.isNotEmpty) {
      return notificationBody;
    }

    final dataBody = message.data['body'] ?? message.data['message'] ?? message.data['body_th'];
    if (dataBody != null && dataBody.toString().trim().isNotEmpty) {
      return dataBody.toString();
    }

    return 'คุณมีข้อความใหม่';
  }

  static void _showLocalNotification(RemoteMessage message) {
    final title = resolveTitle(message);
    final body = resolveBody(message);

    _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'order_alert_channel_v2',
          'การแจ้งเตือนออเดอร์',
          channelDescription: 'แจ้งเตือนเมื่อมีออเดอร์ใหม่เข้าทีม',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          color: Color(0xFF000000), // โทนดำเข้ากับธีมแอป
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.mp3',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final orderId = data['orderId'];
    if (orderId == null) return;

    final context = main_app.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(child: CircularProgressIndicator(color: Color(0xFFD2E862))),
    );

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/orders/detail?order_id=$orderId'); 
      final response = await ApiService.get(url).timeout(const Duration(seconds: 10));

      Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        final dataStr = jsonDecode(response.body);
        final Map<String, dynamic> groupedData = {
          'order_data': dataStr,
          'order_items': dataStr['order_items'] ?? [],
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PoolProjectDetailScreen(groupedOrderData: groupedData),
          ),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลออเดอร์นี้')));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('โหลดข้อมูลล้มเหลว')));
    }
  }

  static Future<String?> getFcmToken() async {
    if (Platform.isIOS) {
      String? apnsToken;
      for (var attempt = 0; attempt < 10; attempt++) {
        apnsToken = await _fcm.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // ถ้ารอจนครบ 5 วินาทีแล้วยังไม่ได้ APNs Token (เช่น รันบน Simulator) ให้หยุดทันที
      // ขืนไปเรียก _fcm.getToken() ต่อ จะพังด้วย Error [firebase_messaging/apns-token-not-set]
      if (apnsToken == null) {
        print("❌ ไม่พบ APNs Token (คุณกำลังรันบน Simulator หรือไม่ได้เพิ่ม Push Notification Capability ใช่ไหม?)");
        return null;
      }
    }

    try {
      return await _fcm.getToken();
    } catch (e) {
      print("❌ ดึง FCM Token ไม่สำเร็จ: $e");
      return null;
    }
  }

  // 🌟 แยกออกมาให้ชัดเจน และทำ Public ไว้เผื่อเรียกใช้ตอน Login เสร็จ
  static Future<void> uploadTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // เก็บ Token ลงเครื่องไว้ก่อน
      await prefs.setString('fcm_token', token);

      // เช็คว่ามีคน Login อยู่หรือเปล่า
      final authToken = prefs.getString('auth_token');

      if (authToken != null && authToken.isNotEmpty) {
        print("📤 กำลังส่ง FCM Token เข้า Database...");
        await ApiService.updateFcmToken(token);
      } else {
        print("⚠️ ยังไม่ได้ล็อกอิน เก็บ Token ไว้ในเครื่องรอไปก่อนนะจ๊ะ");
      }
    } catch (e) {
      print("❌ อัปเดต Token พลาด: $e");
    }
  }
}
