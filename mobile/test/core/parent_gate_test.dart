// The gate in front of the grown-up screens.
//
// Behind it are the parent dashboard and logging out, and logging out is
// the one that matters: signing back in needs a phone number, so a child
// who gets through locks themselves out of their own app. It is meant to
// stop a small child exploring, not a determined adult.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/auth/parent_gate.dart';

/// Reads the sum off the screen and works out the answer, since the
/// question is generated fresh each time.
int answerOnScreen(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((d) => d.contains('×'));
  final parts = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(text)!;
  return int.parse(parts.group(1)!) * int.parse(parts.group(2)!);
}

/// Opens the gate, handing back a box that fills in once it resolves.
///
/// The result has to be read after the dialog closes, not when it opens —
/// and it has to be the result, not merely that the dialog went away.
/// Cancelling makes it go away too, so a test that checks only for a
/// closed dialog passes whether the gate let you through or turned you
/// back.
Future<List<bool?>> openedGate(WidgetTester tester) async {
  final box = <bool?>[null];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async => box[0] = await ParentGate.open(context),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return box;
}

void main() {
  testWidgets('the right answer opens it', (tester) async {
    final result = await openedGate(tester);
    await tester.enterText(
        find.byType(TextField), '${answerOnScreen(tester)}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing, reason: 'gate should close');
    expect(result.single, isTrue);
  });

  testWidgets('a wrong answer does not', (tester) async {
    final result = await openedGate(tester);
    await tester.enterText(
        find.byType(TextField), '${answerOnScreen(tester) + 1}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget, reason: 'gate stays open');
    expect(find.textContaining('Not quite'), findsOneWidget);
    expect(result.single, isNull, reason: 'nothing resolved; still shut');
  });

  testWidgets('a wrong answer brings a different question', (tester) async {
    // Otherwise a child could arrive at the answer by working through the
    // numbers against one unchanging sum.
    await openedGate(tester);

    final seen = <int>{answerOnScreen(tester)};
    for (var i = 0; i < 12; i++) {
      await tester.enterText(find.byType(TextField), '-1');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      seen.add(answerOnScreen(tester));
    }
    expect(seen.length, greaterThan(1));
  });

  testWidgets('cancelling does not open it', (tester) async {
    final result = await openedGate(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(result.single, isFalse);
  });

  testWidgets('dismissing by tapping outside does not open it',
      (tester) async {
    // showDialog resolves null when barrier-dismissed, and null must not
    // be read as a pass.
    final result = await openedGate(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(result.single, isFalse);
  });

  testWidgets('the sum is beyond the ages this app is for', (tester) async {
    // Both factors three or more: nothing here is reachable by counting,
    // and nothing is a times-one or a times-two.
    for (var i = 0; i < 30; i++) {
      await openedGate(tester);
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('×'));
      final m = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(text)!;
      expect(int.parse(m.group(1)!), greaterThanOrEqualTo(3));
      expect(int.parse(m.group(2)!), greaterThanOrEqualTo(3));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
