import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../main.dart' as main_app;
import 'api_service.dart';

class AppUpdateService {
  static const _installDeviceIdKey = 'wallcraft_install_device_id';
  static const _syncThrottleDuration = Duration(minutes: 5);

  static bool _isCheckingUpdate = false;
  static bool _isDialogVisible = false;
  static String? _dismissedOptionalVersion;
  static DateTime? _lastDeviceSyncAt;
  static String? _lastSyncedUserId;

  /// แยกส่วนเลขเวอร์ชัน (รองรับรูปแบบ `2.1.1`, `v2.1.1+10`, `2.1.1-beta`)
  static List<int> _parseVersionSegments(String raw) {
    final normalized = raw
        .trim()
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split('+')
        .first
        .split('-')
        .first;
    if (normalized.isEmpty) return const [0];
    return normalized.split('.').map((segment) {
      final match = RegExp(r'\d+').firstMatch(segment);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();
  }

  /// คืนค่า true เมื่อ currentVersion น้อยกว่า latestVersion เท่านั้น
  static bool isVersionOutdated(String currentVersion, String latestVersion) {
    final currentParts = _parseVersionSegments(currentVersion);
    final latestParts = _parseVersionSegments(latestVersion);
    final maxLen = max(currentParts.length, latestParts.length);
    for (int i = 0; i < maxLen; i++) {
      final currentVal = i < currentParts.length ? currentParts[i] : 0;
      final latestVal = i < latestParts.length ? latestParts[i] : 0;
      if (currentVal < latestVal) return true;
      if (currentVal > latestVal) return false;
    }
    return false;
  }

  static Future<String> _getOrCreateDeviceKey(
    SharedPreferences prefs,
    String platform,
    String brand,
    String model,
  ) async {
    final existing = prefs.getString(_installDeviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final cleanBrand = brand.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final cleanModel = model.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final rand = Random().nextInt(0x7fffffff).toRadixString(36);
    final timePart = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final generated = '${platform}_${cleanBrand}_${cleanModel}_$timePart$rand';
    await prefs.setString(_installDeviceIdKey, generated);
    return generated;
  }

  /// ส่งข้อมูลเวอร์ชันแอปและรุ่นอุปกรณ์ของพนักงานขึ้น Backend API
  static Future<void> syncDeviceAndVersion({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.trim().isEmpty) return;

      final userId = prefs.getString('user_id') ?? '';
      final now = DateTime.now();
      if (!force &&
          _lastDeviceSyncAt != null &&
          _lastSyncedUserId == userId &&
          now.difference(_lastDeviceSyncAt!) < _syncThrottleDuration) {
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version.trim();
      final buildNumber = int.tryParse(packageInfo.buildNumber.trim());

      String platform = 'other';
      String deviceBrand = '';
      String deviceModel = '';
      String osVersion = '';

      if (kIsWeb) {
        platform = 'web';
        final webInfo = await DeviceInfoPlugin().webBrowserInfo;
        deviceBrand = webInfo.browserName.name;
        deviceModel = webInfo.platform ?? 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        deviceBrand = androidInfo.brand;
        deviceModel = androidInfo.model;
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        platform = 'ios';
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        deviceBrand = 'Apple';
        deviceModel = iosInfo.utsname.machine;
        osVersion = iosInfo.systemVersion;
      }

      final deviceKey = await _getOrCreateDeviceKey(
        prefs,
        platform,
        deviceBrand,
        deviceModel,
      );

      final response = await ApiService.post(
        Uri.parse('${AppConfig.baseUrl}/profile/device'),
        body: jsonEncode({
          'token': token,
          'device_key': deviceKey,
          'platform': platform,
          'app_version': appVersion,
          'build_number': buildNumber,
          'device_brand': deviceBrand,
          'device_model': deviceModel,
          'os_version': osVersion,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastDeviceSyncAt = now;
        _lastSyncedUserId = userId;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Device sync skipped: $e');
    }
  }

  /// เช็กเวอร์ชันใหม่จาก Backend และแสดง Popup (รองรับทั้งแบบปิดข้ามได้ และแบบบังคับอัปเดต)
  static Future<void> checkForUpdate({
    BuildContext? context,
    bool showNoUpdateToast = false,
  }) async {
    if (kIsWeb || _isCheckingUpdate || _isDialogVisible) return;
    _isCheckingUpdate = true;

    final ScaffoldMessengerState? messenger = (context != null && context.mounted)
        ? ScaffoldMessenger.maybeOf(context)
        : (main_app.navigatorKey.currentContext != null
            ? ScaffoldMessenger.maybeOf(main_app.navigatorKey.currentContext!)
            : null);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final uri = Uri.parse('${AppConfig.baseUrl}/check-update');
      http.Response response;
      try {
        response = await http.get(uri).timeout(const Duration(seconds: 10));
      } catch (_) {
        if (!AppConfig.isLocalUrl(uri)) rethrow;
        AppConfig.switchToProduction();
        response = await http
            .get(AppConfig.remapToActiveBaseUrl(uri))
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode != 200) {
        if (showNoUpdateToast) {
          _showInfoSnackBar(messenger, 'เวอร์ชันปัจจุบัน: v$currentVersion');
        }
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final isIos = Platform.isIOS;
      final latestVersion = (isIos
              ? data['latest_version_ios']
              : data['latest_version_android'])
          ?.toString()
          .trim() ??
          '';
      final downloadUrl = (isIos
              ? data['download_url_ios']
              : data['download_url_android'])
          ?.toString()
          .trim() ??
          '';
      final forceUpdate = isIos
          ? data['force_update_ios'] == true
          : data['force_update_android'] == true;
      final changeLog = data['change_log']?.toString().trim() ?? '';
      final releaseDate = data['release_date']?.toString().trim() ?? '';

      final outdated =
          latestVersion.isNotEmpty && isVersionOutdated(currentVersion, latestVersion);

      if (!outdated || downloadUrl.isEmpty) {
        if (showNoUpdateToast) {
          _showInfoSnackBar(
            messenger,
            'คุณกำลังใช้งานเวอร์ชันล่าสุด (v$currentVersion) เรียบร้อยแล้ว',
          );
        }
        return;
      }

      // ถ้าเป็นอัปเดตแบบปิดข้ามได้ และผู้ใช้เพิ่งกดปิดเวอร์ชันนี้ในรอบเปิดแอปนี้ ไม่ต้องเด้งซ้ำ
      if (!forceUpdate &&
          !showNoUpdateToast &&
          _dismissedOptionalVersion == latestVersion) {
        return;
      }

      final dialogContext = context != null && context.mounted
          ? context
          : main_app.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) return;

      _showUpdateDialog(
        context: dialogContext,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        forceUpdate: forceUpdate,
        changeLog: changeLog,
        releaseDate: releaseDate,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking update: $e');
      if (showNoUpdateToast) {
        try {
          final info = await PackageInfo.fromPlatform();
          _showInfoSnackBar(messenger, 'เวอร์ชันปัจจุบัน: v${info.version}');
        } catch (_) {}
      }
    } finally {
      _isCheckingUpdate = false;
    }
  }

  static void _showInfoSnackBar(ScaffoldMessengerState? messenger, String message) {
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1C1C1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required bool forceUpdate,
    required String changeLog,
    required String releaseDate,
  }) {
    _isDialogVisible = true;
    StreamSubscription<OtaEvent>? otaSub;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        String progress = '';
        bool isDownloading = false;
        String? otaError;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return PopScope(
              canPop: !forceUpdate && !isDownloading,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop && !forceUpdate) {
                  _dismissedOptionalVersion = latestVersion;
                }
              },
              child: AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: (forceUpdate
                            ? Colors.redAccent
                            : const Color(0xFFD2E862))
                        .withValues(alpha: 0.35),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(
                      forceUpdate
                          ? Icons.system_update_rounded
                          : Icons.new_releases_rounded,
                      color: forceUpdate
                          ? Colors.redAccent
                          : const Color(0xFFD2E862),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        forceUpdate
                            ? 'จำเป็นต้องอัปเดตแอป'
                            : 'มีอัปเดตเวอร์ชันใหม่!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v$currentVersion  →  v$latestVersion',
                            style: const TextStyle(
                              color: Color(0xFFD2E862),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (releaseDate.isNotEmpty)
                          Text(
                            'วันที่อัปเดต: $releaseDate',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isDownloading)
                      Text(
                        'กำลังดาวน์โหลดไฟล์อัปเดต... $progress%\nกรุณาอย่าปิดหน้าจอสักครู่ครับ',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      )
                    else ...[
                      Text(
                        forceUpdate
                            ? 'ผู้ดูแลระบบกำหนดให้ต้องอัปเดตเป็นเวอร์ชัน $latestVersion ก่อนเข้าใช้งานต่อครับ'
                            : 'พบแอปเวอร์ชัน $latestVersion คุณสามารถอัปเดตตอนนี้หรือกดข้ามไว้ก่อนได้ครับ',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                      if (changeLog.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'รายละเอียด: $changeLog',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                    if (otaError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        otaError!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!forceUpdate && !isDownloading)
                    TextButton(
                      onPressed: () {
                        _dismissedOptionalVersion = latestVersion;
                        Navigator.of(dialogCtx).pop();
                      },
                      child: const Text(
                        'ปิดข้ามไว้ก่อน',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  if (otaError != null && !isDownloading)
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse(downloadUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: const Text(
                        'เปิดลิงก์ในเบราว์เซอร์',
                        style: TextStyle(color: Color(0xFF7DD3FC)),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDownloading
                          ? Colors.grey
                          : const Color(0xFFD2E862),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isDownloading
                        ? null
                        : () async {
                            if (Platform.isIOS) {
                              final uri = Uri.parse(downloadUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                              if (!forceUpdate && dialogCtx.mounted) {
                                _dismissedOptionalVersion = latestVersion;
                                Navigator.of(dialogCtx).pop();
                              }
                              return;
                            }

                            setStateDialog(() {
                              isDownloading = true;
                              progress = '0';
                              otaError = null;
                            });

                            try {
                              await otaSub?.cancel();
                              otaSub = OtaUpdate()
                                  .execute(
                                    downloadUrl,
                                    destinationFilename:
                                        'wallcraft_update_$latestVersion.apk',
                                  )
                                  .listen(
                                    (OtaEvent event) {
                                      if (!dialogCtx.mounted) return;
                                      if (event.status == OtaStatus.DOWNLOADING) {
                                        setStateDialog(() {
                                          progress = event.value ?? progress;
                                        });
                                      } else if (event.status ==
                                              OtaStatus.INSTALLING ||
                                          event.status ==
                                              OtaStatus.INSTALLATION_DONE) {
                                        if (!forceUpdate && dialogCtx.mounted) {
                                          Navigator.of(dialogCtx).pop();
                                        } else {
                                          setStateDialog(() {
                                            isDownloading = false;
                                          });
                                        }
                                      } else {
                                        setStateDialog(() {
                                          isDownloading = false;
                                          otaError =
                                              'ดาวน์โหลดอัตโนมัติไม่สำเร็จ ลองกดอีกครั้งหรือเปิดในเบราว์เซอร์';
                                        });
                                      }
                                    },
                                    onError: (err) {
                                      if (!dialogCtx.mounted) return;
                                      setStateDialog(() {
                                        isDownloading = false;
                                        otaError =
                                            'ไม่สามารถดาวน์โหลดไฟล์ได้ ลองเปิดผ่านเบราว์เซอร์แทนครับ';
                                      });
                                    },
                                  );
                            } catch (e) {
                              debugPrint('OTA Update failed: $e');
                              if (!dialogCtx.mounted) return;
                              setStateDialog(() {
                                isDownloading = false;
                                otaError =
                                    'เริ่มการดาวน์โหลดไม่สำเร็จ ลองเปิดในเบราว์เซอร์แทนครับ';
                              });
                            }
                          },
                    child: Text(
                      isDownloading ? 'กำลังโหลด...' : 'อัปเดตเลย',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      otaSub?.cancel();
      _isDialogVisible = false;
    });
  }
}
