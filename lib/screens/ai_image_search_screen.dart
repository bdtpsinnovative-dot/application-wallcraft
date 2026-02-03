
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI-only screen:
/// - ไม่มีค้นหาแบบ ID/Style
/// - กดเลือกรูป -> หา match จาก aHash
/// - แนะนำให้เพิ่มคอลัมน์ ahash (TEXT 64 bits) ใน table `mobile_backgrounds` เพื่อความลื่น
class AiImageSearchScreen extends StatefulWidget {
  const AiImageSearchScreen({super.key});

  @override
  State<AiImageSearchScreen> createState() => _AiImageSearchScreenState();
}

class _AiImageSearchScreenState extends State<AiImageSearchScreen> {
  // ===== CONFIG =====
  static const String table = "mobile_backgrounds";

  // storage ที่คุณใช้เก็บรูป background + รูปที่ upload log
  static const String bucket = "product-images";
  static const String folder = "bg";

  static const String logTable = "mobile_collect";
  static const String collectFolder = "collect";

  // แสดงผลกี่รูป
  static const int topK = 30;

  // ถ้ายังไม่มีคอลัมน์ ahash หรือยังไม่ backfill จะ fallback ไปโหมดช้า (download candidates)
  static const int slowCandidatesLimit = 120;

  // upload webp
  static const int uploadMaxBytes = 220 * 1024; // ~220KB
  static const int uploadMaxDim = 1024;

  final http.Client _http = http.Client();

  bool _loading = false;
  String? _msg;

  Uint8List? _queryPreview;

