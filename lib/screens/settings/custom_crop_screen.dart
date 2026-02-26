// lib/screens/settings/custom_crop_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

// 🎨 Palette สีสำหรับหน้า Crop (ธีมมืออาชีพ)
const Color kCropBg = Color(0xFF000000); 
const Color kControlPanelBg = Color(0xFF1C1C1E); 
const Color kPrimaryActionColor = Colors.white; 
const Color kPrimaryActionTextColor = Colors.black; 
const Color kSecondaryActionTextColor = Colors.white70; 

class CustomCropScreen extends StatefulWidget {
  final Uint8List image; 

  const CustomCropScreen({super.key, required this.image});

  @override
  State<CustomCropScreen> createState() => _CustomCropScreenState();
}

class _CustomCropScreenState extends State<CustomCropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCropBg,
      appBar: AppBar(
        backgroundColor: kCropBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (!_isCropping) Navigator.pop(context); 
          },
        ),
        title: const Text(
          'ปรับแต่งรูปภาพ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. ส่วนแสดงการตัดรูป
            Expanded(
              child: Stack(
                children: [
                  Crop(
                    image: widget.image,
                    controller: _controller,
                    
                    onCropped: (result) {
                      if (mounted) {
                        setState(() => _isCropping = false);
                        
                        Future.microtask(() {
                          if (!mounted) return;
                          
                          if (result is CropSuccess) {
                            // ✅ แก้คำว่า .data เป็น .croppedImage ครับ!
                            Navigator.pop(context, result.croppedImage); 
                          } else {
                            Navigator.pop(context, null); 
                          }
                        });
                      }
                    },
                    aspectRatio: 1 / 1, 
                    withCircleUi: true, 
                    baseColor: kCropBg,
                    maskColor: kCropBg.withOpacity(0.8),
                    cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: kPrimaryActionColor),
                    interactive: true, 
                  ),
                  
                  // แสดง Loading ถ้า _isCropping เป็น true
                  if (_isCropping)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: kPrimaryActionColor),
                            SizedBox(height: 16),
                            Text("กำลังบันทึกรูปภาพ...", style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. ส่วนปุ่มควบคุมด้านล่าง
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: kControlPanelBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)), 
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // ปุ่มยกเลิก
                      Expanded(
                        child: SizedBox(
                          height: 56, 
                          child: TextButton(
                            onPressed: _isCropping ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: kSecondaryActionTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: kSecondaryActionTextColor.withOpacity(0.3)), 
                              ),
                            ),
                            child: const Text(
                              "ยกเลิก",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ปุ่มตกลง
                      Expanded(
                        flex: 2, 
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isCropping
                                ? null
                                : () {
                                    setState(() => _isCropping = true); 
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _controller.crop(); 
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryActionColor,
                              foregroundColor: kPrimaryActionTextColor,
                              elevation: 0, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              "บันทึกรูปภาพ", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}