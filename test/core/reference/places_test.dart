import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/reference/airports.dart';
import 'package:tripsplit_world/core/reference/countries.dart';

void main() {
  group('country list', () {
    test('has no duplicate codes', () {
      final Set<String> codes = kCountries.map((Country c) => c.code).toSet();
      expect(codes.length, kCountries.length);
    });

    test('codes are valid ISO 3166-1 alpha-2', () {
      for (final Country c in kCountries) {
        expect(c.code.length, 2, reason: '${c.name} has code "${c.code}"');
        expect(
          RegExp(r'^[A-Z]{2}$').hasMatch(c.code),
          isTrue,
          reason: '${c.name} has code "${c.code}"',
        );
      }
    });

    test('names are non-empty', () {
      for (final Country c in kCountries) {
        expect(c.name.trim(), isNotEmpty, reason: 'code ${c.code}');
      }
    });

    test('covers the places people actually travel', () {
      for (final String code in <String>[
        'IN',
        'US',
        'GB',
        'SG',
        'AE',
        'JP',
        'TH',
        'HK',
        'AU',
        'NZ',
        'FR',
        'IT',
        'ES',
        'DE',
        'CH',
        'NL',
        'PT',
        'GR',
        'TR',
        'ID',
        'MY',
        'VN',
        'KR',
        'CN',
        'MX',
        'BR',
        'ZA',
        'EG',
        'KE',
        'NP',
        'LK',
        'PK',
      ]) {
        expect(countryByCode(code), isNotNull, reason: 'missing $code');
      }
    });
  });

  group('country search', () {
    test('an empty query returns everything', () {
      expect(searchCountries('').length, kCountries.length);
    });

    test('finds by name prefix', () {
      expect(searchCountries('ind').first.code, 'IN', reason: 'India before Indonesia');
    });

    test('finds by ISO code', () {
      expect(searchCountries('jp').map((Country c) => c.code), contains('JP'));
    });

    test('is case insensitive', () {
      expect(searchCountries('JAPAN').first.code, 'JP');
    });

    test('ignores apostrophes and accents', () {
      // A phone keyboard may omit both, and the user still means the same place.
      expect(
        searchCountries('turkiye').map((Country c) => c.code),
        contains('TR'),
      );
      expect(
        searchCountries("cote divoire").map((Country c) => c.code),
        contains('CI'),
      );
    });

    test('returns nothing for gibberish rather than throwing', () {
      expect(searchCountries('zzzzqqq'), isEmpty);
    });
  });

  group('country lookup', () {
    test('byCode is case insensitive and null-safe', () {
      expect(countryByCode('in')?.name, 'India');
      expect(countryByCode('XX'), isNull);
      expect(countryByCode(null), isNull);
      expect(countryByCode('IND'), isNull);
    });

    test('byName resolves free text', () {
      expect(countryByName('Japan')?.code, 'JP');
      expect(countryByName('Hong Kong')?.code, 'HK');
      expect(countryByName('nowhere at all'), isNull);
    });

    test('flag emoji derives from the code and never throws', () {
      expect(countryByCode('IN')!.flagEmoji.runes.length, 2);
      expect(countryByCode('JP')!.flagEmoji.runes.length, 2);
      // A malformed code yields nothing rather than throwing; a flag is
      // decoration, never a correctness issue.
      expect(const Country('X', 'Bad').flagEmoji, '');
      expect(const Country('', 'Empty').flagEmoji, '');
    });
  });

  group('airports', () {
    test('has no duplicate IATA codes', () {
      final Set<String> codes = kAirports.map((Airport a) => a.code).toSet();
      expect(codes.length, kAirports.length);
    });

    test('codes are 3 uppercase letters', () {
      for (final Airport a in kAirports) {
        expect(
          RegExp(r'^[A-Z]{3}$').hasMatch(a.code),
          isTrue,
          reason: '${a.name} has IATA code "${a.code}"',
        );
      }
    });

    test('every airport resolves to a real country code', () {
      for (final Airport a in kAirports) {
        expect(
          countryByCode(a.countryCode),
          isNotNull,
          reason: '${a.code} (${a.name}) has country "${a.countryCode}"',
        );
      }
    });

    test('searches by IATA code, airport name and city', () {
      expect(searchAirports('DEL').first.code, 'DEL', reason: 'Delhi by code');
      expect(
        searchAirports('changi').first.code,
        'SIN',
        reason: 'Singapore Changi by name',
      );
      expect(
        searchAirports('singapore').first.code,
        'SIN',
        reason: 'Singapore by city',
      );
    });

    test('matches a partial code', () {
      expect(searchAirports('del').map((Airport a) => a.code), contains('DEL'));
    });

    test('returns nothing for gibberish rather than throwing', () {
      expect(searchAirports('zzzzzz'), isEmpty);
    });

    test('byCode resolves and is null-safe', () {
      expect(airportByCode('sin')?.city, 'Singapore');
      expect(airportByCode('ZZZ'), isNull);
      expect(airportByCode(null), isNull);
    });
  });
}