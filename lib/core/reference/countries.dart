/// ISO 3166-1 alpha-2 country list.
///
/// Bundled rather than fetched so destination selection works offline and on
/// first launch, which matters for the app's stated offline-first promise.
///
/// Deliberately code-and-name only. No flags, no dialling codes, no currency:
/// those are all things that go stale or are wrong for a given traveller, and
/// none of them are needed to record where a trip is going.
library;

import 'package:flutter/foundation.dart';

@immutable
class Country {
  const Country(this.code, this.name);

  /// ISO 3166-1 alpha-2, uppercase. Matches `trips.country_code`.
  final String code;
  final String name;

  /// Flag emoji derived from the code.
  ///
  /// Regional indicator symbols: 'IN' -> U+1F1EE U+1F1F3 -> the Indian flag.
  /// Countries with no emoji (and any bad code) return an empty string rather
  /// than throwing, because a flag is decoration, never a correctness issue.
  String get flagEmoji {
    if (code.length != 2) return '';
    const int base = 0x1F1E6; // REGIONAL INDICATOR SYMBOL LETTER A
    final int a = code.codeUnitAt(0) - 0x41;
    final int b = code.codeUnitAt(1) - 0x41;
    if (a < 0 || a > 25 || b < 0 || b > 25) return '';
    return String.fromCharCodes(<int>[base + a, base + b]);
  }

  @override
  bool operator ==(Object other) =>
      other is Country && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(code, name);

  @override
  String toString() => '$code $name';
}

