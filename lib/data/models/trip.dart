import 'package:flutter/foundation.dart';

import '../../core/money/currency.dart';
import 'model.dart';

enum TripStatus {
  draft,
  planning,
  upcoming,
  ongoing,
  completed,
  cancelled,
  archived;

  static TripStatus fromId(String? id) => TripStatus.values.firstWhere(
    (s) => s.name == id,
    orElse: () => TripStatus.planning,
  );

  String get label => switch (this) {
    TripStatus.draft => 'Draft',
    TripStatus.planning => 'Planning',
    TripStatus.upcoming => 'Upcoming',
    TripStatus.ongoing => 'In progress',
    TripStatus.completed => 'Completed',
    TripStatus.cancelled => 'Cancelled',
    TripStatus.archived => 'Archived',
  };
}

enum TravelStyle {
  budget,
  balanced,
  comfort,
  luxury;

  static TravelStyle fromId(String? id) => TravelStyle.values.firstWhere(
    (s) => s.name == id,
    orElse: () => TravelStyle.balanced,
  );

  String get label => switch (this) {
    TravelStyle.budget => 'Budget',
    TravelStyle.balanced => 'Balanced',
    TravelStyle.comfort => 'Comfort',
    TravelStyle.luxury => 'Luxury',
  };
}

enum ItineraryPace {
  relaxed,
  balanced,
  packed;

  static ItineraryPace fromId(String? id) => ItineraryPace.values.firstWhere(
    (s) => s.name == id,
    orElse: () => ItineraryPace.balanced,
  );

  String get label => switch (this) {
    ItineraryPace.relaxed => 'Relaxed',
    ItineraryPace.balanced => 'Balanced',
    ItineraryPace.packed => 'Packed',
  };

  String get activityHint => switch (this) {
    ItineraryPace.relaxed => '2–3 activities per day, with room to wander',
    ItineraryPace.balanced => '4–5 activities per day',
    ItineraryPace.packed => '6–8 activities per day',
  };
}

enum TripRole {
  owner,
  admin,
  editor,
  viewer;

  static TripRole fromId(String? id) => TripRole.values.firstWhere(
    (r) => r.name == id,
    orElse: () => TripRole.viewer,
  );

  String get label => switch (this) {
    TripRole.owner => 'Owner',
    TripRole.admin => 'Administrator',
    TripRole.editor => 'Editor',
    TripRole.viewer => 'Viewer',
  };

  String get description => switch (this) {
    TripRole.owner => 'Full control, including deleting the trip',
    TripRole.admin => 'Manage members, invitations and trip settings',
    TripRole.editor => 'Add expenses, itinerary items and bookings',
    TripRole.viewer => 'View everything, change nothing',
  };

  bool get canEdit => this != TripRole.viewer;
  bool get canAdmin => this == owner || this == admin;
  bool get isOwner => this == owner;
}

@immutable
class Profile extends Model {
  const Profile({
    required this.id,
    this.fullName,
    this.avatarPath,
    this.phone,
    this.homeCountry,
    this.residenceCountry,
    this.nationalityCountries = const <String>[],
    this.passportCountry,
    this.passportExpiryDate,
    this.preferredCurrency = Currencies.defaultCode,
    this.preferredLanguage = 'en',
    this.timezone = 'UTC',
    this.dietaryPreferences = const <String>[],
    this.accessibilityNeeds,
    this.travelInterests = const <String>[],
    this.travelStyle,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactEmail,
    this.notificationPreferences = const <String, dynamic>{},
    this.onboardingCompleted = false,
    this.demoAccount = false,
  });

  final String id;
  final String? fullName;
  final String? avatarPath;
  final String? phone;
  final String? homeCountry;
  final String? residenceCountry;
  final List<String> nationalityCountries;
  final String? passportCountry;

  /// Reminder only. TripSplit never asks for or stores a passport number.
  final DateTime? passportExpiryDate;
  final String preferredCurrency;
  final String preferredLanguage;
  final String timezone;
  final List<String> dietaryPreferences;
  final String? accessibilityNeeds;
  final List<String> travelInterests;
  final TravelStyle? travelStyle;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactEmail;
  final Map<String, dynamic> notificationPreferences;
  final bool onboardingCompleted;
  final bool demoAccount;

  String get displayName {
    final String? name = fullName?.trim();
    if (name == null || name.isEmpty) return 'Traveller';
    return name.split(' ').first;
  }

