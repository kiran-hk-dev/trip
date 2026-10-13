import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/features/auth/auth_shell.dart';

/// The screens the /welcome child routes render directly.
///
/// These are pushed as children of /welcome, so go_router replaces AuthShell
/// rather than nesting inside it. They must therefore supply their own
/// Scaffold: without a Material ancestor above them, every TextField throws
/// "No Material widget found". They must also fit a 390px-wide phone.
///
/// Note: two things are deliberately avoided here.
///
/// `pumpAndSettle` hangs, because the screens show progress indicators whose
/// animations never end. Fixed frames are enough to surface a layout or
/// Material-ancestor fault.
///
/// Replacing `FlutterError.onError` to collect messages also hangs the run:
/// flutter_test relies on that hook to complete a test, so swallowing errors
/// stalls it. `tester.takeException()` reports the first error the normal way.
Future<void> pumpFrames(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  expect(
    tester.takeException(),
    isNull,
    reason:
        'these pages are /welcome child routes, so they replace AuthShell and '
        'must supply their own Scaffold',
  );
}

void main() {
  testWidgets('SignInPage has a Material ancestor and fits a 390px phone', (
    WidgetTester tester,
  ) async {
    await pumpFrames(tester, const SignInPage());
  });

  testWidgets('SignUpPage has a Material ancestor and fits a 390px phone', (
    WidgetTester tester,
  ) async {
    await pumpFrames(tester, const SignUpPage());
  });

  testWidgets('ForgotPasswordPage has a Material ancestor and fits', (
    WidgetTester tester,
  ) async {
    await pumpFrames(tester, const ForgotPasswordPage());
  });

  testWidgets('sign-up fields are present and editable', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const SignUpPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(TextFormField), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Robin Fields',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up does not ask the user to confirm their email', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const SignUpPage()),
      ),
    );
    await tester.pump();

    // Signing up lands the user straight in, so nothing may tell them to go
    // and check an inbox before they can use the app.
    expect(find.textContaining('Confirm your email'), findsNothing);
    expect(find.textContaining('finish signing up'), findsNothing);
  });
}
