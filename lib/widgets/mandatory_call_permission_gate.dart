import 'dart:async';
import 'package:flutter/material.dart';
import '../services/customer_directory_service.dart';

/// Mandatory startup permission gate on Android:
/// Requests Call Log, Phone State, Notification, and Caller ID permissions immediately
/// on launch. If any mandatory permission is denied, blocks app interaction with a
/// non-dismissible modal until permissions are granted (in-app or via App Settings).
class MandatoryCallPermissionGate {
  static bool _isDialogShowing = false;

  static Future<void> ensureGrantedOrBlock(BuildContext context) async {
    if (!CustomerDirectoryService.isAndroidNative) return;
    if (_isDialogShowing || !context.mounted) return;

    var status = await CustomerDirectoryService.getCallerIdStatus();
    if (status.hasMandatoryPermissions) {
      return;
    }

    // Request permissions immediately on first launch / missing permission
    status = await CustomerDirectoryService.requestCallerIdPermissions();
    if (status.hasMandatoryPermissions) {
      unawaited(CustomerDirectoryService.syncDirectoryAndCallLogs(force: true));
      return;
    }

    if (!context.mounted) return;
    _isDialogShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        builder: (_) => _MandatoryPermissionDialog(initialStatus: status),
      );
    } finally {
      _isDialogShowing = false;
    }
  }
}

class _MandatoryPermissionDialog extends StatefulWidget {
  final CallerIdStatus initialStatus;
  const _MandatoryPermissionDialog({required this.initialStatus});

  @override
  State<_MandatoryPermissionDialog> createState() =>
      _MandatoryPermissionDialogState();
}

class _MandatoryPermissionDialogState extends State<_MandatoryPermissionDialog>
    with WidgetsBindingObserver {
  static const Color _cardBg = Color(0xFF15171E);
  static const Color _cardBorder = Color(0xFF282C3A);
  static const Color _lime = Color(0xFFD2E862);

  late CallerIdStatus _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recheckStatus());
    }
  }

  Future<void> _recheckStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final latest = await CustomerDirectoryService.getCallerIdStatus();
      if (!mounted) return;
      setState(() {
        _status = latest;
        _checking = false;
      });
      if (latest.hasMandatoryPermissions) {
        unawaited(
          CustomerDirectoryService.syncDirectoryAndCallLogs(force: true),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _requestAgain() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final latest = await CustomerDirectoryService.requestCallerIdPermissions();
      if (!mounted) return;
      setState(() {
        _status = latest;
        _checking = false;
      });
      if (latest.hasMandatoryPermissions) {
        unawaited(
          CustomerDirectoryService.syncDirectoryAndCallLogs(force: true),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _cardBorder),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  color: Colors.orangeAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ต้องอนุญาตสิทธิ์ก่อนใช้งานแอป',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'แอป WallCraft ใช้งานระบบแสดงชื่อลูกค้า (Caller ID) และบันทึกประวัติการโทรของทีมขาย กรุณาเปิดสิทธิ์ให้ครบทั้ง 3 รายการด้านล่างครับ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1015),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  children: [
                    _permItem(
                      'ประวัติการโทร (Call Log)',
                      _status.hasCallLogPermission,
                    ),
                    const SizedBox(height: 8),
                    _permItem(
                      'สถานะโทรศัพท์ (Phone)',
                      _status.hasPhoneStatePermission,
                    ),
                    const SizedBox(height: 8),
                    _permItem(
                      'การแจ้งเตือน (Notifications)',
                      _status.hasNotificationPermission,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _checking ? null : _requestAgain,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 18),
                  label: Text(
                    _checking ? 'กำลังตรวจสอบ...' : 'อนุญาตสิทธิ์ตอนนี้',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: CustomerDirectoryService.openAppSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text(
                    'ไปที่หน้าตั้งค่าแอป (เปิดสิทธิ์เอง)',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'หากกดปิด popup ไปแล้ว ให้กด "ไปที่หน้าตั้งค่าแอป" -> การอนุญาต (Permissions) -> เปิด โทรศัพท์, บันทึกการโทร และ การแจ้งเตือน',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permItem(String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: granted ? Colors.greenAccent : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: granted ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: granted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          granted ? 'ผ่านแล้ว' : 'ยังไม่อนุญาต',
          style: TextStyle(
            color: granted ? Colors.greenAccent : Colors.orangeAccent,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
