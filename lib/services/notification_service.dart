// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initNotification() async {
    // 1. ขอสิทธิ์แจ้งเตือน
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. ตั้งค่า Foreground สำหรับ iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. ตั้งค่า Initialization
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit, 
      iOS: iosInit
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("Notification Payload: ${response.payload}");
      },
    );

    // 4. จัดการ Token
    String? token = await _fcm.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await uploadTokenToServer(token);
    }

    // 5. ดักฟังข้อความ
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 แจ้งเตือนเข้า: ${message.notification?.title}");
      _showLocalNotification(message);
    });
  }

static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            // 🌟 1. เปลี่ยนชื่อ Channel ID ตรงนี้ (เปลี่ยนจาก high_importance_channel เป็นชื่ออื่น เพื่อล้างค่าเดิมที่มือถือจำไว้)
            'order_alert_channel_v2', 
            'การแจ้งเตือนออเดอร์',
            channelDescription: 'แจ้งเตือนเมื่อมีออเดอร์ใหม่เข้าทีม',
            importance: Importance.max, 
            priority: Priority.high,    
            icon: 'ic_notification', 
            color: Color(0xFF000000), 
            
            // 🌟 2. เพิ่ม 2 บรรทัดนี้สำหรับเรียกเสียงที่เราเอาไปใส่ในโฟลเดอร์ raw
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification_sound'), 
          ),
          // 🌟 3. เพิ่มของ iOS เข้าไปด้วยเลยครับ วันหน้านายทำลง iPhone จะได้มีเสียงดังปังๆ
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'notification_sound.mp3', // ของ iOS ต้องระบุนามสกุล .mp3 ด้วยครับ
          )
        ),
      );
    }
  }

  static Future<void> uploadTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      if (authToken != null) {
        await ApiService.updateFcmToken(token);
      }
    } catch (e) {
      print("❌ อัปเดต Token พลาด: $e");
    }
  }
}