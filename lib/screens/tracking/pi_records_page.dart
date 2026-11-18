// lib/screens/tracking/pi_records_page.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants.dart';
import '../../widgets/in_app_doc_viewer.dart';

enum PiRecordSortOption {
  recordDateDesc('วันที่บันทึก (ล่าสุด)'),
  recordDateAsc('วันที่บันทึก (เก่าสุด)'),
  lastUpdateDesc('อัปเดตล่าสุด'),
  dateOrderDesc('ลูกค้าชำระ (ล่าสุด)'),
  dateOrderAsc('ลูกค้าชำระ (เก่าสุด)'),
  deliveredDateAsc('วันสินค้าถึง (เร็ว→ช้า)'),
  deliveredDateDesc('วันสินค้าถึง (ล่าสุด)'),
  statusPendingFirst('สถานะ: งานค้าง→เสร็จ'),
  statusDoneFirst('สถานะ: เสร็จ→งานค้าง'),
  orderNoAsc('เลข Order (A–Z)'),
  saleNameAsc('ชื่อเซลล์ (ก–ฮ)');

  const PiRecordSortOption(this.label);
  final String label;
}

class PiRecordsPage extends StatefulWidget {
  const PiRecordsPage({super.key});

  static DateTime? parseFlexibleDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return null;

    final dateToken = trimmed.split(RegExp(r'\s+')).first;
    final slashParts = dateToken.split('/');
    if (slashParts.length == 3) {
      final first = int.tryParse(slashParts[0]);
      final second = int.tryParse(slashParts[1]);
      int? year = int.tryParse(slashParts[2]);
      if (first != null && second != null && year != null) {
        if (year < 100) {
          year += 2000;
        } else if (year > 2400) {
          year -= 543;
        }
        int day;
        int month;
        if (second > 12 && first >= 1 && first <= 12) {
          month = first;
          day = second;
        } else {
          day = first;
          month = second;
        }
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
        return null;
      }
    }

    final isoParsed = DateTime.tryParse(trimmed);
    if (isoParsed != null) return isoParsed;

    final dashParts = dateToken.split('-');
    if (dashParts.length == 3 && dashParts[0].length <= 2) {
      final day = int.tryParse(dashParts[0]);
      final month = int.tryParse(dashParts[1]);
      int? year = int.tryParse(dashParts[2]);
      if (day != null && month != null && year != null) {
        if (year < 100) {
          year += 2000;
        } else if (year > 2400) {
          year -= 543;
        }
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  static const int missingStatusRank = 99;

  static int statusWorkflowRank(String? etd) {
    final normalized = (etd ?? '').trim().toLowerCase();
    if (normalized.isEmpty || normalized == '-') return missingStatusRank;

    const orderedPatterns = <MapEntry<List<String>, int>>[
      MapEntry(['รอสั่ง', 'pending order'], 1),
      MapEntry(['รอชำระ', 'payment', 'unpaid'], 2),
      MapEntry(['รอโรงงานส่งมา warehouse', 'รอโรงงาน'], 3),
      MapEntry(['โรงงานกำลังส่ง', 'กำลังส่ง', 'shipping', 'transit'], 4),
      MapEntry(['ถึง warehouse', 'warehouse แล้ว'], 5),
      MapEntry(['อยู่ในสต๊อก', 'สต๊อก', 'stock'], 6),
      MapEntry(['รอส่งให้ลูกค้า', 'รอส่งลูกค้า'], 7),
      MapEntry(['ถึงลูกค้า', 'delivered'], 8),
      MapEntry(['event', 'อีเวนต์'], 9),
    ];

    for (final entry in orderedPatterns) {
      if (entry.key.any(normalized.contains)) {
        return entry.value;
      }
    }
    return 50;
  }

  static String _readField(
    dynamic item,
    String camelKey, [
    String? snakeKey,
  ]) {
    if (item is! Map) return '';
    final raw = item[camelKey] ?? (snakeKey != null ? item[snakeKey] : null);
    final text = (raw ?? '').toString().trim();
    return text == '-' ? '' : text;
  }

  static int _compareNullableDates(
    DateTime? a,
    DateTime? b, {
    required bool descending,
  }) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }

  static int _compareNullableStrings(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 0;
    if (a.isEmpty) return 1;
    if (b.isEmpty) return -1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static void sortRecords(
    List<dynamic> records,
    PiRecordSortOption option,
  ) {
    records.sort((a, b) {
      int primary = 0;
      switch (option) {
        case PiRecordSortOption.recordDateDesc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'recordDate', 'record_date')),
            parseFlexibleDate(_readField(b, 'recordDate', 'record_date')),
            descending: true,
          );
        case PiRecordSortOption.recordDateAsc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'recordDate', 'record_date')),
            parseFlexibleDate(_readField(b, 'recordDate', 'record_date')),
            descending: false,
          );
        case PiRecordSortOption.lastUpdateDesc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'lastUpdate', 'last_update')),
            parseFlexibleDate(_readField(b, 'lastUpdate', 'last_update')),
            descending: true,
          );
        case PiRecordSortOption.dateOrderDesc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'dateOrder', 'date_order')),
            parseFlexibleDate(_readField(b, 'dateOrder', 'date_order')),
            descending: true,
          );
        case PiRecordSortOption.dateOrderAsc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'dateOrder', 'date_order')),
            parseFlexibleDate(_readField(b, 'dateOrder', 'date_order')),
            descending: false,
          );
        case PiRecordSortOption.deliveredDateAsc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'deliveredDate', 'delivered_date')),
            parseFlexibleDate(_readField(b, 'deliveredDate', 'delivered_date')),
            descending: false,
          );
        case PiRecordSortOption.deliveredDateDesc:
          primary = _compareNullableDates(
            parseFlexibleDate(_readField(a, 'deliveredDate', 'delivered_date')),
            parseFlexibleDate(_readField(b, 'deliveredDate', 'delivered_date')),
            descending: true,
          );
        case PiRecordSortOption.statusPendingFirst:
          final rankA = statusWorkflowRank(_readField(a, 'etd'));
          final rankB = statusWorkflowRank(_readField(b, 'etd'));
          primary = rankA.compareTo(rankB);
        case PiRecordSortOption.statusDoneFirst:
          final rankA = statusWorkflowRank(_readField(a, 'etd'));
          final rankB = statusWorkflowRank(_readField(b, 'etd'));
          if (rankA >= 50 && rankB >= 50) {
            primary = rankA.compareTo(rankB);
          } else if (rankA >= 50) {
            primary = 1;
          } else if (rankB >= 50) {
            primary = -1;
          } else {
            primary = rankB.compareTo(rankA);
          }
        case PiRecordSortOption.orderNoAsc:
          primary = _compareNullableStrings(
            _readField(a, 'orderNo', 'order_no'),
            _readField(b, 'orderNo', 'order_no'),
          );
        case PiRecordSortOption.saleNameAsc:
          primary = _compareNullableStrings(
            _readField(a, 'saleName', 'sale_name'),
            _readField(b, 'saleName', 'sale_name'),
          );
      }
      if (primary != 0) return primary;

      return _compareNullableDates(
        parseFlexibleDate(_readField(a, 'recordDate', 'record_date')),
        parseFlexibleDate(_readField(b, 'recordDate', 'record_date')),
        descending: true,
      );
    });
  }

  @override
  State<PiRecordsPage> createState() => _PiRecordsPageState();
}

