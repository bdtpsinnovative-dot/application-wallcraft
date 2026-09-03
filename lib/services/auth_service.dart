// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

enum AuthRefreshResult { refreshed, invalid, unavailable }

class RememberedAccount {
  const RememberedAccount({
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String email;
  final String? displayName;
  final String? avatarUrl;

  String get label {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final username = email.split('@').first.trim();
    return username.isEmpty ? 'บัญชีของฉัน' : username;
  }

  String get initial {
    final value = label.trim();
    return value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
  }
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _refreshTokenKey = 'wallcraft_refresh_token';
  static const _savedEmailKey = 'wallcraft_saved_email';
  static const _savedPasswordKey = 'wallcraft_saved_password';
  static const _rememberedAvatarKey = 'wallcraft_remembered_avatar';
  static const _rememberedNameKey = 'wallcraft_remembered_name';
  static const _rememberedAccountsKey = 'wallcraft_remembered_accounts_v1';
  static const _signedOutKey = 'auth_explicitly_signed_out';

  static Completer<AuthRefreshResult>? _refreshCompleter;
  static Future<void>? _migrationFuture;

  /// ตรวจสอบว่า JWT หมดอายุหรือใกล้หมดอายุ (เหลือน้อยกว่า 10 วินาที) หรือไม่
  static bool isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final data = jsonDecode(payload);
      final exp = data['exp'];
      if (exp is num) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
        );
        return DateTime.now().isAfter(
          expiryTime.subtract(const Duration(seconds: 10)),
        );
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  static Future<bool> persistLoginSession({
    required Map<String, dynamic> response,
    required String email,
    required String password,
  }) async {
    await _ensureVaultMigrated();
    final persisted = await _persistSessionPayload(
      response,
      fallbackEmail: email,
      password: password,
    );
    if (persisted) {
      await syncRememberedAccountProfile(email: email);
    }
    return persisted;
  }

  static Future<AuthRefreshResult> ensureFreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_signedOutKey) == true) {
      return AuthRefreshResult.invalid;
    }
    final accessToken = prefs.getString('auth_token');
    if (!isTokenExpired(accessToken)) return AuthRefreshResult.refreshed;
    return refreshSession();
  }

  /// Silent Re-Authentication backed by OS encrypted storage.
  static Future<bool> silentReAuthenticate() async {
    return await _silentReAuthenticate() == AuthRefreshResult.refreshed;
  }

  static Future<List<RememberedAccount>> loadRememberedAccounts() async {
    await _ensureVaultMigrated();
    final credentials = await _readRememberedCredentials();
    return credentials.map((value) => value.account).toList(growable: false);
  }

  static Future<bool> syncRememberedAccountProfile({
    required String email,
    @visibleForTesting http.Client? client,
    @visibleForTesting Uri? profileUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('auth_token');
    if (accessToken == null || accessToken.isEmpty) return false;

    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .post(
            profileUrl ?? Uri.parse('${AppConfig.baseUrl}/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({'token': accessToken}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['profile'] is! Map) return false;
      final profile = Map<String, dynamic>.from(decoded['profile'] as Map);
      final displayName = profile['full_name']?.toString();
      final avatarUrl = profile['avatar_url']?.toString();

      await updateRememberedAccountProfile(
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      return true;
    } catch (error) {
      debugPrint('[AuthService] Could not sync remembered profile: $error');
      return false;
    } finally {
      if (client == null) requestClient.close();
    }
  }

  static Future<void> updateCurrentRememberedAccountProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final email = await _storage.read(key: _savedEmailKey);
    if (email == null || email.trim().isEmpty) return;
    await updateRememberedAccountProfile(
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  static Future<AuthRefreshResult> signInRememberedAccount(
    RememberedAccount account,
  ) async {
    final credentials = await _readRememberedCredentials();
    final normalizedEmail = account.email.trim().toLowerCase();
    for (final credential in credentials) {
      if (credential.email.toLowerCase() == normalizedEmail) {
        return _authenticateWithCredential(credential);
      }
    }
    return AuthRefreshResult.invalid;
  }

  static Future<void> forgetRememberedAccount(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credentials = await _readRememberedCredentials();
    final remaining = credentials
        .where((value) => value.email.toLowerCase() != normalizedEmail)
        .toList(growable: false);
    await _writeRememberedCredentials(remaining);

    final selectedEmail = await _storage.read(key: _savedEmailKey);
    if (selectedEmail?.trim().toLowerCase() == normalizedEmail) {
      await Future.wait([
        _storage.delete(key: _savedEmailKey),
        _storage.delete(key: _savedPasswordKey),
        _storage.delete(key: _rememberedAvatarKey),
        _storage.delete(key: _rememberedNameKey),
      ]);
    }
  }

  static Future<AuthRefreshResult> _silentReAuthenticate() async {
    await _ensureVaultMigrated();
    final email = await _storage.read(key: _savedEmailKey);
    final password = await _storage.read(key: _savedPasswordKey);

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return AuthRefreshResult.invalid;
    }

    return _authenticateWithCredential(
      _RememberedCredential(email: email.trim(), password: password),
    );
  }

  static Future<AuthRefreshResult> _authenticateWithCredential(
    _RememberedCredential credential,
  ) async {
    try {
      debugPrint('[AuthService] Attempting silent session recovery.');
      final response = await http
          .post(
            AppConfig.loginUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': credential.email.trim(),
              'password': credential.password,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            await _persistSessionPayload(
              decoded,
              fallbackEmail: credential.email,
              password: credential.password,
            )) {
          await syncRememberedAccountProfile(email: credential.email);
          return AuthRefreshResult.refreshed;
        }
      }

      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return AuthRefreshResult.invalid;
      }
    } catch (error) {
      debugPrint('[AuthService] Silent re-authentication unavailable: $error');
    }
    return AuthRefreshResult.unavailable;
  }

  /// Compatibility wrapper used by API calls that only need success/failure.
  static Future<bool> tryRefreshToken() async {
    return await refreshSession() == AuthRefreshResult.refreshed;
  }

  /// Refreshes once for all concurrent callers and retries transient failures.
  static Future<AuthRefreshResult> refreshSession() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<AuthRefreshResult>();
    _refreshCompleter = completer;
    var result = AuthRefreshResult.unavailable;

    try {
      await _ensureVaultMigrated();
      final refreshToken = await _storage.read(key: _refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        result = await _silentReAuthenticate();
        return result;
      }

      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await http
              .post(
                AppConfig.refreshTokenUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'refresh_token': refreshToken}),
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic> &&
                await _persistSessionPayload(decoded)) {
              result = AuthRefreshResult.refreshed;
              return result;
            }

            return result;
          }

          if (response.statusCode == 401) {
            final decoded = _tryDecodeMap(response.body);
            if (decoded?['is_invalid_grant'] == true) {
              result = await _silentReAuthenticate();
              return result;
            }
          }
        } catch (error) {
          debugPrint(
            '[AuthService] Refresh attempt $attempt unavailable: $error',
          );
        }

        if (attempt < 3) {
          await Future.delayed(
            Duration(milliseconds: 250 * (1 << (attempt - 1))),
          );
        }
      }

      return result;
    } finally {
      if (!completer.isCompleted) completer.complete(result);
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  static Future<void> signOut({bool forgetAccount = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('auth_token'),
      prefs.remove('refresh_token'),
      prefs.remove('saved_email'),
      prefs.remove('saved_pass'),
      prefs.remove('user_id'),
      prefs.setBool(_signedOutKey, true),
      _storage.delete(key: _refreshTokenKey),
      if (forgetAccount) _storage.delete(key: _savedEmailKey),
      if (forgetAccount) _storage.delete(key: _savedPasswordKey),
      if (forgetAccount) _storage.delete(key: _rememberedAvatarKey),
      if (forgetAccount) _storage.delete(key: _rememberedNameKey),
      if (forgetAccount) _storage.delete(key: _rememberedAccountsKey),
    ]);
  }

  static Future<bool> _persistSessionPayload(
    Map<String, dynamic> payload, {
    String? fallbackEmail,
    String? password,
  }) async {
    final sessionValue = payload['session'];
    final session = sessionValue is Map
        ? Map<String, dynamic>.from(sessionValue)
        : payload;
    final accessToken = session['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) return false;

    final refreshToken = session['refresh_token']?.toString();
    final userValue = payload['user'] ?? session['user'];
    final user = userValue is Map ? Map<String, dynamic>.from(userValue) : null;
    final metadataValue = user?['user_metadata'];
    final metadata = metadataValue is Map
        ? Map<String, dynamic>.from(metadataValue)
        : null;
    final email = user?['email']?.toString() ?? fallbackEmail;
    final userId = user?['id']?.toString();
    final displayName =
        metadata?['nickname']?.toString() ??
        metadata?['display_name']?.toString() ??
        metadata?['full_name']?.toString() ??
        metadata?['name']?.toString();
    final avatarUrl =
        metadata?['avatar_url']?.toString() ?? metadata?['picture']?.toString();
    final prefs = await SharedPreferences.getInstance();

    // Persist rotated refresh credentials before publishing the new access
    // token so a vault failure cannot leave an unusable token pair.
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (email != null && email.isNotEmpty) {
      await _storage.write(key: _savedEmailKey, value: email.trim());
    }
    if (password != null && password.isNotEmpty) {
      await _storage.write(key: _savedPasswordKey, value: password);
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _storage.write(key: _rememberedNameKey, value: displayName.trim());
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      await _storage.write(key: _rememberedAvatarKey, value: avatarUrl.trim());
    }
    if (email != null && email.trim().isNotEmpty) {
      if (password != null && password.isNotEmpty) {
        await _rememberCredential(
          email: email,
          password: password,
          displayName: displayName,
          avatarUrl: avatarUrl,
        );
      } else {
        await updateRememberedAccountProfile(
          email: email,
          displayName: displayName,
          avatarUrl: avatarUrl,
        );
      }
    }
    await prefs.setString('auth_token', accessToken);
    await prefs.setBool(_signedOutKey, false);
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString('user_id', userId);
    }

    await Future.wait([
      prefs.remove('refresh_token'),
      prefs.remove('saved_email'),
      prefs.remove('saved_pass'),
    ]);
    return true;
  }

  static Future<List<_RememberedCredential>>
  _readRememberedCredentials() async {
    await _ensureVaultMigrated();
    final raw = await _storage.read(key: _rememberedAccountsKey);
    final result = <_RememberedCredential>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final credential = _RememberedCredential.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (credential.email.isNotEmpty &&
                  credential.password.isNotEmpty) {
                result.add(credential);
              }
            }
          }
        }
      } catch (decodeError) {
        debugPrint(
          '[AuthService] Could not decode remembered accounts: $decodeError',
        );
      }
    }

    if (result.isEmpty) {
      final email = await _storage.read(key: _savedEmailKey);
      final password = await _storage.read(key: _savedPasswordKey);
      if (email != null &&
          email.trim().isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        result.add(
          _RememberedCredential(
            email: email.trim(),
            password: password,
            displayName: await _storage.read(key: _rememberedNameKey),
            avatarUrl: await _storage.read(key: _rememberedAvatarKey),
          ),
        );
        await _writeRememberedCredentials(result);
      }
    }
    return result;
  }

  static Future<void> _writeRememberedCredentials(
    List<_RememberedCredential> credentials,
  ) async {
    if (credentials.isEmpty) {
      await _storage.delete(key: _rememberedAccountsKey);
      return;
    }
    await _storage.write(
      key: _rememberedAccountsKey,
      value: jsonEncode(
        credentials.map((value) => value.toJson()).toList(growable: false),
      ),
    );
  }

  static Future<void> _rememberCredential({
    required String email,
    required String password,
    String? displayName,
    String? avatarUrl,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) return;
    final credentials = await _readRememberedCredentials();
    _RememberedCredential? existing;
    for (final credential in credentials) {
      if (credential.email.toLowerCase() == normalizedEmail) {
        existing = credential;
        break;
      }
    }
    final remembered = _RememberedCredential(
      email: email.trim(),
      password: password,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : existing?.displayName,
      avatarUrl: avatarUrl?.trim().isNotEmpty == true
          ? avatarUrl!.trim()
          : existing?.avatarUrl,
    );
    final updated = <_RememberedCredential>[
      remembered,
      ...credentials.where(
        (value) => value.email.toLowerCase() != normalizedEmail,
      ),
    ].take(5).toList(growable: false);
    await _writeRememberedCredentials(updated);
  }

  static Future<void> updateRememberedAccountProfile({
    required String email,
    String? displayName,
    String? avatarUrl,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return;
    final credentials = await _readRememberedCredentials();
    var changed = false;
    final updated = credentials
        .map((credential) {
          if (credential.email.toLowerCase() != normalizedEmail) {
            return credential;
          }
          changed = true;
          return _RememberedCredential(
            email: credential.email,
            password: credential.password,
            displayName: displayName?.trim().isNotEmpty == true
                ? displayName!.trim()
                : credential.displayName,
            avatarUrl: avatarUrl?.trim().isNotEmpty == true
                ? avatarUrl!.trim()
                : credential.avatarUrl,
          );
        })
        .toList(growable: false);
    if (changed) await _writeRememberedCredentials(updated);

    final selectedEmail = await _storage.read(key: _savedEmailKey);
    if (selectedEmail?.trim().toLowerCase() == normalizedEmail) {
      if (displayName?.trim().isNotEmpty == true) {
        await _storage.write(
          key: _rememberedNameKey,
          value: displayName!.trim(),
        );
      }
      if (avatarUrl?.trim().isNotEmpty == true) {
        await _storage.write(
          key: _rememberedAvatarKey,
          value: avatarUrl!.trim(),
        );
      }
    }
  }

  static Map<String, dynamic>? _tryDecodeMap(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureVaultMigrated() {
    return _migrationFuture ??= _migrateLegacyVault();
  }

  static Future<void> _migrateLegacyVault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyValues = <String, String?>{
        _refreshTokenKey: prefs.getString('refresh_token'),
        _savedEmailKey: prefs.getString('saved_email'),
        _savedPasswordKey: prefs.getString('saved_pass'),
      };
      final legacyKeys = <String, String>{
        _refreshTokenKey: 'refresh_token',
        _savedEmailKey: 'saved_email',
        _savedPasswordKey: 'saved_pass',
      };

      for (final entry in legacyValues.entries) {
        final current = await _storage.read(key: entry.key);
        if ((current == null || current.isEmpty) &&
            entry.value != null &&
            entry.value!.isNotEmpty) {
          await _storage.write(key: entry.key, value: entry.value);
        }
        await prefs.remove(legacyKeys[entry.key]!);
      }
    } catch (error) {
      // Keep legacy values untouched if the OS vault is temporarily unavailable.
      debugPrint('[AuthService] Secure vault migration deferred: $error');
    }
  }
}

class _RememberedCredential {
  const _RememberedCredential({
    required this.email,
    required this.password,
    this.displayName,
    this.avatarUrl,
  });

  factory _RememberedCredential.fromJson(Map<String, dynamic> json) {
    return _RememberedCredential(
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String email;
  final String password;
  final String? displayName;
  final String? avatarUrl;

  RememberedAccount get account => RememberedAccount(
    email: email,
    displayName: displayName,
    avatarUrl: avatarUrl,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (displayName?.trim().isNotEmpty == true)
      'display_name': displayName!.trim(),
    if (avatarUrl?.trim().isNotEmpty == true) 'avatar_url': avatarUrl!.trim(),
  };
}
