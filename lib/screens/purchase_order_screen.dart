import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // เพิ่มสำหรับจัดการ StatusBar
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _company = TextEditingController();
  final _customer = TextEditingController();
  final _product = TextEditingController();
  final _desc = TextEditingController();

  String _status = 'pending';
  final List<XFile> _photos = [];
  bool _saving = false;

  static const String _table = 'purchase_mobie';
  static const String _bucket = 'product-images';
  static const String _folderPrefix = 'collect/purchase_mobie';

  // --- Modern Tailwind-inspired Colors ---
  final Color bgSlate50 = const Color(0xFFF8FAFC);
  final Color slate100 = const Color(0xFFF1F5F9);
  final Color slate200 = const Color(0xFFE2E8F0);
  final Color slate300 = const Color(0xFFCBD5E1);
  final Color slate400 = const Color(0xFF94A3B8);
  final Color slate500 = const Color(0xFF64748B);
  final Color slate700 = const Color(0xFF334155);
  final Color slate900 = const Color(0xFF0F172A);
  final Color primaryBlue = const Color(0xFF2563EB); // Blue-600
  final Color dangerRed = const Color(0xFFEF4444);

  int get _maxPhotos => 5;

  @override
  void dispose() {
    _company.dispose();
    _customer.dispose();
    _product.dispose();
    _desc.dispose();
    super.dispose();
  }

  String _rand6() => (Random().nextInt(900000) + 100000).toString();

  Future<Uint8List> _toWebpBytes(String inputPath) async {
    final out = await FlutterImageCompress.compressWithFile(
      inputPath,
      format: CompressFormat.webp,
      quality: 70,
    );

    if (out == null) {
      return File(inputPath).readAsBytes();
    }
    return out is Uint8List ? out : Uint8List.fromList(out);
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= _maxPhotos) return;

    final list = await _picker.pickMultiImage(imageQuality: 85);
    if (list.isEmpty) return;

    setState(() {
      final remain = _maxPhotos - _photos.length;
      _photos.addAll(list.take(remain));
    });
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= _maxPhotos) return;

    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;

    setState(() => _photos.add(x));
  }

  void _removePhotoAt(int index) => setState(() => _photos.removeAt(index));

  List<Map<String, String>> get _statusItems => const [
        {'value': 'pending', 'label': 'Pending (รอดำเนินการ)'},
        {'value': 'new', 'label': 'New (รายการใหม่)'},
        {'value': 'contacted', 'label': 'Contacted (ติดต่อแล้ว)'},
        {'value': 'closed', 'label': 'Closed (ปิดงาน)'},
      ];

  // --- Logic Save (คงเดิม) ---
  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      // เพิ่มแจ้งเตือนถ้ายลืมกรอก
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน'),
          backgroundColor: dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    int? insertedId;
    try {
      final supabase = Supabase.instance.client;

      final inserted = await supabase
          .from(_table)
          .insert({
            'company_name': _company.text.trim(),
            'customer_name': _customer.text.trim(),
            'product_of_interest': _product.text.trim(),
            'current_status': _status,
            'additional_description':
                _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            'photos': <String>[],
          })
          .select('id')
          .single();

      insertedId = (inserted['id'] as num).toInt();

      final urls = <String>[];
      for (final x in _photos) {
        final fileName =
            '${DateTime.now().microsecondsSinceEpoch}_${_rand6()}.webp';
        final path = '$_folderPrefix/$insertedId/$fileName';

        final bytes = await _toWebpBytes(x.path);

        await supabase.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/webp',
              ),
            );

        final url = supabase.storage.from(_bucket).getPublicUrl(path);
        urls.add(url);
      }

      if (urls.isNotEmpty) {
        await supabase
            .from(_table)
            .update({'photos': urls}).eq('id', insertedId);
      }

      if (!mounted) return;
      
      // Show Success Dialog แบบสวยๆ
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 40, color: Colors.green.shade600),
              ),
              const SizedBox(height: 16),
              const Text('บันทึกสำเร็จ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('หมายเลขรายการ #$insertedId', style: TextStyle(color: slate500)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ตกลง', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- Modern Components ---

  InputDecoration _modernInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: slate400, fontSize: 14),
      prefixIcon: Icon(icon, color: slate400, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dangerRed.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 20),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: slate500,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: slate900.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: slate900.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSlate50,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: slate900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Order',
          style: TextStyle(color: slate900, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: slate100, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Customer Info'),
                        _buildCard(
                          children: [
                            Text('Company Name', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _company,
                              style: TextStyle(color: slate900, fontWeight: FontWeight.w500),
                              decoration: _modernInputDecoration('Ex. Tesla Inc.', Icons.business_rounded),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            Text('Contact Person', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _customer,
                              style: TextStyle(color: slate900, fontWeight: FontWeight.w500),
                              decoration: _modernInputDecoration('Ex. Elon Musk', Icons.person_rounded),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ],
                        ),

                        _buildSectionLabel('Job Details'),
                        _buildCard(
                          children: [
                            Text('Product of Interest', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _product,
                              style: TextStyle(color: slate900, fontWeight: FontWeight.w500),
                              decoration: _modernInputDecoration('Ex. Solar Roof V3', Icons.inventory_2_rounded),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            Text('Status', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: slate200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _status,
                                  isExpanded: true,
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: slate400),
                                  style: TextStyle(color: slate900, fontSize: 15, fontWeight: FontWeight.w500),
                                  items: _statusItems.map((m) {
                                    return DropdownMenuItem(
                                      value: m['value'],
                                      child: Row(
                                        children: [
                                          _StatusDot(status: m['value']!),
                                          const SizedBox(width: 10),
                                          Text(m['label']!),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _status = v ?? 'pending'),
                                ),
                              ),
                            ),
                          ],
                        ),

                        _buildSectionLabel('Additional & Photos'),
                        _buildCard(
                          children: [
                            Text('Note', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _desc,
                              maxLines: 4,
                              style: TextStyle(color: slate900),
                              decoration: _modernInputDecoration('Additional details...', Icons.notes_rounded),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Text('Photos', style: TextStyle(color: slate700, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: slate100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_photos.length}/$_maxPhotos',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: slate500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // คำนวณขนาดรูปให้พอดี (3 รูปต่อแถว)
                                final double itemSize = (constraints.maxWidth - 20) / 3;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    if (_photos.length < _maxPhotos)
                                      _ModernAddButton(
                                        size: itemSize,
                                        onTap: () => _showPickerSheet(context),
                                      ),
                                    ..._photos.asMap().entries.map((entry) {
                                      return _ModernPhotoTile(
                                        file: entry.value,
                                        size: itemSize,
                                        onRemove: () => _removePhotoAt(entry.key),
                                      );
                                    }).toList(),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        // พื้นที่ว่างด้านล่างเพื่อให้ Scroll ได้พ้นปุ่ม
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // --- Sticky Bottom Button ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: slate200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: slate200,
                    disabledForegroundColor: slate400,
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: slate500, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Save Order',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: slate200, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: slate100, shape: BoxShape.circle),
                  child: Icon(Icons.photo_library_rounded, color: primaryBlue),
                ),
                title: Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: slate900)),
                subtitle: Text('Choose from library', style: TextStyle(color: slate500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotos();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: slate100, shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt_rounded, color: primaryBlue),
                ),
                title: Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, color: slate900)),
                subtitle: Text('Take a new photo', style: TextStyle(color: slate500)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Components ---

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'new': color = Colors.blue; break;
      case 'contacted': color = Colors.orange; break;
      case 'closed': color = Colors.green; break;
      default: color = Colors.grey;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ModernAddButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _ModernAddButton({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid), // Dashed look simulated
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: const Color(0xFF64748B), size: 28),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: TextStyle(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
            )
          ],
        ),
      ),
    );
  }
}

class _ModernPhotoTile extends StatelessWidget {
  final XFile file;
  final double size;
  final VoidCallback onRemove;

  const _ModernPhotoTile({required this.file, required this.size, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: FileImage(File(file.path)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                  ]
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}