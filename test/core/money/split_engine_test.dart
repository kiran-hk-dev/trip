import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/money/split_engine.dart';

void main() {
  group('SplitEngine.equal', () {
    test('spec example: ₹3,000 dinner among three people', () {
      final result = SplitEngine.equal(
        totalMinor: 300000,
        currencyCode: 'INR',
        participantIds: const <String>['alice', 'bob', 'charlie'],
      );
      expect(result.shares['alice'], 100000);
      expect(result.shares['bob'], 100000);
      expect(result.shares['charlie'], 100000);
      expect(result.isBalanced, isTrue);
    });

    test('indivisible total stays balanced and is deterministic', () {
      final result = SplitEngine.equal(
        totalMinor: 10000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b', 'c'],
      );
      expect(result.shares.values.fold<int>(0, (x, y) => x + y), 10000);
      expect(result.shares['a'], 3334);
      expect(result.shares['b'], 3333);
      expect(result.shares['c'], 3333);

      // Recalculating after an edit must not reshuffle the remainder.
      final again = SplitEngine.equal(
        totalMinor: 10000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b', 'c'],
      );
      expect(again.shares, result.shares);
    });

    test('one cent among three people', () {
      final result = SplitEngine.equal(
        totalMinor: 1,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b', 'c'],
      );
      expect(result.shares.values.fold<int>(0, (x, y) => x + y), 1);
      expect(result.shares['a'], 1);
      expect(result.shares['b'], 0);
      expect(result.shares['c'], 0);
    });

    test('partial participation excludes non-participants', () {
      final result = SplitEngine.equal(
        totalMinor: 20000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b'],
      );
      expect(result.shares.keys, <String>['a', 'b']);
    });

    test('rejects an empty participant set', () {
      expect(
        () => SplitEngine.equal(
          totalMinor: 100,
          currencyCode: 'USD',
          participantIds: const <String>[],
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });

    test('rejects a duplicate participant', () {
      expect(
        () => SplitEngine.equal(
          totalMinor: 100,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'a'],
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });

    test('rejects a non-positive amount', () {
      expect(
        () => SplitEngine.equal(
          totalMinor: 0,
          currencyCode: 'USD',
          participantIds: const <String>['a'],
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });
  });

  group('SplitEngine.exact', () {
    test('honours custom amounts that already sum to the total', () {
      final result = SplitEngine.exact(
        totalMinor: 10000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b', 'c'],
        amountsMinor: const <String, int>{'a': 5000, 'b': 3000, 'c': 2000},
      );
      expect(result.shares['a'], 5000);
      expect(result.shares['b'], 3000);
      expect(result.shares['c'], 2000);
      expect(result.warnings, isEmpty);
    });

    test('repairs an off-by-one entry and warns the user', () {
      final result = SplitEngine.exact(
        totalMinor: 10000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b'],
        amountsMinor: const <String, int>{'a': 5000, 'b': 4000},
      );
      expect(result.shares.values.fold<int>(0, (x, y) => x + y), 10000);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, contains('USD'));
    });

    test('treats a missing entry as zero', () {
      final result = SplitEngine.exact(
        totalMinor: 10000,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b'],
        amountsMinor: const <String, int>{'a': 10000},
      );
      expect(result.shares['a'], 10000);
      expect(result.shares['b'], 0);
      expect(result.isBalanced, isTrue);
    });
  });

  group('SplitEngine.percentage', () {
    test('splits on percentages and stays balanced', () {
      final result = SplitEngine.percentage(
        totalMinor: 10001,
        currencyCode: 'USD',
        participantIds: const <String>['a', 'b', 'c'],
        percentages: const <String, double>{'a': 50, 'b': 25, 'c': 25},
      );
      expect(result.shares.values.fold<int>(0, (x, y) => x + y), 10001);
      expect(result.shares['a'], 5001);
      expect(result.shares['b'], 2500);
      expect(result.shares['c'], 2500);
    });

    test('supports fractional percentages', () {
      final result = SplitEngine.percentage(
        totalMinor: 100000,
        currencyCode: 'INR',
        participantIds: const <String>['a', 'b', 'c'],
        percentages: const <String, double>{'a': 33.34, 'b': 33.33, 'c': 33.33},
      );
      expect(result.shares.values.fold<int>(0, (x, y) => x + y), 100000);
    });

    test('rejects percentages that do not total 100', () {
      expect(
        () => SplitEngine.percentage(
          totalMinor: 1000,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b'],
          percentages: const <String, double>{'a': 60, 'b': 30},
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });

    test('requires at least two participants', () {
      expect(
        () => SplitEngine.percentage(
          totalMinor: 1000,
          currencyCode: 'USD',
          participantIds: const <String>['a'],
          percentages: const <String, double>{'a': 100},
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });
  });

  group('SplitEngine.shares', () {
    test('splits by weight', () {
      final result = SplitEngine.shares(
        totalMinor: 45000,
        currencyCode: 'INR',
        participantIds: const <String>['adult1', 'adult2', 'child'],
        weights: const <String, int>{'adult1': 1, 'adult2': 1, 'child': 1},
      );
      expect(result.shares['adult1'], 15000);
      expect(result.shares['child'], 15000);

      final weighted = SplitEngine.shares(
        totalMinor: 45000,
        currencyCode: 'INR',
        participantIds: const <String>['adult1', 'adult2', 'child'],
        weights: const <String, int>{'adult1': 1, 'adult2': 1, 'child': 2},
      );
      // 3 adults-units + 2 child-units = 5 units
      expect(weighted.shares['adult1'], 11250);
      expect(weighted.shares['child'], 22500);
      expect(weighted.isBalanced, isTrue);
    });

    test('rejects all-zero weights', () {
      expect(
        () => SplitEngine.shares(
          totalMinor: 1000,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b'],
          weights: const <String, int>{'a': 0, 'b': 0},
        ),
        throwsA(isA<SplitValidationException>()),
      );
    });
  });

  group('split() dispatcher', () {
    test('routes to the correct engine', () {
      expect(
        SplitEngine.split(
          method: SplitMethod.equal,
          totalMinor: 900,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b', 'c'],
        ).method,
        SplitMethod.equal,
      );
      expect(
        SplitEngine.split(
          method: SplitMethod.exact,
          totalMinor: 900,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b'],
          exactAmounts: const <String, int>{'a': 400, 'b': 500},
        ).shares['a'],
        400,
      );
      expect(
        SplitEngine.split(
          method: SplitMethod.percentage,
          totalMinor: 900,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b'],
          percentages: const <String, double>{'a': 60, 'b': 40},
        ).shares['b'],
        360,
      );
      expect(
        SplitEngine.split(
          method: SplitMethod.shares,
          totalMinor: 900,
          currencyCode: 'USD',
          participantIds: const <String>['a', 'b'],
          weights: const <String, int>{'a': 1, 'b': 2},
        ).shares['b'],
        600,
      );
    });

    test('SplitMethod.fromId falls back to equal', () {
      expect(SplitMethod.fromId('percentage'), SplitMethod.percentage);
      expect(SplitMethod.fromId('nonsense'), SplitMethod.equal);
      expect(SplitMethod.fromId(null), SplitMethod.equal);
    });
  });
}
