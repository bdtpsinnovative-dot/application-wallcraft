import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'api_service.dart';

/// Normalize Thai phone numbers to canonical digit format (e.g. 0812345678 / 021234567).
String normalizeThaiPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('660') && digits.length >= 11) {
    return '0${digits.substring(3)}';
  }
  if (digits.startsWith('66') && digits.length >= 10) {
    return '0${digits.substring(2)}';
  }
  return digits;
}

/// Format Thai phone number cleanly for display (e.g. 081-234-5678, 02-123-4567).
String formatThaiPhoneDisplay(String? raw) {
  final norm = normalizeThaiPhone(raw);
  if (norm.length == 10 && norm.startsWith('0')) {
    return '${norm.substring(0, 3)}-${norm.substring(3, 6)}-${norm.substring(6)}';
  }
  if (norm.length == 9 && norm.startsWith('02')) {
    return '02-${norm.substring(2, 5)}-${norm.substring(5)}';
  }
  if (norm.length == 9 && norm.startsWith('0')) {
    return '${norm.substring(0, 3)}-${norm.substring(3, 6)}-${norm.substring(6)}';
  }
  return (raw ?? '').trim();
}

/// Format call duration seconds into human-readable Thai duration string.
String formatCallDurationThai(int seconds) {
  if (seconds <= 0) return 'ไม่ได้รับ/ไม่ถึง 1 วิ';
  if (seconds < 60) return '$seconds วิ';
  final minutes = seconds ~/ 60;
  final rem = seconds % 60;
  if (rem == 0) return '$minutes นาที';
  return '$minutes นาที $rem วิ';
}

/// Prepare Android CallLog rows for upload: strictly keeps only numbers
/// matching customer_contacts directory (skips outside/personal numbers).
List<Map<String, dynamic>> buildCallLogsPayloadFromDeviceLogs(
  List<Map<String, dynamic>> rawLogs,
  Map<String, CustomerContact> directoryByPhone,
) {
  final List<Map<String, dynamic>> payloads = [];
  for (final item in rawLogs) {
    final norm = normalizeThaiPhone(
      (item['phone_normalized'] ?? item['phone'] ?? '').toString(),
    );
    if (norm.isEmpty ||
        !norm.startsWith('0') ||
        (norm.length != 9 && norm.length != 10)) {
      continue;
    }
    final contact = directoryByPhone[norm];
    if (contact == null) {
      continue;
    }

    final rawDir = (item['direction'] ?? item['call_direction'] ?? 'incoming')
        .toString()
        .toLowerCase();
    final callDirection = rawDir == 'outgoing'
        ? 'outgoing'
        : (rawDir == 'incoming' ? 'incoming' : 'missed');

    final durationSec =
        (item['duration_seconds'] ?? item['duration_sec'] ?? 0) is num
            ? ((item['duration_seconds'] ?? item['duration_sec'] ?? 0) as num)
                .toInt()
            : int.tryParse(
                    (item['duration_seconds'] ?? item['duration_sec'] ?? '0')
                        .toString(),
                  ) ??
                0;

    final outcome = durationSec > 0
        ? 'connected'
        : (callDirection == 'missed' ? 'no_answer' : 'unknown');

    payloads.add({
      'phone': norm,
      'contact_id': contact.id,
      'contact_name': contact.displayName,
      if (contact.companyName.isNotEmpty) 'company_name': contact.companyName,
      'call_direction': callDirection,
      'call_source': 'android_call_log',
      'started_at': item['started_at'],
      'duration_sec': durationSec,
      'outcome': outcome,
      'device_call_key': item['device_call_key'],
    });
  }
  return payloads;
}

class CustomerContact {
  final String id;
  final String phoneNormalized;
  final String phoneDisplay;
  final String displayName;
  final String companyName;
  final String contactCategory;
  final List<String> projectNames;
  final String ownerSaleName;
  final String notes;
  final int orderCount;
  final String lastOrderAt;
  final String updatedAt;

  const CustomerContact({
    required this.id,
    required this.phoneNormalized,
    required this.phoneDisplay,
    required this.displayName,
    required this.companyName,
    required this.contactCategory,
    required this.projectNames,
    required this.ownerSaleName,
    required this.notes,
    required this.orderCount,
    required this.lastOrderAt,
    required this.updatedAt,
  });

