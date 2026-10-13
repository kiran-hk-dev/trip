import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/money/currency.dart';

void main() {
  group('Money.parse', () {
    test('parses plain decimal input', () {
      expect(Money.parse('1234.56', 'USD').minorUnits, 123456);
      expect(Money.parse('0.01', 'USD').minorUnits, 1);
      expect(Money.parse('100', 'USD').minorUnits, 10000);
    });

    test('parses grouped thousands', () {
      expect(Money.parse('1,250.75', 'USD').minorUnits, 125075);
      expect(Money.parse('12 345', 'EUR').minorUnits, 1234500);
    });

    test('parses european decimal comma', () {
      expect(Money.parse('1.250,75', 'EUR').minorUnits, 125075);
      expect(Money.parse('9,99', 'EUR').minorUnits, 999);
    });

    test('treats a lone triple-digit group as thousands', () {
      expect(Money.parse('1,500', 'USD').minorUnits, 150000);
    });

    test('handles zero-decimal currencies', () {
      expect(Money.parse('1500', 'JPY').minorUnits, 1500);
      expect(Money.parse('1500.4', 'JPY').minorUnits, 1500);
    });

    test('handles three-decimal currencies', () {
      expect(Money.parse('1.234', 'KWD').minorUnits, 1234);
      expect(Money.parse('12.5', 'KWD').minorUnits, 12500);
      expect(Money.parse('12.5', 'KWD').format(), '12.500');
    });

    test('rounds half away from zero rather than truncating', () {
      expect(Money.parse('9.995', 'USD').minorUnits, 1000);
      expect(Money.parse('9.994', 'USD').minorUnits, 999);
      expect(Money.parse('0.005', 'USD').minorUnits, 1);
    });

    test('strips currency symbols and whitespace', () {
      expect(Money.parse(r'  $3,000.00 ', 'USD').minorUnits, 300000);
      expect(Money.parse('₹3,000', 'INR').minorUnits, 300000);
    });

    test('handles negative amounts', () {
      expect(Money.parse('-42.50', 'USD').minorUnits, -4250);
    });

    test('returns zero for unparseable input instead of throwing', () {
      expect(Money.parse('', 'USD').minorUnits, 0);
      expect(Money.parse('abc', 'USD').minorUnits, 0);
      expect(Money.tryParse(null, 'USD').minorUnits, 0);
    });
  });

  group('Money.format', () {
    test('always emits the currency precision', () {
      expect(const Money(1, 'USD').format(), '0.01');
      expect(const Money(0, 'USD').format(), '0.00');
      expect(const Money(123456789, 'USD').format(), '1,234,567.89');
      expect(const Money(500, 'JPY').format(), '500');
      expect(const Money(-4250, 'USD').format(), '-42.50');
    });

    test('round-trips through parseFormatted', () {
      for (final m in <Money>[
        const Money(0, 'USD'),
        const Money(1, 'USD'),
        const Money(999999, 'EUR'),
        const Money(-12345, 'GBP'),
        const Money(7, 'JPY'),
        const Money(1234, 'KWD'),
      ]) {
        final parsed = Money.tryParseFormatted(m.format(), m.currencyCode);
        expect(parsed, m, reason: 'round-trip failed for ${m.format()}');
      }
    });
  });

  group('Money arithmetic', () {
    test('adding minor units never drifts', () {
      var total = const Money(0, 'USD');
      for (var i = 0; i < 10; i++) {
        total = total + const Money(10, 'USD'); // 0.10
      }
      expect(total.minorUnits, 100);
      expect(total.format(), '1.00');
    });

    test('rejects mixed-currency arithmetic', () {
      expect(
        () => const Money(1, 'USD') + const Money(1, 'EUR'),
        throwsArgumentError,
      );
    });

    test('sum validates a single currency', () {
      final total = Money.sum(<Money>[
        const Money(1500, 'INR'),
        const Money(2500, 'INR'),
      ], 'INR');
      expect(total.minorUnits, 4000);
    });

    test('equality and hashing work for value objects', () {
      expect(const Money(500, 'GBP'), const Money(500, 'GBP'));
      expect(
        const Money(500, 'GBP').hashCode,
        const Money(500, 'GBP').hashCode,
      );
      expect(const Money(500, 'GBP') == const Money(500, 'USD'), isFalse);
    });
  });

  group('Currency registry', () {
    test('knows minor units for zero-, two- and three-decimal currencies', () {
      expect(Currencies.minorUnitsFor('JPY'), 0);
      expect(Currencies.minorUnitsFor('USD'), 2);
      expect(Currencies.minorUnitsFor('KWD'), 3);
      expect(Currencies.minorUnitsFor('VND'), 0);
      expect(Currencies.minorUnitsFor('BHD'), 3);
    });

    test('has no duplicate codes and covers the required 15 currencies', () {
      final codes = Currencies.all.map((c) => c.code).toSet();
      expect(codes.length, Currencies.all.length);
      for (final required in <String>[
        'INR',
        'USD',
        'EUR',
        'GBP',
        'AED',
        'SGD',
        'HKD',
        'JPY',
        'AUD',
        'CAD',
        'THB',
        'MYR',
        'IDR',
        'CHF',
        'CNY',
      ]) {
        expect(codes, contains(required), reason: 'missing $required');
      }
    });

    test('falls back safely for an unknown code', () {
      final unknown = Currencies.get('ZZZ');
      expect(unknown.code, 'ZZZ');
      expect(unknown.minorUnits, 2);
    });
  });

  group('allocateById', () {
    test('distributes remainder deterministically', () {
      final first = allocateById(
        100,
        <String>['a', 'b', 'c'],
        <String, int>{'a': 1, 'b': 1, 'c': 1},
      );
      final second = allocateById(
        100,
        <String>['a', 'b', 'c'],
        <String, int>{'a': 1, 'b': 1, 'c': 1},
      );
      expect(first, second, reason: 'must be stable across recalculations');
      expect(first.values.fold<int>(0, (x, y) => x + y), 100);
      expect(first['a'], 34);
      expect(first['b'], 33);
      expect(first['c'], 33);
    });

    test('sums exactly for awkward totals', () {
      for (final total in <int>[1, 7, 99, 1001, 99999]) {
        final out = allocateById(
          total,
          <String>['a', 'b', 'c', 'd', 'e', 'f', 'g'],
          <String, int>{
            for (final id in <String>['a', 'b', 'c', 'd', 'e', 'f', 'g']) id: 1,
          },
        );
        expect(out.values.fold<int>(0, (x, y) => x + y), total);
      }
    });

    test('honours weights', () {
      final out = allocateById(
        1000,
        <String>['adult', 'child'],
        <String, int>{'adult': 3, 'child': 1},
      );
      expect(out['adult'], 750);
      expect(out['child'], 250);
    });

    test('handles zero-weight participants without losing money', () {
      final out = allocateById(
        100,
        <String>['a', 'b', 'c'],
        <String, int>{'a': 2, 'b': 0, 'c': 2},
      );
      expect(out.values.fold<int>(0, (x, y) => x + y), 100);
      expect(out['b'], 0);
    });

    test('falls back to equal when all weights are zero', () {
      final out = allocateById(
        100,
        <String>['a', 'b', 'c'],
        <String, int>{'a': 0, 'b': 0, 'c': 0},
      );
      expect(out.values.fold<int>(0, (x, y) => x + y), 100);
    });
  });

  group('FxSnapshot', () {
    test('converts across differing minor units exactly', () {
      final snapshot = FxSnapshot(
        fromCurrency: 'USD',
        toCurrency: 'JPY',
        rate: Decimal.parse('150.25'),
        fetchedAt: DateTime.utc(2026, 1, 1),
        provider: 'test',
      );
      // 10.00 USD -> 1502.5 JPY -> 1503 (0 decimals, half-up)
      final converted = snapshot.convert(const Money(1000, 'USD'));
      expect(converted.currencyCode, 'JPY');
      expect(converted.minorUnits, 1503);
    });

    test('identity snapshot is a no-op', () {
      final id = FxSnapshot.identity('EUR');
      expect(id.convert(const Money(1234, 'EUR')).minorUnits, 1234);
    });

    test('rejects a mismatched source currency', () {
      final snapshot = FxSnapshot(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        rate: Decimal.parse('0.9'),
        fetchedAt: DateTime.utc(2026, 1, 1),
        provider: 'test',
      );
      expect(
        () => snapshot.convert(const Money(100, 'GBP')),
        throwsArgumentError,
      );
    });
  });
}
