import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/customer_directory_service.dart';

class CustomerDirectoryPage extends StatefulWidget {
  final int initialTabIndex;
  const CustomerDirectoryPage({super.key, this.initialTabIndex = 0});

  @override
  State<CustomerDirectoryPage> createState() => _CustomerDirectoryPageState();
}

class _CustomerDirectoryPageState extends State<CustomerDirectoryPage> {
  // Monochrome Dark Luxury palette (matching ProfileScreen)
  static const Color _bgColor = Color(0xFF0C0C0E);
  static const Color _surfaceColor = Color(0xFF161618);
  static const Color _elevatedColor = Color(0xFF232328);
  static const Color _borderColor = Color(0xFF242428);
  static const Color _accentWhite = Color(0xFFF4F4F5);

  final TextEditingController _searchCtrl = TextEditingController();

  late int _activeTab; // 0 = directory, 1 = call logs
  bool _loadingContacts = true;
  bool _loadingLogs = true;
  bool _syncingAndroid = false;
  bool _migrationRequired = false;
  String? _contactsError;
  String? _logsError;

  List<CustomerContact> _contacts = [];
  List<CustomerCallLog> _callLogs = [];
  CallLogsSummary _summary = const CallLogsSummary();
  CallerIdStatus _callerIdStatus = CallerIdStatus(
    supported: CustomerDirectoryService.isAndroidNative,
  );