/// Every country a traveller might reasonably plan a trip to.
const List<Country> kCountries = <Country>[
  Country('AF', 'Afghanistan'),
  Country('AX', 'Aland Islands'),
  Country('AL', 'Albania'),
  Country('DZ', 'Algeria'),
  Country('AS', 'American Samoa'),
  Country('AD', 'Andorra'),
  Country('AO', 'Angola'),
  Country('AI', 'Anguilla'),
  Country('AG', 'Antigua and Barbuda'),
  Country('AR', 'Argentina'),
  Country('AM', 'Armenia'),
  Country('AW', 'Aruba'),
  Country('AU', 'Australia'),
  Country('AT', 'Austria'),
  Country('AZ', 'Azerbaijan'),
  Country('BS', 'Bahamas'),
  Country('BH', 'Bahrain'),
  Country('BD', 'Bangladesh'),
  Country('BB', 'Barbados'),
  Country('BY', 'Belarus'),
  Country('BE', 'Belgium'),
  Country('BZ', 'Belize'),
  Country('BJ', 'Benin'),
  Country('BM', 'Bermuda'),
  Country('BT', 'Bhutan'),
  Country('BO', 'Bolivia'),
  Country('BQ', 'Bonaire, Sint Eustatius and Saba'),
  Country('BA', 'Bosnia and Herzegovina'),
  Country('BW', 'Botswana'),
  Country('BR', 'Brazil'),
  Country('IO', 'British Indian Ocean Territory'),
  Country('BN', 'Brunei'),
  Country('BG', 'Bulgaria'),
  Country('BF', 'Burkina Faso'),
  Country('BI', 'Burundi'),
  Country('CV', 'Cabo Verde'),
  Country('KH', 'Cambodia'),
  Country('CM', 'Cameroon'),
  Country('CA', 'Canada'),
  Country('KY', 'Cayman Islands'),
  Country('CF', 'Central African Republic'),
  Country('TD', 'Chad'),
  Country('CL', 'Chile'),
  Country('CN', 'China'),
  Country('CX', 'Christmas Island'),
  Country('CC', 'Cocos (Keeling) Islands'),
  Country('CO', 'Colombia'),
  Country('KM', 'Comoros'),
  Country('CG', 'Congo'),
  Country('CD', 'Congo (Democratic Republic)'),
  Country('CK', 'Cook Islands'),
  Country('CR', 'Costa Rica'),
  Country('CI', "Cote d'Ivoire"),
  Country('HR', 'Croatia'),
  Country('CU', 'Cuba'),
  Country('CW', 'Curacao'),
  Country('CY', 'Cyprus'),
  Country('CZ', 'Czechia'),
  Country('DK', 'Denmark'),
  Country('DJ', 'Djibouti'),
  Country('DM', 'Dominica'),
  Country('DO', 'Dominican Republic'),
  Country('EC', 'Ecuador'),
  Country('EG', 'Egypt'),
  Country('SV', 'El Salvador'),
  Country('GQ', 'Equatorial Guinea'),
  Country('ER', 'Eritrea'),
  Country('EE', 'Estonia'),
  Country('SZ', 'Eswatini'),
  Country('ET', 'Ethiopia'),
  Country('FK', 'Falkland Islands'),
  Country('FO', 'Faroe Islands'),
  Country('FJ', 'Fiji'),
  Country('FI', 'Finland'),
  Country('FR', 'France'),
  Country('GF', 'French Guiana'),
  Country('PF', 'French Polynesia'),
  Country('GA', 'Gabon'),
  Country('GM', 'Gambia'),
  Country('GE', 'Georgia'),
  Country('DE', 'Germany'),
  Country('GH', 'Ghana'),
  Country('GI', 'Gibraltar'),
  Country('GR', 'Greece'),
  Country('GL', 'Greenland'),
  Country('GD', 'Grenada'),
  Country('GP', 'Guadeloupe'),
  Country('GU', 'Guam'),
  Country('GT', 'Guatemala'),
  Country('GG', 'Guernsey'),
  Country('GN', 'Guinea'),
  Country('GW', 'Guinea-Bissau'),
  Country('GY', 'Guyana'),
  Country('HT', 'Haiti'),
  Country('HM', 'Heard Island and McDonald Islands'),
  Country('VA', 'Holy See'),
  Country('HN', 'Honduras'),
  Country('HK', 'Hong Kong'),
  Country('HU', 'Hungary'),
  Country('IS', 'Iceland'),
  Country('IN', 'India'),
  Country('ID', 'Indonesia'),
  Country('IR', 'Iran'),
  Country('IQ', 'Iraq'),
  Country('IE', 'Ireland'),
  Country('IM', 'Isle of Man'),
  Country('IL', 'Israel'),
  Country('IT', 'Italy'),
  Country('JM', 'Jamaica'),
  Country('JP', 'Japan'),
  Country('JE', 'Jersey'),
  Country('JO', 'Jordan'),
  Country('KZ', 'Kazakhstan'),
  Country('KE', 'Kenya'),
  Country('KI', 'Kiribati'),
  Country('KP', 'North Korea'),
  Country('KR', 'South Korea'),
  Country('KW', 'Kuwait'),
  Country('KG', 'Kyrgyzstan'),
  Country('LA', 'Laos'),
  Country('LV', 'Latvia'),
  Country('LB', 'Lebanon'),
  Country('LS', 'Lesotho'),
  Country('LR', 'Liberia'),
  Country('LY', 'Libya'),
  Country('LI', 'Liechtenstein'),
  Country('LT', 'Lithuania'),
  Country('LU', 'Luxembourg'),
  Country('MO', 'Macao'),
  Country('MG', 'Madagascar'),
  Country('MW', 'Malawi'),
  Country('MY', 'Malaysia'),
  Country('MV', 'Maldives'),
  Country('ML', 'Mali'),
  Country('MT', 'Malta'),
  Country('MH', 'Marshall Islands'),
  Country('MQ', 'Martinique'),
  Country('MR', 'Mauritania'),
  Country('MU', 'Mauritius'),
  Country('YT', 'Mayotte'),
  Country('MX', 'Mexico'),
  Country('FM', 'Micronesia'),
  Country('MD', 'Moldova'),
  Country('MC', 'Monaco'),
  Country('MN', 'Mongolia'),
  Country('ME', 'Montenegro'),
  Country('MS', 'Montserrat'),
  Country('MA', 'Morocco'),
  Country('MZ', 'Mozambique'),
  Country('MM', 'Myanmar'),
  Country('NA', 'Namibia'),
  Country('NR', 'Nauru'),
  Country('NP', 'Nepal'),
  Country('NL', 'Netherlands'),
  Country('NC', 'New Caledonia'),
  Country('NZ', 'New Zealand'),
  Country('NI', 'Nicaragua'),
  Country('NE', 'Niger'),
  Country('NG', 'Nigeria'),
  Country('NU', 'Niue'),
  Country('NF', 'Norfolk Island'),
  Country('MK', 'North Macedonia'),
  Country('MP', 'Northern Mariana Islands'),
  Country('NO', 'Norway'),
  Country('OM', 'Oman'),
  Country('PK', 'Pakistan'),
  Country('PW', 'Palau'),
  Country('PS', 'Palestine'),
  Country('PA', 'Panama'),
  Country('PG', 'Papua New Guinea'),
  Country('PY', 'Paraguay'),
  Country('PE', 'Peru'),
  Country('PH', 'Philippines'),
  Country('PN', 'Pitcairn'),
  Country('PL', 'Poland'),
  Country('PT', 'Portugal'),
  Country('PR', 'Puerto Rico'),
  Country('QA', 'Qatar'),
  Country('RE', 'Reunion'),
  Country('RO', 'Romania'),
  Country('RU', 'Russia'),
  Country('RW', 'Rwanda'),
  Country('BL', 'Saint Barthelemy'),
  Country('SH', 'Saint Helena'),
  Country('KN', 'Saint Kitts and Nevis'),
  Country('LC', 'Saint Lucia'),
  Country('MF', 'Saint Martin'),
  Country('PM', 'Saint Pierre and Miquelon'),
  Country('VC', 'Saint Vincent and the Grenadines'),
  Country('WS', 'Samoa'),
  Country('SM', 'San Marino'),
  Country('ST', 'Sao Tome and Principe'),
  Country('SA', 'Saudi Arabia'),
  Country('SN', 'Senegal'),
  Country('RS', 'Serbia'),
  Country('SC', 'Seychelles'),
  Country('SL', 'Sierra Leone'),
  Country('SG', 'Singapore'),
  Country('SX', 'Sint Maarten'),
  Country('SK', 'Slovakia'),
  Country('SI', 'Slovenia'),
  Country('SB', 'Solomon Islands'),
  Country('SO', 'Somalia'),
  Country('ZA', 'South Africa'),
  Country('GS', 'South Georgia and the South Sandwich Islands'),
  Country('SS', 'South Sudan'),
  Country('ES', 'Spain'),
  Country('LK', 'Sri Lanka'),
  Country('SD', 'Sudan'),
  Country('SR', 'Suriname'),
  Country('SJ', 'Svalbard and Jan Mayen'),
  Country('SE', 'Sweden'),
  Country('CH', 'Switzerland'),
  Country('SY', 'Syria'),
  Country('TW', 'Taiwan'),
  Country('TJ', 'Tajikistan'),
  Country('TZ', 'Tanzania'),
  Country('TH', 'Thailand'),
  Country('TL', 'Timor-Leste'),
  Country('TG', 'Togo'),
  Country('TK', 'Tokelau'),
  Country('TO', 'Tonga'),
  Country('TT', 'Trinidad and Tobago'),
  Country('TN', 'Tunisia'),
  Country('TR', 'Turkiye'),
  Country('TM', 'Turkmenistan'),
  Country('TC', 'Turks and Caicos Islands'),
  Country('TV', 'Tuvalu'),
  Country('UG', 'Uganda'),
  Country('UA', 'Ukraine'),
  Country('AE', 'United Arab Emirates'),
  Country('GB', 'United Kingdom'),
  Country('UM', 'United States Minor Outlying Islands'),
  Country('US', 'United States'),
  Country('UY', 'Uruguay'),
  Country('UZ', 'Uzbekistan'),
  Country('VU', 'Vanuatu'),
  Country('VE', 'Venezuela'),
  Country('VN', 'Vietnam'),
  Country('VG', 'Virgin Islands (British)'),
  Country('VI', 'Virgin Islands (US)'),
  Country('WF', 'Wallis and Futuna'),
  Country('EH', 'Western Sahara'),
  Country('YE', 'Yemen'),
  Country('ZM', 'Zambia'),
  Country('ZW', 'Zimbabwe'),
];

