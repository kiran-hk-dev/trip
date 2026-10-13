/// Major airports, for logging a flight expense without typing.
///
/// This is deliberately a *major airports* list, not the full ICAO database. It
/// covers the airports a leisure or business traveller is realistically booked
/// on, and the picker always allows free text, so an obscure strip still gets
/// recorded rather than blocked.
///
/// Code and city are stored so a search for "DEL", "Delhi" or "Indira Gandhi"
/// all land on the same row. Airport schedules change; the city and country do
/// not, so nothing here should ever be treated as authoritative.
///
/// Not stored: schedules, terminals, contact numbers, or anything else that
/// goes stale. TripSplit records what the user spent, not what the airport's
/// website says today.
library;

import 'package:flutter/foundation.dart';

@immutable
class Airport {
  const Airport(this.code, this.name, this.city, this.countryCode);

  /// IATA 3-letter code. Unique across this list.
  final String code;

  /// Airport name as commonly used, e.g. "Indira Gandhi International".
  final String name;

  /// City the airport serves.
  final String city;

  /// ISO 3166-1 alpha-2 of the country the airport is in.
  final String countryCode;

  /// "Delhi (DEL)" — what a traveller scans for on their boarding pass.
  String get label => '$city ($code)';

  @override
  bool operator ==(Object other) =>
      other is Airport && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code $name, $city';
}

