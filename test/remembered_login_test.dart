import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Wallcraft/screens/auth/login_screen.dart';
import 'package:Wallcraft/services/auth_service.dart';

const _rememberedAccountsKey = 'wallcraft_remembered_accounts_v1';

String _accountsJson() => jsonEncode([
  {
    'email': 'mali@example.com',
    'password': 'secret-one',
    'display_name': 'มะลิ',
  },
  {
    'email': 'krit@example.com',
    'password': 'secret-two',
    'display_name': 'ชื่อเก่าในเครื่อง',
  },
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      _rememberedAccountsKey: _accountsJson(),
    });
  });

  testWidgets('compact remembered-account chooser fits a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(debugShowCheckedModeBanner: false, home: LoginScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('เลือกบัญชี'), findsOneWidget);
    expect(find.text('มะลิ'), findsOneWidget);
    expect(find.text('ชื่อเก่าในเครื่อง'), findsOneWidget);
    expect(find.text('ใช้บัญชีอื่น'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ใช้บัญชีอื่น'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ใช้บัญชีอื่น'), findsNothing);
    expect(find.text('สร้างบัญชีใหม่'), findsOneWidget);
    final createButton = find.widgetWithText(OutlinedButton, 'สร้างบัญชีใหม่');
    expect(createButton, findsOneWidget);
    expect(tester.getSize(createButton), const Size(180, 40));
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('จัดการบัญชีที่จำไว้'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    var accounts = await AuthService.loadRememberedAccounts();
    expect(accounts.map((account) => account.email), ['krit@example.com']);
    expect(find.text('มะลิ'), findsNothing);
    expect(find.text('ชื่อเก่าในเครื่อง'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'test-access-token');
    final synced = await AuthService.syncRememberedAccountProfile(
      email: 'krit@example.com',
      profileUrl: Uri.parse('https://example.com/api/v1/profile'),
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/profile'));
        expect(jsonDecode(request.body), {'token': 'test-access-token'});
        return http.Response(
          jsonEncode({
            'profile': {
              'full_name': 'กฤต วอลล์คราฟท์',
              'avatar_url': 'https://example.com/krit.webp',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(synced, isTrue);
    accounts = await AuthService.loadRememberedAccounts();
    expect(accounts.single.label, 'กฤต วอลล์คราฟท์');
    expect(accounts.single.avatarUrl, 'https://example.com/krit.webp');
  });
}
