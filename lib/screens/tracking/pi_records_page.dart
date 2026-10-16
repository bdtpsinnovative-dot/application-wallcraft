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

class PiRecordsPage extends StatefulWidget {
  const PiRecordsPage({super.key});

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

          // เรียงตามวันที่ล่าสุดเสมอ (Newest first)
          data.sort((a, b) {
            final dateA = _parseRecordDate(a['recordDate'] ?? a['record_date']);
            final dateB = _parseRecordDate(b['recordDate'] ?? b['record_date']);
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

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

    setState(() {
      _filteredRecords = _allRecords.where((item) {
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
          final pi = (item['piSupplier'] ?? '').toString().toLowerCase();
          final orderNo = (item['orderNo'] ?? '').toString().toLowerCase();
          final project = (item['projectName'] ?? '').toString().toLowerCase();
          final supplier = (item['supplier'] ?? '').toString().toLowerCase();
          final sale = (item['saleName'] ?? '').toString().toLowerCase();
          final brand = (item['brand'] ?? '').toString().toLowerCase();

          return pi.contains(query) ||
              orderNo.contains(query) ||
              project.contains(query) ||
              supplier.contains(query) ||
              sale.contains(query) ||
              brand.contains(query);
        }

        return true;
      }).toList();
    });
  }

  DateTime? _parseRecordDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return null;
    final str = raw.trim();
    final parts = str.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      int? year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        if (year > 2500) year -= 543;
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(str);
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

