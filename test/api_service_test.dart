import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../lib/services/api_service.dart';

void main() {
  group('ApiService FCM response parsing', () {
    test('treats 2xx response as success', () {
      final response = http.Response('ok', 200);
      expect(ApiService.isSuccessfulFcmUpdateResponse(response), isTrue);
    });

    test('treats success flag in JSON body as success', () {
      final response = http.Response(jsonEncode({'success': true}), 400);
      expect(ApiService.isSuccessfulFcmUpdateResponse(response), isTrue);
    });

    test('treats failed body as failure', () {
      final response = http.Response(jsonEncode({'success': false}), 400);
      expect(ApiService.isSuccessfulFcmUpdateResponse(response), isFalse);
    });
  });
}
