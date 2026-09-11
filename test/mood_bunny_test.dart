import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk_ai/widgets/mood_bunny_icon.dart';

void main() {
  group('MoodBunnyIcon tests', () {
    test('getAssetPath maps correctly', () {
      expect(MoodBunnyIcon.getAssetPath(index: 0), 'assets/images/moods/bunny_sad.png');
      expect(MoodBunnyIcon.getAssetPath(index: 1), 'assets/images/moods/bunny_weary.png');
      expect(MoodBunnyIcon.getAssetPath(index: 2), 'assets/images/moods/bunny_neutral.png');
      expect(MoodBunnyIcon.getAssetPath(index: 3), 'assets/images/moods/bunny_calm.png');
      expect(MoodBunnyIcon.getAssetPath(index: 4), 'assets/images/moods/bunny_happy.png');
    });

    test('emojiToIndex maps legacy emojis properly', () {
      expect(MoodBunnyIcon.emojiToIndex('😢'), 0);
      expect(MoodBunnyIcon.emojiToIndex('😔'), 1);
      expect(MoodBunnyIcon.emojiToIndex('😐'), 2);
      expect(MoodBunnyIcon.emojiToIndex('🙂'), 3);
      expect(MoodBunnyIcon.emojiToIndex('😊'), 4);
    });

    test('getLabel returns valid labels', () {
      expect(MoodBunnyIcon.getLabel(0), 'Sedih');
      expect(MoodBunnyIcon.getLabel(1), 'Lelah');
      expect(MoodBunnyIcon.getLabel(2), 'Biasa');
      expect(MoodBunnyIcon.getLabel(3), 'Tenang');
      expect(MoodBunnyIcon.getLabel(4), 'Bahagia');
    });

    testWidgets('MoodBunnyIcon renders Image widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoodBunnyIcon(moodIndex: 4, size: 48),
          ),
        ),
      );

      expect(find.byType(MoodBunnyIcon), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