  String get initials {
    final String name = (fullName ?? '').trim();
    if (name.isEmpty) return '?';
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool isNotificationEnabled(String key) {
    final Object? value = notificationPreferences[key];
    return value is bool ? value : true;
  }

  /// Months of passport validity left, or null when not configured.
  int? get passportMonthsRemaining {
    if (passportExpiryDate == null) return null;
    final DateTime now = DateTime.now();
    final int months =
        (passportExpiryDate!.year - now.year) * 12 +
        (passportExpiryDate!.month - now.month);
    return months;
  }

  /// True when the passport is inside the common six-month validity window.
  bool get passportNeedsAttention {
    final int? months = passportMonthsRemaining;
    return months != null && months <= 6;
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: '${json['id']}',
    fullName: json['full_name'] as String?,
    avatarPath: json['avatar_path'] as String?,
    phone: json['phone'] as String?,
    homeCountry: json['home_country'] as String?,
    residenceCountry: json['residence_country'] as String?,
    nationalityCountries: decodeStringList(json['nationality_countries']),
    passportCountry: json['passport_country'] as String?,
    passportExpiryDate: decodeDateOrNull(json['passport_expiry_date']),
    preferredCurrency:
        (json['preferred_currency'] as String?) ?? Currencies.defaultCode,
    preferredLanguage: (json['preferred_language'] as String?) ?? 'en',
    timezone: (json['timezone'] as String?) ?? 'UTC',
    dietaryPreferences: decodeStringList(json['dietary_preferences']),
    accessibilityNeeds: json['accessibility_needs'] as String?,
    travelInterests: decodeStringList(json['travel_interests']),
    travelStyle: json['travel_style'] == null
        ? null
        : TravelStyle.fromId(json['travel_style'] as String?),
    emergencyContactName: json['emergency_contact_name'] as String?,
    emergencyContactPhone: json['emergency_contact_phone'] as String?,
    emergencyContactEmail: json['emergency_contact_email'] as String?,
    notificationPreferences: decodeMap(json['notification_preferences']),
    onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    demoAccount: json['demo_account'] as bool? ?? false,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'full_name': fullName,
    'avatar_path': avatarPath,
    'phone': phone,
    'home_country': homeCountry,
    'residence_country': residenceCountry,
    'nationality_countries': nationalityCountries,
    'passport_country': passportCountry,
    'passport_expiry_date': passportExpiryDate == null
        ? null
        : _isoDate(passportExpiryDate!),
    'preferred_currency': preferredCurrency,
    'preferred_language': preferredLanguage,
    'timezone': timezone,
    'dietary_preferences': dietaryPreferences,
    'accessibility_needs': accessibilityNeeds,
    'travel_interests': travelInterests,
    'travel_style': travelStyle?.name,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
    'emergency_contact_email': emergencyContactEmail,
    'notification_preferences': notificationPreferences,
    'onboarding_completed': onboardingCompleted,
    'demo_account': demoAccount,
  };

  Profile copyWith({
    String? fullName,
    String? avatarPath,
    String? phone,
    String? homeCountry,
    String? residenceCountry,
    List<String>? nationalityCountries,
    String? passportCountry,
    DateTime? passportExpiryDate,
    bool clearPassportExpiry = false,
    String? preferredCurrency,
    String? preferredLanguage,
    String? timezone,
    List<String>? dietaryPreferences,
    String? accessibilityNeeds,
    List<String>? travelInterests,
    TravelStyle? travelStyle,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactEmail,
    Map<String, dynamic>? notificationPreferences,
    bool? onboardingCompleted,
  }) => Profile(
    id: id,
    fullName: fullName ?? this.fullName,
    avatarPath: avatarPath ?? this.avatarPath,
    phone: phone ?? this.phone,
    homeCountry: homeCountry ?? this.homeCountry,
    residenceCountry: residenceCountry ?? this.residenceCountry,
    nationalityCountries: nationalityCountries ?? this.nationalityCountries,
    passportCountry: passportCountry ?? this.passportCountry,
    passportExpiryDate: clearPassportExpiry
        ? null
        : (passportExpiryDate ?? this.passportExpiryDate),
    preferredCurrency: preferredCurrency ?? this.preferredCurrency,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    timezone: timezone ?? this.timezone,
    dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
    accessibilityNeeds: accessibilityNeeds ?? this.accessibilityNeeds,
    travelInterests: travelInterests ?? this.travelInterests,
    travelStyle: travelStyle ?? this.travelStyle,
    emergencyContactName: emergencyContactName ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    emergencyContactEmail: emergencyContactEmail ?? this.emergencyContactEmail,
    notificationPreferences:
        notificationPreferences ?? this.notificationPreferences,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    demoAccount: demoAccount,
  );

  @override
  String toString() => 'Profile($id, $fullName)';
}

@immutable
class TripDestination extends Model {
  const TripDestination({
    required this.id,
    required this.tripId,
    required this.position,
    required this.name,
    this.country,
    this.countryCode,
    this.city,
    this.latitude,
    this.longitude,
    this.timezone,
    this.arrivalDate,
    this.departureDate,
    this.notes,
  });

  final String id;
  final String tripId;
  final int position;
  final String name;
  final String? country;
  final String? countryCode;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? timezone;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String? notes;

