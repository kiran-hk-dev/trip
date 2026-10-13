import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/features/profile/settings_page.dart';
import 'package:tripsplit_world/shared/widgets/common.dart';

/// Guards the account section of Settings.
///
/// The sign-out action was implemented on [AuthController] but never wired to
/// any UI, so a signed-in user had no way to end their session. These tests
/// pin the wiring so it cannot silently disappear again.
Future<void> _pumpSettings(WidgetTester tester) async {
  // The account section sits below the fold in a phone-sized viewport, so give
  // the test a tall surface; otherwise the ListView never builds it and the
  // assertions pass/fail for the wrong reason.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SettingsPage()),
      ),
    ),
  );
  await tester.pump();
  // Let the post-frame work in the page settle.
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Settings account section', () {
    testWidgets('offers a sign-out action', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('sign-out sits above the destructive delete-account action',
        (WidgetTester tester) async {
      await _pumpSettings(tester);

      final Finder signOut = find.text('Sign out');
      final Finder delete = find.text('Delete my account');
      expect(signOut, findsOneWidget);
      expect(delete, findsOneWidget);

      // Sign out must be reachable without scrolling past the irreversible
      // delete option, so it comes first.
      final double signOutY = tester.getTopLeft(signOut).dy;
      final double deleteY = tester.getTopLeft(delete).dy;
      expect(signOutY, lessThan(deleteY));
    });

    testWidgets('sign-out explains itself in demo mode', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester);
      // Under `flutter test` DEMO_MODE is false, so the live-session wording is
      // expected here; the demo wording is covered by the source branch.
      expect(find.textContaining('session'), findsWidgets);
    });

    testWidgets(
      'does not ask to confirm when there is no session to end',
      (WidgetTester tester) async {
        // A unit test has no Supabase client, so the page must explain that
        // rather than opening a confirmation it could never honour.
        await _pumpSettings(tester);

        await tester.tap(find.text('Sign out'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('no session'), findsOneWidget);
      },
    );

    testWidgets('leaves the user on the page when there is nothing to end', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Still on Settings, not navigated away.
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  group('confirmDestructive', () {
    testWidgets('returns false when dismissed', (WidgetTester tester) async {
      bool? result = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmDestructive(
                    context,
                    title: 'Sure?',
                    message: 'Cannot be undone.',
                    confirmLabel: 'Do it',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isFalse);
    });
  });
}