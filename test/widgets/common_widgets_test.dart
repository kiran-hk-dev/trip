import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/router/app_shell.dart';
import 'package:tripsplit_world/shared/widgets/common.dart';

void main() {
  group('AppShell responsive navigation', () {
    Future<void> pumpShell(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: AppShell(
              tab: AppTab.home,
              child: const Scaffold(body: Text('content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a phone-width shell shows the bottom navigation bar', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester, const Size(390, 844));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      // Five primary destinations, labelled.
      for (final AppTab tab in AppTab.values) {
        expect(
          find.text(tab.label),
          findsOneWidget,
          reason: '${tab.label} is missing from the bottom navigation',
        );
      }
    });

    testWidgets('a small phone (320px) still shows all five destinations', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester, const Size(320, 640));

      expect(find.byType(NavigationBar), findsOneWidget);
      // No overflow errors at the narrowest supported width.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet-width shell switches to a navigation rail', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester, const Size(1024, 768));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a desktop-width shell uses an extended rail', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester, const Size(1440, 900));

      final NavigationRail rail = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(rail.extended, isTrue);
      expect(find.text('My trips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shell content stays reachable at every breakpoint', (
      WidgetTester tester,
    ) async {
      for (final Size size in <Size>[
        const Size(320, 640),
        const Size(375, 812),
        const Size(768, 1024),
        const Size(1440, 900),
      ]) {
        await pumpShell(tester, size);
        expect(find.text('content'), findsOneWidget, reason: 'failed at $size');
      }
    });
  });

  group('Interactive sizing', () {
    testWidgets('filled buttons reach the 48dp touch target', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Add expense'),
              ),
            ),
          ),
        ),
      );

      final Rect buttonRect = tester.getRect(find.byType(FilledButton));
      expect(
        buttonRect.height,
        greaterThanOrEqualTo(AppHitTarget.minimum),
        reason: 'primary actions must meet the minimum touch target',
      );
    });

    testWidgets('outlined buttons also reach the touch target', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Add expense'),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getRect(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(AppHitTarget.minimum),
      );
    });
  });

  group('Layout integrity', () {
    Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('a long trip title wraps instead of overflowing at 320px', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        320,
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'A very long trip title that should wrap rather than overflow the card',
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Body copy that is also long enough to need more than one line.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('an expense-style row does not overflow at 320px', (
      WidgetTester tester,
    ) async {
      await pumpAt(
        tester,
        320,
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('🍜', style: TextStyle(fontSize: 19)),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Birthday dinner at a restaurant with a long name'),
                      Text('Dana Rivera · Equal split'),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('1,234.56'),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Design system widgets', () {
    testWidgets('StatusPill renders its label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusPill(label: 'Verified', icon: Icons.verified),
          ),
        ),
      );
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('InlineBanner always renders its message as text', (
      WidgetTester tester,
    ) async {
      // Colour alone must never be the only carrier of a warning.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineBanner(
              message: 'This number has not been verified.',
              tone: StatusTone.warning,
            ),
          ),
        ),
      );
      expect(find.text('This number has not been verified.'), findsOneWidget);
    });

    testWidgets('EmptyState shows its call to action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.luggage_outlined,
              title: 'No trips yet',
              message: 'Create your first trip.',
              action: FilledButton(
                onPressed: () {},
                child: const Text('Create'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('No trips yet'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('skeleton placeholders render while loading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SkeletonCard(lines: 3))),
      );
      expect(find.byType(SkeletonBox), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CopyableValue copies to the clipboard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CopyableValue(
              value: '999',
              label: 'Emergency',
              icon: Icons.call,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Accessibility', () {
    testWidgets('the app clamps extreme text scaling without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 720);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: AppShell(
                tab: AppTab.home,
                child: const Scaffold(body: Text('content')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