class _PiRecordsPageState extends State<PiRecordsPage> {
  List<dynamic> _allRecords = [];
  List<dynamic> _filteredRecords = [];
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ทั้งหมด';
  List<String> _statusFilters = ['ทั้งหมด'];
  String _selectedBrandFilter = 'ทั้งหมด';
  List<String> _brandFilters = ['ทั้งหมด'];
  String _selectedSaleFilter = 'ทั้งหมด';
  List<String> _saleFilters = ['ทั้งหมด'];
  PiRecordSortOption? _selectedSortOption;

  PiRecordSortOption get _effectiveSortOption =>
      _selectedSortOption ?? PiRecordSortOption.recordDateDesc;

  // Palette สีธีม Minimal Monochrome (Black & White)
  final Color _bgDark = const Color(0xFF0C0C0E);
  final Color _cardDark = const Color(0xFF161618);

  @override
  void initState() {
    super.initState();
    fetchPiRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchPiRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uri targetUrl = AppConfig.piRecordsUrl;
      debugPrint("🚀 [PiRecordsPage] กำลังดึงข้อมูลจาก: $targetUrl");

      http.Response response;
      try {
        response = await http.get(targetUrl);
      } catch (netErr) {
        // หากเชื่อมต่อ IP วงแลนไม่ได้ หรือรันบน Web Browser ลองเชื่อมต่อผ่าน localhost
        if (AppConfig.isLocalUrl(targetUrl) && !targetUrl.host.contains('localhost')) {
          final localUri = targetUrl.replace(host: 'localhost');
          debugPrint("🔄 [PiRecordsPage] ลองเชื่อมต่อผ่าน localhost: $localUri");
          response = await http.get(localUri);
          targetUrl = localUri;
        } else {
          rethrow;
        }
      }

      // หากเจอปัญหา 404 (เช่น ระบบเคยจำว่าสลับไป Production แล้ว แต่ Production ยังไม่มี API นี้)
      // ให้ลองดึงจาก BASE_URL ใน .env หรือ localhost:3000 อัตโนมัติ
      if (response.statusCode == 404) {
        final envBase = dotenv.env['BASE_URL']?.trim();
        if (envBase != null && envBase.isNotEmpty) {
          final envUri = Uri.parse('$envBase/pi-records');
          if (envUri != targetUrl) {
            debugPrint("🔄 [PiRecordsPage] 404 -> ลองดึงจาก .env BASE_URL: $envUri");
            try {
              final envRes = await http.get(envUri);
              if (envRes.statusCode == 200) {
                response = envRes;
                targetUrl = envUri;
              }
            } catch (_) {}
          }
        }

        // หากยังไม่ได้ ลอง localhost:3000
        if (response.statusCode == 404 && !targetUrl.host.contains('localhost')) {
          final localPort3000 = Uri.parse('http://localhost:3000/api/v1/pi-records');
          debugPrint("🔄 [PiRecordsPage] 404 -> ลองดึงจาก localhost:3000: $localPort3000");
          try {
            final locRes = await http.get(localPort3000);
            if (locRes.statusCode == 200) {
              response = locRes;
              targetUrl = localPort3000;
            }
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'] ?? [];

          // ดึงรายการสถานะ ETD, Brand และ เซลล์ผู้ดูแล (Sale) ทั้งหมดที่ไม่ซ้ำ
          final Set<String> statusSet = {};
          final Set<String> brandSet = {};
          final Set<String> saleSet = {};
          for (var item in data) {
            final etd = (item['etd'] ?? '').toString().trim();
            if (etd.isNotEmpty && etd != '-') {
              statusSet.add(etd);
            }
            final brand = (item['brand'] ?? '').toString().trim();
            if (brand.isNotEmpty && brand != '-') {
              brandSet.add(brand);
            }
            final sale = (item['saleName'] ?? item['sale_name'] ?? '').toString().trim();
            if (sale.isNotEmpty && sale != '-') {
              saleSet.add(sale);
            }
          }

          PiRecordsPage.sortRecords(data, PiRecordSortOption.recordDateDesc);

          if (mounted) {
            setState(() {
              _allRecords = data;
              _statusFilters = ['ทั้งหมด', ...statusSet];
              _brandFilters = ['ทั้งหมด', ...brandSet];
              _saleFilters = ['ทั้งหมด', ...saleSet];
              _isLoading = false;
            });
            _applyFilter();
          }
        } else {
          throw Exception(decoded['error'] ?? 'โหลดข้อมูลไม่สำเร็จ');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} (URL: $targetUrl)');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allRecords.where((item) {
        // กรองตามแบรนด์
        if (_selectedBrandFilter != 'ทั้งหมด') {
          final brand = (item['brand'] ?? '').toString().trim();
          if (brand != _selectedBrandFilter) return false;
        }

        // กรองตามหมวดหมู่สถานะ
        if (_selectedStatusFilter != 'ทั้งหมด') {
          final etd = (item['etd'] ?? '').toString().trim();
          if (etd != _selectedStatusFilter) return false;
        }

        // กรองตามเซลล์ผู้ดูแล (Sale)
        if (_selectedSaleFilter != 'ทั้งหมด') {
          final sale = (item['saleName'] ?? item['sale_name'] ?? '').toString().trim();
          if (sale != _selectedSaleFilter) return false;
        }

        // ค้นหาตามคำค้น
        if (query.isNotEmpty) {
          final pi = _fieldText(item, 'piSupplier', 'pi_supplier').toLowerCase();
          final orderNo = _fieldText(item, 'orderNo', 'order_no').toLowerCase();
          final project = _fieldText(item, 'projectName', 'project_name').toLowerCase();
          final supplier = _fieldText(item, 'supplier').toLowerCase();
          final sale = _fieldText(item, 'saleName', 'sale_name').toLowerCase();
          final brand = _fieldText(item, 'brand').toLowerCase();
          final etd = _fieldText(item, 'etd').toLowerCase();
          final shippingMethod = _fieldText(item, 'shippingMethod', 'shipping_method').toLowerCase();
          final dateOrder = _fieldText(item, 'dateOrder', 'date_order').toLowerCase();
          final deliveredDate = _fieldText(item, 'deliveredDate', 'delivered_date').toLowerCase();
          final lastUpdate = _fieldText(item, 'lastUpdate', 'last_update').toLowerCase();

          return pi.contains(query) ||
              orderNo.contains(query) ||
              project.contains(query) ||
              supplier.contains(query) ||
              sale.contains(query) ||
              brand.contains(query) ||
              etd.contains(query) ||
              shippingMethod.contains(query) ||
              dateOrder.contains(query) ||
              deliveredDate.contains(query) ||
              lastUpdate.contains(query);
        }

        return true;
      }).toList();

    PiRecordsPage.sortRecords(filtered, _effectiveSortOption);

    setState(() {
      _filteredRecords = filtered;
    });
  }

