import 'package:decimal/decimal.dart';

/// ISO 4217 currency metadata.
///
/// [minorUnits] is the number of decimal places the currency actually uses
/// (JPY = 0, KWD = 3). All monetary arithmetic in TripSplit World is done in
/// these integer minor units so that 0.1 + 0.2 == 0.3 always holds.
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.minorUnits,
    this.flagEmoji,
    this.regionName,
  });

  final String code;
  final String symbol;
  final String name;
  final int minorUnits;
  final String? flagEmoji;
  final String? regionName;

  bool get isZeroDecimal => minorUnits == 0;

  /// 10^minorUnits as an integer, e.g. 100 for USD, 1 for JPY.
  int get minorFactor {
    int f = 1;
    for (int i = 0; i < minorUnits; i++) {
      f *= 10;
    }
    return f;
  }

  @override
  String toString() => 'Currency($code)';
}

/// Lookup table for every currency the app supports.
///
/// The full ISO 4217 active list is included so the converter never has to
/// guess minor-unit precision; the UI highlights the most-used ones.
abstract final class Currencies {
  static const List<Currency> all = <Currency>[
    Currency(
      code: 'USD',
      symbol: r'$',
      name: 'US Dollar',
      minorUnits: 2,
      flagEmoji: '🇺🇸',
      regionName: 'United States',
    ),
    Currency(
      code: 'EUR',
      symbol: '€',
      name: 'Euro',
      minorUnits: 2,
      flagEmoji: '🇪🇺',
      regionName: 'Euro area',
    ),
    Currency(
      code: 'GBP',
      symbol: '£',
      name: 'Pound Sterling',
      minorUnits: 2,
      flagEmoji: '🇬🇧',
      regionName: 'United Kingdom',
    ),
    Currency(
      code: 'JPY',
      symbol: '¥',
      name: 'Japanese Yen',
      minorUnits: 0,
      flagEmoji: '🇯🇵',
      regionName: 'Japan',
    ),
    Currency(
      code: 'CNY',
      symbol: '¥',
      name: 'Chinese Yuan',
      minorUnits: 2,
      flagEmoji: '🇨🇳',
      regionName: 'China',
    ),
    Currency(
      code: 'INR',
      symbol: '₹',
      name: 'Indian Rupee',
      minorUnits: 2,
      flagEmoji: '🇮🇳',
      regionName: 'India',
    ),
    Currency(
      code: 'AUD',
      symbol: r'A$',
      name: 'Australian Dollar',
      minorUnits: 2,
      flagEmoji: '🇦🇺',
      regionName: 'Australia',
    ),
    Currency(
      code: 'CAD',
      symbol: r'C$',
      name: 'Canadian Dollar',
      minorUnits: 2,
      flagEmoji: '🇨🇦',
      regionName: 'Canada',
    ),
    Currency(
      code: 'CHF',
      symbol: 'CHF',
      name: 'Swiss Franc',
      minorUnits: 2,
      flagEmoji: '🇨🇭',
      regionName: 'Switzerland',
    ),
    Currency(
      code: 'HKD',
      symbol: r'HK$',
      name: 'Hong Kong Dollar',
      minorUnits: 2,
      flagEmoji: '🇭🇰',
      regionName: 'Hong Kong SAR',
    ),
    Currency(
      code: 'SGD',
      symbol: r'S$',
      name: 'Singapore Dollar',
      minorUnits: 2,
      flagEmoji: '🇸🇬',
      regionName: 'Singapore',
    ),
    Currency(
      code: 'AED',
      symbol: 'AED',
      name: 'UAE Dirham',
      minorUnits: 2,
      flagEmoji: '🇦🇪',
      regionName: 'United Arab Emirates',
    ),
    Currency(
      code: 'THB',
      symbol: '฿',
      name: 'Thai Baht',
      minorUnits: 2,
      flagEmoji: '🇹🇭',
      regionName: 'Thailand',
    ),
    Currency(
      code: 'MYR',
      symbol: 'RM',
      name: 'Malaysian Ringgit',
      minorUnits: 2,
      flagEmoji: '🇲🇾',
      regionName: 'Malaysia',
    ),
    Currency(
      code: 'IDR',
      symbol: 'Rp',
      name: 'Indonesian Rupiah',
      minorUnits: 2,
      flagEmoji: '🇮🇩',
      regionName: 'Indonesia',
    ),
    Currency(
      code: 'PHP',
      symbol: '₱',
      name: 'Philippine Peso',
      minorUnits: 2,
      flagEmoji: '🇵🇭',
      regionName: 'Philippines',
    ),
    Currency(
      code: 'VND',
      symbol: '₫',
      name: 'Vietnamese Dong',
      minorUnits: 0,
      flagEmoji: '🇻🇳',
      regionName: 'Vietnam',
    ),
    Currency(
      code: 'KRW',
      symbol: '₩',
      name: 'South Korean Won',
      minorUnits: 0,
      flagEmoji: '🇰🇷',
      regionName: 'South Korea',
    ),
    Currency(
      code: 'TWD',
      symbol: r'NT$',
      name: 'New Taiwan Dollar',
      minorUnits: 2,
      flagEmoji: '🇹🇼',
      regionName: 'Taiwan',
    ),
    Currency(
      code: 'NZD',
      symbol: r'NZ$',
      name: 'New Zealand Dollar',
      minorUnits: 2,
      flagEmoji: '🇳🇿',
      regionName: 'New Zealand',
    ),
    Currency(
      code: 'ZAR',
      symbol: 'R',
      name: 'South African Rand',
      minorUnits: 2,
      flagEmoji: '🇿🇦',
      regionName: 'South Africa',
    ),
    Currency(
      code: 'EGP',
      symbol: 'E£',
      name: 'Egyptian Pound',
      minorUnits: 2,
      flagEmoji: '🇪🇬',
      regionName: 'Egypt',
    ),
    Currency(
      code: 'MAD',
      symbol: 'MAD',
      name: 'Moroccan Dirham',
      minorUnits: 2,
      flagEmoji: '🇲🇦',
      regionName: 'Morocco',
    ),
    Currency(
      code: 'KES',
      symbol: 'KSh',
      name: 'Kenyan Shilling',
      minorUnits: 2,
      flagEmoji: '🇰🇪',
      regionName: 'Kenya',
    ),
    Currency(
      code: 'NGN',
      symbol: '₦',
      name: 'Nigerian Naira',
      minorUnits: 2,
      flagEmoji: '🇳🇬',
      regionName: 'Nigeria',
    ),
    Currency(
      code: 'BRL',
      symbol: r'R$',
      name: 'Brazilian Real',
      minorUnits: 2,
      flagEmoji: '🇧🇷',
      regionName: 'Brazil',
    ),
    Currency(
      code: 'MXN',
      symbol: r'MX$',
      name: 'Mexican Peso',
      minorUnits: 2,
      flagEmoji: '🇲🇽',
      regionName: 'Mexico',
    ),
    Currency(
      code: 'ARS',
      symbol: r'AR$',
      name: 'Argentine Peso',
      minorUnits: 2,
      flagEmoji: '🇦🇷',
      regionName: 'Argentina',
    ),
    Currency(
      code: 'CLP',
      symbol: r'CL$',
      name: 'Chilean Peso',
      minorUnits: 0,
      flagEmoji: '🇨🇱',
      regionName: 'Chile',
    ),
    Currency(
      code: 'COP',
      symbol: r'COL$',
      name: 'Colombian Peso',
      minorUnits: 2,
      flagEmoji: '🇨🇴',
      regionName: 'Colombia',
    ),
    Currency(
      code: 'PEN',
      symbol: 'S/',
      name: 'Peruvian Sol',
      minorUnits: 2,
      flagEmoji: '🇵🇪',
      regionName: 'Peru',
    ),
    Currency(
      code: 'ISK',
      symbol: 'kr',
      name: 'Icelandic Krona',
      minorUnits: 0,
      flagEmoji: '🇮🇸',
      regionName: 'Iceland',
    ),
    Currency(
      code: 'SEK',
      symbol: 'kr',
      name: 'Swedish Krona',
      minorUnits: 2,
      flagEmoji: '🇸🇪',
      regionName: 'Sweden',
    ),
    Currency(
      code: 'NOK',
      symbol: 'kr',
      name: 'Norwegian Krone',
      minorUnits: 2,
      flagEmoji: '🇳🇴',
      regionName: 'Norway',
    ),
    Currency(
      code: 'DKK',
      symbol: 'kr',
      name: 'Danish Krone',
      minorUnits: 2,
      flagEmoji: '🇩🇰',
      regionName: 'Denmark',
    ),
    Currency(
      code: 'PLN',
      symbol: 'zł',
      name: 'Polish Zloty',
      minorUnits: 2,
      flagEmoji: '🇵🇱',
      regionName: 'Poland',
    ),
    Currency(
      code: 'CZK',
      symbol: 'Kč',
      name: 'Czech Koruna',
      minorUnits: 2,
      flagEmoji: '🇨🇿',
      regionName: 'Czechia',
    ),
    Currency(
      code: 'HUF',
      symbol: 'Ft',
      name: 'Hungarian Forint',
      minorUnits: 2,
      flagEmoji: '🇭🇺',
      regionName: 'Hungary',
    ),
    Currency(
      code: 'RON',
      symbol: 'lei',
      name: 'Romanian Leu',
      minorUnits: 2,
      flagEmoji: '🇷🇴',
      regionName: 'Romania',
    ),
    Currency(
      code: 'BGN',
      symbol: 'лв',
      name: 'Bulgarian Lev',
      minorUnits: 2,
      flagEmoji: '🇧🇬',
      regionName: 'Bulgaria',
    ),
    Currency(
      code: 'TRY',
      symbol: '₺',
      name: 'Turkish Lira',
      minorUnits: 2,
      flagEmoji: '🇹🇷',
      regionName: 'Türkiye',
    ),
    Currency(
      code: 'RUB',
      symbol: '₽',
      name: 'Russian Ruble',
      minorUnits: 2,
      flagEmoji: '🇷🇺',
      regionName: 'Russia',
    ),
    Currency(
      code: 'UAH',
      symbol: '₴',
      name: 'Ukrainian Hryvnia',
      minorUnits: 2,
      flagEmoji: '🇺🇦',
      regionName: 'Ukraine',
    ),
    Currency(
      code: 'SAR',
      symbol: 'SAR',
      name: 'Saudi Riyal',
      minorUnits: 2,
      flagEmoji: '🇸🇦',
      regionName: 'Saudi Arabia',
    ),
    Currency(
      code: 'QAR',
      symbol: 'QR',
      name: 'Qatari Riyal',
      minorUnits: 2,
      flagEmoji: '🇶🇦',
      regionName: 'Qatar',
    ),
    Currency(
      code: 'KWD',
      symbol: 'KD',
      name: 'Kuwaiti Dinar',
      minorUnits: 3,
      flagEmoji: '🇰🇼',
      regionName: 'Kuwait',
    ),
    Currency(
      code: 'BHD',
      symbol: '.د.ب',
      name: 'Bahraini Dinar',
      minorUnits: 3,
      flagEmoji: '🇧🇭',
      regionName: 'Bahrain',
    ),
    Currency(
      code: 'OMR',
      symbol: 'ر.ع.',
      name: 'Omani Rial',
      minorUnits: 3,
      flagEmoji: '🇴🇲',
      regionName: 'Oman',
    ),
    Currency(
      code: 'JOD',
      symbol: 'د.ا',
      name: 'Jordanian Dinar',
      minorUnits: 3,
      flagEmoji: '🇯🇴',
      regionName: 'Jordan',
    ),
    Currency(
      code: 'TND',
      symbol: 'د.ت',
      name: 'Tunisian Dinar',
      minorUnits: 3,
      flagEmoji: '🇹🇳',
      regionName: 'Tunisia',
    ),
    Currency(
      code: 'LKR',
      symbol: 'Rs',
      name: 'Sri Lankan Rupee',
      minorUnits: 2,
      flagEmoji: '🇱🇰',
      regionName: 'Sri Lanka',
    ),
    Currency(
      code: 'NPR',
      symbol: 'Rs',
      name: 'Nepalese Rupee',
      minorUnits: 2,
      flagEmoji: '🇳🇵',
      regionName: 'Nepal',
    ),
    Currency(
      code: 'BDT',
      symbol: '৳',
      name: 'Bangladeshi Taka',
      minorUnits: 2,
      flagEmoji: '🇧🇩',
      regionName: 'Bangladesh',
    ),
    Currency(
      code: 'PKR',
      symbol: '₨',
      name: 'Pakistani Rupee',
      minorUnits: 2,
      flagEmoji: '🇵🇰',
      regionName: 'Pakistan',
    ),
    Currency(
      code: 'KZT',
      symbol: '₸',
      name: 'Kazakhstani Tenge',
      minorUnits: 2,
      flagEmoji: '🇰🇿',
      regionName: 'Kazakhstan',
    ),
    Currency(
      code: 'AZN',
      symbol: '₼',
      name: 'Azerbaijani Manat',
      minorUnits: 2,
      flagEmoji: '🇦🇿',
      regionName: 'Azerbaijan',
    ),
    Currency(
      code: 'GEL',
      symbol: '₾',
      name: 'Georgian Lari',
      minorUnits: 2,
      flagEmoji: '🇬🇪',
      regionName: 'Georgia',
    ),
    Currency(
      code: 'MNT',
      symbol: '₮',
      name: 'Mongolian Tugrik',
      minorUnits: 2,
      flagEmoji: '🇲🇳',
      regionName: 'Mongolia',
    ),
    Currency(
      code: 'IQD',
      symbol: 'ع.د',
      name: 'Iraqi Dinar',
      minorUnits: 3,
      flagEmoji: '🇮🇶',
      regionName: 'Iraqa',
    ),
    Currency(
      code: 'ILS',
      symbol: '₪',
      name: 'Israeli New Shekel',
      minorUnits: 2,
      flagEmoji: '🇮🇱',
      regionName: 'Israel',
    ),
  ];