const List<Airport> kAirports = <Airport>[
  // ---- India ----
  Airport('DEL', 'Indira Gandhi International', 'Delhi', 'IN'),
  Airport('BOM', 'Chhatrapati Shivaji Maharaj', 'Mumbai', 'IN'),
  Airport('BLR', 'Kempegowda International', 'Bengaluru', 'IN'),
  Airport('MAA', 'Chennai International', 'Chennai', 'IN'),
  Airport('HYD', 'Rajiv Gandhi International', 'Hyderabad', 'IN'),
  Airport('CCU', 'Netaji Subhas Chandra Bose', 'Kolkata', 'IN'),
  Airport('COK', 'Cochin International', 'Kochi', 'IN'),
  Airport('AMD', 'Sardar Vallabhbhai Patel', 'Ahmedabad', 'IN'),
  Airport('PNQ', 'Pune International', 'Pune', 'IN'),
  Airport('JAI', 'Jaipur International', 'Jaipur', 'IN'),
  Airport('GOI', 'Dabolim / Manohar International', 'Goa', 'IN'),
  Airport('GOX', 'Manohar International', 'Goa', 'IN'),
  Airport('LKO', 'Chaudhary Charan Singh', 'Lucknow', 'IN'),
  Airport('IXC', 'Kangra', 'Dharamshala', 'IN'),
  Airport('IDR', 'Vallabhbhai Patel', 'Indore', 'IN'),
  Airport('TRV', 'Trivandrum International', 'Thiruvananthapuram', 'IN'),
  Airport('GAU', 'Lokpriya Gopinath Bordoloi', 'Guwahati', 'IN'),
  Airport('SXR', 'Sheikh ul-Alam', 'Srinagar', 'IN'),
  Airport('IXB', 'Kushok Bakula Rimpochee', 'Leh', 'IN'),
  Airport('VNS', 'Lal Bahadur Shastri', 'Varanasi', 'IN'),

  // ---- South and Southeast Asia ----
  Airport('SIN', 'Changi', 'Singapore', 'SG'),
  Airport('KUL', 'Kuala Lumpur International', 'Kuala Lumpur', 'MY'),
  Airport('BKK', 'Suvarnabhumi', 'Bangkok', 'TH'),
  Airport('DMK', 'Don Mueang', 'Bangkok', 'TH'),
  Airport('HKT', 'Phuket International', 'Phuket', 'TH'),
  Airport('CNX', 'Chiang Mai International', 'Chiang Mai', 'TH'),
  Airport('DPS', 'Ngurah Rai International', 'Bali', 'ID'),
  Airport('CGK', 'Soekarno-Hatta International', 'Jakarta', 'ID'),
  Airport('SUB', 'Juanda', 'Surabaya', 'ID'),
  Airport('SGN', 'Tan Son Nhat International', 'Ho Chi Minh City', 'VN'),
  Airport('HAN', 'Noi Bai International', 'Hanoi', 'VN'),
  Airport('DAD', 'Da Nang International', 'Da Nang', 'VN'),
  Airport('PNH', 'Phnom Penh International', 'Phnom Penh', 'KH'),
  Airport('REP', 'Siem Reap International', 'Siem Reap', 'KH'),
  Airport('RGN', 'Yangon International', 'Yangon', 'MM'),
  Airport('VTE', 'Wattay International', 'Vientiane', 'LA'),
  Airport('MNL', 'Ninoy Aquino International', 'Manila', 'PH'),
  Airport('CEB', 'Mactan-Cebu International', 'Cebu', 'PH'),
  Airport('MDL', 'Chapel International', 'Mandalay', 'MM'),

  // ---- East Asia ----
  Airport('HKG', 'Hong Kong International', 'Hong Kong', 'HK'),
  Airport('NRT', 'Narita International', 'Tokyo', 'JP'),
  Airport('HND', 'Haneda', 'Tokyo', 'JP'),
  Airport('KIX', 'Kansai International', 'Osaka', 'JP'),
  Airport('ICN', 'Incheon International', 'Seoul', 'KR'),
  Airport('GMP', 'Gimpo International', 'Seoul', 'KR'),
  Airport('PEK', 'Beijing Capital', 'Beijing', 'CN'),
  Airport('PKX', 'Beijing Daxing', 'Beijing', 'CN'),
  Airport('PVG', 'Shanghai Pudong', 'Shanghai', 'CN'),
  Airport('SHA', 'Shanghai Hongqiao', 'Shanghai', 'CN'),
  Airport('CAN', 'Guangzhou Baiyun', 'Guangzhou', 'CN'),
  Airport('SZX', 'Shenzhen Baoan', 'Shenzhen', 'CN'),
  Airport('CTU', 'Chengdu Tianfu', 'Chengdu', 'CN'),
  Airport('HGH', 'Hangzhou Xiaoshan', 'Hangzhou', 'CN'),
  Airport('TPE', 'Taiwan Taoyuan', 'Taipei', 'TW'),

  // ---- Middle East ----
  Airport('DXB', 'Dubai International', 'Dubai', 'AE'),
  Airport('AUH', 'Zayed International', 'Abu Dhabi', 'AE'),
  Airport('SHJ', 'Sharjah International', 'Sharjah', 'AE'),
  Airport('DOH', 'Hamad International', 'Doha', 'QA'),
  Airport('RUH', 'King Khalid International', 'Riyadh', 'SA'),
  Airport('JED', 'King Abdulaziz International', 'Jeddah', 'SA'),
  Airport('KWI', 'Kuwait International', 'Kuwait City', 'KW'),
  Airport('BAH', 'Bahrain International', 'Manama', 'BH'),
  Airport('MCT', 'Muscat International', 'Muscat', 'OM'),
  Airport('AMM', 'Queen Alia International', 'Amman', 'JO'),
  Airport('BEY', 'Beirut-Rafic Hariri', 'Beirut', 'LB'),
  Airport('TLV', 'Ben Gurion', 'Tel Aviv', 'IL'),
  Airport('IST', 'Istanbul', 'Istanbul', 'TR'),
  Airport('AYT', 'Antalya', 'Antalya', 'TR'),
  Airport('ESB', 'Ankara Esenbooga', 'Ankara', 'TR'),

  // ---- Europe ----
  Airport('LHR', 'Heathrow', 'London', 'GB'),
  Airport('LGW', 'Gatwick', 'London', 'GB'),
  Airport('STN', 'Stansted', 'London', 'GB'),
  Airport('MAN', 'Manchester', 'Manchester', 'GB'),
  Airport('EDI', 'Edinburgh', 'Edinburgh', 'GB'),
  Airport('DUB', 'Dublin', 'Dublin', 'IE'),
  Airport('CDG', 'Charles de Gaulle', 'Paris', 'FR'),
  Airport('ORY', 'Orly', 'Paris', 'FR'),
  Airport('AMS', 'Schiphol', 'Amsterdam', 'NL'),
  Airport('FRA', 'Frankfurt am Main', 'Frankfurt', 'DE'),
  Airport('MUC', 'Munich', 'Munich', 'DE'),
  Airport('BER', 'Berlin Brandenburg', 'Berlin', 'DE'),
  Airport('DUS', 'Dusseldorf', 'Dusseldorf', 'DE'),
  Airport('MAD', 'Adolfo Suarez Barajas', 'Madrid', 'ES'),
  Airport('BCN', 'El Prat', 'Barcelona', 'ES'),
  Airport('AGP', 'Costa del Sol', 'Malaga', 'ES'),
  Airport('PMI', 'Palma de Mallorca', 'Palma', 'ES'),
  Airport('FCO', 'Fiumicino', 'Rome', 'IT'),
  Airport('MXP', 'Malpensa', 'Milan', 'IT'),
  Airport('LIN', 'Linate', 'Milan', 'IT'),
  Airport('VCE', 'Marco Polo', 'Venice', 'IT'),
  Airport('NAP', 'Capodichino', 'Naples', 'IT'),
  Airport('LIS', 'Humberto Delgado', 'Lisbon', 'PT'),
  Airport('OPO', 'Francisco Sa Carneiro', 'Porto', 'PT'),
  Airport('BRU', 'Brussels', 'Brussels', 'BE'),
  Airport('ZRH', 'Zurich', 'Zurich', 'CH'),
  Airport('GVA', 'Geneva', 'Geneva', 'CH'),
  Airport('VIE', 'Vienna International', 'Vienna', 'AT'),
  Airport('CPH', 'Kastrup', 'Copenhagen', 'DK'),
  Airport('ARN', 'Arlanda', 'Stockholm', 'SE'),
  Airport('OSL', 'Gardermoen', 'Oslo', 'NO'),
  Airport('HEL', 'Helsinki-Vantaa', 'Helsinki', 'FI'),
  Airport('KEF', 'Keflavik', 'Reykjavik', 'IS'),
  Airport('ATH', 'Eleftherios Venizelos', 'Athens', 'GR'),
  Airport('SKG', 'Macedonia', 'Thessaloniki', 'GR'),
  Airport('PRG', 'Vaclav Havel', 'Prague', 'CZ'),
  Airport('BUD', 'Ferenc Liszt', 'Budapest', 'HU'),
  Airport('WAW', 'Chopin', 'Warsaw', 'PL'),
  Airport('KRK', 'John Paul II', 'Krakow', 'PL'),
  Airport('OTP', 'Henri Coanda', 'Bucharest', 'RO'),
  Airport('SOF', 'Sofia', 'Sofia', 'BG'),
  Airport('SPU', 'Split', 'Split', 'HR'),
  Airport('DBV', 'Dubrovnik', 'Dubrovnik', 'HR'),
  Airport('LJU', 'Ljubljana Joze Pucnik', 'Ljubljana', 'SI'),
  Airport('RIX', 'Riga International', 'Riga', 'LV'),
  Airport('TLL', 'Lennart Meri', 'Tallinn', 'EE'),
  Airport('VNO', 'Vilnius', 'Vilnius', 'LT'),
  Airport('LUX', 'Luxembourg', 'Luxembourg', 'LU'),
  Airport('MLA', 'Malta International', 'Malta', 'MT'),
  Airport('SVO', 'Sheremetyevo', 'Moscow', 'RU'),
  Airport('DME', 'Domodedovo', 'Moscow', 'RU'),

  // ---- North America ----
  Airport('JFK', 'John F. Kennedy International', 'New York', 'US'),
  Airport('EWR', 'Newark Liberty', 'New York', 'US'),
  Airport('LGA', 'LaGuardia', 'New York', 'US'),
  Airport('LAX', 'Los Angeles International', 'Los Angeles', 'US'),
  Airport('SFO', 'San Francisco International', 'San Francisco', 'US'),
  Airport('SJC', 'Norman Y. Mineta San Jose', 'San Jose', 'US'),
  Airport('OAK', 'Oakland International', 'Oakland', 'US'),
  Airport('ORD', "O'Hare International", 'Chicago', 'US'),
  Airport('MDW', 'Midway International', 'Chicago', 'US'),
  Airport('ATL', 'Hartsfield-Jackson Atlanta', 'Atlanta', 'US'),
  Airport('MIA', 'Miami International', 'Miami', 'US'),
  Airport('MCO', 'Orlando International', 'Orlando', 'US'),
  Airport('TPA', 'Tampa International', 'Tampa', 'US'),
  Airport('BOS', 'Logan International', 'Boston', 'US'),
  Airport('IAD', 'Washington Dulles', 'Washington', 'US'),
  Airport('DCA', 'Ronald Reagan Washington National', 'Washington', 'US'),
  Airport('SEA', 'Seattle-Tacoma', 'Seattle', 'US'),
  Airport('DEN', 'Denver International', 'Denver', 'US'),
  Airport('DFW', 'Dallas/Fort Worth', 'Dallas', 'US'),
  Airport('IAH', 'George Bush Intercontinental', 'Houston', 'US'),
  Airport('MSP', 'Minneapolis-St Paul', 'Minneapolis', 'US'),
  Airport('DTW', 'Detroit Metropolitan', 'Detroit', 'US'),
  Airport('PHL', 'Philadelphia International', 'Philadelphia', 'US'),
  Airport('LAS', 'Harry Reid International', 'Las Vegas', 'US'),
  Airport('PHX', 'Sky Harbor', 'Phoenix', 'US'),
  Airport('SAN', 'San Diego International', 'San Diego', 'US'),
  Airport('AUS', 'Austin-Bergstrom', 'Austin', 'US'),
  Airport('YYZ', 'Toronto Pearson', 'Toronto', 'CA'),
  Airport('YVR', 'Vancouver International', 'Vancouver', 'CA'),
  Airport('YUL', 'Montreal-Trudeau', 'Montreal', 'CA'),
  Airport('YYC', 'Calgary International', 'Calgary', 'CA'),
  Airport('YOW', 'Ottawa Macdonald-Cartier', 'Ottawa', 'CA'),
  Airport('MEX', 'Benito Juarez International', 'Mexico City', 'MX'),
  Airport('CUN', 'Cancun International', 'Cancun', 'MX'),
  Airport('GDL', 'Miguel Hidalgo y Costilla', 'Guadalajara', 'MX'),
  Airport('MTY', 'Monterrey International', 'Monterrey', 'MX'),

  // ---- South America ----
  Airport('GRU', 'Guarulhos', 'Sao Paulo', 'BR'),
  Airport('GIG', 'Galeao Antonio Carlos Jobim', 'Rio de Janeiro', 'BR'),
  Airport('BSB', 'Brasilia International', 'Brasilia', 'BR'),
  Airport('EZE', 'Ministro Pistarini', 'Buenos Aires', 'AR'),
  Airport('AEP', 'Aeroparque', 'Buenos Aires', 'AR'),
  Airport('SCL', 'Arturo Merino Benitez', 'Santiago', 'CL'),
  Airport('LIM', 'Jorge Chavez International', 'Lima', 'PE'),
  Airport('BOG', 'El Dorado', 'Bogota', 'CO'),
  Airport('MDE', 'Jose Maria Cordova', 'Medellin', 'CO'),
  Airport('UIO', 'Mariscal Sucre', 'Quito', 'EC'),
  Airport('GYE', 'Jose Joaquin de Olmedo', 'Guayaquil', 'EC'),
  Airport('MVD', 'Carrasco International', 'Montevideo', 'UY'),
  Airport('ASU', 'Silvio Pettirossi', 'Asuncion', 'PY'),

  // ---- Africa ----
  Airport('CPT', 'Cape Town International', 'Cape Town', 'ZA'),
  Airport('JNB', 'O.R. Tambo International', 'Johannesburg', 'ZA'),
  Airport('DUR', 'King Shaka International', 'Durban', 'ZA'),
  Airport('CXR', 'Cairo International', 'Cairo', 'EG'),
  Airport('HRG', 'Hurghada International', 'Hurghada', 'EG'),
  Airport('NBO', 'Jomo Kenyatta International', 'Nairobi', 'KE'),
  Airport('ADD', 'Bole International', 'Addis Ababa', 'ET'),
  Airport('CMN', 'Mohammed V International', 'Casablanca', 'MA'),
  Airport('RAK', 'Menara', 'Marrakesh', 'MA'),
  Airport('TNG', 'Ibn Battouta', 'Tangier', 'MA'),
  Airport('ALG', 'Houari Boumediene', 'Algiers', 'DZ'),
  Airport('TUN', 'Carthage', 'Tunis', 'TN'),
  Airport('LOS', 'Murtala Muhammed', 'Lagos', 'NG'),
  Airport('ABV', 'Nnamdi Azikiwe', 'Abuja', 'NG'),
  Airport('ACC', 'Kotoka International', 'Accra', 'GH'),
  Airport('DKR', 'Blaise Diagne', 'Dakar', 'SN'),
  Airport('MRU', 'Sir Seewoosagur Ramgoolam', 'Port Louis', 'MU'),

  // ---- Oceania ----
  Airport('SYD', 'Kingsford Smith', 'Sydney', 'AU'),
  Airport('MEL', 'Melbourne', 'Melbourne', 'AU'),
  Airport('BNE', 'Brisbane', 'Brisbane', 'AU'),
  Airport('PER', 'Perth', 'Perth', 'AU'),
  Airport('ADL', 'Adelaide', 'Adelaide', 'AU'),
  Airport('CBR', 'Canberra', 'Canberra', 'AU'),
  Airport('CNS', 'Cairns', 'Cairns', 'AU'),
  Airport('OOL', 'Gold Coast', 'Gold Coast', 'AU'),
  Airport('AKL', 'Auckland', 'Auckland', 'NZ'),
  Airport('CHC', 'Christchurch', 'Christchurch', 'NZ'),
  Airport('WLG', 'Wellington', 'Wellington', 'NZ'),
  Airport('NAN', 'Nadi International', 'Nadi', 'FJ'),
  Airport('POM', 'Port Moresby', 'Port Moresby', 'PG'),
  Airport('APW', 'Apia International', 'Apia', 'WS'),
];

/// Case-insensitive search over code, airport name and city.
///
/// Prefix matches rank first so "sin" surfaces Singapore Changi before
/// anything that merely contains those letters.
List<Airport> searchAirports(String query) {
  final String q = query.toLowerCase().trim();
  if (q.isEmpty) return kAirports;

  final List<Airport> prefix = <Airport>[];
  final List<Airport> contains = <Airport>[];

  for (final Airport a in kAirports) {
    final String code = a.code.toLowerCase();
    final String name = a.name.toLowerCase();
    final String city = a.city.toLowerCase();

    if (code.startsWith(q) || city.startsWith(q) || name.startsWith(q)) {
      prefix.add(a);
    } else if (code.contains(q) || name.contains(q) || city.contains(q)) {
      contains.add(a);
    }
  }
  return <Airport>[...prefix, ...contains];
}

Airport? airportByCode(String? code) {
  if (code == null) return null;
  final String wanted = code.trim().toUpperCase();
  if (wanted.length != 3) return null;
  for (final Airport a in kAirports) {
    if (a.code == wanted) return a;
  }
  return null;
}
