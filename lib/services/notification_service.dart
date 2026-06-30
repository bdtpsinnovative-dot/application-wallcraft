// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotification() async {
    // 1. ขอสิทธิ์แจ้งเตือน
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

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
      },
    );

    // 4. จัดการ Token ทันทีที่เปิดแอป
    String? token = await _getFcmToken();
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
  }

  static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
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
      );
    }
  }

  static Future<String?> _getFcmToken() async {
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        final apnsToken = await _fcm.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return _fcm.getToken();
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