  static final Map<String, Currency> _byCode = <String, Currency>{
    for (final c in all) c.code: c,
  };

  /// The currency a new user, trip or expense starts in.
  ///
  /// Every default in the app resolves to this one constant so changing it is
  /// a single edit rather than a search for scattered 'USD' literals. Money
  /// already recorded keeps whatever currency it was entered in; this only
  /// affects new records and empty fields.
  static const String defaultCode = 'INR';

  /// Currencies surfaced first in pickers.
  static const List<String> popular = <String>[
    defaultCode,
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'AED',
    'SGD',
    'HKD',
    'AUD',
    'CAD',
    'THB',
    'MYR',
    'CHF',
    'CNY',
    'IDR',
  ];

  static Currency? tryGet(String code) => _byCode[code.toUpperCase()];

  /// Falls back to a 2-decimal placeholder rather than throwing, so a bad
  /// stored code can never crash a money computation.
  static Currency get(String code) =>
      _byCode[code.toUpperCase()] ??
      Currency(
        code: code.toUpperCase(),
        symbol: code.toUpperCase(),
        name: code.toUpperCase(),
        minorUnits: 2,
      );

  static int minorUnitsFor(String code) => get(code).minorUnits;

  static List<Currency> get popularCurrencies =>
      popular.map(get).toList(growable: false);
}