  factory TripDestination.fromJson(Map<String, dynamic> json) =>
      TripDestination(
        id: '${json['id']}',
        tripId: '${json['trip_id']}',
        position: decodeInt(json['position']),
        name: json['name'] as String? ?? '',
        country: json['country'] as String?,
        countryCode: json['country_code'] as String?,
        city: json['city'] as String?,
        latitude: decodeDouble(json['latitude']),
        longitude: decodeDouble(json['longitude']),
        timezone: json['timezone'] as String?,
        arrivalDate: decodeDateOrNull(json['arrival_date']),
        departureDate: decodeDateOrNull(json['departure_date']),
        notes: json['notes'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'position': position,
    'name': name,
    'country': country,
    'country_code': countryCode,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'arrival_date': arrivalDate == null ? null : _isoDate(arrivalDate!),
    'departure_date': departureDate == null ? null : _isoDate(departureDate!),
    'notes': notes,
  };
}

@immutable
class Trip extends Model {
  const Trip({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.origin,
    this.countryCode,
    required this.startDate,
    required this.endDate,
    this.timezone,
    this.travelerCount = 1,
    this.baseCurrency = Currencies.defaultCode,
    this.totalBudgetMinor = 0,
    this.contingencyPct = 10,
    this.travelStyle = TravelStyle.balanced,
    this.travelPurpose,
    this.interests = const <String>[],
    this.transportPreferences = const <String>[],
    this.accommodationPreferences = const <String>[],
    this.dietaryNotes,
    this.accessibilityNotes,
    this.notes,
    this.coverImageUrl,
    this.status = TripStatus.planning,
    this.visibility = 'private',
    this.itineraryPace = ItineraryPace.balanced,
    this.archived = false,
    this.version = 1,
    this.myRole = TripRole.viewer,
    this.destinations = const <TripDestination>[],
    this.memberCount = 1,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? origin;
  final String? countryCode;
  final DateTime startDate;
  final DateTime endDate;
  final String? timezone;
  final int travelerCount;
  final String baseCurrency;
  final int totalBudgetMinor;
  final double contingencyPct;
  final TravelStyle travelStyle;
  final String? travelPurpose;
  final List<String> interests;
  final List<String> transportPreferences;
  final List<String> accommodationPreferences;
  final String? dietaryNotes;
  final String? accessibilityNotes;
  final String? notes;
  final String? coverImageUrl;
  final TripStatus status;
  final String visibility;
  final ItineraryPace itineraryPace;
  final bool archived;
  final int version;

  /// The signed-in user's role in this trip, resolved by the caller.
  final TripRole myRole;
  final List<TripDestination> destinations;
  final int memberCount;

  String get baseCurrencySymbol => Currencies.get(baseCurrency).symbol;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  int get daysUntilStart => startDate.difference(DateTime.now()).inDays;

  bool get isUpcoming => daysUntilStart > 0;

  bool get isOngoing {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return !today.isBefore(startDate) && !today.isAfter(endDate);
  }

  bool get isPast => endDate.isBefore(DateTime.now());

  /// Status derived from real dates unless the user has explicitly overridden
  /// it (draft, cancelled or archived all win).
  TripStatus get effectiveStatus {
    if (status == TripStatus.draft ||
        status == TripStatus.cancelled ||
        status == TripStatus.archived) {
      return status;
    }
    if (isOngoing) return TripStatus.ongoing;
    if (isUpcoming) return TripStatus.upcoming;
    return TripStatus.completed;
  }

  String get dateRangeLabel {
    final DateFormatRange range = DateFormatRange.of(startDate, endDate);
    return range.label;
  }

  String get destinationLabel {
    if (destinations.isNotEmpty) {
      return destinations.map((d) => d.name).join(' → ');
    }
    return countryCode ?? 'Destination not set';
  }

  /// Budget including the contingency reserve, in minor units.
  int get totalWithContingency =>
      totalBudgetMinor + (totalBudgetMinor * contingencyPct / 100).round();

  int get perTravelerBudgetMinor => travelerCount <= 0
      ? totalBudgetMinor
      : (totalBudgetMinor / travelerCount).round();

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: '${json['id']}',
    ownerId: '${json['owner_id']}',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    origin: json['origin'] as String?,
    countryCode: json['country_code'] as String?,
    startDate: decodeDate(json['start_date']),
    endDate: decodeDate(json['end_date']),
    timezone: json['timezone'] as String?,
    travelerCount: decodeInt(json['traveler_count'], 1),
    baseCurrency: (json['base_currency'] as String?) ?? Currencies.defaultCode,
    totalBudgetMinor: decodeInt(json['total_budget_minor']),
    contingencyPct: decodeDouble(json['contingency_pct'])?.toDouble() ?? 10,
    travelStyle: TravelStyle.fromId(json['travel_style'] as String?),
    travelPurpose: json['travel_purpose'] as String?,
    interests: decodeStringList(json['interests']),
    transportPreferences: decodeStringList(json['transport_preferences']),
    accommodationPreferences: decodeStringList(
      json['accommodation_preferences'],
    ),
    dietaryNotes: json['dietary_notes'] as String?,
    accessibilityNotes: json['accessibility_notes'] as String?,
    notes: json['notes'] as String?,
    coverImageUrl: json['cover_image_url'] as String?,
    status: TripStatus.fromId(json['status'] as String?),
    visibility: (json['visibility'] as String?) ?? 'private',
    itineraryPace: ItineraryPace.fromId(json['itinerary_pace'] as String?),
    archived: json['archived'] as bool? ?? false,
    version: decodeInt(json['version'], 1),
    myRole: TripRole.fromId(json['my_role'] as String?),
    destinations: ((json['trip_destinations'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TripDestination.fromJson)
        .toList(),
    memberCount: decodeInt(json['member_count'], 1),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'description': description,
    'origin': origin,
    'country_code': countryCode,
    'start_date': _isoDate(startDate),
    'end_date': _isoDate(endDate),
    'timezone': timezone,
    'traveler_count': travelerCount,
    'base_currency': baseCurrency,
    'total_budget_minor': totalBudgetMinor,
    'contingency_pct': contingencyPct,
    'travel_style': travelStyle.name,
    'travel_purpose': travelPurpose,
    'interests': interests,
    'transport_preferences': transportPreferences,
    'accommodation_preferences': accommodationPreferences,
    'dietary_notes': dietaryNotes,
    'accessibility_notes': accessibilityNotes,
    'notes': notes,
    'cover_image_url': coverImageUrl,
    'status': status.name,
    'visibility': visibility,
    'itinerary_pace': itineraryPace.name,
    'archived': archived,
    'version': version,
  };

  Trip copyWith({
    String? name,
    String? description,
    String? origin,
    String? countryCode,
    DateTime? startDate,
    DateTime? endDate,
    String? timezone,
    int? travelerCount,
    String? baseCurrency,
    int? totalBudgetMinor,
    double? contingencyPct,
    TravelStyle? travelStyle,
    String? travelPurpose,
    List<String>? interests,
    List<String>? transportPreferences,
    List<String>? accommodationPreferences,
    String? dietaryNotes,
    String? accessibilityNotes,
    String? notes,
    String? coverImageUrl,
    TripStatus? status,
    String? visibility,
    ItineraryPace? itineraryPace,
    bool? archived,
    TripRole? myRole,
    List<TripDestination>? destinations,
    int? memberCount,
  }) => Trip(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    description: description ?? this.description,
    origin: origin ?? this.origin,
    countryCode: countryCode ?? this.countryCode,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    timezone: timezone ?? this.timezone,
    travelerCount: travelerCount ?? this.travelerCount,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    totalBudgetMinor: totalBudgetMinor ?? this.totalBudgetMinor,
    contingencyPct: contingencyPct ?? this.contingencyPct,
    travelStyle: travelStyle ?? this.travelStyle,
    travelPurpose: travelPurpose ?? this.travelPurpose,
    interests: interests ?? this.interests,
    transportPreferences: transportPreferences ?? this.transportPreferences,
    accommodationPreferences:
        accommodationPreferences ?? this.accommodationPreferences,
    dietaryNotes: dietaryNotes ?? this.dietaryNotes,
    accessibilityNotes: accessibilityNotes ?? this.accessibilityNotes,
    notes: notes ?? this.notes,
    coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    status: status ?? this.status,
    visibility: visibility ?? this.visibility,
    itineraryPace: itineraryPace ?? this.itineraryPace,
    archived: archived ?? this.archived,
    version: version,
    myRole: myRole ?? this.myRole,
    destinations: destinations ?? this.destinations,
    memberCount: memberCount ?? this.memberCount,
  );
}

/// Small helper so `intl` formatting stays out of the model layer.
class DateFormatRange {
  const DateFormatRange(this.start, this.end, this.label);

  final DateTime start;
  final DateTime end;
  final String label;

  static DateFormatRange of(DateTime start, DateTime end) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String fmt(DateTime d) => '${d.day} ${months[d.month - 1]}';
    if (start.year == end.year) {
      if (start.month == end.month) {
        return DateFormatRange(
          start,
          end,
          '${start.day}–${fmt(end)} ${end.year}',
        );
      }
      return DateFormatRange(
        start,
        end,
        '${fmt(start)} – ${fmt(end)} ${end.year}',
      );
    }
    return DateFormatRange(
      start,
      end,
      '${fmt(start)} ${start.year} – ${fmt(end)} ${end.year}',
    );
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
