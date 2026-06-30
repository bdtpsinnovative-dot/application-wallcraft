import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/notification_service.dart';

void main() {
  group('NotificationService title/body resolution', () {
    test('uses the FCM data title when the notification payload is missing', () {
      final message = RemoteMessage(
        data: {
          'title': 'ออเดอร์ใหม่',
          'body': 'มีคำสั่งซื้อใหม่เข้ามา',
        },
      );

      expect(NotificationService.resolveTitle(message), 'ออเดอร์ใหม่');
      expect(NotificationService.resolveBody(message), 'มีคำสั่งซื้อใหม่เข้ามา');
    });

    test('falls back to the app default title when no title is provided', () {
      final message = RemoteMessage(data: {'body': 'ข้อความจากเซิร์ฟเวอร์'});

      expect(NotificationService.resolveTitle(message), 'WallCraft');
      expect(NotificationService.resolveBody(message), 'ข้อความจากเซิร์ฟเวอร์');
    });
  });
}
