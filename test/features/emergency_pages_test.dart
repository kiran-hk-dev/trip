import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/features/emergency/emergency_center_page.dart';
import 'package:tripsplit_world/features/emergency/guide_page.dart';
import 'package:tripsplit_world/features/emergency/hk_emergency_page.dart';

/// The Emergency Center must work without a network and without an account,
/// so these tests run with no Supabase client initialised and the bundled
/// offline data serves every screen.

/// Tall enough to lay out the longest of these screens in full.
///
/// These pages are long lists, and a scroll view only builds what is on screen.
/// Asserting on a closing disclaimer from a phone-sized viewport therefore
/// tests nothing unless the viewport is scrolled, and scrolling is unreliable
/// here because the total extent is only known after the content below the
/// fold has been laid out. A tall viewport sidesteps that: everything is built
/// and the tests stay about content rather than scroll mechanics.
///
/// At 390dp wide the longest of these screens is the Hong Kong page at roughly
/// 5,000px once its contact cards and step strip are measured, so this leaves
/// headroom.
///
/// Layout regressions are still covered by the phone-sized tests, which are
/// the ones that would catch an overflow.
const Size kTallPhone = Size(390, 7000);

/// Renders a screen at a given viewport size.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Renders a screen tall enough that every section is built and findable.
Future<void> pumpTallScreen(WidgetTester tester, Widget child) =>
    pumpScreen(tester, child, size: kTallPhone);

/// The page-level scroll view.
///
/// The pages use different scroll widgets (`ListView` on the guide and Hong
/// Kong pages, `CustomScrollView` on the Emergency Center) and the guide adds
/// nested scroll views of its own, so this goes through the common
/// `Scrollable` and takes the outermost one.
Finder get pageScroll => find.byType(Scrollable).first;