/// An immutable monetary amount stored in integer minor units.
///
/// `Money(300000, 'INR')` is ₹3,000.00. Because the value is an `int`, no
/// floating point rounding error can ever accumulate in a balance.
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currencyCode);

  final int minorUnits;
  final String currencyCode;

  Currency get currency => Currencies.get(currencyCode);

  int get minorDigits => currency.minorUnits;

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  /// Exact decimal major-unit value, for display and decimal math only.
  Decimal get major =>
      Decimal.parse(minorUnits.toString()).shift(-currency.minorUnits);

  Money plus(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currencyCode);
  }

  Money minus(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currencyCode);
  }

  Money get negated => Money(-minorUnits, currencyCode);
  Money get absolute => Money(minorUnits.abs(), currencyCode);

  /// Integer scaling. Use [allocate] for splitting — never multiply a share.
  Money scale(int factor) => Money(minorUnits * factor, currencyCode);

  /// Largest-remainder apportionment of this amount across [weights].
  ///
  /// The returned minor units always sum back to `this` exactly, which is the
  /// single most important invariant in the whole expense engine.
  Map<int, int> allocate(List<int> weights) => allocateByIndex(
    minorUnits,
    weights,
    <int>[for (var i = 0; i < weights.length; i++) i],
  );

  void _assertSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Currency mismatch: cannot combine $currencyCode with '
        '${other.currencyCode}. Convert explicitly first.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  Money operator +(Money other) => plus(other);
  Money operator -(Money other) => minus(other);
  Money operator -() => negated;

  /// Parses user input such as `1,250.75`, `₹300`, `1.234,56` (EU) or `-42`.
  ///
  /// Handles the European decimal-comma case and stray currency symbols, and
  /// rounds half-up into the currency's minor unit (so `9.995` becomes 1000
  /// minor units, never 999).
  static Money parse(String input, String currencyCode) {
    final Currency c = Currencies.get(currencyCode);
    String s = input.trim().replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.isEmpty) return Money(0, c.code);

    final bool negative = s.startsWith('-');
    if (negative) s = s.substring(1);

    final int lastComma = s.lastIndexOf(',');
    final int lastDot = s.lastIndexOf('.');
    int decimalSep = -1;
    if (lastComma >= 0 && lastDot >= 0) {
      decimalSep = lastComma > lastDot ? lastComma : lastDot;
    } else if (lastComma >= 0) {
      // A single comma is a decimal separator only when it is not a thousands
      // group (e.g. `1,50` is one-and-a-half, `1,500` is fifteen hundred).
      final bool onlyOneComma = s.indexOf(',') == lastComma;
      final int digitsAfter = s.length - lastComma - 1;
      decimalSep = (onlyOneComma && digitsAfter != 3) ? lastComma : -1;
    } else if (lastDot >= 0) {
      final bool onlyOneDot = s.indexOf('.') == lastDot;
      final int digitsAfter = s.length - lastDot - 1;
      decimalSep = (onlyOneDot && digitsAfter != 3) ? lastDot : -1;
    }

    String whole;
    String frac;
    if (decimalSep >= 0) {
      whole = s.substring(0, decimalSep).replaceAll(RegExp(r'[,.]'), '');
      frac = s.substring(decimalSep + 1).replaceAll(RegExp(r'[,.]'), '');
    } else {
      whole = s.replaceAll(',', '');
      frac = '';
    }
    if (whole.isEmpty) whole = '0';

    final String normalised =
        '${negative ? '-' : ''}$whole${frac.isEmpty ? '' : '.$frac'}';
    final Decimal value = Decimal.tryParse(normalised) ?? Decimal.zero;
    final Decimal scaled = value * Decimal.fromInt(c.minorFactor);
    final Decimal rounded = _roundHalfUp(scaled, 0);
    final int minor = rounded.toBigInt().toInt();
    return Money(minor, c.code);
  }

  static Money fromDecimal(Decimal value, String currencyCode) {
    final Currency c = Currencies.get(currencyCode);
    final Decimal scaled = value * Decimal.fromInt(c.minorFactor);
    return Money(_roundHalfUp(scaled, 0).toBigInt().toInt(), c.code);
  }

  /// Best-effort parse for analytics-ish inputs; never throws.
  static Money tryParse(String? input, String currencyCode) {
    if (input == null || input.trim().isEmpty) return Money(0, currencyCode);
    try {
      return parse(input, currencyCode);
    } on FormatException {
      return Money(0, currencyCode);
    }
  }

  /// Rounds half away from zero to [scale] decimal places.
  static Decimal _roundHalfUp(Decimal value, int scale) =>
      value.round(scale: scale);

  /// Human-readable amount using the currency's real minor-unit precision.
  ///
  /// `format()` on [Decimal] strips trailing zeros, which would render 1.00 as
  /// "1" — wrong for a ledger. This always emits exactly [minorDigits]
  /// decimals, and always uses a plain minus sign (never Unicode U+2212)
  /// so the output can be embedded in CSV and parsed back.
  String format({
    String? locale,
    bool withCode = false,
    bool withSymbol = false,
  }) {
    final Currency c = currency;
    final bool negative = minorUnits < 0;
    final int abs = minorUnits.abs();
    int factor = 1;
    for (var i = 0; i < c.minorUnits; i++) {
      factor *= 10;
    }
    final int whole = abs ~/ factor;
    final int frac = abs % factor;
    final String fracText = frac.toString().padLeft(c.minorUnits, '0');
    final String grouped = _group(whole);
    final String sign = negative ? '-' : '';
    final String buffer = c.minorUnits == 0
        ? '$sign$grouped'
        : '$sign$grouped.$fracText';
    final String symbol = withSymbol ? '${c.symbol} ' : '';
    final String code = withCode ? ' ${c.code}' : '';
    return '$symbol$buffer$code';
  }

  /// Parses the output of [format].
  ///
  /// Unlike [parse] this assumes the strict `1,234.56` layout that [format]
  /// emits, so commas are unambiguously thousands separators. That matters for
  /// three-decimal currencies, where a bare `1.234` means one dinar and two
  /// hundred and thirty-four fils rather than one thousand two hundred and
  /// thirty-four.
  static Money? tryParseFormatted(String input, String currencyCode) {
    final Currency c = Currencies.get(currencyCode);
    final String text = input
        .replaceAll(RegExp(r'[^0-9.\-]'), '')
        .replaceAll(',', '');
    if (text.isEmpty || text == '-') return null;
    final Decimal? value = Decimal.tryParse(text);
    if (value == null) return null;
    int factor = 1;
    for (var i = 0; i < c.minorUnits; i++) {
      factor *= 10;
    }
    return Money(
      (value * Decimal.fromInt(factor)).round().toBigInt().toInt(),
      c.code,
    );
  }

  static String _group(int value) {
    final String digits = value.toString();
    if (digits.length <= 3) return digits;
    final StringBuffer buffer = StringBuffer();
    final int lead = digits.length % 3;
    if (lead > 0) buffer.write(digits.substring(0, lead));
    for (int i = lead; i < digits.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write(',');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }

  static Money zero(String currencyCode) => Money(0, currencyCode);

  static Money sum(Iterable<Money> items, String currencyCode) {
    int total = 0;
    for (final m in items) {
      if (m.currencyCode != currencyCode) {
        throw ArgumentError('Currency mismatch in Money.sum');
      }
      total += m.minorUnits;
    }
    return Money(total, currencyCode);
  }

  @override
  String toString() => '$currencyCode ${(major).toStringAsFixed(minorDigits)}';
}