  String _selectedCategory = 'all';
  String _logScope = 'mine';
  int _logDays = 30;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex.clamp(0, 1);
    _initLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    final cached = await CustomerDirectoryService.loadCachedDirectory();
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _contacts = cached;
        _loadingContacts = false;
      });
    }
    await Future.wait([
      _refreshCallerIdStatus(),
      _loadDirectory(forceSyncAndroid: true),
      _loadCallLogs(),
    ]);
  }

  Future<void> _refreshCallerIdStatus() async {
    final status = await CustomerDirectoryService.getCallerIdStatus();
    if (mounted) {
      setState(() => _callerIdStatus = status);
    }
  }

  Future<void> _loadDirectory({bool forceSyncAndroid = false}) async {
    if (_contacts.isEmpty && mounted) {
      setState(() {
        _loadingContacts = true;
        _contactsError = null;
      });
    }
    try {
      final list = await CustomerDirectoryService.fetchDirectory(
        pushToNative: true,
      );
      if (mounted) {
        setState(() {
          _contacts = list;
          _loadingContacts = false;
          _contactsError = null;
        });
      }
      if (forceSyncAndroid && CustomerDirectoryService.isAndroidNative) {
        final synced = await CustomerDirectoryService.syncAndroidCallLogs(
          knownContacts: list,
        );
        if (synced > 0 && mounted) {
          await _loadCallLogs();
        }
        await _refreshCallerIdStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingContacts = false;
          _contactsError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadCallLogs() async {
    if (mounted) {
      setState(() {
        _loadingLogs = true;
        _logsError = null;
      });
    }
    try {
      final res = await CustomerDirectoryService.fetchCallLogs(
        scope: _logScope,
        days: _logDays,
      );
      if (mounted) {
        setState(() {
          _callLogs = res.logs;
          _summary = res.summary;
          _migrationRequired = res.migrationRequired;
          _loadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
          _logsError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _syncAndroidCallsNow() async {
    if (!CustomerDirectoryService.isAndroidNative) return;
    setState(() => _syncingAndroid = true);
    try {
      var status = await CustomerDirectoryService.getCallerIdStatus();
      if (!status.hasCallLogPermission) {
        status = await CustomerDirectoryService.requestCallerIdPermissions();
        if (mounted) setState(() => _callerIdStatus = status);
      }
      if (!status.hasCallLogPermission) {
        _showSnack('กรุณาอนุญาตสิทธิ์ประวัติการโทร (Call Log) ก่อนซิงค์');
        return;
      }

      if (_contacts.isEmpty) {
        await _loadDirectory();
      }

      final count = await CustomerDirectoryService.syncAndroidCallLogs(
        knownContacts: _contacts,
      );
      await _loadCallLogs();
      await _refreshCallerIdStatus();
      _showSnack(
        count > 0
            ? 'ซิงค์สายเข้าระบบเรียบร้อย ($count รายการ)'
            : 'ประวัติสายโทรอัปเดตล่าสุดแล้ว',
      );
    } catch (e) {
      _showSnack('ซิงค์ไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _syncingAndroid = false);
    }
  }

  Future<void> _requestAndroidCallerIdSetup() async {
    final status = await CustomerDirectoryService.requestCallerIdPermissions();
    if (!mounted) return;
    setState(() => _callerIdStatus = status);

    if (status.isFullyReady) {
      await _loadDirectory(forceSyncAndroid: true);
      _showSnack('เปิดใช้งาน Caller ID + ซิงค์อัตโนมัติเรียบร้อยแล้ว');
    } else {
      _showSnack(
        'สิทธิ์ที่ยังขาด: ${!status.hasNotificationPermission ? "แจ้งเตือน " : ""}'
        '${!status.hasCallLogPermission ? "ประวัติโทร " : ""}'
        '${status.supportsCallScreeningRole && !status.hasCallScreeningRole ? "Caller ID" : ""}',
      );
    }
  }

  Future<void> _testNotificationBanner() async {
    if (!CustomerDirectoryService.isAndroidNative) return;
    if (!_callerIdStatus.hasNotificationPermission) {
      await _requestAndroidCallerIdSetup();
    }
    final ok = await CustomerDirectoryService.showTestCallerIdNotification(
      sampleContact: _contacts.isNotEmpty ? _contacts.first : null,
    );
    _showSnack(
      ok
          ? 'ส่งแจ้งเตือนทดสอบแล้ว (ดูแถบแจ้งเตือนด้านบน)'
          : 'กรุณาเปิดสิทธิ์การแจ้งเตือนของแอปก่อน',
    );
  }

  Future<void> _dialCustomer({
    required String phone,
    String? contactId,
    required String displayName,
    String companyName = '',
  }) async {
    final norm = normalizeThaiPhone(phone);
    if (norm.isEmpty) {
      _showSnack('เบอร์โทรไม่ถูกต้อง');
      return;
    }

    CustomerCallLog? createdLog;
    try {
      createdLog = await CustomerDirectoryService.logCall(
        phone: norm,
        contactId: contactId,
        contactName: displayName,
        companyName: companyName,
        callDirection: 'outgoing',
        callSource: 'in_app_dial',
        durationSec: 0,
        outcome: 'unknown',
      );
      unawaited(_loadCallLogs());
    } catch (_) {}

    final telUri = Uri(scheme: 'tel', path: norm);
    final launched = await launchUrl(telUri);
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: formatThaiPhoneDisplay(norm)));
      _showSnack('อุปกรณ์นี้โทรออกไม่ได้ คัดลอกเบอร์ไว้ให้แล้ว');
    }

    if (mounted && createdLog != null) {
      await _openCallOutcomeSheet(createdLog, isAfterDial: true);
    }
  }

  Future<void> _openCallerIdSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final isAndroid = CustomerDirectoryService.isAndroidNative;
        final ready = _callerIdStatus.isFullyReady;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    ready ? Icons.verified_user_outlined : Icons.tune_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'ตั้งค่า Caller ID & ซิงค์สาย',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isAndroid)
                Text(
                  'บน iPhone / Web ระบบจะบันทึกสายเมื่อกดโทรออกจากแอป และจดโน้ตหลังวางสายได้ทันที',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                )
              else ...[
                _statusRow('สิทธิ์ประวัติโทร (Call Log)', _callerIdStatus.hasCallLogPermission),
                _statusRow('สิทธิ์สถานะวางสาย (Phone State)', _callerIdStatus.hasPhoneStatePermission),
                _statusRow('สิทธิ์แสดงแจ้งเตือนสายเข้า', _callerIdStatus.hasNotificationPermission),
                if (_callerIdStatus.supportsCallScreeningRole)
                  _statusRow('บทบาท Caller ID (Call Screening)', _callerIdStatus.hasCallScreeningRole),
                const SizedBox(height: 8),
                Text(
                  'สมุดเบอร์ในเครื่อง ${_callerIdStatus.directoryCount} เบอร์ • วางสายแล้วส่งขึ้นหลังบ้านอัตโนมัติ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (!ready) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentWhite,
                        foregroundColor: _bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _requestAndroidCallerIdSetup();
                      },
                      icon: const Icon(Icons.security_rounded, size: 18),
                      label: const Text('อนุญาตสิทธิ์ที่ยังขาด', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: _borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _testNotificationBanner();
                        },
                        icon: const Icon(Icons.notifications_none_rounded, size: 17),
                        label: const Text('ทดสอบแจ้งเตือน'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: _borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _syncAndroidCallsNow();
                        },
                        icon: const Icon(Icons.sync_rounded, size: 17),
                        label: const Text('ซิงค์สายตอนนี้'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(String label, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: granted ? const Color(0xFF9CA3AF) : Colors.amber[300],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: granted ? Colors.white70 : Colors.amber[200],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContactDetailSheet(CustomerContact c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    child: Text(
                      _contactInitial(c),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.displayName.isNotEmpty ? c.displayName : c.phoneDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (c.companyName.isNotEmpty && c.companyName != c.displayName)
                          Text(
                            c.companyName,
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      c.categoryLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Colors.white54),
                        const SizedBox(width: 8),
                        Text(
                          c.phoneDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (c.orderCount > 0)
                          Text(
                            '${c.orderCount} ออเดอร์',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                      ],
                    ),
                    if (c.ownerSaleName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            'เซลส์ดูแล: ${c.ownerSaleName}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                    if (c.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes_rounded, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.notes,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (c.projectNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'โครงการที่เกี่ยวข้อง',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: c.projectNames.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _elevatedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: _borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: c.phoneDisplay));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSnack('คัดลอกเบอร์ ${c.phoneDisplay} แล้ว');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('คัดลอก'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentWhite,
                        foregroundColor: _bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _dialCustomer(
                          phone: c.phoneNormalized,
                          contactId: c.id,
                          displayName: c.displayName,
                          companyName: c.companyName,
                        );
                      },
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text(
                        'โทรออก',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCallOutcomeSheet(
    CustomerCallLog log, {
    bool isAfterDial = false,
  }) async {
    String selectedOutcome =
        log.outcome == 'unknown' && isAfterDial ? 'connected' : log.outcome;
    final noteCtrl = TextEditingController(text: log.note);
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    isAfterDial ? 'บันทึกผลคุยสายหลังโทร' : 'แก้ไขโน้ต & ผลคุยสาย',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.contactName.isNotEmpty ? log.contactName : log.phoneDisplay} • ${log.phoneDisplay}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _outcomeChip('connected', 'คุยสำเร็จ', selectedOutcome,
                          (v) => setModalState(() => selectedOutcome = v)),
                      _outcomeChip('follow_up', 'ติดตามต่อ', selectedOutcome,
                          (v) => setModalState(() => selectedOutcome = v)),
                      _outcomeChip('no_answer', 'ไม่รับสาย', selectedOutcome,
                          (v) => setModalState(() => selectedOutcome = v)),
                      _outcomeChip('busy', 'สายไม่ว่าง', selectedOutcome,
                          (v) => setModalState(() => selectedOutcome = v)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'จดสรุปสิ่งที่คุย / โครงการ / นัดหมาย...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentWhite,
                        foregroundColor: _bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                await CustomerDirectoryService.updateCallLog(
                                  id: log.id,
                                  outcome: selectedOutcome,
                                  note: noteCtrl.text,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                await _loadCallLogs();
                                _showSnack('บันทึกผลคุยสายแล้ว');
                              } catch (e) {
                                setModalState(() => saving = false);
                                _showSnack(
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            },
                      child: Text(
                        saving ? 'กำลังบันทึก...' : 'บันทึก',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    noteCtrl.dispose();
  }

  Widget _outcomeChip(
    String value,
    String label,
    String current,
    ValueChanged<String> onSelect,
  ) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(value),
      selectedColor: _accentWhite,
      backgroundColor: _bgColor,
      labelStyle: TextStyle(
        color: selected ? _bgColor : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? _accentWhite : _borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Future<void> _openSuggestContactDialog() async {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'architect';
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final inset = MediaQuery.of(ctx).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 22 + inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'เพิ่มเบอร์ลูกค้าใหม่เข้าสมุดกลาง',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ระบบจะส่งให้แอดมินอนุมัติขึ้น Caller ID กลางให้ทั้งทีม',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  _darkField(phoneCtrl, 'เบอร์โทร * (เช่น 081-234-5678)',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  _darkField(nameCtrl, 'ชื่อผู้ติดต่อ / ชื่อลูกค้า *'),
                  const SizedBox(height: 10),
                  _darkField(companyCtrl, 'บริษัท / สตูดิโอ (ถ้ามี)'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    dropdownColor: _surfaceColor,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'ประเภทลูกค้า',
                      labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _borderColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'architect', child: Text('Architect')),
                      DropdownMenuItem(value: 'interior', child: Text('Interior')),
                      DropdownMenuItem(value: 'contractor', child: Text('Contractor / ผู้รับเหมา')),
                      DropdownMenuItem(value: 'owner', child: Text('เจ้าของโครงการ')),
                      DropdownMenuItem(value: 'project', child: Text('งานโครงการ')),
                      DropdownMenuItem(value: 'general', child: Text('ลูกค้าทั่วไป')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  _darkField(noteCtrl, 'ชื่อโครงการ / หมายเหตุ', maxLines: 2),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentWhite,
                        foregroundColor: _bgColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (phoneCtrl.text.trim().isEmpty ||
                                  nameCtrl.text.trim().isEmpty) {
                                _showSnack('กรุณากรอกเบอร์โทรและชื่อลูกค้าให้ครบ');
                                return;
                              }
                              setModalState(() => submitting = true);
                              try {
                                final msg = await CustomerDirectoryService
                                    .suggestContact(
                                  phone: phoneCtrl.text,
                                  displayName: nameCtrl.text,
                                  companyName: companyCtrl.text,
                                  contactCategory: category,
                                  notes: noteCtrl.text,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showSnack(msg);
                              } catch (e) {
                                setModalState(() => submitting = false);
                                _showSnack(
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            },
                      child: Text(
                        submitting ? 'กำลังส่ง...' : 'ส่งเพิ่มเบอร์',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    phoneCtrl.dispose();
    nameCtrl.dispose();
    companyCtrl.dispose();
    noteCtrl.dispose();
  }

  Widget _darkField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surfaceColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<CustomerContact> get _filteredContacts {
    final q = _searchCtrl.text.trim().toLowerCase();
    final qDigits = normalizeThaiPhone(q);
    return _contacts.where((c) {
      if (_selectedCategory != 'all' &&
          c.contactCategory.toLowerCase() != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        c.displayName,
        c.companyName,
        c.phoneDisplay,
        c.phoneNormalized,
        c.ownerSaleName,
        ...c.projectNames,
      ].join(' ').toLowerCase();
      if (hay.contains(q)) return true;
      if (qDigits.isNotEmpty && c.phoneNormalized.contains(qDigits)) return true;
      return false;
    }).toList();
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '-';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} $hh:$mm';
  }

  String _contactInitial(CustomerContact c) {
    final source = (c.displayName.isNotEmpty ? c.displayName : c.phoneDisplay).trim();
    if (source.isEmpty) return '?';
    final cleaned = source
        .replaceFirst(RegExp(r'^(บริษัท|บจก\.|หจก\.|คุณ)\s*'), '')
        .trim();
    final target = cleaned.isNotEmpty ? cleaned : source;
    return target.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final showSetupBanner = CustomerDirectoryService.isAndroidNative &&
        !_callerIdStatus.hasMandatoryPermissions;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 4,
        title: const Text(
          'สมุดเบอร์ & โทรคุย',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'ตั้งค่า Caller ID & ซิงค์สาย',
            onPressed: _openCallerIdSettingsSheet,
            icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 21),
          ),
          IconButton(
            tooltip: 'เพิ่มเบอร์ใหม่',
            onPressed: _openSuggestContactDialog,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calm monochrome pill switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  _pillTab(0, 'สมุดเบอร์ (${_contacts.length})'),
                  _pillTab(1, 'ประวัติโทร (${_callLogs.length})'),
                ],
              ),
            ),
          ),
          if (showSetupBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _requestAndroidCallerIdSetup,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: Colors.grey[400], size: 17),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'เปิดสิทธิ์ Caller ID + เก็บสายอัตโนมัติ',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ),
                      const Text(
                        'เปิดเลย →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _activeTab == 0
                ? _buildDirectoryTab()
                : _buildCallLogsTab(),
          ),
        ],
      ),
    );
  }

  Widget _pillTab(int index, String label) {
    final selected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8.5),
          decoration: BoxDecoration(
            color: selected ? _elevatedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected ? Border.all(color: Colors.white12) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[500],
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryTab() {
    final filtered = _filteredContacts;
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: _surfaceColor,
      onRefresh: () => _loadDirectory(forceSyncAndroid: true),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ค้นหา ชื่อลูกค้า, บริษัท, เบอร์, โครงการ...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: 19),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded, color: Colors.grey[500], size: 18),
                      )
                    : null,
                filled: true,
                fillColor: _surfaceColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _catPill('all', 'ทั้งหมด'),
                _catPill('architect', 'Architect'),
                _catPill('interior', 'Interior'),
                _catPill('contractor', 'Contractor'),
                _catPill('project', 'งานโครงการ'),
                _catPill('owner', 'เจ้าของโครงการ'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingContacts && _contacts.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                : _contactsError != null && _contacts.isEmpty
                    ? _errorBox(_contactsError!, () => _loadDirectory())
                    : filtered.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Icon(Icons.contact_phone_outlined,
                                  color: Colors.grey[700], size: 40),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  'ไม่พบรายชื่อที่ค้นหา',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 7),
                            itemBuilder: (_, i) => _buildMinimalContactRow(filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _catPill(String value, String label) {
    final active = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _elevatedColor : _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.white24 : _borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey[500],
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalContactRow(CustomerContact c) {
    final subtitleParts = <String>[c.phoneDisplay];
    if (c.projectNames.isNotEmpty) {
      subtitleParts.add(c.projectNames.first);
    } else if (c.companyName.isNotEmpty && c.companyName != c.displayName) {
      subtitleParts.add(c.companyName);
    }

    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openContactDetailSheet(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                child: Text(
                  _contactInitial(c),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.displayName.isNotEmpty ? c.displayName : c.phoneDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.categoryLabel,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _dialCustomer(
                  phone: c.phoneNormalized,
                  contactId: c.id,
                  displayName: c.displayName,
                  companyName: c.companyName,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Icon(Icons.call_outlined, color: Colors.white70, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallLogsTab() {
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: _surfaceColor,
      onRefresh: _loadCallLogs,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _scopePill('mine', 'ของฉัน'),
                const SizedBox(width: 6),
                _scopePill('team', 'ทั้งทีม'),
                const Spacer(),
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _logDays,
                      dropdownColor: _surfaceColor,
                      iconEnabledColor: Colors.grey[400],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 วัน')),
                        DropdownMenuItem(value: 30, child: Text('30 วัน')),
                        DropdownMenuItem(value: 90, child: Text('90 วัน')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _logDays = v);
                          _loadCallLogs();
                        }
                      },
                    ),
                  ),
                ),
                if (CustomerDirectoryService.isAndroidNative) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _syncingAndroid ? null : _syncAndroidCallsNow,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        children: [
                          if (_syncingAndroid)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            )
                          else
                            const Icon(Icons.sync_rounded, color: Colors.white70, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            _syncingAndroid ? 'ซิงค์...' : 'ซิงค์',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('รวม ${_summary.total} สาย',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('ออก ${_summary.outgoing}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  Text('เข้า ${_summary.incoming}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  Text('พลาด ${_summary.missed}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _migrationRequired
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Text(
                        'รอแอดมินรัน SQL สร้างตาราง customer_call_logs ใน Supabase ครั้งแรก',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  )
                : _loadingLogs && _callLogs.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                    : _logsError != null && _callLogs.isEmpty
                        ? _errorBox(_logsError!, _loadCallLogs)
                        : _callLogs.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Icon(Icons.history_rounded,
                                      color: Colors.grey[700], size: 40),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: Text(
                                      'ยังไม่มีประวัติการโทรในช่วงเวลานี้',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                                itemCount: _callLogs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 7),
                                itemBuilder: (_, i) => _buildMinimalCallLogRow(_callLogs[i]),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _scopePill(String value, String label) {
    final active = _logScope == value;
    return GestureDetector(
      onTap: () {
        if (_logScope == value) return;
        setState(() => _logScope = value);
        _loadCallLogs();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _elevatedColor : _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? Colors.white24 : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey[500],
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalCallLogRow(CustomerCallLog log) {
    final IconData dirIcon;
    final Color dirColor;
    switch (log.callDirection) {
      case 'incoming':
        dirIcon = Icons.call_received_rounded;
        dirColor = const Color(0xFF93C5FD);
        break;
      case 'missed':
        dirIcon = Icons.call_missed_rounded;
        dirColor = const Color(0xFFFCA5A5);
        break;
      default:
        dirIcon = Icons.call_made_rounded;
        dirColor = Colors.white70;
    }

    final title = log.contactName.isNotEmpty && log.contactName != 'เบอร์นอกสมุด'
        ? log.contactName
        : log.phoneDisplay;
    final durationText = log.durationSec > 0
        ? formatCallDurationThai(log.durationSec)
        : (log.callDirection == 'missed' ? 'ไม่รับสาย' : 'ไม่ติด/วางไว');

    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openCallOutcomeSheet(log),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                child: Icon(dirIcon, color: dirColor, size: 17),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatShortDate(log.startedAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${log.phoneDisplay} • $durationText'
                      '${_logScope == "team" && log.saleName.isNotEmpty ? " • ${log.saleName}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    if (log.note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'โน้ต: ${log.note}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'โทรซ้ำ',
                visualDensity: VisualDensity.compact,
                onPressed: () => _dialCustomer(
                  phone: log.phoneNormalized,
                  contactId: log.contactId,
                  displayName: title,
                  companyName: log.companyName,
                ),
                icon: const Icon(Icons.call_outlined, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[300])),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentWhite,
                foregroundColor: _bgColor,
              ),
              onPressed: onRetry,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
