import 'package:flutter/foundation.dart';

import 'model.dart';

/// Verification state carried by every piece of safety-critical reference
/// data. The UI is not allowed to present anything as fact unless this says so.
enum VerificationState {
  verified,
  unverified,
  stale,
  needsReview;

  static VerificationState fromId(String? id) =>
      VerificationState.values.firstWhere(
        (v) => v.name == id,
        orElse: () => VerificationState.unverified,
      );

  String get label => switch (this) {
    VerificationState.verified => 'Verified',
    VerificationState.unverified => 'Not yet verified',
    VerificationState.stale => 'May be out of date',
    VerificationState.needsReview => 'Awaiting review',
  };

  bool get isTrusted => this == VerificationState.verified;
}

@immutable
class EmergencyResource extends Model {
  const EmergencyResource({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.category,
    required this.serviceName,
    this.phone,
    this.alternatePhone,
    this.address,
    this.officialUrl,
    this.languages = const <String>[],
    this.hours,
    this.availabilityNote,
    required this.sourceUrl,
    required this.sourceOrg,
    this.verification = VerificationState.unverified,
    this.lastVerifiedAt,
    this.reviewDueAt,
    this.notes,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final String category;
  final String serviceName;
  final String? phone;
  final String? alternatePhone;
  final String? address;
  final String? officialUrl;
  final List<String> languages;
  final String? hours;
  final String? availabilityNote;
  final String sourceUrl;
  final String sourceOrg;
  final VerificationState verification;
  final DateTime? lastVerifiedAt;
  final DateTime? reviewDueAt;
  final String? notes;

  bool get hasPhone => phone != null && phone!.isNotEmpty;

  bool get isOverdueForReview =>
      reviewDueAt != null && reviewDueAt!.isBefore(DateTime.now());

  String get categoryLabel => switch (category) {
    'police' => 'Police',
    'ambulance' => 'Ambulance',
    'fire' => 'Fire',
    'emergency' => 'All emergency services',
    'immigration' => 'Immigration',
    'consular_directory' => 'Consular directory',
    'tourist_assistance' => 'Tourist assistance',
    'lost_property' => 'Lost property',
    _ => category,
  };

  factory EmergencyResource.fromJson(Map<String, dynamic> json) =>
      EmergencyResource(
        id: '${json['id']}',
        countryCode: (json['country_code'] as String?) ?? '',
        countryName: json['country_name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        serviceName: json['service_name'] as String? ?? '',
        phone: json['phone'] as String?,
        alternatePhone: json['alternate_phone'] as String?,
        address: json['address'] as String?,
        officialUrl: json['official_url'] as String?,
        languages: decodeStringList(json['languages']),
        hours: json['hours'] as String?,
        availabilityNote: json['availability_note'] as String?,
        sourceUrl: json['source_url'] as String? ?? '',
        sourceOrg: json['source_org'] as String? ?? '',
        verification: VerificationState.fromId(json['verification'] as String?),
        lastVerifiedAt: decodeDateTimeOrNull(json['last_verified_at']),
        reviewDueAt: decodeDateTimeOrNull(json['review_due_at']),
        notes: json['notes'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'country_code': countryCode,
    'country_name': countryName,
    'category': category,
    'service_name': serviceName,
    'phone': phone,
    'official_url': officialUrl,
    'source_url': sourceUrl,
    'source_org': sourceOrg,
    'verification': verification.name,
  };
}

/// One step of a multi-step emergency guide.
@immutable
class GuideAction {
  const GuideAction({
    required this.label,
    required this.url,
    this.kind = 'external',
  });

  final String label;
  final String url;

  /// external | call | map | sms
  final String kind;

  factory GuideAction.fromJson(Map<String, dynamic> json) => GuideAction(
    label: json['label'] as String? ?? '',
    url: json['url'] as String? ?? '',
    kind: json['kind'] as String? ?? 'external',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'url': url,
    'kind': kind,
  };
}

@immutable
class GuideStep {
  const GuideStep({
    required this.heading,
    required this.body,
    this.actions = const <GuideAction>[],
    this.callouts = const <String>[],
  });

  final String heading;
  final String body;
  final List<GuideAction> actions;
  final List<String> callouts;

  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
    heading: json['heading'] as String? ?? '',
    body: json['body'] as String? ?? '',
    actions: ((json['actions'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(GuideAction.fromJson)
        .toList(),
    callouts: ((json['callouts'] as List?) ?? const <dynamic>[])
        .map((e) => '$e')
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'heading': heading,
    'body': body,
    'actions': actions.map((a) => a.toJson()).toList(),
    'callouts': callouts,
  };
}

@immutable
class EmergencyGuide extends Model {
  const EmergencyGuide({
    required this.id,
    required this.slug,
    this.countryCode,
    required this.title,
    this.summary,
    this.steps = const <GuideStep>[],
    this.languages = const <String>[],
    this.phrases = const <String, List<String>>{},
    this.sourceUrl,
    this.sourceOrg,
    this.verification = VerificationState.unverified,
    this.lastVerifiedAt,
    this.reviewDueAt,
  });

  final String id;
  final String slug;
  final String? countryCode;
  final String title;
  final String? summary;
  final List<GuideStep> steps;

  /// BCP-47-ish language codes this guide is available in, e.g. `zh-Hant`.
  final List<String> languages;

  /// Localised help phrases, keyed by language code.
  final Map<String, List<String>> phrases;
  final String? sourceUrl;
  final String? sourceOrg;
  final VerificationState verification;
  final DateTime? lastVerifiedAt;
  final DateTime? reviewDueAt;

  bool isForCountry(String code) => countryCode == code;

  List<String> phrasesFor(String language) =>
      phrases[language] ?? const <String>[];

  factory EmergencyGuide.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> langs = decodeMap(json['languages']);
    final Map<String, dynamic> rawPhrases = decodeMap(json['phrases']);
    return EmergencyGuide(
      id: '${json['id']}',
      slug: json['slug'] as String? ?? '',
      countryCode: json['country_code'] as String?,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      steps: ((json['steps'] as List?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GuideStep.fromJson)
          .toList(),
      languages: langs.keys.where((k) => langs[k] == true).toList(),
      phrases: rawPhrases.map(
        (k, v) => MapEntry<String, List<String>>(
          k,
          (v as List?)?.map((e) => '$e').toList() ?? const <String>[],
        ),
      ),
      sourceUrl: json['source_url'] as String?,
      sourceOrg: json['source_org'] as String?,
      verification: VerificationState.fromId(json['verification'] as String?),
      lastVerifiedAt: decodeDateTimeOrNull(json['last_verified_at']),
      reviewDueAt: decodeDateTimeOrNull(json['review_due_at']),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'slug': slug,
    'country_code': countryCode,
    'title': title,
    'summary': summary,
    'steps': steps.map((s) => s.toJson()).toList(),
    'languages': languages,
    'phrases': phrases,
    'source_url': sourceUrl,
    'source_org': sourceOrg,
    'verification': verification.name,
  };

  EmergencyGuide copyWith({
    List<GuideStep>? steps,
    Map<String, List<String>>? phrases,
    List<String>? languages,
    VerificationState? verification,
    DateTime? lastVerifiedAt,
  }) => EmergencyGuide(
    id: id,
    slug: slug,
    countryCode: countryCode,
    title: title,
    summary: summary,
    steps: steps ?? this.steps,
    languages: languages ?? this.languages,
    phrases: phrases ?? this.phrases,
    sourceUrl: sourceUrl,
    sourceOrg: sourceOrg,
    verification: verification ?? this.verification,
    lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    reviewDueAt: reviewDueAt,
  );
}

enum EmergencyCategory {
  lostPassport('lost_passport', 'Lost passport', '🛂'),
  stolenWallet('stolen_wallet', 'Stolen wallet', '👛'),
  lostPhone('lost_phone', 'Lost phone', '📱'),
  noAccommodation('no_accommodation', 'Nowhere to stay', '🏨'),
  medical('medical', 'Medical emergency', '🚑'),
  accident('accident', 'Accident or injury', '🤕'),
  theft('theft', 'Theft or robbery', '🚨'),
  arrest('arrest', 'Arrest or detention', '⚖️'),
  disaster('disaster', 'Natural disaster', '🌊'),
  flightDisruption('flight_disruption', 'Flight cancelled or missed', '✈️'),
  lostMedication('lost_medication', 'Lost medication', '💊'),
  cardBlocked('card_blocked', 'Bank card blocked', '💳'),
  scam('scam', 'Suspected scam', '🕵️'),
  personalSafety('personal_safety', 'Personal safety emergency', '🛡️'),
  consular('consular', 'Consular assistance', '🏛️');

  const EmergencyCategory(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  static EmergencyCategory fromId(String? id) =>
      EmergencyCategory.values.firstWhere(
        (c) => c.id == id,
        orElse: () => EmergencyCategory.lostPassport,
      );
}

@immutable
class VisaResourceLink extends Model {
  const VisaResourceLink({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.officialUrl,
    required this.sourceOrg,
    required this.sourceUrl,
    this.category = 'entry_requirements',
    this.verification = VerificationState.unverified,
    this.lastVerifiedAt,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final String officialUrl;
  final String sourceOrg;
  final String sourceUrl;
  final String category;
  final VerificationState verification;
  final DateTime? lastVerifiedAt;

  factory VisaResourceLink.fromJson(Map<String, dynamic> json) =>
      VisaResourceLink(
        id: '${json['id']}',
        countryCode: (json['country_code'] as String?) ?? '',
        countryName: json['country_name'] as String? ?? '',
        officialUrl: json['official_url'] as String? ?? '',
        sourceOrg: json['source_org'] as String? ?? '',
        sourceUrl: json['source_url'] as String? ?? '',
        category: (json['category'] as String?) ?? 'entry_requirements',
        verification: VerificationState.fromId(json['verification'] as String?),
        lastVerifiedAt: decodeDateTimeOrNull(json['last_verified_at']),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'country_code': countryCode,
    'country_name': countryName,
    'official_url': officialUrl,
    'source_org': sourceOrg,
  };
}

@immutable
class VisaRecord extends Model {
  const VisaRecord({
    required this.id,
    required this.tripId,
    required this.destinationCountry,
    required this.nationalityCountry,
    this.residenceCountry,
    this.transitCountries = const <String>[],
    this.travelPurpose,
    this.entryDate,
    this.exitDate,
    this.authorizationType,
    this.status = 'not_checked',
    this.officialUrl,
    this.sourceOrganization,
    this.lastVerifiedAt,
    this.verification = VerificationState.unverified,
    this.notes,
  });

  final String id;
  final String tripId;
  final String destinationCountry;
  final String nationalityCountry;
  final String? residenceCountry;
  final List<String> transitCountries;
  final String? travelPurpose;
  final DateTime? entryDate;
  final DateTime? exitDate;
  final String? authorizationType;
  final String status;
  final String? officialUrl;
  final String? sourceOrganization;
  final DateTime? lastVerifiedAt;
  final VerificationState verification;
  final String? notes;

  static const List<({String id, String label})> statuses =
      <({String id, String label})>[
        (id: 'not_checked', label: 'Not checked'),
        (id: 'required', label: 'Required — user confirmed'),
        (id: 'not_required', label: 'Not required — user confirmed'),
        (id: 'applied', label: 'Applied'),
        (id: 'approved', label: 'Approved'),
        (id: 'expired', label: 'Expired'),
        (id: 'unknown', label: 'Unknown'),
      ];

  String get statusLabel => statuses
      .firstWhere((s) => s.id == status, orElse: () => statuses.first)
      .label;

  factory VisaRecord.fromJson(Map<String, dynamic> json) => VisaRecord(
    id: '${json['id']}',
    tripId: '${json['trip_id']}',
    destinationCountry: json['destination_country'] as String? ?? '',
    nationalityCountry: json['nationality_country'] as String? ?? '',
    residenceCountry: json['residence_country'] as String?,
    transitCountries: decodeStringList(json['transit_countries']),
    travelPurpose: json['travel_purpose'] as String?,
    entryDate: decodeDateOrNull(json['entry_date']),
    exitDate: decodeDateOrNull(json['exit_date']),
    authorizationType: json['authorization_type'] as String?,
    status: (json['status'] as String?) ?? 'not_checked',
    officialUrl: json['official_url'] as String?,
    sourceOrganization: json['source_organization'] as String?,
    lastVerifiedAt: decodeDateTimeOrNull(json['last_verified_at']),
    verification: VerificationState.fromId(json['verification'] as String?),
    notes: json['notes'] as String?,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'destination_country': destinationCountry,
    'nationality_country': nationalityCountry,
    'residence_country': residenceCountry,
    'transit_countries': transitCountries,
    'travel_purpose': travelPurpose,
    'entry_date': entryDate == null ? null : _isoDate(entryDate!),
    'exit_date': exitDate == null ? null : _isoDate(exitDate!),
    'authorization_type': authorizationType,
    'status': status,
    'official_url': officialUrl,
    'notes': notes,
  };
}

@immutable
class TravelAdvisory extends Model {
  const TravelAdvisory({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.officialUrl,
    required this.sourceOrg,
    required this.sourceUrl,
    this.advisoryLevel,
    this.headline,
    this.summary,
    this.verification = VerificationState.unverified,
    this.lastVerifiedAt,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final String officialUrl;
  final String sourceOrg;
  final String sourceUrl;
  final String? advisoryLevel;
  final String? headline;
  final String? summary;
  final VerificationState verification;
  final DateTime? lastVerifiedAt;

  factory TravelAdvisory.fromJson(Map<String, dynamic> json) => TravelAdvisory(
    id: '${json['id']}',
    countryCode: (json['country_code'] as String?) ?? '',
    countryName: json['country_name'] as String? ?? '',
    officialUrl: json['official_url'] as String? ?? '',
    sourceOrg: json['source_org'] as String? ?? '',
    sourceUrl: json['source_url'] as String? ?? '',
    advisoryLevel: json['advisory_level'] as String?,
    headline: json['headline'] as String?,
    summary: json['summary'] as String?,
    verification: VerificationState.fromId(json['verification'] as String?),
    lastVerifiedAt: decodeDateTimeOrNull(json['last_verified_at']),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'country_code': countryCode,
    'country_name': countryName,
    'official_url': officialUrl,
    'source_org': sourceOrg,
  };
}

@immutable
class Destination extends Model {
  const Destination({
    required this.id,
    required this.name,
    this.country,
    this.countryCode,
    this.city,
    this.latitude,
    this.longitude,
    this.timezone,
    this.currency,
    this.languages = const <String>[],
    this.imageUrl,
    this.summary,
    this.categories = const <String>[],
    this.bestMonths = const <int>[],
    this.typicalDailyBudgetMinor,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? country;
  final String? countryCode;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? timezone;
  final String? currency;
  final List<String> languages;
  final String? imageUrl;
  final String? summary;
  final List<String> categories;
  final List<int> bestMonths;
  final int? typicalDailyBudgetMinor;
  final bool verified;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get categoriesLabel => categories.join(' · ');

  /// Best-effort seasonal guidance derived from the month list. Not a
  /// guarantee of weather — the UI labels it as guidance only.
  String get seasonalGuidance {
    if (bestMonths.isEmpty) return 'No seasonal guidance recorded.';
    final int month = DateTime.now().month;
    return bestMonths.contains(month)
        ? '${_monthName(month)} is listed as a good month to visit.'
        : '${_monthName(month)} is outside the listed best months — expect it to be busier or less comfortable.';
  }

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    country: json['country'] as String?,
    countryCode: json['country_code'] as String?,
    city: json['city'] as String?,
    latitude: decodeDouble(json['latitude']),
    longitude: decodeDouble(json['longitude']),
    timezone: json['timezone'] as String?,
    currency: json['currency'] as String?,
    languages: decodeStringList(json['languages']),
    imageUrl: json['image_url'] as String?,
    summary: json['summary'] as String?,
    categories: decodeStringList(json['categories']),
    bestMonths:
        (json['best_months'] as List?)?.map((e) => decodeInt(e)).toList() ??
        const <int>[],
    typicalDailyBudgetMinor: json['typical_daily_budget_minor'] == null
        ? null
        : decodeInt(json['typical_daily_budget_minor']),
    verified: json['verified'] as bool? ?? false,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'country': country,
    'country_code': countryCode,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'currency': currency,
    'languages': languages,
    'image_url': imageUrl,
    'summary': summary,
    'categories': categories,
    'typical_daily_budget_minor': typicalDailyBudgetMinor,
  };
}

String _monthName(int month) => const <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
