import 'package:flutter_test/flutter_test.dart';

import 'package:phonics_app/app.dart';

void main() {
  testWidgets('PhonicsApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const PhonicsApp());
    expect(find.byType(PhonicsApp), findsOneWidget);
  });
}
