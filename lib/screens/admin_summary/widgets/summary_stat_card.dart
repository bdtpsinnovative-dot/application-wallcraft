import 'package:flutter/material.dart';

class SummaryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const SummaryStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  static const Color kCardDark = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final bool hasK = value.endsWith('K') || value.endsWith('k');
    final String cleanValueStr = hasK ? value.substring(0, value.length - 1) : value;
    final double? parsedVal = double.tryParse(cleanValueStr);
    final bool isInteger = parsedVal != null && !cleanValueStr.contains('.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardDark, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), 
            child: Icon(icon, color: color, size: 20)
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline, 
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (parsedVal != null)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: parsedVal),
                  duration: Duration(
                    milliseconds: (900 + (parsedVal * 1.0).toInt()).clamp(900, 1800),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    final displayStr = isInteger
                        ? "${val.toInt()}${hasK ? 'K' : ''}"
                        : "${val.toStringAsFixed(1)}${hasK ? 'K' : ''}";
                    return Text(
                      displayStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}