import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/money/currency.dart';
import 'package:tripsplit_world/data/models/expense.dart';
import 'package:tripsplit_world/data/models/planning.dart';
import 'package:tripsplit_world/data/models/trip.dart';

/// The app starts in INR.
///
/// Every default resolves to `Currencies.defaultCode`, so this test pins the
/// one constant rather than a list of places: if someone changes the default
/// deliberately, this is the single line to update alongside it.
void main() {
  group('default currency', () {
    test('is INR', () {
      expect(Currencies.defaultCode, 'INR');
    });

    test('INR is a supported currency with two decimal places', () {
      final Currency inr = Currencies.get('INR');
      expect(inr.code, 'INR');
      expect(inr.minorUnits, 2, reason: 'rupees are split into paise');
    });

    test('INR is surfaced first in currency pickers', () {
      expect(Currencies.popular.first, Currencies.defaultCode);
    });

    test('parsing and formatting use the default currency', () {
      expect(
        Money.parse('1,250.75', Currencies.defaultCode).minorUnits,
        125075,
      );
      expect(const Money(125075, Currencies.defaultCode).format(), '1,250.75');
    });
  });

  group('models start in the default currency', () {
    test('a new profile prefers the default currency', () {
      expect(Profile(id: 'u1').preferredCurrency, Currencies.defaultCode);
    });

    test('a new trip is budgeted in the default currency', () {
      expect(
        Trip(
          id: 't1',
          ownerId: 'u1',
          name: 'Trip',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 2),
        ).baseCurrency,
        Currencies.defaultCode,
      );
    });

    test('an empty budget falls back to the default currency', () {
      expect(
        Budget.fromJson(<String, dynamic>{
          'id': 'b1',
          'trip_id': 't1',
          'currency': null,
          'total_minor': 0,
        }).currency,
        Currencies.defaultCode,
      );
    });

    test('a booking with no currency recorded falls back to the default', () {
      expect(
        Booking.fromJson(<String, dynamic>{
          'id': 'k1',
          'trip_id': 't1',
          'kind': 'hotel',
          'provider': 'Example',
          'title': 'Hotel',
          'currency': null,
        }).currency,
        Currencies.defaultCode,
      );
    });

    test('an itinerary with no costed items falls back to the default', () {
      expect(
        ItineraryDay(
          id: 'd1',
          tripId: 't1',
          dayNumber: 1,
          date: DateTime(2026, 1, 1),
        ).costCurrency,
        Currencies.defaultCode,
      );
    });

    test('a malformed currency in stored data falls back to the default', () {
      // A blank or absent currency must not crash a money computation, and must
      // not silently become USD when the app default is INR.
      final Expense fromNull = Expense.fromJson(<String, dynamic>{
        'id': 'e1',
        'trip_id': 't1',
        'title': 'Tea',
        'amount_minor': 1000,
        'currency': null,
        'base_amount_minor': 1000,
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(fromNull.currency, Currencies.defaultCode);
    });
  });
}