  Widget _buildShippingMethodPill(String raw, {bool isMini = false}) {
    final formatted = _formatShippingMethod(raw);
    if (formatted == '-' || formatted.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMini ? 8 : 10, vertical: isMini ? 2 : 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.35), width: 1),
      ),
      child: Text(
        formatted,
        style: TextStyle(
          color: const Color(0xFF7DD3FC),
          fontSize: isMini ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
    if (lower.contains('.pdf') || lower.contains('drive.google.com') || lower.contains('po') || lower.contains('doc')) {
      return 'ดาวน์โหลด PDF';
    } else if (lower.contains('spreadsheets') || lower.contains('excel') || lower.contains('.xlsx') || lower.contains('.csv')) {
      return 'ดาวน์โหลดตาราง';
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

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF161618),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
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
                      const SizedBox(width: 8),

                      // 1. ปุ่มดาวน์โหลด PDF / บันทึกรูป (Dynamic Label & Icon)
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

                      // 3. ปุ่มเปิดแท็บใหม่
                      IconButton(
                        tooltip: 'เปิดในแท็บใหม่',
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

    // ถ้ากำลังรันบน Web ให้เปิดเป็น In-App Document Modal ทันที
    if (kIsWeb) {
      _showDocumentModal(title, clean);
      return;
    }

    try {
      final uri = Uri.parse(clean.startsWith('http') ? clean : 'https://$clean');

      // 1. ลองเปิดเป็น In-App Browser Modal (Chrome Custom Tabs บน Android / SFSafariViewController บน iOS)
      // โหมดนี้จะเลื่อนเปิดขึ้นมาเป็นหน้าต่างซ้อนในแอป (Modal Sheet) มีปุ่มปิด (X) บนหัวแถบ
      // และยังแชร์คุกกี้กับบัญชี Google ทำให้เปิด Google Drive / Sheets ได้สะดวก ไม่หลุดออกจากแอป
      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
      } catch (_) {}

      // 2. ถ้าเครื่องไม่รองรับ inAppBrowserView ให้ลอง inAppWebView
      if (!launched) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } catch (_) {}
      }

      // 3. Fallback หากระบบไม่รองรับ In-App ใดๆ ให้เปิดผ่านแอปภายนอก
      if (!launched) {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      }

      if (!launched) {
        throw 'Cannot launch $clean';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปิดลิงก์ได้: $clean', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildFilterButton() {
    final bool hasActiveFilter =
        _selectedBrandFilter != 'ทั้งหมด' ||
        _selectedStatusFilter != 'ทั้งหมด' ||
        _selectedSaleFilter != 'ทั้งหมด';
    final int activeCount = (_selectedBrandFilter != 'ทั้งหมด' ? 1 : 0) +
        (_selectedStatusFilter != 'ทั้งหมด' ? 1 : 0) +
        (_selectedSaleFilter != 'ทั้งหมด' ? 1 : 0);

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

  void _showFilterModal() {
    String tempBrand = _selectedBrandFilter;
    String tempStatus = _selectedStatusFilter;
    String tempSale = _selectedSaleFilter;

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
                padding: const EdgeInsets.all(24),
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
                            // 🏢 Section 1: Brand
                            const Row(
                              children: [
                                Icon(Icons.apartment_rounded, color: Colors.white70, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'แบรนด์สินค้า (Brand)',
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
                              spacing: 8,
                              runSpacing: 8,
                              children: _brandFilters.map((brand) {
                                final isSelected = tempBrand == brand;
                                return ChoiceChip(
                                  label: Text(
                                    brand == 'ทั้งหมด' ? 'ทุกแบรนด์' : brand,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.white,
                                  backgroundColor: const Color(0xFF2C2C2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
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
                                  'สถานะการจัดส่ง (Status / ETD)',
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
                              spacing: 8,
                              runSpacing: 8,
                              children: _statusFilters.map((status) {
                                final isSelected = tempStatus == status;
                                return ChoiceChip(
                                  label: Text(
                                    status == 'ทั้งหมด' ? 'ทุกสถานะ' : status,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: Colors.white,
                                  backgroundColor: const Color(0xFF2C2C2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                                    ),
                                  ),
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
                                    'เซลล์ผู้ดูแล (Sale)',
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
                                spacing: 8,
                                runSpacing: 8,
                                children: _saleFilters.map((sale) {
                                  final isSelected = tempSale == sale;
                                  return ChoiceChip(
                                    label: Text(
                                      sale == 'ทั้งหมด' ? 'ทุกคน' : sale,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white70,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: Colors.white,
                                    backgroundColor: const Color(0xFF2C2C2E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                                      ),
                                    ),
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
    final bool hasActiveFilter =
        _selectedBrandFilter != 'ทั้งหมด' ||
        _selectedStatusFilter != 'ทั้งหมด' ||
        _selectedSaleFilter != 'ทั้งหมด';

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
                          if (_selectedBrandFilter != 'ทั้งหมด')
                            _buildActiveFilterChip(
                              label: 'แบรนด์: $_selectedBrandFilter',
                              onDeleted: () {
                                setState(() => _selectedBrandFilter = 'ทั้งหมด');
                                _applyFilter();
                              },
                            ),
                          if (_selectedStatusFilter != 'ทั้งหมด') ...[
                            if (_selectedBrandFilter != 'ทั้งหมด') const SizedBox(width: 8),
                            _buildActiveFilterChip(
                              label: 'สถานะ: $_selectedStatusFilter',
                              onDeleted: () {
                                setState(() => _selectedStatusFilter = 'ทั้งหมด');
                                _applyFilter();
                              },
                            ),
                          ],
                          if (_selectedSaleFilter != 'ทั้งหมด') ...[
                            if (_selectedBrandFilter != 'ทั้งหมด' || _selectedStatusFilter != 'ทั้งหมด')
                              const SizedBox(width: 8),
                            _buildActiveFilterChip(
                              label: 'เซลล์: $_selectedSaleFilter',
                              onDeleted: () {
                                setState(() => _selectedSaleFilter = 'ทั้งหมด');
                                _applyFilter();
                              },
                            ),
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

  Widget _buildRecordCard(Map<String, dynamic> item) {
    final piSupplier = (item['piSupplier'] ?? '-').toString().trim();
    final supplier = (item['supplier'] ?? '-').toString().trim();
    final orderNo = (item['orderNo'] ?? '').toString().trim();
    final projectName = (item['projectName'] ?? '').toString().trim();
    final saleName = (item['saleName'] ?? '').toString().trim();
    final etd = (item['etd'] ?? '-').toString().trim();
    final brand = (item['brand'] ?? '').toString().trim();
    final amountYuan = (item['amountYuan'] ?? '').toString().trim();
    final amountDollar = (item['amountDollar'] ?? '').toString().trim();
    final shippingMethod = (item['shippingMethod'] ?? '').toString().trim();

    final recordDate = (item['recordDate'] ?? item['record_date'] ?? '').toString().trim();

    final hasPi = piSupplier.isNotEmpty && piSupplier != '-';
    final hasBrand = brand.isNotEmpty && brand != '-';
    final hasEtd = etd.isNotEmpty && etd != '-';
    final hasSupplier = supplier.isNotEmpty && supplier != '-';
    final hasOrder = orderNo.isNotEmpty && orderNo != '-';
    final hasProject = projectName.isNotEmpty && projectName != '-';

    return Material(
      color: _cardDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecordDetails(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. หัวการ์ด: รหัส PI คมชัด ตัวเต็ม ไม่โดนบีบ และแบรนด์
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      hasPi ? piSupplier : (hasOrder ? 'Order #$orderNo' : supplier),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasBrand) ...[
                    const SizedBox(width: 8),
                    Text(
                      brand,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              // 2. ป้ายสถานะการจัดส่ง (ETD) & วันที่บันทึก
              if (hasEtd || (recordDate.isNotEmpty && recordDate != '-')) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasEtd)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                etd,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasEtd && recordDate.isNotEmpty && recordDate != '-')
                      const SizedBox(width: 8),
                    if (recordDate.isNotEmpty && recordDate != '-')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            recordDate,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],

              // 3. ชื่อซัพพลายเออร์
              if (hasSupplier) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.business_rounded, color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        supplier,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 4. เลข Order & ชื่อโปรเจกต์
              if (hasOrder || hasProject) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (hasOrder) ...[
                      const Icon(Icons.tag_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        orderNo,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasProject)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        ),
                    ],
                    if (hasProject)
                      Expanded(
                        child: Text(
                          projectName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],

              // 5. ขีดคั่น & ยอดเงิน & วิธีจัดส่ง & ปุ่มดูลูกศร
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ยอดเงิน (ทางซ้าย)
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (amountDollar.isNotEmpty && amountDollar != '-')
                          Text(
                            amountDollar,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (amountDollar.isNotEmpty &&
                            amountDollar != '-' &&
                            amountYuan.isNotEmpty &&
                            amountYuan != '-')
                          const Text('/', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        if (amountYuan.isNotEmpty && amountYuan != '-')
                          Text(
                            amountYuan,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if ((amountDollar.isEmpty || amountDollar == '-') &&
                            (amountYuan.isEmpty || amountYuan == '-'))
                          if (saleName.isNotEmpty && saleName != '-')
                            Text(
                              'เซลล์: $saleName',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ป้ายวิธีการจัดส่ง (ชิดขวาสม่ำเสมอทุกใบ ไม่ย่น ไม่กระโดด)
                  if (shippingMethod.isNotEmpty && shippingMethod != '-') ...[
                    _buildShippingMethodPill(shippingMethod, isMini: true),
                    const SizedBox(width: 8),
                  ],

                  const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordDetails(Map<String, dynamic> item) {
    final piSupplier = (item['piSupplier'] ?? '-').toString();
    final supplier = (item['supplier'] ?? '-').toString();
    final orderNo = (item['orderNo'] ?? '-').toString();
    final projectName = (item['projectName'] ?? '-').toString();
    final saleName = (item['saleName'] ?? '-').toString();
    final etd = (item['etd'] ?? '-').toString();
    final brand = (item['brand'] ?? '-').toString();
    final amountYuan = (item['amountYuan'] ?? '-').toString();
    final amountDollar = (item['amountDollar'] ?? '-').toString();
    final shippingMethod = (item['shippingMethod'] ?? '-').toString();
    final recordDate = (item['recordDate'] ?? '-').toString();
    final dateOrder = (item['dateOrder'] ?? '-').toString();
    final paymentDate = (item['paymentDate'] ?? '-').toString();
    final requestedDate = (item['requestedDate'] ?? '-').toString();
    final deliveredDate = (item['deliveredDate'] ?? '-').toString();

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

                _buildDetailRow('ซัพพลายเออร์ (Supplier)', supplier),
                _buildDetailRow('แบรนด์ (Brand)', brand),
                _buildDetailRow('เลขคำสั่งซื้อ (Order No.)', orderNo),
                _buildDetailRow('โปรเจกต์ (Project Name)', projectName),
                _buildDetailRow('ผู้ดูแล (Sale Name)', saleName),
                _buildDetailRow('สถานะ / กำหนดส่ง (ETD)', etd, valueColor: Colors.white),
                _buildDetailRow('วิธีการจัดส่ง (Shipping)', _formatShippingMethod(shippingMethod), valueColor: const Color(0xFF7DD3FC)),
                const Divider(color: Colors.white10, height: 24),

                _buildDetailRow('จำนวนเงิน (\$)', amountDollar, valueColor: Colors.white),
                _buildDetailRow('จำนวนเงิน (Yuan)', amountYuan, valueColor: Colors.white70),
                const Divider(color: Colors.white10, height: 24),

                _buildDetailRow('วันที่บันทึก (Date)', recordDate),
                _buildDetailRow('วันที่ลูกค้าชำระเงิน (Date Order)', dateOrder),
                _buildDetailRow('วันที่ชำระเงินซัพพลายเออร์', paymentDate),
                _buildDetailRow('วันที่ต้องการสินค้า (Requested)', requestedDate),
                _buildDetailRow('วันที่จัดส่งถึง (Delivered)', deliveredDate),

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

                    addAttachment(item['fileUrl'] ?? item['file_url'] ?? item['fileName'] ?? item['file_name'], 'ไฟล์เอกสารหลัก (File)', Icons.description_rounded);
                    addAttachment(item['linkFileUrl'] ?? item['link_file_url'] ?? item['linkFile'] ?? item['link_file'], 'ลิงก์ที่เกี่ยวข้อง (Link/File)', Icons.link_rounded);

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
            width: 130,
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
