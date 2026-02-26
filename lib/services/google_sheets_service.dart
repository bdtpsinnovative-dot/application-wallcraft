import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  // TODO: เดี๋ยวเราต้องมาใส่ URL ของ Google Apps Script ตรงนี้
  static const String _scriptUrl = 'ใส่_URL_ที่ได้จาก_Google_Script_ตรงนี้';

  static Future<bool> saveOrderToSheet(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        return true;
      }
      return false;
    } catch (e) {
      print('Error saving to Google Sheets: $e');
      return false;
    }
  }
}