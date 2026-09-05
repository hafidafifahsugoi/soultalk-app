import 'package:flutter/material.dart';

class MoodIndicatorCircle extends StatelessWidget {
  final String moodAbbr;
  const MoodIndicatorCircle({super.key, required this.moodAbbr});

  @override
  Widget build(BuildContext context) {
    Color centerColor;
    Color outerColor;
    
    final clean = moodAbbr.toLowerCase().trim();
    if (clean == 'sd' || clean == 'sangat sedih') {
      // Sangat sedih -> dusty blue / periwinkle
      centerColor = const Color(0xFF899BCA);
      outerColor = const Color(0xFFB4C3EC);
    } else if (clean == 'cm' || clean == 'sedih') {
      // Sedih -> soft lavender
      centerColor = const Color(0xFFBCA6E6);
      outerColor = const Color(0xFFD6C8F2);
    } else if (clean == 'st' || clean == 'netral' || clean == 'biasa') {
      // Netral -> soft grey-blue
      centerColor = const Color(0xFF9AB2C5);
      outerColor = const Color(0xFFC5D4E2);
    } else if (clean == 'ti' || clean == 'senang' || clean == 'baik') {
      // Senang -> soft mint / sage
      centerColor = const Color(0xFFA2CEB7);
      outerColor = const Color(0xFFCDE8DB);
    } else {
      // Sangat bahagia -> soft peach / warm yellow (default/Te/Bh/Hebat)
      centerColor = const Color(0xFFF6C8A6);
      outerColor = const Color(0xFFFBE5D6);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: centerColor.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                centerColor,
                outerColor.withValues(alpha: 0.6),
                outerColor.withValues(alpha: 0.1),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
