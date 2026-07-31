import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real fonts into the test binding.
///
/// Golden tests otherwise render every glyph as a filled box, because the
/// test environment substitutes a placeholder face and does not bundle the
/// Material icon font. That makes the resulting image useless for reviewing
/// anything except gross layout — you cannot see copy, type, or icons.
///
/// Call this from any preview test whose whole purpose is to be looked at.
/// Advances animations by pumping many small frames.
///
/// A single `pump(Duration)` renders exactly one frame that far ahead,
/// which leaves anything driven by flutter_animate sitting at its opening
/// value — invisible, if it starts from opacity zero. pumpAndSettle is not
/// an option either: Kiki breathes on a repeating controller, so settling
/// never terminates. Stepping frame by frame is the only way to get a
/// preview that shows the finished state.
Future<void> settleAnimations(
  WidgetTester tester, {
  Duration total = const Duration(milliseconds: 2600),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final frames = total.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

Future<void> loadPreviewFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
      );
      any = true;
    }
    if (any) await loader.load();
  }

  await load('Nunito', [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
    'assets/fonts/Nunito-Black.ttf',
  ]);
  await load('PatrickHand', ['assets/fonts/PatrickHand-Regular.ttf']);

  // The icon font ships with the SDK rather than the project. Probed
  // across the known install layouts; if none match, icons fall back to
  // boxes and only the icons are unreviewable.
  await load('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '${Platform.environment['HOME']}'
        '/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/usr/lib/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}