/// Jumps to the bottom of the page.
Future<void> scrollToBottom(WidgetTester tester) async {
  final ScrollableState state = tester.state<ScrollableState>(pageScroll);
  state.position.jumpTo(state.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

/// Collects the rendered help phrases.
///
/// They are selectable so a traveller can copy them or read them aloud in a
/// language they cannot speak.
List<String> renderedPhrases(WidgetTester tester) => tester
    .widgetList<SelectableText>(find.byType(SelectableText))
    .map((SelectableText w) => w.data ?? '')
    .toList(growable: false);

/// Advances the emergency wizard one step.
///
/// Returns false once the wizard has reached its final step and the button
/// reads "Done".
Future<bool> tapNext(WidgetTester tester) async {
  final Finder next = find.text('Next step');
  if (next.evaluate().isEmpty) return false;
  await tester.tap(next);
  await tester.pumpAndSettle();
  return true;
}

/// Advances the wizard to its final step.
Future<void> runToLastStep(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    if (!await tapNext(tester)) return;
  }
}

void main() {
  group('Emergency Center', () {
    testWidgets('shows the "not a substitute for authorities" disclaimer', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const EmergencyCenterPage());

      expect(find.textContaining('not a substitute'), findsOneWidget);
    });

    testWidgets('lists bundled Hong Kong contacts with their source', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const EmergencyCenterPage());

      expect(find.text('999'), findsWidgets);
      // Every safety-critical claim carries its publisher.
      expect(
        find.textContaining('Source: Hong Kong Police Force'),
        findsWidgets,
      );
    });

    testWidgets('never presents bundled data as verified', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const EmergencyCenterPage());

      expect(find.text('Not yet verified'), findsWidgets);
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('offers the Hong Kong lost-passport flow', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const EmergencyCenterPage());

      expect(find.text('Lost passport in Hong Kong'), findsOneWidget);
    });

    testWidgets('lists every bundled scenario', (WidgetTester tester) async {
      await pumpTallScreen(tester, const EmergencyCenterPage());

      expect(find.text('Lost passport'), findsOneWidget);
      expect(find.text('Lost phone'), findsOneWidget);
      expect(find.text('Stolen wallet'), findsOneWidget);
      expect(find.text('Medical emergency'), findsOneWidget);
    });

    testWidgets('renders on a phone without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const EmergencyCenterPage());
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 320px without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyCenterPage(),
        size: const Size(320, 720),
      );
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('Lost passport guide', () {
    testWidgets('walks through the steps one at a time', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: kTallPhone,
      );

      expect(find.textContaining('Step 1 of'), findsOneWidget);
      expect(find.textContaining('Get to safety'), findsOneWidget);

      await tapNext(tester);
      expect(find.textContaining('Report to the police'), findsOneWidget);

      await tapNext(tester);
      expect(find.textContaining('embassy or consulate'), findsWidgets);
    });

    testWidgets('never claims a police report replaces a document', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: kTallPhone,
      );

      expect(
        find.textContaining('does not replace a travel document'),
        findsWidgets,
      );
    });

    testWidgets('exposes help phrases on the final step', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: kTallPhone,
      );

      await runToLastStep(tester);

      expect(find.textContaining('Show this to someone'), findsOneWidget);

      final List<String> phrases = renderedPhrases(tester);
      expect(phrases, isNotEmpty);
      expect(
        phrases.any(
          (String p) => p.contains('passport has been lost or stolen'),
        ),
        isTrue,
        reason: 'a traveller must be able to say what happened',
      );
      expect(
        phrases.any((String p) => p.contains('incident reference number')),
        isTrue,
        reason: 'the police report is the thing the traveller needs most',
      );
    });

    testWidgets('offers the phrases in the local language', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: kTallPhone,
      );

      await runToLastStep(tester);

      expect(find.text('繁體中文'), findsOneWidget);
    });

    testWidgets('refuses to guarantee airline boarding', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: kTallPhone,
      );

      // Step 5 covers the airline.
      for (int i = 0; i < 4; i++) {
        await tapNext(tester);
      }

      expect(
        find.textContaining('No airline can promise boarding'),
        findsOneWidget,
      );
    });

    testWidgets('shows a helpful state for an unknown slug', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'does-not-exist'),
      );

      expect(find.text('Guide unavailable'), findsOneWidget);
    });

    testWidgets('renders on a phone without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
      );
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 320px without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const EmergencyGuidePage(slug: 'lost-passport-abroad'),
        size: const Size(320, 720),
      );
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('Hong Kong lost-passport flow', () {
    testWidgets('leads with the immediate-danger question and 999', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(find.text('Are you in immediate danger?'), findsOneWidget);
      expect(find.text('Call 999'), findsOneWidget);
    });

    testWidgets('offers a Chinese phrase the traveller can show someone', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(
        renderedPhrases(tester).any((String p) => p.contains('請幫我叫警察')),
        isTrue,
        reason: 'pointing at the screen beats trying to speak Cantonese',
      );
    });

    testWidgets('lists HK contacts with the source organisation', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(find.text('Hong Kong contacts'), findsOneWidget);
      expect(
        find.textContaining('Source: Hong Kong Police Force'),
        findsWidgets,
      );
      expect(find.text('Not yet verified'), findsWidgets);
    });

    testWidgets('lays out the step strip without overflowing', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(find.text('Full procedure'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('explains that not every country has a HK consulate', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(find.textContaining('resident consulate'), findsWidgets);
    });

    testWidgets('states it cannot guarantee boarding or issue documents', (
      WidgetTester tester,
    ) async {
      await pumpTallScreen(tester, const HongKongLostPassportPage());

      expect(find.textContaining('cannot confirm your identity'), findsWidgets);
      expect(find.textContaining('guarantee'), findsWidgets);
    });

    testWidgets('renders on a phone without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const HongKongLostPassportPage());
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at 320px without overflow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const HongKongLostPassportPage(),
        size: const Size(320, 720),
      );
      await scrollToBottom(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
