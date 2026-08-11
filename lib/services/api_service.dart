import 'dart:convert';
import 'dart:io'; // 👈 เพิ่มตัวนี้เพื่อเช็ค Platform.isAndroid
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ==================================================
  // 🔔 ให้ Flutter ยิงกลับไปที่ API Next.js ตามเดิมครับ
  // ==================================================
  static Future<void> updateFcmToken(String fcmToken) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/profile/fcm');

      final response = await patch(
        url,
        body: jsonEncode({
          'fcm_token': fcmToken,
          'device_type': Platform.isAndroid ? 'android' : 'ios',
        }),
      );

      if (isSuccessfulFcmUpdateResponse(response)) {
        print("🚀 [ApiService] อัปเดต FCM Token ผ่าน API สำเร็จ!");
        print("📦 [ApiService] Response body: ${response.body}");
      } else {
        print("❌ [ApiService] อัปเดต FCM Token พลาด: ${response.statusCode}");
        print("📦 [ApiService] Response body: ${response.body}");
      }
    } catch (e) {
      print("❌ [ApiService] Error: $e");
    }
  }

  static bool isSuccessfulFcmUpdateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['success'] == true ||
            decoded['ok'] == true ||
            decoded['status'] == 'success';
      }
    } catch (_) {}

    return false;
  }

  // --- Method อื่นๆ (get, post, put, patch) คงเดิมไว้ครับ ---

  // --- In-Memory Caches ---
  static http.Response? _pipelineCache;
  static http.Response? _companiesCache;
  static http.Response? _projectsCache;
  static http.Response? _projectTypesCache;
  static http.Response? _categoriesCache;

  static void clearCache() {
    _pipelineCache = null;
    _companiesCache = null;
    _projectsCache = null;
    _projectTypesCache = null;
    _categoriesCache = null;
  }

  static Future<http.Response> getPipeline() async {
    if (_pipelineCache != null) return _pipelineCache!;
    final url = Uri.parse('${AppConfig.baseUrl}/profile/pipeline');
    final res = await get(url);
    if (res.statusCode == 200) _pipelineCache = res;
    return res;
  }

  static Future<http.Response> getVisitPlans() async {
    final url = Uri.parse('${AppConfig.baseUrl}/profile/visit-plans');
    return await get(url);
  }

  static Future<http.Response> getCompanies({String? query}) async {
    if (query == null || query.isEmpty) {
      if (_companiesCache != null) return _companiesCache!;
      final url = Uri.parse('${AppConfig.baseUrl}/companies');
      final res = await get(url);
      if (res.statusCode == 200) _companiesCache = res;
      return res;
    }
    final url = Uri.parse('${AppConfig.baseUrl}/companies?q=$query');
    return await get(url);
  }

  static Future<http.Response> getProjects({String? query}) async {
    if (query == null || query.isEmpty) {
      if (_projectsCache != null) return _projectsCache!;
      final url = Uri.parse('${AppConfig.baseUrl}/projects');
      final res = await get(url);
      if (res.statusCode == 200) _projectsCache = res;
      return res;
    }
    final url = Uri.parse('${AppConfig.baseUrl}/projects?q=$query');
    return await get(url);
  }

  static Future<http.Response> getProjectTypes() async {
    if (_projectTypesCache != null) return _projectTypesCache!;
    final url = Uri.parse('${AppConfig.baseUrl}/project-types');
    final res = await get(url);
    if (res.statusCode == 200) _projectTypesCache = res;
    return res;
  }

  static Future<http.Response> getCategories() async {
    if (_categoriesCache != null) return _categoriesCache!;
    final url = Uri.parse('${AppConfig.baseUrl}/categories');
    final res = await get(url);
    if (res.statusCode == 200) _categoriesCache = res;
    return res;
  }

  // 🌟 12-Week Visit Planner Board APIs
  static Future<http.Response> getWeeklyVisitPlansBoard() async {
    final url = Uri.parse('${AppConfig.baseUrl}/visit-plans');
    return await get(url);
  }

  static Future<http.Response> getRepeatedVisits() async {
    final url = Uri.parse('${AppConfig.baseUrl}/repeated-visits');
    return await get(url);
  }

  static Future<http.Response> addVisitPlan(Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.baseUrl}/visit-plans');
    return await post(url, body: jsonEncode(body));
  }

  static Future<http.Response> deleteVisitPlan(String id) async {
    final url = Uri.parse('${AppConfig.baseUrl}/visit-plans?id=$id');
    var headers = await _getHeaders();
    return await http.delete(url, headers: headers);
  }

  static Future<http.Response> get(Uri uri) async {
    var headers = await _getHeaders();
    var response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.get(uri, headers: headers);
      }
    }
    return response;
  }

  static Future<http.Response> post(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.post(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  static Future<http.Response> patch(Uri uri, {Object? body}) async {
    var headers = await _getHeaders();
    var response = await http.patch(uri, headers: headers, body: body);
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.tryRefreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.patch(uri, headers: headers, body: body);
      }
    }
    return response;
  }

  static Future<http.Response> triggerDailySummaryCron() async {
    final url = Uri.parse('${AppConfig.baseUrl}/cron/daily-summary');
    return await get(url); // get() already handles headers and token
  }
}
