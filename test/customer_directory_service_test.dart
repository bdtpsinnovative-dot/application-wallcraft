import 'package:flutter_test/flutter_test.dart';
import 'package:Wallcraft/services/customer_directory_service.dart';

void main() {
  group('Thai Phone Normalization & Formatting', () {
    test('normalizes +66, 660, dashes, and spaces into canonical Thai digits', () {
      expect(normalizeThaiPhone('+66 81-234-5678'), '0812345678');
      expect(normalizeThaiPhone('6627361130'), '027361130');
      expect(normalizeThaiPhone('660891112222'), '0891112222');
      expect(normalizeThaiPhone('02-736-1130'), '027361130');
      expect(normalizeThaiPhone(''), '');
      expect(normalizeThaiPhone(null), '');
    });

    test('formats 9-digit and 10-digit Thai numbers cleanly', () {
      expect(formatThaiPhoneDisplay('0812345678'), '081-234-5678');
      expect(formatThaiPhoneDisplay('+66812345678'), '081-234-5678');
      expect(formatThaiPhoneDisplay('027361130'), '02-736-1130');
      expect(formatThaiPhoneDisplay('6627361130'), '02-736-1130');
      expect(formatThaiPhoneDisplay('053123456'), '053-123-456');
    });
  });

  group('Duration Formatting', () {
    test('formats 0, seconds, exact minutes, and mixed minutes+seconds', () {
      expect(formatCallDurationThai(0), 'ไม่ได้รับ/ไม่ถึง 1 วิ');
      expect(formatCallDurationThai(45), '45 วิ');
      expect(formatCallDurationThai(120), '2 นาที');
      expect(formatCallDurationThai(135), '2 นาที 15 วิ');
    });
  });

  group('Device CallLog Payload Builder (buildCallLogsPayloadFromDeviceLogs)', () {
    test('captures only directory customers and ignores unlisted numbers and shortcodes', () {
      final contact1 = CustomerContact.fromJson({
        'id': 'c-1',
        'phone_normalized': '0812345678',
        'phone_display': '081-234-5678',
        'display_name': 'คุณสมชาย (สถาปนิก)',
        'company_name': 'Studio A Co., Ltd.',
        'contact_category': 'architect',
        'project_names': ['Noble Ploenchit'],
        'owner_sale_name': 'Jay',
      });

      final directoryByPhone = <String, CustomerContact>{
        contact1.phoneNormalized: contact1,
      };

      final rawAndroidLogs = <Map<String, dynamic>>[
        {
          'device_call_key': '101_1700000_outgoing_0812345678',
          'phone_normalized': '+6681-234-5678',
          'direction': 'outgoing',
          'duration_seconds': 95,
          'started_at': '2026-11-12T06:00:00.000Z',
        },
        {
          'device_call_key': '102_1700001_incoming_0899999999',
          'phone_normalized': '0899999999',
          'cached_name': 'คุณเอ ผู้รับเหมาใหม่',
          'direction': 'incoming',
          'duration_seconds': 300,
          'started_at': '2026-11-12T06:10:00.000Z',
        },
        {
          'device_call_key': '103_1700002_rejected_0821112222',
          'phone_normalized': '0821112222',
          'direction': 'rejected',
          'duration_seconds': 0,
          'started_at': '2026-11-12T06:20:00.000Z',
        },
        {
          'device_call_key': '104_1700003_outgoing_1242',
          'phone_normalized': '1242', // short carrier code ignored
          'direction': 'outgoing',
          'duration_seconds': 15,
          'started_at': '2026-11-12T06:30:00.000Z',
        },
      ];

      final payloads =
          buildCallLogsPayloadFromDeviceLogs(rawAndroidLogs, directoryByPhone);

      // Only the matched customer_contacts number should be included
      expect(payloads.length, 1);

      expect(payloads[0]['phone'], '0812345678');
      expect(payloads[0]['contact_id'], 'c-1');
      expect(payloads[0]['contact_name'], 'คุณสมชาย (สถาปนิก)');
      expect(payloads[0]['call_direction'], 'outgoing');
      expect(payloads[0]['call_source'], 'android_call_log');
      expect(payloads[0]['duration_sec'], 95);
      expect(payloads[0]['outcome'], 'connected');

      // Ensure CustomerCallLog.fromJson parses snapshot fields from API
      final parsedLog = CustomerCallLog.fromJson({
        'id': 'log-1',
        'phone_normalized': '0812345678',
        'contact_name_snapshot': 'คุณสมชาย (สถาปนิก)',
        'company_name_snapshot': 'Studio A Co., Ltd.',
        'call_direction': 'outgoing',
        'duration_sec': 95,
      });
      expect(parsedLog.contactName, 'คุณสมชาย (สถาปนิก)');
      expect(parsedLog.companyName, 'Studio A Co., Ltd.');
    });
  });
}