  factory CustomerContact.fromJson(Map<String, dynamic> json) {
    final norm = normalizeThaiPhone(
      (json['phone_normalized'] ?? json['phone_display'] ?? '').toString(),
    );
    final rawProjects = json['project_names'];
    final List<String> projects = rawProjects is List
        ? rawProjects
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : [];
    return CustomerContact(
      id: (json['id'] ?? '').toString(),
      phoneNormalized: norm,
      phoneDisplay: (json['phone_display'] ?? '').toString().trim().isNotEmpty
          ? json['phone_display'].toString().trim()
          : formatThaiPhoneDisplay(norm),
      displayName: (json['display_name'] ?? '').toString().trim(),
      companyName: (json['company_name'] ?? '').toString().trim(),
      contactCategory:
          (json['contact_category'] ?? 'general').toString().trim(),
      projectNames: projects,
      ownerSaleName: (json['owner_sale_name'] ?? '').toString().trim(),
      notes: (json['notes'] ?? '').toString().trim(),
      orderCount: (json['order_count'] is num)
          ? (json['order_count'] as num).toInt()
          : int.tryParse((json['order_count'] ?? '0').toString()) ?? 0,
      lastOrderAt: (json['last_order_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_normalized': phoneNormalized,
        'phone_display': phoneDisplay,
        'display_name': displayName,
        'company_name': companyName,
        'contact_category': contactCategory,
        'project_names': projectNames,
        'owner_sale_name': ownerSaleName,
        'notes': notes,
        'order_count': orderCount,
        'last_order_at': lastOrderAt,
        'updated_at': updatedAt,
      };

  /// Minimal payload pushed into Android native Caller ID SharedPreferences cache.
  Map<String, dynamic> toNativeCallerIdJson() => {
        'id': id,
        'phone_normalized': phoneNormalized,
        'phone_display': phoneDisplay,
        'display_name': displayName,
        'company_name': companyName,
        'customer_type': categoryLabel,
        'project_name': projectNames.take(2).join(', '),
        'assigned_sales_name': ownerSaleName,
      };

  String get categoryLabel {
    switch (contactCategory.toLowerCase()) {
      case 'architect':
        return 'Architect';
      case 'interior':
        return 'Interior';
      case 'contractor':
        return 'Contractor';
      case 'owner':
        return 'เจ้าของโครงการ';
      case 'project':
        return 'งานโครงการ';
      default:
        return 'ลูกค้าทั่วไป';
    }
  }
}

class CustomerCallLog {
  final String id;
  final String userId;
  final String saleName;
  final String contactId;
  final String phoneNormalized;
  final String phoneDisplay;
  final String contactName;
  final String companyName;
  final String callDirection;
  final String callSource;
  final DateTime? startedAt;
  final int durationSec;
  final String outcome;
  final String note;

  const CustomerCallLog({
    required this.id,
    required this.userId,
    required this.saleName,
    required this.contactId,
    required this.phoneNormalized,
    required this.phoneDisplay,
    required this.contactName,
    required this.companyName,
    required this.callDirection,
    required this.callSource,
    required this.startedAt,
    required this.durationSec,
    required this.outcome,
    required this.note,
  });

  factory CustomerCallLog.fromJson(Map<String, dynamic> json) {
    final norm = normalizeThaiPhone(
      (json['phone_normalized'] ?? json['phone_display'] ?? '').toString(),
    );
    return CustomerCallLog(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      saleName: (json['sale_name'] ?? 'พนักงาน').toString(),
      contactId: (json['contact_id'] ?? '').toString(),
      phoneNormalized: norm,
      phoneDisplay: (json['phone_display'] ?? '').toString().trim().isNotEmpty
          ? json['phone_display'].toString().trim()
          : formatThaiPhoneDisplay(norm),
      contactName:
          (json['contact_name'] ?? json['contact_name_snapshot'] ?? '')
              .toString()
              .trim(),
      companyName:
          (json['company_name'] ?? json['company_name_snapshot'] ?? '')
              .toString()
              .trim(),
      callDirection: (json['call_direction'] ?? 'outgoing').toString(),
      callSource: (json['call_source'] ?? 'manual').toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString())
          ?.toLocal(),
      durationSec: (json['duration_sec'] is num)
          ? (json['duration_sec'] as num).toInt()
          : int.tryParse((json['duration_sec'] ?? '0').toString()) ?? 0,
      outcome: (json['outcome'] ?? 'unknown').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class CallLogsSummary {
  final int total;
  final int outgoing;
  final int incoming;
  final int missed;
  final int totalDurationSec;

  const CallLogsSummary({
    this.total = 0,
    this.outgoing = 0,
    this.incoming = 0,
    this.missed = 0,
    this.totalDurationSec = 0,
  });

  factory CallLogsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CallLogsSummary();
    return CallLogsSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      outgoing: (json['outgoing'] as num?)?.toInt() ?? 0,
      incoming: (json['incoming'] as num?)?.toInt() ?? 0,
      missed: (json['missed'] as num?)?.toInt() ?? 0,
      totalDurationSec: (json['totalDurationSec'] as num?)?.toInt() ?? 0,
    );
  }
}

class CallerIdStatus {
  final bool supported;
  final int directoryCount;
  final bool hasCallLogPermission;
  final bool hasPhoneStatePermission;
  final bool hasNotificationPermission;
  final bool hasCallScreeningRole;
  final bool supportsCallScreeningRole;
  final int androidSdk;

  const CallerIdStatus({
    required this.supported,
    this.directoryCount = 0,
    this.hasCallLogPermission = false,
    this.hasPhoneStatePermission = false,
    this.hasNotificationPermission = false,
    this.hasCallScreeningRole = false,
    this.supportsCallScreeningRole = false,
    this.androidSdk = 0,
  });

  bool get hasMandatoryPermissions =>
      !supported ||
      (hasCallLogPermission &&
          hasPhoneStatePermission &&
          hasNotificationPermission);

  bool get isFullyReady =>
      supported &&
      hasCallLogPermission &&
      hasPhoneStatePermission &&
      hasNotificationPermission &&
      (!supportsCallScreeningRole || hasCallScreeningRole);

  factory CallerIdStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CallerIdStatus(supported: false);
    return CallerIdStatus(
      supported: true,
      directoryCount: (map['directoryCount'] as num?)?.toInt() ?? 0,
      hasCallLogPermission: map['hasCallLogPermission'] == true,
      hasPhoneStatePermission: map['hasPhoneStatePermission'] == true,
      hasNotificationPermission: map['hasNotificationPermission'] == true,
      hasCallScreeningRole: map['hasCallScreeningRole'] == true,
      supportsCallScreeningRole: map['supportsCallScreeningRole'] == true,
      androidSdk: (map['androidSdk'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerDirectoryService {
  static const MethodChannel _channel = MethodChannel('com.wallcraft.caller_id');
  static const String _cacheKey = 'customer_directory_cache_v1';
  static const String _lastCallSyncMsKey = 'customer_call_last_sync_ms_v1';
  static DateTime? _lastAutoSyncAt;

  static bool get isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<CustomerContact>> loadCachedDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => CustomerContact.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCachedAndPushNative(
    List<CustomerContact> contacts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);

      if (isAndroidNative) {
        final nativeJson = jsonEncode(
          contacts.map((c) => c.toNativeCallerIdJson()).toList(),
        );
        await _channel.invokeMethod('saveContactsDirectory', {
          'json': nativeJson,
          'baseUrl': AppConfig.baseUrl,
          'authToken': prefs.getString('auth_token') ?? '',
        });
      }
    } catch (e) {
      debugPrint('CustomerDirectoryService cache/native push warning: $e');
    }
  }

  /// Fetch verified customer directory from wallcraft-next backend API.
  static Future<List<CustomerContact>> fetchDirectory({
    String query = '',
    bool pushToNative = true,
  }) async {
    final q = query.trim();
    final uri = Uri.parse('${AppConfig.baseUrl}/customer-contacts').replace(
      queryParameters: q.isNotEmpty ? {'q': q} : null,
    );

    final res = await ApiService.get(uri);
    if (res.statusCode != 200) {
      throw Exception('โหลดสมุดเบอร์ไม่สำเร็จ (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    final rawList = (decoded is Map && decoded['contacts'] is List)
        ? decoded['contacts'] as List
        : <dynamic>[];

    final contacts = rawList
        .whereType<Map>()
        .map((e) => CustomerContact.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.phoneNormalized.isNotEmpty)
        .toList();

    // Only overwrite full cache when query is empty
    if (q.isEmpty && pushToNative) {
      await _saveCachedAndPushNative(contacts);
    }

    return contacts;
  }

  static Future<({
    List<CustomerCallLog> logs,
    CallLogsSummary summary,
    bool migrationRequired,
  })> fetchCallLogs({
    String scope = 'mine',
    String phone = '',
    int days = 30,
    int limit = 150,
  }) async {
    final params = <String, String>{
      'scope': scope,
      'days': days.toString(),
      'limit': limit.toString(),
    };
    if (phone.trim().isNotEmpty) {
      params['phone'] = normalizeThaiPhone(phone);
    }
    final uri = Uri.parse('${AppConfig.baseUrl}/call-logs').replace(
      queryParameters: params,
    );

    final res = await ApiService.get(uri);
    if (res.statusCode != 200) {
      throw Exception('โหลดประวัติโทรไม่สำเร็จ (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawLogs = (decoded['logs'] is List) ? decoded['logs'] as List : [];
    final logs = rawLogs
        .whereType<Map>()
        .map((e) => CustomerCallLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final summary = CallLogsSummary.fromJson(
      decoded['summary'] is Map<String, dynamic>
          ? decoded['summary'] as Map<String, dynamic>
          : null,
    );

    return (
      logs: logs,
      summary: summary,
      migrationRequired: decoded['migrationRequired'] == true,
    );
  }

  static Future<CustomerCallLog?> logCall({
    required String phone,
    String? contactId,
    String? contactName,
    String? companyName,
    String callDirection = 'outgoing',
    String callSource = 'in_app_dial',
    int durationSec = 0,
    String outcome = 'connected',
    String note = '',
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/call-logs');
    final payload = {
      'phone': normalizeThaiPhone(phone),
      if (contactId != null && contactId.isNotEmpty) 'contact_id': contactId,
      if (contactName != null && contactName.isNotEmpty)
        'contact_name': contactName,
      if (companyName != null && companyName.isNotEmpty)
        'company_name': companyName,
      'call_direction': callDirection,
      'call_source': callSource,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'duration_sec': durationSec,
      'outcome': outcome,
      'note': note.trim(),
    };

    final res = await ApiService.post(uri, body: jsonEncode(payload));
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? 'บันทึกสายโทรไม่สำเร็จ');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map &&
        decoded['logs'] is List &&
        (decoded['logs'] as List).isNotEmpty) {
      final first = (decoded['logs'] as List).first;
      if (first is Map) {
        return CustomerCallLog.fromJson(Map<String, dynamic>.from(first));
      }
    }
    return null;
  }

  static Future<void> updateCallLog({
    required String id,
    String? outcome,
    String? note,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/call-logs');
    final body = <String, dynamic>{'id': id};
    if (outcome != null) body['outcome'] = outcome;
    if (note != null) body['note'] = note.trim();

    final res = await ApiService.patch(uri, body: jsonEncode(body));
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body);
      throw Exception(decoded['error'] ?? 'อัปเดตบันทึกสายไม่สำเร็จ');
    }
  }

  static Future<String> suggestContact({
    required String phone,
    required String displayName,
    String companyName = '',
    String contactCategory = 'general',
    String notes = '',
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/customer-contacts');
    final res = await ApiService.post(
      uri,
      body: jsonEncode({
        'phone': phone.trim(),
        'display_name': displayName.trim(),
        'company_name': companyName.trim(),
        'contact_category': contactCategory,
        'notes': notes.trim(),
      }),
    );

    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(decoded['error'] ?? 'ส่งเสนอเบอร์ลูกค้าไม่สำเร็จ');
    }
    return (decoded['message'] ?? 'บันทึกเรียบร้อย').toString();
  }

  static Future<CallerIdStatus> getCallerIdStatus() async {
    if (!isAndroidNative) {
      return const CallerIdStatus(supported: false);
    }
    try {
      final map = await _channel.invokeMapMethod('getCallerIdStatus');
      return CallerIdStatus.fromMap(map);
    } catch (e) {
      debugPrint('getCallerIdStatus error: $e');
      return const CallerIdStatus(supported: true);
    }
  }

  static Future<CallerIdStatus> requestCallerIdPermissions() async {
    if (!isAndroidNative) {
      return const CallerIdStatus(supported: false);
    }
    try {
      final map = await _channel.invokeMapMethod('requestCallerIdPermissions');
      return CallerIdStatus.fromMap(map);
    } catch (e) {
      debugPrint('requestCallerIdPermissions error: $e');
      return await getCallerIdStatus();
    }
  }

  static Future<bool> openAppSettings() async {
    if (!isAndroidNative) return false;
    try {
      final res = await _channel.invokeMethod('openAppSettings');
      return res == true;
    } catch (e) {
      debugPrint('openAppSettings error: $e');
      return false;
    }
  }

  static Future<bool> showTestCallerIdNotification({
    CustomerContact? sampleContact,
  }) async {
    if (!isAndroidNative) return false;
    try {
      final res = await _channel.invokeMethod('showTestNotification', {
        'phone': sampleContact?.phoneNormalized ?? '0812345678',
        'displayName':
            sampleContact?.displayName ?? 'คุณสมชาย (ลูกค้าทดสอบ WallCraft)',
        'companyName':
            sampleContact?.companyName ?? 'บริษัท ตัวอย่าง ดีไซน์ จำกัด',
        'customerType': sampleContact?.categoryLabel ?? 'Architect',
        'projectName': sampleContact != null &&
                sampleContact.projectNames.isNotEmpty
            ? sampleContact.projectNames.first
            : 'โครงการตัวอย่าง',
        'assignedSalesName': sampleContact?.ownerSaleName ?? 'ทีมขาย',
      });
      return res == true;
    } catch (e) {
      debugPrint('showTestCallerIdNotification error: $e');
      return false;
    }
  }

  /// Sync recent Android device calls matching customer_contacts directory.
  /// Returns number of matched call logs uploaded.
  static Future<int> syncAndroidCallLogs({
    List<CustomerContact>? knownContacts,
    int lookbackDays = 14,
  }) async {
    if (!isAndroidNative) return 0;

    final status = await getCallerIdStatus();
    if (!status.hasCallLogPermission) return 0;

    final contacts = knownContacts ?? await loadCachedDirectory();

    final Map<String, CustomerContact> byPhone = {
      for (final c in contacts)
        if (c.phoneNormalized.isNotEmpty) c.phoneNormalized: c,
    };

    final prefs = await SharedPreferences.getInstance();
    await _channel.invokeMethod('saveApiConfig', {
      'baseUrl': AppConfig.baseUrl,
      'authToken': prefs.getString('auth_token') ?? '',
    });
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fallbackSince =
        nowMs - Duration(days: lookbackDays).inMilliseconds;
    final storedSince = prefs.getInt(_lastCallSyncMsKey);
    // Re-scan 24h overlap window to guarantee missed/late call records aren't skipped;
    // backend upserts idempotently via device_call_key.
    final sinceMs = storedSince != null
        ? (storedSince - const Duration(hours: 24).inMilliseconds)
            .clamp(fallbackSince, nowMs)
        : fallbackSince;

    final rawList = await _channel.invokeListMethod('getRecentCallLogs', {
      'sinceEpochMs': sinceMs,
      'limit': 150,
    });

    if (rawList == null || rawList.isEmpty) {
      await prefs.setInt(_lastCallSyncMsKey, nowMs);
      return 0;
    }

    final normalizedRaw = rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final payloads = buildCallLogsPayloadFromDeviceLogs(normalizedRaw, byPhone);
    if (payloads.isEmpty) {
      await prefs.setInt(_lastCallSyncMsKey, nowMs);
      return 0;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/call-logs');
    final res = await ApiService.post(
      uri,
      body: jsonEncode({'logs': payloads}),
    );

    if (res.statusCode == 200) {
      await prefs.setInt(_lastCallSyncMsKey, nowMs);
      final decoded = jsonDecode(res.body);
      return (decoded['insertedCount'] as num?)?.toInt() ?? payloads.length;
    }

    return 0;
  }

  /// Background-safe sync for HomeScreen startup (throttled to every 3 minutes unless forced).
  static Future<int> syncDirectoryAndCallLogs({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastAutoSyncAt != null &&
        now.difference(_lastAutoSyncAt!) < const Duration(minutes: 3)) {
      return 0;
    }
    _lastAutoSyncAt = now;

    try {
      final contacts = await fetchDirectory(pushToNative: true);
      if (isAndroidNative) {
        return await syncAndroidCallLogs(knownContacts: contacts);
      }
    } catch (e) {
      debugPrint('syncDirectoryAndCallLogs silent error: $e');
    }
    return 0;
  }
}
