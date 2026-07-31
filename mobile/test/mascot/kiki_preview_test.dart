// Renders Kiki in every mood so her artwork can be reviewed as an image.
// Regenerate with:  flutter test --update-goldens test/mascot
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/mascot/kiki.dart';
import 'package:phonics_app/core/theme/app_colors.dart';

void main() {
  testWidgets('Kiki renders in every mood', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 200));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: AppColors.parchment,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final m in KikiMood.values) Kiki(size: 140, mood: m),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('kiki_moods.png'),
    );
  });
}