/// Case- and accent-tolerant search.
///
/// A traveller typing "turkiye", "Turkiye" or "turkey" should all land on
/// Turkey, and typing "IN" should surface India. Accents are stripped so
/// "Cote d'Ivoire" is findable without the apostrophe.
List<Country> searchCountries(String query) {
  final String q = _fold(query);
  if (q.isEmpty) return kCountries;

  // Prefix matches first: typing "ind" should put India above Indonesia.
  final List<Country> prefix = <Country>[];
  final List<Country> contains = <Country>[];

  for (final Country c in kCountries) {
    final String name = _fold(c.name);
    final String code = _fold(c.code);
    if (name.startsWith(q) || code.startsWith(q)) {
      prefix.add(c);
    } else if (name.contains(q) || c.name.toLowerCase().contains(query.toLowerCase().trim())) {
      contains.add(c);
    }
  }
  return <Country>[...prefix, ...contains];
}

Country? countryByCode(String? code) {
  if (code == null || code.trim().length != 2) return null;
  final String wanted = code.trim().toUpperCase();
  for (final Country c in kCountries) {
    if (c.code == wanted) return c;
  }
  return null;
}

/// Best-effort match from free text, for data that arrived without a code.
Country? countryByName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final String q = _fold(name);
  for (final Country c in kCountries) {
    if (_fold(c.name) == q) return c;
  }
  for (final Country c in kCountries) {
    if (_fold(c.name).contains(q)) return c;
  }
  return null;
}

String _fold(String input) {
  final String lower = input.toLowerCase().trim();
  // Strip the marks a phone keyboard may omit, so Cote -> Cote, not Coté.
  return lower
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[̀-ͯ]'), '');
}