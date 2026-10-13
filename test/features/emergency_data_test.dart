import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/data/demo/demo_fixtures.dart';
import 'package:tripsplit_world/core/money/split_engine.dart';
import 'package:tripsplit_world/data/models/reference.dart';
import 'package:tripsplit_world/data/models/expense.dart';
import 'package:tripsplit_world/features/emergency/emergency_data.dart';

void main() {
  group('Bundled offline emergency data', () {
    test('every guide has at least one step', () {
      expect(kBundledGuides, isNotEmpty);
      for (final EmergencyGuide guide in kBundledGuides) {
        expect(
          guide.steps,
          isNotEmpty,
          reason: 'guide ${guide.slug} has no steps',
        );
        for (final GuideStep step in guide.steps) {
          expect(
            step.heading,
            isNotEmpty,
            reason: '${guide.slug} has a blank heading',
          );
          expect(
            step.body,
            isNotEmpty,
            reason: '${guide.slug} has an empty body',
          );
        }
      }
    });

    test('every guide slug is unique', () {
      final Set<String> slugs = kBundledGuides
          .map((EmergencyGuide g) => g.slug)
          .toSet();
      expect(slugs.length, kBundledGuides.length);
    });

    test('every scenario points at a guide that exists', () {
      for (final ({EmergencyCategory category, IconData icon, String guideSlug})
          s
          in kEmergencyScenarios) {
        expect(
          kBundledGuides.any((EmergencyGuide g) => g.slug == s.guideSlug),
          isTrue,
          reason: 'scenario ${s.category.id} points at a missing guide',
        );
      }
    });

    test('no contact is presented as verified without a human check', () {
      for (final List<EmergencyResource> list
          in kBundledEmergencyContacts.values) {
        for (final EmergencyResource r in list) {
          expect(
            r.verification.isTrusted,
            isFalse,
            reason:
                '${r.id} is bundled as verified. Bundled data must never claim to be '
                'checked without a reviewer.',
          );
        }
      }
    });

    test('every bundled contact carries a source URL and organisation', () {
      for (final List<EmergencyResource> list
          in kBundledEmergencyContacts.values) {
        for (final EmergencyResource r in list) {
          expect(r.sourceUrl, isNotEmpty, reason: '${r.id} has no source URL');
          expect(r.sourceOrg, isNotEmpty, reason: '${r.id} has no source org');
          expect(
            r.sourceUrl.startsWith('https://'),
            isTrue,
            reason: '${r.id} source must be https',
          );
        }
      }
    });

    test('phone numbers are plausible for their country', () {
      // A light sanity check: no country code is invented from nowhere.
      final Map<String, List<EmergencyResource>> contacts =
          kBundledEmergencyContacts;
      expect(
        contacts.keys,
        containsAll(<String>['HK', 'JP', 'SG', 'GB', 'US', 'IN', 'AU', 'DE']),
      );
      for (final List<EmergencyResource> list in contacts.values) {
        for (final EmergencyResource r in list) {
          if (!r.hasPhone) continue;
          expect(
            r.phone!.replaceAll(RegExp(r'[^0-9]'), '').length,
            greaterThanOrEqualTo(3),
            reason: '${r.id} has a suspiciously short number',
          );
        }
      }
    });

    test('the Hong Kong guide exists and has Traditional Chinese phrases', () {
      final EmergencyGuide hk = kBundledGuides.firstWhere(
        (EmergencyGuide g) => g.slug == 'lost-passport-hong-kong',
      );
      expect(hk.countryCode, 'HK');
      expect(hk.phrasesFor('zh-Hant'), isNotEmpty);
      expect(hk.phrasesFor('zh-Hant').first, contains('護照'));
    });

    test('every guide has English help phrases', () {
      for (final EmergencyGuide guide in kBundledGuides) {
        expect(guide.phrasesFor('en'), isNotEmpty, reason: guide.slug);
      }
    });
  });

  group('Demo fixtures financial consistency', () {
    test('demo expense shares always sum to the expense total', () {
      for (final Expense e in DemoFixtures.expensesFor(DemoFixtures.hkTripId)) {
        final int sum = e.shares.fold<int>(0, (int s, x) => s + x.amountMinor);
        expect(
          sum,
          e.amountMinor,
          reason: 'shares for "${e.title}" do not sum to the total',
        );
      }
    });

    test('demo balances net to zero across the group', () {
      final List<MemberBalance> balances = DemoFixtures.balancesFor(
        DemoFixtures.hkTripId,
      );
      final int total = balances.fold<int>(
        0,
        (int s, MemberBalance b) => s + b.netMinor,
      );
      expect(
        total,
        0,
        reason:
            'balances must net to zero, or money has been created or destroyed',
      );
    });

    test('suggested settlements fully clear the demo balances', () {
      final List<MemberBalance> balances = DemoFixtures.balancesFor(
        DemoFixtures.hkTripId,
      );
      final Map<String, int> residual = <String, int>{
        for (final MemberBalance b in balances) b.memberId: b.netMinor,
      };
      for (final SettlementTransfer t in DemoFixtures.suggestionsFor(
        DemoFixtures.hkTripId,
      )) {
        residual[t.fromMemberId] = residual[t.fromMemberId]! + t.amountMinor;
        residual[t.toMemberId] = residual[t.toMemberId]! - t.amountMinor;
      }
      for (final MapEntry<String, int> e in residual.entries) {
        expect(e.value, 0, reason: '${e.key} is left unsettled');
      }
    });

    test('a personal expense never creates debt for another member', () {
      // Charlie's own SIM card must not appear in anyone else's share.
      final Expense sim = DemoFixtures.expensesFor(DemoFixtures.hkTripId)
          .firstWhere((Expense e) => e.isPersonal);
      expect(sim.paidBy, DemoFixtures.charlieId);
      expect(sim.participantIds, <String>[DemoFixtures.charlieId]);

      final List<Expense> shared = DemoFixtures.expensesFor(
        DemoFixtures.hkTripId,
      ).where((Expense e) => !e.isPersonal).toList();

      for (final MemberBalance balance in DemoFixtures.balancesFor(
        DemoFixtures.hkTripId,
      )) {
        if (balance.memberId == DemoFixtures.charlieId) continue;
        final int owedFromShared = shared
            .expand((Expense e) => e.shares)
            .where((ExpenseShareEntry s) => s.userId == balance.memberId)
            .fold<int>(
              0,
              (int sum, ExpenseShareEntry s) => sum + s.baseAmountMinor,
            );
        expect(
          balance.owesMinor,
          owedFromShared,
          reason:
              'a personal expense leaked into ${balance.memberId}\'s share total',
        );
      }
    });

    test('the taxi expense excludes the non-participant', () {
      final Expense taxi = DemoFixtures.expensesFor(DemoFixtures.hkTripId)
          .firstWhere((Expense e) => e.title.contains('Taxi'));
      expect(taxi.participantIds, isNot(contains(DemoFixtures.danaId)));
      expect(taxi.participantIds.length, 3);
    });

    test('the foreign-currency expense keeps its original amount and rate', () {
      final Expense cny = DemoFixtures.expensesFor(DemoFixtures.hkTripId)
          .firstWhere((Expense e) => e.isForeignCurrency);
      expect(cny.currency, 'CNY');
      expect(cny.amountMinor, 88000);
      expect(cny.baseAmountMinor, 96000);
      expect(cny.fxRate, greaterThan(0));
    });
  });
}
