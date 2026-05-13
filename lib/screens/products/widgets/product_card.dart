import 'package:flutter/material.dart';

// เปลี่ยน Path ให้ตรงกับโฟลเดอร์ของนายนะจ๊ะ
import '../../../constants.dart';

const Color kCardDark = Color(0xFF1C1C1E); 
const Color kAccentColor = Color(0xFFC6A87C);

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String Function(dynamic) formatPrice;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.formatPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String priceText = "";
    if (product['minPrice'] == product['maxPrice']) {
      priceText = "฿${formatPrice(product['minPrice'])}";
    } else {
      priceText = "฿${formatPrice(product['minPrice'])} - ฿${formatPrice(product['maxPrice'])}";
    }

    String displayImage = product['image'] ?? '';
    if (displayImage.isEmpty && product['variants'].isNotEmpty) {
      displayImage = product['variants'][0]['variant_image'] ?? '';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), 
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardDark,
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.black26, 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: displayImage.isNotEmpty
                    ? Image.network(displayImage, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image_rounded, color: Colors.white38))
                    : const Icon(Icons.image_not_supported_rounded, color: Colors.white38),
              ),
            ),
            const SizedBox(width: 16), 

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product["collection"].toString().isNotEmpty)
                    Text(
                      product["collection"].toString().toUpperCase(),
                      style: const TextStyle(color: kAccentColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product["name"],
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    priceText,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kAccentColor.withOpacity(0.15), 
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${product['variants'].length} รุ่นย่อย",
                      style: const TextStyle(color: kAccentColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}