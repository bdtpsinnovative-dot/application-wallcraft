import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProductItem {
  String? categoryId;
  String? interestLevel;
  TextEditingController noteCtrl = TextEditingController();
  
  // 🌟 ฟีเจอร์ที่ 1 ที่คุณอยากได้ (พื้นที่ และ ตำแหน่ง) เรามาสร้างตัวแปรรับค่าตรงนี้ครับ
  TextEditingController areaCtrl = TextEditingController(); 
  TextEditingController locationCtrl = TextEditingController(); 

  List<XFile> itemImages = [];
  List<dynamic> selectedProjectIds = [];
  Map<dynamic, TextEditingController> projectAreaControllers = {};
}