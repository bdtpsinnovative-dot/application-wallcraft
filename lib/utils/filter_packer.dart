/// อัลกอริทึมจัดเรียงตัวกรองแบบ Bin-Packing (Best-Fit Decreasing)
/// ช่วยประกบคู่คำสั้นและคำยาวให้อยู่ในแถวเดียวกันได้เยอะที่สุด ลดพื้นที่ว่างเปลือย
List<T> packFilterItems<T>({
  required List<T> items,
  required String Function(T) labelExtractor,
  double maxRowWidth = 330.0,
  String pinnedFirst = 'ทั้งหมด',
}) {
  if (items.length <= 1) return items;

  // 1. แยกรายการที่ต้องการตรึงไว้หน้าสุด (เช่น 'ทั้งหมด' หรือ 'all')
  T? pinnedItem;
  final others = <T>[];

  for (final item in items) {
    final label = labelExtractor(item).trim();
    if (pinnedItem == null && (label == pinnedFirst || label.toLowerCase() == 'all')) {
      pinnedItem = item;
    } else if (label.isNotEmpty) {
      others.add(item);
    }
  }

  if (others.isEmpty) return items;

  // ฟังก์ชันคำนวณความกว้างประมาณการของชิป (ตัวอักษร + padding/border + spacing)
  double estimateChipWidth(String text) {
    final displayText = (text == 'ทั้งหมด' || text.toLowerCase() == 'all') ? 'ทุกรายการ' : text;
    return (displayText.length * 7.5) + 30.0;
  }

  // 2. จัดเรียงคำตามความยาวจากมากไปน้อย (First-Fit Decreasing)
  others.sort((a, b) => labelExtractor(b).length.compareTo(labelExtractor(a).length));

  final List<List<T>> rows = [];
  final List<double> rowWidths = [];

  // แถวแรกเริ่มด้วย pinnedItem (ถ้ามี)
  if (pinnedItem != null) {
    rows.add([pinnedItem]);
    rowWidths.add(estimateChipWidth(labelExtractor(pinnedItem)));
  }

  for (final item in others) {
    final label = labelExtractor(item);
    final w = estimateChipWidth(label);
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

  final List<T> result = [];
  for (final row in rows) {
    result.addAll(row);
  }
  return result;
}
