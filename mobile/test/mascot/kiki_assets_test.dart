// Kiki is the app's only image, and she is chosen by enum rather than by
// path, so a mood with no artwork behind it is not a compile error — it is
// a grey box in front of a child, on whichever screen happens to use that
// mood. Most of her call sites have no golden covering them.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/mascot/kiki.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every mood has artwork in the bundle', () async {
    for (final mood in KikiMood.values) {
      final bytes = await rootBundle.load(Kiki.assetFor(mood));
      expect(
        bytes.lengthInBytes,
        greaterThan(0),
        reason: 'no artwork bundled for KikiMood.${mood.name}',
      );
    }
  });

  test('the retired characters are gone from the bundle', () async {
    // A monster, an elephant filed as the monster's excited face, and the
    // heroes nothing referenced. Deleting the files is only half of it;
    // this fails if a path creeps back into pubspec.
    for (final path in const [
      'assets/images/popi.png',
      'assets/images/popiE.png',
      'assets/images/im.png',
      'assets/images/image.png',
      'assets/images/image2.png',
    ]) {
      expect(
        () => rootBundle.load(path),
        throwsA(isA<FlutterError>()),
        reason: '$path is still shipping',
      );
    }
  });
}