  List<_BgRow> _rows = const [];

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  void _setMsg(String? s) {
    if (!mounted) return;
    setState(() => _msg = s);
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF0F172A);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI ค้นหารูป'),
        actions: [
          IconButton(
            tooltip: "เลือกภาพจากคลัง",
            onPressed: _loading ? null : () => _pickAndSearch(source: ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
          ),
          IconButton(
            tooltip: "ถ่ายรูปเพื่อค้นหา",
            onPressed: _loading ? null : () => _pickAndSearch(source: ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(
                title: "AI Image Search",
                subtitle: "เลือกภาพ 1 รูป แล้วระบบจะแมตช์กับคลัง background อัตโนมัติ",
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ค้นหาด้วยรูป (AI)",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: dark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: _loading ? null : () => _pickAndSearch(source: ImageSource.gallery),
                              child: const Text("เลือกภาพจากคลัง", style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: "ถ่ายรูป",
                            onPressed: _loading ? null : () => _pickAndSearch(source: ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_queryPreview == null)
                        const Text(
                          "ยังไม่ได้เลือกภาพ",
                          style: TextStyle(color: Colors.black54),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _queryPreview!,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("ภาพที่ใช้ค้นหา", style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _msg ?? "—",
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : () {
                                            setState(() {
                                              _queryPreview = null;
                                              _rows = const [];
                                              _msg = null;
                                            });
                                          },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text("ล้างผลลัพธ์"),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Text(
                    "ผลลัพธ์ (${_rows.length})",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  if (_msg != null) Text(_msg!, style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 10),

              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text("ยังไม่มีผลลัพธ์")),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 9 / 16,
                  ),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return _BgCard(
                      row: r,
                      onTap: () => _openDetails(r),
                    );
                  },
                ),
              const SizedBox(height: 20),

              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    "ถ้าคลังมี ~1000 รูป ให้เพิ่มคอลัมน์ `ahash` (text 64 ตัว) ในตาราง mobile_backgrounds แล้ว backfill ค่า 1 รอบ "
                    "จากนั้นการค้นหาจะลื่นมาก เพราะไม่ต้อง download รูป 1000 รูปมาคำนวณทุกครั้ง",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),

          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: 240,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text("กำลังค้นหา..."),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- MAIN FLOW ----------
  Future<void> _pickAndSearch({required ImageSource source}) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source);
    if (x == null) return;

    final bytes = await x.readAsBytes();

    await _runBusy(() async {
      setState(() {
        _queryPreview = bytes;
        _rows = const [];
      });

      _setMsg("กำลังคำนวณ hash...");
      final queryHash = _aHashFromBytes(bytes);
      final queryBits = _hashToBits(queryHash);

      // 1) โหมดเร็ว (ใช้ ahash จาก DB ถ้ามี)
      final fast = await _tryFastSearch(queryBits: queryBits, originalBytes: bytes);
      if (fast) return;

      // 2) fallback โหมดช้า (download candidates มาคำนวณ)
      await _slowSearch(queryHash: queryHash, originalBytes: bytes);
    });
  }

  Future<bool> _tryFastSearch({required String queryBits, required Uint8List originalBytes}) async {
    try {
      final data = await supabase.from(table).select("id,style,image_url,ahash").limit(2000);
      final list = (data as List).cast<Map<String, dynamic>>();

      final candidates = <_BgCandidate>[];
      for (final r in list) {
        final bits = (r["ahash"] ?? "").toString().trim();
        if (bits.length != 64) continue;
        candidates.add(
          _BgCandidate(
            id: (r["id"] ?? "").toString(),
            style: (r["style"] ?? "").toString(),
            imageUrl: _normalizePublicUrl((r["image_url"] ?? "").toString()),
            ahashBits: bits,
          ),
        );
      }
      if (candidates.isEmpty) return false;

      _setMsg("โหมดเร็ว: เทียบ hash กับคลัง ${candidates.length} รูป...");
      final scored = <_ScoredRow>[];
      for (final c in candidates) {
        final dist = _hammingBits64(queryBits, c.ahashBits);
        final score = 1.0 - (dist / 64.0);
        scored.add(_ScoredRow(row: _BgRow(id: c.id, style: c.style, imagePublic: c.imageUrl), score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final top = scored.take(topK).toList();

      setState(() => _rows = top.map((e) => e.row).toList());

      final best = top.isNotEmpty ? top.first : null;
      _setMsg(best == null ? "ไม่พบ match" : "Best: ${best.row.id} (${(best.score * 100).toStringAsFixed(1)}%)");

      await _saveCollectLog(
        originalBytes: originalBytes,
        bestMatchId: best?.row.id,
        bestScore: best?.score,
        topMatches: top
            .map((e) => {
                  "id": e.row.id,
                  "score": double.parse(e.score.toStringAsFixed(4)),
                  "style": e.row.style,
                  "image_public": e.row.imagePublic,
                })
            .toList(),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _slowSearch({required BigInt queryHash, required Uint8List originalBytes}) async {
    _setMsg("โหมดช้า: กำลังดึง candidates...");
    final candidates = await _fetchRows(limit: slowCandidatesLimit);

    if (candidates.isEmpty) {
      _setMsg("ไม่พบรูปในตาราง");
      setState(() => _rows = const []);
      return;
    }

    _setMsg("โหมดช้า: ดาวน์โหลดรูปเพื่อคำนวณ ${candidates.length} รูป...");
    final picked = candidates.take(min(candidates.length, slowCandidatesLimit)).toList();

    final scored = <_ScoredRow>[];
    const int concurrency = 8;
    for (int i = 0; i < picked.length; i += concurrency) {
      final chunk = picked.skip(i).take(concurrency).toList();
      final results = await Future.wait(chunk.map((r) async {
        final h = await _hashForUrl(r.imagePublic);
        if (h == null) return null;
        final dist = _hamming64(queryHash, h);
        final score = 1.0 - (dist / 64.0);
        return _ScoredRow(row: r, score: score);
      }));
      for (final s in results) {
        if (s != null) scored.add(s);
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(topK).toList();

    setState(() => _rows = top.map((e) => e.row).toList());

    final best = top.isNotEmpty ? top.first : null;
    _setMsg(best == null ? "ไม่พบ match" : "Best: ${best.row.id} (${(best.score * 100).toStringAsFixed(1)}%)");

    await _saveCollectLog(
      originalBytes: originalBytes,
      bestMatchId: best?.row.id,
      bestScore: best?.score,
      topMatches: top
          .map((e) => {
                "id": e.row.id,
                "score": double.parse(e.score.toStringAsFixed(4)),
                "style": e.row.style,
                "image_public": e.row.imagePublic,
              })
          .toList(),
    );
  }

  // ---------- Data ----------
  Future<List<_BgRow>> _fetchRows({int limit = 200}) async {
    final data = await supabase.from(table).select("id,style,image_url").order("id", ascending: false).limit(limit);
    final list = (data as List).cast<Map<String, dynamic>>();

    return list.map((r) {
      final idVal = (r["id"] ?? "").toString();
      final styleVal = (r["style"] ?? "").toString();
      final imageUrl = (r["image_url"] ?? "").toString();
      return _BgRow(id: idVal, style: styleVal, imagePublic: _normalizePublicUrl(imageUrl));
    }).toList();
  }

  String _normalizePublicUrl(String imageUrl) {
    final s = imageUrl.trim();
    if (s.isEmpty) return s;
    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    var path = s.replaceFirst(RegExp(r"^/+"), "");
    if (!path.contains("/")) path = "$folder/$path";
    if (path.startsWith("$bucket/")) path = path.substring(bucket.length + 1);

    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  // ---------- Hash ----------
  Future<BigInt?> _hashForUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return null;
    try {
      final res = await _http.get(Uri.parse(u)).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      return _aHashFromBytes(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  BigInt _aHashFromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return BigInt.zero;

    final small = img.copyResize(
      decoded,
      width: 8,
      height: 8,
      interpolation: img.Interpolation.average,
    );

    final lum = List<int>.filled(64, 0);
    int sum = 0;
    int idx = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final p = small.getPixel(x, y);
        final int r = p.r.toInt();
        final int g = p.g.toInt();
        final int b = p.b.toInt();
        final int gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
        lum[idx++] = gray;
        sum += gray;
      }
    }

    final double avg = sum / 64.0;
    BigInt hash = BigInt.zero;

    for (int i = 0; i < 64; i++) {
      if (lum[i] >= avg) hash |= (BigInt.one << (63 - i));
    }
    return hash;
  }

  String _hashToBits(BigInt h) => h.toUnsigned(64).toRadixString(2).padLeft(64, "0");

  int _hammingBits64(String a, String b) {
    int d = 0;
    for (int i = 0; i < 64; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) d++;
    }
    return d;
  }

  int _hamming64(BigInt a, BigInt b) {
    final x = a ^ b;
    int count = 0;
    BigInt v = x;
    while (v != BigInt.zero) {
      v &= (v - BigInt.one);
      count++;
    }
    return count;
  }

  // ---------- Location + Log ----------
  Future<Map<String, dynamic>> _getLocationPayload() async {
    final payload = <String, dynamic>{
      "loc_source": null,
      "lat": null,
      "lng": null,
      "accuracy_m": null,
    };

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        payload["loc_source"] = "service_off";
        return payload;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        payload["loc_source"] = "denied";
        return payload;
      }
      if (perm == LocationPermission.deniedForever) {
        payload["loc_source"] = "denied_forever";
        return payload;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        payload["lat"] = last.latitude;
        payload["lng"] = last.longitude;
        payload["accuracy_m"] = last.accuracy;
        payload["loc_source"] = "last_known";
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
      payload["lat"] = current.latitude;
      payload["lng"] = current.longitude;
      payload["accuracy_m"] = current.accuracy;
      payload["loc_source"] = "current_high";
      return payload;
    } catch (_) {
      payload["loc_source"] = "error";
      return payload;
    }
  }

  Future<void> _saveCollectLog({
    required Uint8List originalBytes,
    required String? bestMatchId,
    required double? bestScore,
    required List<Map<String, dynamic>> topMatches,
  }) async {
    try {
      final loc = await _getLocationPayload();
      final webpBytes = await _compressToWebpUnderLimit(originalBytes);

      final sha = sha256.convert(webpBytes).toString();
      final now = DateTime.now();
      final y = now.year.toString();
      final m = now.month.toString().padLeft(2, "0");
      final d = now.day.toString().padLeft(2, "0");

      final id = "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}";
      final path = "$collectFolder/$y/$m/$d/$id.webp";

      await supabase.storage.from(bucket).uploadBinary(
        path,
        webpBytes,
        fileOptions: const FileOptions(upsert: true, contentType: "image/webp"),
      );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
      final ua = kIsWeb ? "flutter_web" : "flutter_mobile";

      await supabase.from(logTable).insert({
        "image_path": path,
        "image_public": publicUrl,
        "mime": "image/webp",
        "size_bytes": webpBytes.length,
        "sha256": sha,

        "lat": loc["lat"],
        "lng": loc["lng"],
        "accuracy_m": loc["accuracy_m"],
        "loc_source": loc["loc_source"],

        "best_match_id": (bestMatchId == null ? null : int.tryParse(bestMatchId)),
        "best_score": bestScore,
        "top_matches": topMatches,

        "page": "AiImageSearchScreen",
        "user_agent": ua,
      });
    } catch (_) {
      // ไม่ทำให้ flow พัง
    }
  }

  Future<Uint8List> _compressToWebpUnderLimit(Uint8List input) async {
    int targetW = uploadMaxDim;
    int targetH = uploadMaxDim;

    try {
      final decoded = img.decodeImage(input);
      if (decoded != null) {
        final w = decoded.width;
        final h = decoded.height;
        if (w > h) {
          targetW = uploadMaxDim;
          targetH = (h * uploadMaxDim / w).round();
        } else {
          targetH = uploadMaxDim;
          targetW = (w * uploadMaxDim / h).round();
        }
      }
    } catch (_) {}

    Uint8List best = input;
    for (int q = 85; q >= 30; q -= 5) {
      final out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: targetW,
        minHeight: targetH,
        quality: q,
        format: CompressFormat.webp,
      );
      best = out;
      if (out.length <= uploadMaxBytes) break;
    }
    return best;
  }

  // ---------- Details ----------
  void _openDetails(_BgRow row) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("ID: ${row.id}", style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text("Style: ${row.style}", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Image.network(
                    row.imagePublic,
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE"),
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
}

class _BgCandidate {
  final String id;
  final String style;
  final String imageUrl;
  final String ahashBits;

  _BgCandidate({required this.id, required this.style, required this.imageUrl, required this.ahashBits});
}

class _BgRow {
  final String id;
  final String style;
  final String imagePublic;

  const _BgRow({required this.id, required this.style, required this.imagePublic});
}

class _ScoredRow {
  final _BgRow row;
  final double score;
  const _ScoredRow({required this.row, required this.score});
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFF2563EB);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [gold, Color(0xFF60A5FA)]),
            ),
            child: const Icon(Icons.image_search, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BgCard extends StatelessWidget {
  final _BgRow row;
  final VoidCallback onTap;

  const _BgCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFF2563EB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              row.imagePublic,
              fit: BoxFit.cover,
              cacheWidth: 420,
              filterQuality: FilterQuality.low,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (context, error, stack) =>
                  const Center(child: Icon(Icons.broken_image_rounded, color: Colors.black38)),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withOpacity(0.45),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