/// Largest-remainder ("Hamilton") apportionment.
///
/// Given a total in minor units and one non-negative weight per participant,
/// returns a share per participant such that the shares sum **exactly** to the
/// total. Ties are broken by ascending participant id so results are stable
/// and reproducible across devices and recalculations.
Map<String, int> allocateById(
  int totalMinor,
  List<String> participantIds,
  Map<String, int> weights,
) {
  final List<String> ids = participantIds.toList()..sort();
  final Map<String, int> result = <String, int>{for (final id in ids) id: 0};
  if (ids.isEmpty) return result;

  final int totalWeight = ids.fold<int>(0, (a, id) => a + (weights[id] ?? 0));
  if (totalWeight <= 0) {
    // Degenerate weights: fall back to an equal split so money is never lost.
    return allocateById(totalMinor, ids, <String, int>{
      for (final id in ids) id: 1,
    });
  }

  final List<_Quota> quotas = <_Quota>[];
  int assigned = 0;
  for (final String id in ids) {
    final int w = weights[id] ?? 0;
    // Exact integer arithmetic: numerator = total * w, denominator = totalWeight.
    final int numerator = totalMinor * w;
    final int base = _floorDiv(numerator, totalWeight);
    final int remainder = numerator - base * totalWeight;
    quotas.add(_Quota(id: id, base: base, remainder: remainder));
    assigned += base;
  }

  int residual = totalMinor - assigned;
  if (residual != 0) {
    quotas.sort((a, b) {
      final int byRemainder = b.remainder.compareTo(a.remainder);
      if (byRemainder != 0) return byRemainder;
      return a.id.compareTo(b.id);
    });
    int index = 0;
    while (residual != 0 && quotas.isNotEmpty) {
      final int step = residual > 0 ? 1 : -1;
      quotas[index % quotas.length].base += step;
      residual -= step;
      index++;
    }
  }

  for (final q in quotas) {
    result[q.id] = q.base;
  }
  return result;
}

