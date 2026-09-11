import 'package:flutter/material.dart';

/// Reusable widget for displaying the cute SoulTalk rabbit mood character.
/// Transparent background, scalable, and supports tap animations.
class MoodBunnyIcon extends StatelessWidget {
  const MoodBunnyIcon({
    super.key,
    this.moodIndex,
    this.emoji,
    this.moodKey,
    this.size = 32.0,
    this.isSelected = false,
    this.onTap,
  });

  final int? moodIndex;
  final String? emoji;
  final String? moodKey;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Returns the asset path for a given mood index (0..4) or emoji string.
  static String getAssetPath({int? index, String? emoji, String? key}) {
    if (key != null) {
      switch (key.toLowerCase()) {
        case 'sad':
        case '0':
          return 'assets/images/moods/bunny_sad.png';
        case 'weary':
        case '1':
          return 'assets/images/moods/bunny_weary.png';
        case 'neutral':
        case '2':
          return 'assets/images/moods/bunny_neutral.png';
        case 'calm':
        case '3':
          return 'assets/images/moods/bunny_calm.png';
        case 'happy':
        case '4':
          return 'assets/images/moods/bunny_happy.png';
        case 'sparkle':
          return 'assets/images/moods/bunny_sparkle.png';
        case 'broken':
          return 'assets/images/moods/bunny_broken.png';
        case 'angry':
          return 'assets/images/moods/bunny_angry.png';
        case 'shiver':
          return 'assets/images/moods/bunny_shiver.png';
      }
    }

    int? resolvedIndex = index;
    if (resolvedIndex == null && emoji != null) {
      resolvedIndex = emojiToIndex(emoji);
    }

    switch (resolvedIndex) {
      case 0:
        return 'assets/images/moods/bunny_sad.png';
      case 1:
        return 'assets/images/moods/bunny_weary.png';
      case 2:
        return 'assets/images/moods/bunny_neutral.png';
      case 3:
        return 'assets/images/moods/bunny_calm.png';
      case 4:
        return 'assets/images/moods/bunny_happy.png';
      default:
        return 'assets/images/moods/bunny_calm.png';
    }
  }

  /// Maps legacy text emojis to mood index
  static int emojiToIndex(String emoji) {
    if (emoji.contains('😢') || emoji.contains('😭') || emoji.contains('St')) return 0;
    if (emoji.contains('😔') || emoji.contains('😞') || emoji.contains('Lh')) return 1;
    if (emoji.contains('😐') || emoji.contains('😶') || emoji.contains('Bs')) return 2;
    if (emoji.contains('🙂') || emoji.contains('😌') || emoji.contains('Tn')) return 3;
    if (emoji.contains('😊') || emoji.contains('🥰') || emoji.contains('😄') || emoji.contains('Bh')) return 4;
    return 3;
  }

  /// Label for a given mood index
  static String getLabel(int index) {
    switch (index) {
      case 0:
        return 'Sedih';
      case 1:
        return 'Lelah';
      case 2:
        return 'Biasa';
      case 3:
        return 'Tenang';
      case 4:
        return 'Bahagia';
      default:
        return 'Tenang';
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = getAssetPath(index: moodIndex, emoji: emoji, key: moodKey);

    Widget imageWidget = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        Icons.sentiment_satisfied_alt_rounded,
        size: size,
        color: const Color(0xFF6E8BD6),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
