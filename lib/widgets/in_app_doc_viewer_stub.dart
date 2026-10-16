import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildInAppDocView(String url) {
  return _MobileDocViewer(url: url);
}

void downloadFileWeb(String url, String filename) {}

class _MobileDocViewer extends StatefulWidget {
  final String url;
  const _MobileDocViewer({required this.url});

  @override
  State<_MobileDocViewer> createState() => _MobileDocViewerState();
}

class _MobileDocViewerState extends State<_MobileDocViewer> {
  bool _imageError = false;

  String? _getGoogleDriveId(String url) {
    final match = RegExp(r'(?:file\/d\/|open\?id=|thumbnail\?id=)([a-zA-Z0-9_-]+)').firstMatch(url);
    return match?.group(1);
  }

  bool _isDirectImage(String url) {
    return RegExp(r'\.(jpg|jpeg|png|webp|gif)($|\?)', caseSensitive: false).hasMatch(url);
  }

  bool _isSheet(String url) {
    return url.contains('spreadsheets') || url.contains('sheets.google.com');
  }

  bool _isDoc(String url) {
    return url.contains('document/d/') || url.contains('docs.google.com/document');
  }

  bool _isPdf(String url) {
    return url.toLowerCase().contains('.pdf') || (url.contains('drive.google.com') && !_isSheet(url));
  }

  Future<void> _openFullInAppBrowser(BuildContext context) async {
    final cleanUrl = widget.url.startsWith('http') ? widget.url : 'https://${widget.url}';
    final uri = Uri.parse(cleanUrl);
    try {
      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } catch (_) {}
      }

      if (!launched) {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถเปิดลิงก์ได้', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    final cleanUrl = widget.url.startsWith('http') ? widget.url : 'https://${widget.url}';
    await Clipboard.setData(ClipboardData(text: cleanUrl));
    if (context.mounted) {
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
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driveId = _getGoogleDriveId(widget.url);
    final isImage = _isDirectImage(widget.url);
    final isSheet = _isSheet(widget.url);

    // ถ้าไม่ใช่ Google Sheet และมี Drive ID หรือเป็น Direct Image ให้ลองแสดงรูปพรีวิว
    final canPreviewImage = !_imageError && !isSheet && (isImage || driveId != null);
    final previewUrl = isImage
        ? widget.url
        : (driveId != null ? 'https://lh3.googleusercontent.com/d/$driveId=w1000' : null);

    if (canPreviewImage && previewUrl != null) {
      return Container(
        color: const Color(0xFF161618),
        alignment: Alignment.center,
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            previewUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    SizedBox(height: 12),
                    Text(
                      'กำลังโหลดตัวอย่างเอกสาร...',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _imageError = true);
              });
              return _buildFallbackCard(context);
            },
          ),
        ),
      );
    }

    return _buildFallbackCard(context);
  }

  Widget _buildFallbackCard(BuildContext context) {
    final isSheet = _isSheet(widget.url);
    final isDoc = _isDoc(widget.url);
    final isPdf = _isPdf(widget.url);

    final IconData mainIcon = isSheet
        ? Icons.table_chart_rounded
        : (isPdf
            ? Icons.picture_as_pdf_rounded
            : (isDoc ? Icons.article_rounded : Icons.description_rounded));

    final Color accentColor = isSheet
        ? const Color(0xFF10B981)
        : (isPdf
            ? const Color(0xFFEF4444)
            : (isDoc ? const Color(0xFF3B82F6) : Colors.white70));

    final String typeBadge = isSheet
        ? 'ตารางคำนวณ (Google Sheets)'
        : (isPdf ? 'เอกสาร PDF' : (isDoc ? 'Google Docs' : 'เอกสารแนบ'));

    final Uri? parsedUri = Uri.tryParse(widget.url);
    final String domain = parsedUri?.host.isNotEmpty == true ? parsedUri!.host : 'เอกสารแนบออนไลน์';

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      alignment: Alignment.center,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Icon(mainIcon, color: accentColor, size: 36),
              ),
              const SizedBox(height: 16),

              // Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  typeBadge,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Domain
              Text(
                domain,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              // Button: เปิดดูเอกสารแบบเต็ม (In-App Browser)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _openFullInAppBrowser(context),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text(
                      'เปิดดูเอกสารแบบเต็ม',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Button: คัดลอกลิงก์
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _copyLink(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'คัดลอกลิงก์เอกสาร',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