/// Index-keyed variant of [allocateById] used where participants are already
/// positional.
Map<int, int> allocateByIndex(
  int totalMinor,
  List<int> weights,
  List<int> ids,
) {
  final Map<String, int> byId = <String, int>{
    for (var i = 0; i < ids.length; i++) '${ids[i]}': weights[i],
  };
  final Map<String, int> out = allocateById(
    totalMinor,
    ids.map((e) => '$e').toList(),
    byId,
  );
  return <int, int>{
    for (var i = 0; i < ids.length; i++)
      if (out.containsKey('${ids[i]}')) i: out['${ids[i]}']!,
  };
}

int _floorDiv(int a, int b) {
  int q = a ~/ b;
  if ((a % b != 0) && ((a < 0) != (b < 0))) q--;
  return q;
}

class _Quota {
  _Quota({required this.id, required this.base, required this.remainder});
  final String id;
  int base;
  final int remainder;
}

/// Exchange-rate snapshot: how many [targetMinorFactor]-scaled units one unit
/// of the source currency is worth, plus provenance.
class FxSnapshot {
  const FxSnapshot({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.fetchedAt,
    required this.provider,
    this.isIndicative = true,
  });

  final String fromCurrency;
  final String toCurrency;
  final Decimal rate;
  final DateTime? fetchedAt;
  final String provider;

  /// Indicative = mid-market reference rate, not a bank or card rate.
  final bool isIndicative;

  static FxSnapshot identity(String code) => FxSnapshot(
    fromCurrency: code,
    toCurrency: code,
    rate: Decimal.one,
    fetchedAt: null,
    provider: 'identity',
  );

  bool get isIdentity => fromCurrency == toCurrency;

  /// Converts [amount] from this snapshot's source currency to its target,
  /// preserving exactness as far as the currency's minor unit allows.
  Money convert(Money amount) {
    if (amount.currencyCode != fromCurrency) {
      throw ArgumentError(
        'Snapshot converts $fromCurrency, got ${amount.currencyCode}',
      );
    }
    if (isIdentity) return amount;
    final Decimal converted = amount.major * rate;
    return Money.fromDecimal(converted, toCurrency);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'from_currency': fromCurrency,
    'to_currency': toCurrency,
    'rate': rate.toString(),
    'fetched_at': fetchedAt?.toUtc().toIso8601String(),
    'provider': provider,
    'is_indicative': isIndicative,
  };
}