  String _cleanUrl(String? raw) {
    if (raw == null) return '';
    var text = raw.trim();
    final match = RegExp(r'^=HYPERLINK\(\s*"([^"]+)"', caseSensitive: false).firstMatch(text);
    if (match != null) {
      text = match.group(1) ?? text;
    }
    return text.trim();
  }

  String _formatShippingMethod(String? raw) {
    if (raw == null) return '-';
    final text = raw.trim();
    if (text.isEmpty || text == '-') return '-';
    final lower = text.toLowerCase();
    if (lower.contains('sea') || lower.contains('เรือ')) {
      return text.contains('🚢') ? text : '🚢 $text';
    } else if (lower.contains('air') || lower.contains('เครื่องบิน') || lower.contains('flight') || lower.contains('plane')) {
      return text.contains('✈️') ? text : '✈️ $text';
    } else if (lower.contains('truck') || lower.contains('land') || lower.contains('รถ') || lower.contains('บก')) {
      return text.contains('🚚') ? text : '🚚 $text';
    } else if (lower.contains('express') || lower.contains('ด่วน')) {
      return text.contains('⚡') ? text : '⚡ $text';
    }
    return text;
  }

  void _showImageModal(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: const Color(0xFF161618),
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 250,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                                SizedBox(height: 8),
                                Text('ไม่สามารถโหลดรูปภาพได้', style: TextStyle(color: Colors.white54, fontSize: 13)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _toEmbeddableUrl(String rawUrl) {
    final clean = _cleanUrl(rawUrl);
    // Google Drive: file/d/FILE_ID/view... -> /preview
    final driveMatch = RegExp(r'https?:\/\/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1);
      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    // Google Drive: open?id=FILE_ID -> /preview
    final driveOpenMatch = RegExp(r'https?:\/\/drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (driveOpenMatch != null) {
      final fileId = driveOpenMatch.group(1);
      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    // Google Sheets: spreadsheets/d/SHEET_ID... -> /preview
    final sheetMatch = RegExp(r'https?:\/\/docs\.google\.com\/spreadsheets\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (sheetMatch != null) {
      final sheetId = sheetMatch.group(1);
      return 'https://docs.google.com/spreadsheets/d/$sheetId/preview';
    }

    // Google Docs: document/d/DOC_ID... -> /preview
    final docMatch = RegExp(r'https?:\/\/docs\.google\.com\/document\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (docMatch != null) {
      final docId = docMatch.group(1);
      return 'https://docs.google.com/document/d/$docId/preview';
    }

    return clean.startsWith('http') ? clean : 'https://$clean';
  }

  String _toDirectDownloadUrl(String rawUrl) {
    final clean = _cleanUrl(rawUrl);
    final driveMatch = RegExp(r'https?:\/\/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    final driveOpenMatch = RegExp(r'https?:\/\/drive\.google\.com\/open\?id=([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (driveOpenMatch != null) {
      final fileId = driveOpenMatch.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    final sheetMatch = RegExp(r'https?:\/\/docs\.google\.com\/spreadsheets\/d\/([a-zA-Z0-9_-]+)').firstMatch(clean);
    if (sheetMatch != null) {
      final sheetId = sheetMatch.group(1);
      return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=pdf';
    }

    return clean.startsWith('http') ? clean : 'https://$clean';
  }

  String _getDocumentTypeLabel(String title, String rawUrl) {
    final lower = '$title $rawUrl'.toLowerCase();
    if (lower.contains('spreadsheets') || lower.contains('excel') || lower.contains('.xlsx') || lower.contains('.csv') || lower.contains('sheet')) {
      return 'ดาวน์โหลดตาราง';
    } else if (lower.contains('.pdf') || lower.contains('drive.google.com') || lower.contains('po')) {
      return 'ดาวน์โหลด PDF';
    } else if (lower.contains('.jpg') || lower.contains('.jpeg') || lower.contains('.png') || lower.contains('.webp')) {
      return 'บันทึกรูป';
    }
    return 'ดาวน์โหลดไฟล์';
  }

  Future<void> _shareDocument(String title, String rawUrl) async {
    final clean = _cleanUrl(rawUrl);
    final url = clean.startsWith('http') ? clean : 'https://$clean';
    try {
      await Share.share(
        'เอกสาร: $title\n$url',
        subject: title,
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('คัดลอกลิงก์เอกสารเรียบร้อยแล้ว', style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: Color(0xFF1E1E22),
          ),
        );
      }
    }
  }

  Future<void> _executeSaveDocument(
    BuildContext ctx,
    String title,
    String rawUrl,
    int count,
  ) async {
    final downloadUrl = _toDirectDownloadUrl(rawUrl);
    final filename = '${title.replaceAll(RegExp(r'[^\w\.-]'), '_')}_$count';

    try {
      if (kIsWeb) {
        triggerWebDownload(downloadUrl, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ดาวน์โหลด $title ($count รายการ) เรียบร้อยแล้ว',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E1E22),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กำลังบันทึก $title ($count รายการ)...', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E1E22),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึก: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSaveImagesDialog({
    required BuildContext parentContext,
    required String title,
    required String rawUrl,
    int maxItems = 1,
  }) {
    final isPdf = _getDocumentTypeLabel(title, rawUrl).contains('PDF');
    int selectedCount = 1;
    bool saveAsPdf = isPdf;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.download_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPdf ? 'ดาวน์โหลดเอกสาร PDF / รูปภาพ' : 'บันทึกรูปภาพ / เอกสาร',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 28),
                  Text(
                    isPdf ? 'เลือกรูปแบบการดาวน์โหลด:' : 'ต้องการบันทึกกี่รูป / กี่หน้า?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Option 1: PDF ฉบับเต็ม หรือ 1 รูป
                  InkWell(
                    onTap: () => setModalState(() {
                      saveAsPdf = true;
                      selectedCount = 1;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: saveAsPdf ? Colors.white.withOpacity(0.12) : const Color(0xFF26262A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: saveAsPdf ? Colors.white : Colors.white12,
                          width: saveAsPdf ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            saveAsPdf ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: saveAsPdf ? Colors.white : Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPdf
                                      ? 'ดาวน์โหลดไฟล์ PDF ฉบับเต็ม (ครบทุกหน้า 100%)'
                                      : 'บันทึก 1 รูป (หน้านี้ / รูปปัจจุบัน)',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  isPdf
                                      ? 'ไฟล์ PDF คมชัด เหมาะสำหรับสั่งพิมพ์ หรือแชร์ส่ง LINE'
                                      : 'ดาวน์โหลดเฉพาะรูปหรือหน้าที่กำลังเปิดดู',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Option 2: บันทึกเป็นรูปภาพ (ระบุจำนวนรูป)
                  InkWell(
                    onTap: () => setModalState(() {
                      saveAsPdf = false;
                      if (selectedCount <= 1 && maxItems > 1) selectedCount = maxItems;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: !saveAsPdf ? Colors.white.withOpacity(0.12) : const Color(0xFF26262A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !saveAsPdf ? Colors.white : Colors.white12,
                          width: !saveAsPdf ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                !saveAsPdf ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: !saveAsPdf ? Colors.white : Colors.white38,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPdf
                                          ? 'บันทึกเป็นรูปภาพ (ระบุจำนวนรูป/หน้า)'
                                          : 'ระบุจำนวนรูปที่ต้องการบันทึก',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                    const Text('กำหนดจำนวนหน้าที่ต้องการดาวน์โหลดลงเครื่อง', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!saveAsPdf) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                                  icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                                  onPressed: selectedCount > 1 ? () => setModalState(() => selectedCount--) : null,
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    '$selectedCount รูป',
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(backgroundColor: Colors.white12),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                  onPressed: () => setModalState(() => selectedCount++),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _executeSaveDocument(parentContext, title, rawUrl, saveAsPdf ? 1 : selectedCount);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(saveAsPdf && isPdf ? Icons.picture_as_pdf_rounded : Icons.download_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            saveAsPdf && isPdf ? 'ดาวน์โหลดไฟล์ PDF ฉบับเต็ม' : 'ยืนยันบันทึก ($selectedCount รูป)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDocumentModal(String title, String rawUrl) {
    final embedUrl = _toEmbeddableUrl(rawUrl);
    final clean = _cleanUrl(rawUrl);
    final targetUrl = clean.startsWith('http') ? clean : 'https://$clean';
    final downloadLabel = _getDocumentTypeLabel(title, rawUrl);
    final isPdf = downloadLabel.contains('PDF');
    final isSheet = downloadLabel.contains('ตาราง') || rawUrl.contains('spreadsheets') || rawUrl.contains('.xlsx');

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrow = screenWidth < 520;

        return Dialog(
          backgroundColor: const Color(0xFF161618),
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          child: Container(
            width: 900,
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSheet
                            ? Icons.table_chart_rounded
                            : (isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded),
                        color: isSheet ? const Color(0xFF10B981) : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 1. ปุ่มดาวน์โหลด PDF / บันทึกรูป (Dynamic Label & Icon)
                      if (isNarrow)
                        IconButton(
                          tooltip: downloadLabel,
                          icon: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.download_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () => _showSaveImagesDialog(
                            parentContext: context,
                            title: title,
                            rawUrl: rawUrl,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => _showSaveImagesDialog(
                            parentContext: context,
                            title: title,
                            rawUrl: rawUrl,
                          ),
                          icon: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.download_rounded,
                            size: 14,
                          ),
                          label: Text(
                            downloadLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 4),

                      // 2. ปุ่มแชร์ (ส่งเข้า LINE / Social / คัดลอกลิงก์)
                      IconButton(
                        tooltip: 'แชร์เอกสาร',
                        icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 18),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () => _shareDocument(title, rawUrl),
                      ),
                      const SizedBox(width: 4),

                      // 3. ปุ่มเปิดในเบราว์เซอร์ภายนอก
                      IconButton(
                        tooltip: 'เปิดในเบราว์เซอร์ภายนอก',
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 18),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final uri = Uri.parse(targetUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      const SizedBox(width: 4),

                      // 4. ปุ่มปิด [X]
                      IconButton(
                        tooltip: 'ปิด',
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Document preview body
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: getInAppDocView(embedUrl),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchExternalUrl(String urlString, {String title = 'เอกสารแนบ'}) async {
    final clean = _cleanUrl(urlString);
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบลิงก์หรือไฟล์สำหรับเปิด', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // ตรวจสอบว่าเป็นไฟล์รูปภาพโดยตรงหรือไม่ หากใช่ ให้เปิด In-App Image Modal ในแอปทันที
    final isImage = RegExp(r'\.(jpg|jpeg|png|webp|gif)($|\?)', caseSensitive: false).hasMatch(clean);
    if (isImage) {
      _showImageModal(clean);
      return;
    }

    // 🌟 เปิด In-App Document Modal เสมอ ทั้งบน Web และ Mobile
    // จะไม่เด้งออกจากแอปทันที เพื่อให้ผู้ใช้สามารถดูเอกสารในโมดอลได้เลย
    _showDocumentModal(title, clean);
  }

  int get _activeFilterCount =>
      (_selectedBrandFilter != 'ทั้งหมด' ? 1 : 0) +
      (_selectedStatusFilter != 'ทั้งหมด' ? 1 : 0) +
      (_selectedSaleFilter != 'ทั้งหมด' ? 1 : 0) +
      (_effectiveSortOption != PiRecordSortOption.recordDateDesc ? 1 : 0);

  Widget _buildFilterButton() {
    final int activeCount = _activeFilterCount;
    final bool hasActiveFilter = activeCount > 0;

    return InkWell(
      onTap: _showFilterModal,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasActiveFilter ? Colors.white : _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilter ? Colors.white : Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              color: hasActiveFilter ? Colors.black : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              hasActiveFilter ? 'ตัวกรอง ($activeCount)' : 'ตัวกรอง',
              style: TextStyle(
                color: hasActiveFilter ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: hasActiveFilter ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // 🌟 จัดเรียงตัวกรองคำสั้นและคำยาวประกบคู่กัน (Bin Packing) เพื่อให้วางเรียงต่อกันได้มากที่สุดในแต่ละแถว ไม่เปลืองพื้นที่
  List<String> _packFilterItems(List<String> items, {double maxRowWidth = 330.0}) {
    if (items.length <= 1) return items;

    final allItem = items.firstWhere((x) => x == 'ทั้งหมด', orElse: () => '');
    final others = items.where((x) => x != 'ทั้งหมด' && x.trim().isNotEmpty).toList();

    if (others.isEmpty) return items;

    // คำนวณความกว้างประมาณการของชิปแต่ละอัน (ตัวอักษร + padding/margin/border)
    double estimateChipWidth(String text) {
      final displayText = text == 'ทั้งหมด' ? 'ทุกรายการ' : text;
      return (displayText.length * 7.5) + 30.0;
    }

    // เรียงคำตามความยาวจากมากไปน้อย (First-Fit Decreasing)
    others.sort((a, b) => b.length.compareTo(a.length));

    final List<List<String>> rows = [];
    final List<double> rowWidths = [];

    // แถวแรกเริ่มด้วย 'ทั้งหมด' (ถ้ามี)
    if (allItem.isNotEmpty) {
      rows.add([allItem]);
      rowWidths.add(estimateChipWidth(allItem));
    }

    for (final item in others) {
      final w = estimateChipWidth(item);
      int bestRow = -1;
      double minRemaining = double.infinity;

      for (int i = 0; i < rows.length; i++) {
        final remaining = maxRowWidth - (rowWidths[i] + w);
        if (remaining >= 0 && remaining < minRemaining) {
          minRemaining = remaining;
          bestRow = i;
        }
      }

      if (bestRow != -1) {
        rows[bestRow].add(item);
        rowWidths[bestRow] += w;
      } else {
        rows.add([item]);
        rowWidths.add(w);
      }
    }

    final List<String> result = [];
    for (final row in rows) {
      result.addAll(row);
    }
    return result;
  }

  Widget _buildFilterChoiceChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      selected: isSelected,
      selectedColor: Colors.white,
      backgroundColor: const Color(0xFF222226),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
        ),
      ),
      onSelected: onSelected,
    );
  }

  void _showFilterModal() {
    String tempBrand = _selectedBrandFilter;
    String tempStatus = _selectedStatusFilter;
    String tempSale = _selectedSaleFilter;
    PiRecordSortOption tempSort = _effectiveSortOption;

    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = (screenWidth - 32).clamp(280.0, 700.0);
    final packedBrands = _packFilterItems(_brandFilters, maxRowWidth: availableWidth);
    final packedStatuses = _packFilterItems(_statusFilters, maxRowWidth: availableWidth);
    final packedSales = _packFilterItems(_saleFilters, maxRowWidth: availableWidth);

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ตัวกรองข้อมูล',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempBrand = 'ทั้งหมด';
                              tempStatus = 'ทั้งหมด';
                              tempSale = 'ทั้งหมด';
                              tempSort = PiRecordSortOption.recordDateDesc;
                            });
                          },
                          child: const Text(
                            'รีเซ็ต',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ↕️ Section 0: Sort (เรียงลำดับข้อมูล)
                            const Row(
                              children: [
                                Icon(Icons.swap_vert_rounded, color: Colors.white70, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'เรียงลำดับข้อมูล',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: PiRecordSortOption.values.map((option) {
                                final isSelected = tempSort == option;
                                return _buildFilterChoiceChip(
                                  label: option.label,
                                  isSelected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setModalState(() => tempSort = option);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // 🏢 Section 1: Brand
                            const Row(
                              children: [
                                Icon(Icons.apartment_rounded, color: Colors.white70, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'แบรนด์สินค้า',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: packedBrands.map((brand) {
                                final isSelected = tempBrand == brand;
                                return _buildFilterChoiceChip(
                                  label: brand == 'ทั้งหมด' ? 'ทุกแบรนด์' : brand,
                                  isSelected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setModalState(() => tempBrand = brand);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // 🚚 Section 2: Status
                            const Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'สถานะการจัดส่ง',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: packedStatuses.map((status) {
                                final isSelected = tempStatus == status;
                                return _buildFilterChoiceChip(
                                  label: status == 'ทั้งหมด' ? 'ทุกสถานะ' : status,
                                  isSelected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setModalState(() => tempStatus = status);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // 👤 Section 3: Sale (เซลล์ผู้ดูแล)
                            if (_saleFilters.length > 1) ...[
                              const Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'เซลล์ผู้ดูแล',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: packedSales.map((sale) {
                                  final isSelected = tempSale == sale;
                                  return _buildFilterChoiceChip(
                                    label: sale == 'ทั้งหมด' ? 'ทุกคน' : sale,
                                    isSelected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setModalState(() => tempSale = sale);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Apply Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedBrandFilter = tempBrand;
                          _selectedStatusFilter = tempStatus;
                          _selectedSaleFilter = tempSale;
                          _selectedSortOption = tempSort;
                        });
                        _applyFilter();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'ใช้งานตัวกรอง',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilter = _activeFilterCount > 0;
    final List<Widget> activeChips = [
      if (_effectiveSortOption != PiRecordSortOption.recordDateDesc)
        _buildActiveFilterChip(
          label: 'เรียง: ${_effectiveSortOption.label}',
          onDeleted: () {
            setState(() => _selectedSortOption = PiRecordSortOption.recordDateDesc);
            _applyFilter();
          },
        ),
      if (_selectedBrandFilter != 'ทั้งหมด')
        _buildActiveFilterChip(
          label: 'แบรนด์: $_selectedBrandFilter',
          onDeleted: () {
            setState(() => _selectedBrandFilter = 'ทั้งหมด');
            _applyFilter();
          },
        ),
      if (_selectedStatusFilter != 'ทั้งหมด')
        _buildActiveFilterChip(
          label: 'สถานะ: $_selectedStatusFilter',
          onDeleted: () {
            setState(() => _selectedStatusFilter = 'ทั้งหมด');
            _applyFilter();
          },
        ),
      if (_selectedSaleFilter != 'ทั้งหมด')
        _buildActiveFilterChip(
          label: 'เซลล์: $_selectedSaleFilter',
          onDeleted: () {
            setState(() => _selectedSaleFilter = 'ทั้งหมด');
            _applyFilter();
          },
        ),
    ];

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'รายการสั่งซื้อ PI',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildFilterButton(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: fetchPiRecords,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 🔎 Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilter(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ค้นหาเลข PI, Order, โปรเจกต์, เซลล์...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilter();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // 🏷️ Active Filter Pills (แสดงเฉพาะเมื่อมีการเลือกตัวกรอง)
          if (hasActiveFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < activeChips.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            activeChips[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBrandFilter = 'ทั้งหมด';
                        _selectedStatusFilter = 'ทั้งหมด';
                        _selectedSaleFilter = 'ทั้งหมด';
                        _selectedSortOption = PiRecordSortOption.recordDateDesc;
                      });
                      _applyFilter();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('ล้าง', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

          // 📊 Count Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'พบ ${_filteredRecords.length} รายการ',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (_allRecords.isNotEmpty && _filteredRecords.length != _allRecords.length) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${_allRecords.length})',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                if (_searchController.text.isNotEmpty && !hasActiveFilter)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      _applyFilter();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('ล้างค้นหา', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),

          // 📦 Records List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'เกิดข้อผิดพลาด: $_errorMessage',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: fetchPiRecords,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('ลองใหม่อีกครั้ง'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredRecords.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_rounded, color: Colors.white.withOpacity(0.2), size: 64),
                                const SizedBox(height: 12),
                                const Text(
                                  'ไม่พบรายการสั่งซื้อ PI',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: Colors.white,
                            backgroundColor: _cardDark,
                            onRefresh: fetchPiRecords,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _filteredRecords.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _filteredRecords[index];
                                return _buildRecordCard(item);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _fieldText(Map<String, dynamic> item, String camelKey, [String? snakeKey]) {
    final raw = item[camelKey] ?? (snakeKey != null ? item[snakeKey] : null);
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == '-') return '-';
    return value;
  }

  bool _hasValue(String value) => value.isNotEmpty && value != '-';

  Color _etdDotColor(String etd) {
    final lower = etd.toLowerCase();
    if (lower.contains('รอชำระ') || lower.contains('payment') || lower.contains('unpaid')) {
      return const Color(0xFFFB7185);
    }
    if (lower.contains('รอสั่ง') || lower.contains('pending order')) {
      return const Color(0xFFFBBF24);
    }
    if (lower.contains('รอโรงงาน') || lower.contains('โรงงานส่งมา warehouse')) {
      return const Color(0xFF818CF8);
    }
    if (lower.contains('กำลังส่ง') || lower.contains('shipping') || lower.contains('transit')) {
      return const Color(0xFF38BDF8);
    }
    if (lower.contains('ถึง warehouse') || lower.contains('warehouse แล้ว')) {
      return const Color(0xFF2DD4BF);
    }
    if (lower.contains('สต๊อก') || lower.contains('stock') || lower.contains('ถึงลูกค้า') || lower.contains('delivered')) {
      return const Color(0xFF34D399);
    }
    if (lower.contains('รอส่งให้ลูกค้า') || lower.contains('รอส่งลูกค้า')) {
      return const Color(0xFFFACC15);
    }
    if (lower.contains('event') || lower.contains('อีเวนต์')) {
      return const Color(0xFFC084FC);
    }
    return Colors.white70;
  }

  Widget _buildCardKeyValueRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(width: 7),
          SizedBox(
            width: 102,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkFileButton(String rawLink, String title) {
    final cleanUrl = _cleanUrl(rawLink);
    final isUrl = RegExp(r'^https?:\/\/', caseSensitive: false).hasMatch(cleanUrl);
    if (!isUrl) {
      if (!_hasValue(rawLink)) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          rawLink,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final lower = cleanUrl.toLowerCase();
    final bool isSheet = lower.contains('spreadsheets') || lower.contains('.xlsx') || lower.contains('.csv');
    final bool isPdf = lower.contains('.pdf') || lower.contains('drive.google');
    final String label = isSheet ? 'เปิด Google Sheet' : (isPdf ? 'เปิดเอกสาร' : 'เปิดลิงก์');
    final IconData icon = isSheet ? Icons.table_chart_rounded : (isPdf ? Icons.description_rounded : Icons.link_rounded);
    final Color accent = isSheet ? const Color(0xFF34D399) : const Color(0xFF93C5FD);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchExternalUrl(cleanUrl, title: title),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, color: accent, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> item) {
    // แสดงผลแบบแบ่งซ้าย-ขวาสมดุลเต็มความกว้างการ์ด (ซ่อนช่องที่ว่าง '-' เพื่อลดความรก):
    // I (Order_NO.), L (Project_name), K (Sale_Name), Q (Date_Order),
    // O (Shipping_Method), G (ETD), D (Link/File), R (Last Update), C (Supplier), A (PI-Supplier)
    final orderNo = _fieldText(item, 'orderNo', 'order_no');
    final projectName = _fieldText(item, 'projectName', 'project_name');
    final saleName = _fieldText(item, 'saleName', 'sale_name');
    final dateOrder = _fieldText(item, 'dateOrder', 'date_order');
    final shippingMethod = _fieldText(item, 'shippingMethod', 'shipping_method');
    final deliveredDate = _fieldText(item, 'deliveredDate', 'delivered_date');
    final etd = _fieldText(item, 'etd');
    final linkFileRaw = (item['linkFileUrl'] ?? item['link_file_url'] ?? item['linkFile'] ?? item['link_file'] ?? '').toString().trim();
    final lastUpdate = _fieldText(item, 'lastUpdate', 'last_update');
    final supplier = _fieldText(item, 'supplier');
    final piSupplier = _fieldText(item, 'piSupplier', 'pi_supplier');

    final hasOrder = _hasValue(orderNo);
    final hasPi = _hasValue(piSupplier);
    final hasProject = _hasValue(projectName);
    final hasSale = _hasValue(saleName);
    final hasDateOrder = _hasValue(dateOrder);
    final hasShipping = _hasValue(shippingMethod);
    final hasDeliveredDate = _hasValue(deliveredDate);
    final hasLastUpdate = _hasValue(lastUpdate);
    final hasSupplier = _hasValue(supplier);
    final hasLink = _hasValue(_cleanUrl(linkFileRaw)) || _hasValue(linkFileRaw);
    final hasEtd = _hasValue(etd);

    final accentColor = hasEtd ? _etdDotColor(etd) : Colors.white38;

    final List<Widget> detailRows = [
      if (hasSupplier && (hasOrder || hasPi))
        _buildCardKeyValueRow(
          icon: Icons.storefront_rounded,
          label: 'Supplier',
          value: supplier,
          valueColor: Colors.white70,
        ),
      if (hasSale)
        _buildCardKeyValueRow(
          icon: Icons.person_outline_rounded,
          label: 'Sale',
          value: saleName,
        ),
      if (hasDateOrder)
        _buildCardKeyValueRow(
          icon: Icons.event_available_rounded,
          label: 'ลูกค้าชำระเงิน',
          value: dateOrder,
        ),
      if (hasShipping)
        _buildCardKeyValueRow(
          icon: Icons.local_shipping_outlined,
          label: 'วิธีจัดส่ง',
          value: _formatShippingMethod(shippingMethod),
          valueColor: const Color(0xFF7DD3FC),
        ),
      if (hasDeliveredDate)
        _buildCardKeyValueRow(
          icon: Icons.inventory_2_outlined,
          label: 'วันสินค้าถึง',
          value: deliveredDate,
          valueColor: const Color(0xFFFDE047),
        ),
    ];

    return Material(
      color: _cardDark,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showRecordDetails(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasEtd
                  ? accentColor.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. แถบสถานะด้านบนเต็มความกว้าง: G (ETD) ซ้าย — R (Last Update) ขวา
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasEtd
                      ? accentColor.withValues(alpha: 0.13)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border(
                    bottom: BorderSide(
                      color: hasEtd
                          ? accentColor.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasEtd ? etd : 'ยังไม่ระบุสถานะ',
                        style: TextStyle(
                          color: hasEtd ? Colors.white : Colors.white54,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.update_rounded,
                      color: hasLastUpdate ? Colors.white60 : Colors.white30,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasLastUpdate ? 'อัปเดต: $lastUpdate' : 'อัปเดต: -',
                      style: TextStyle(
                        color: hasLastUpdate ? Colors.white70 : Colors.white38,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. ส่วนหัว: I (Order_NO.) ซ้าย — A (PI-Supplier) ขวา
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasOrder
                                    ? 'Order $orderNo'
                                    : (hasPi ? 'PI $piSupplier' : supplier),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (hasOrder && hasPi) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 145),
                            child: Text(
                              'PI $piSupplier',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 3. ชื่อโปรเจกต์ (L) เต็มความกว้าง
                    if (hasProject) ...[
                      const SizedBox(height: 9),
                      Text(
                        projectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 4. รายละเอียดแบบตารางซ้าย-ขวาเต็มแถว (C, K, Q, O)
                    if (detailRows.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < detailRows.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              detailRows[i],
                            ],
                          ],
                        ),
                      ),
                    ],

                    // 5. ส่วนท้าย: D (Link/File) ซ้าย — รายละเอียด ขวา
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: hasLink
                                ? _buildLinkFileButton(linkFileRaw, 'เปิดลิงก์ / ไฟล์')
                                : const Text(
                                    'แตะเพื่อดูรายละเอียดทั้งหมด',
                                    style: TextStyle(color: Colors.white38, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'รายละเอียด',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(Map<String, dynamic> item) {
    final piSupplier = _fieldText(item, 'piSupplier', 'pi_supplier');
    final supplier = _fieldText(item, 'supplier');
    final orderNo = _fieldText(item, 'orderNo', 'order_no');
    final projectName = _fieldText(item, 'projectName', 'project_name');
    final saleName = _fieldText(item, 'saleName', 'sale_name');
    final etd = _fieldText(item, 'etd');
    final brand = _fieldText(item, 'brand');
    final shippingMethod = _fieldText(item, 'shippingMethod', 'shipping_method');
    final recordDate = _fieldText(item, 'recordDate', 'record_date');
    final dateOrder = _fieldText(item, 'dateOrder', 'date_order');
    final paymentDate = _fieldText(item, 'paymentDate', 'payment_date');
    final requestedDate = _fieldText(item, 'requestedDate', 'requested_date');
    final deliveredDate = _fieldText(item, 'deliveredDate', 'delivered_date');
    final lastUpdate = _fieldText(item, 'lastUpdate', 'last_update');

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'PI: $piSupplier',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildDetailRow('ซัพพลายเออร์', supplier),
                _buildDetailRow('แบรนด์', brand),
                _buildDetailRow('เลขคำสั่งซื้อ', orderNo),
                _buildDetailRow('โปรเจกต์', projectName),
                _buildDetailRow('เซลล์ผู้ดูแล', saleName),
                _buildDetailRow('สถานะ / กำหนดส่ง', etd, valueColor: Colors.white),
                _buildDetailRow('วิธีการจัดส่ง', _formatShippingMethod(shippingMethod), valueColor: const Color(0xFF7DD3FC)),
                _buildDetailRow('อัปเดตล่าสุด (Last Update)', lastUpdate),
                const Divider(color: Colors.white10, height: 24),

                _buildDetailRow('วันที่บันทึก', recordDate),
                _buildDetailRow('วันที่ลูกค้าชำระเงิน', dateOrder),
                _buildDetailRow('วันที่ชำระเงินซัพพลายเออร์', paymentDate),
                _buildDetailRow('วันที่ต้องการสินค้า', requestedDate),
                _buildDetailRow('วันสินค้าถึง', deliveredDate),

                // 📂 รายการเอกสารและไฟล์แนบ (รองรับทั้ง 1 ไฟล์ และ หลายๆ ไฟล์)
                Builder(
                  builder: (context) {
                    final List<Map<String, dynamic>> attachments = [];
                    final Set<String> seenUrls = {};

                    void addAttachment(dynamic raw, String defaultTitle, IconData defaultIcon) {
                      if (raw == null) return;
                      final str = raw.toString().trim();
                      if (str.isEmpty || str == '-') return;

                      // แยกในกรณีที่มีหลายลิงก์คั่นด้วย comma หรือ newline
                      final lines = str.split(RegExp(r'[\n,]+'));
                      for (var line in lines) {
                        final clean = _cleanUrl(line);
                        if (clean.isNotEmpty && clean != '-' && !seenUrls.contains(clean)) {
                          seenUrls.add(clean);
                          IconData icon = defaultIcon;
                          String title = defaultTitle;
                          final lower = clean.toLowerCase();
                          if (lower.contains('spreadsheets') || lower.contains('excel') || lower.contains('.xlsx')) {
                            icon = Icons.table_chart_rounded;
                            title = 'ตารางสั่งซื้อ (Google Sheets)';
                          } else if (lower.contains('drive.google') || lower.contains('.pdf')) {
                            icon = Icons.picture_as_pdf_rounded;
                            title = 'เอกสารแนบ (Google Drive / PDF)';
                          }
                          attachments.add({
                            'title': title,
                            'url': clean,
                            'icon': icon,
                          });
                        }
                      }
                    }

                    addAttachment(item['fileUrl'] ?? item['file_url'] ?? item['fileName'] ?? item['file_name'], 'ไฟล์เอกสารหลัก', Icons.description_rounded);
                    addAttachment(item['linkFileUrl'] ?? item['link_file_url'] ?? item['linkFile'] ?? item['link_file'], 'ลิงก์ที่เกี่ยวข้อง', Icons.link_rounded);

                    if (attachments.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white10, height: 28),
                        Row(
                          children: [
                            const Icon(Icons.attach_file_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              attachments.length > 1
                                  ? 'เอกสารและไฟล์แนบ (${attachments.length} รายการ)'
                                  : 'เอกสารและไฟล์แนบ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...attachments.map((att) {
                          final title = att['title'] as String;
                          final url = att['url'] as String;
                          final icon = att['icon'] as IconData;
                          final host = Uri.tryParse(url)?.host ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222226),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _launchExternalUrl(url, title: title),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(icon, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (host.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                host,
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _launchExternalUrl(url, title: title),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('เปิดดู', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            SizedBox(width: 4),
                                            Icon(Icons.visibility_outlined, size: 14),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    if (value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
