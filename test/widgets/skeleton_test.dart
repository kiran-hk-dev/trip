import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/shared/widgets/common.dart';

/// Guards the loading placeholder against the unbounded-height overflow that
/// was reported from the running app (a RenderFlex overflow of 599240 pixels).
///
/// The cause was `SkeletonBox(height: double.infinity)`. A Column sizes itself
/// to its children, so a child asking for infinite height is invalid
/// constraints; wherever the placeholder was not bounded by its parent it
/// overflowed by an arbitrary amount. `height` is now nullable, where null
/// means "fill the height the parent already constrains".
void main() {
  testWidgets('SkeletonBox fills a bounded parent without overflowing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const <Widget>[
              Expanded(child: SkeletonBox()),
              SkeletonBox(height: 16),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SkeletonBox with no height does not overflow an unbounded parent',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(children: const <Widget>[SkeletonBox()]),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'a placeholder must never request infinite height',
      );
    },
  );

  testWidgets('an explicitly infinite height is rejected', (
    WidgetTester tester,
  ) async {
    // Guards against the bug being reintroduced at a call site.
    expect(() => SkeletonBox(height: double.infinity), throwsAssertionError);
  });

  testWidgets('fixed-height placeholders do not overflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: const <Widget>[
                SkeletonBox(height: 80),
                SkeletonBox(height: 12),
                SkeletonBox(height: 160),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
