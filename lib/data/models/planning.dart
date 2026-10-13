import 'package:flutter/foundation.dart';

import '../../core/money/currency.dart';
import 'expense.dart';
import 'model.dart';

@immutable
class BudgetCategoryAllocation extends Model {
  const BudgetCategoryAllocation({
    required this.id,
    required this.category,
    required this.plannedMinor,
    this.actualMinor = 0,
    this.isEssential = false,
    this.notes,
  });

  final String id;
  final ExpenseCategory category;
  final int plannedMinor;

  /// Actual spending, resolved server-side in `budget_summary()`.
  final int actualMinor;
  final bool isEssential;
  final String? notes;

  int get remainingMinor => plannedMinor - actualMinor;

  bool get isOverBudget => actualMinor > plannedMinor && plannedMinor > 0;

  double get utilisation =>
      plannedMinor <= 0 ? 0 : (actualMinor / plannedMinor).clamp(0.0, 1.0);

  bool get isApproachingLimit => !isOverBudget && utilisation >= 0.8;

  factory BudgetCategoryAllocation.fromJson(Map<String, dynamic> json) =>
      BudgetCategoryAllocation(
        id: '${json['id'] ?? json['category']}',
        category: ExpenseCategory.fromId(json['category'] as String?),
        plannedMinor: decodeInt(json['planned_minor']),
        actualMinor: decodeInt(json['actual_minor']),
        isEssential: json['is_essential'] as bool? ?? false,
        notes: json['notes'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category.id,
    'planned_minor': plannedMinor,
    'actual_minor': actualMinor,
    'is_essential': isEssential,
    'notes': notes,
  };

  BudgetCategoryAllocation copyWith({int? plannedMinor, bool? isEssential}) =>
      BudgetCategoryAllocation(
        id: id,
        category: category,
        plannedMinor: plannedMinor ?? this.plannedMinor,
        actualMinor: actualMinor,
        isEssential: isEssential ?? this.isEssential,
        notes: notes,
      );
}

@immutable
class Budget extends Model {
  const Budget({
    required this.id,
    required this.tripId,
    required this.currency,
    required this.totalMinor,
    this.contingencyMinor = 0,
    this.dailyLimitMinor = 0,
    this.alertThresholdPct = 80,
    this.notes,
    this.categories = const <BudgetCategoryAllocation>[],
    this.dayCount = 1,
    this.remainingDays,
  });

  int get allocatedMinor =>
      categories.fold<int>(0, (sum, c) => sum + c.plannedMinor);

  int get unallocatedMinor => totalMinor - allocatedMinor;

  int get totalWithContingency => totalMinor + contingencyMinor;

  int get spentMinor =>
      categories.fold<int>(0, (sum, c) => sum + c.actualMinor);

  int get remainingMinor => totalMinor - spentMinor;

  double get utilisation =>
      totalMinor <= 0 ? 0 : (spentMinor / totalMinor).clamp(0.0, 99.0);

  bool get isOverBudget => spentMinor > totalMinor;

  bool get isApproachingLimit =>
      !isOverBudget &&
      totalMinor > 0 &&
      spentMinor / totalMinor * 100 >= alertThresholdPct;

  final String id;
  final String tripId;
  final String currency;
  final int totalMinor;
  final int contingencyMinor;
  final int dailyLimitMinor;
  final double alertThresholdPct;
  final String? notes;
  final List<BudgetCategoryAllocation> categories;
  final int dayCount;

  /// Days left in the trip, used for the remaining-days daily allowance.
  final int? remainingDays;

  int get daysRemaining {
    final int? days = remainingDays;
    if (days == null) return dayCount;
    return days < 1 ? 1 : days;
  }

  /// Daily spend allowance for the rest of the trip, floored at zero.
  int get safeDailySpendMinor {
    if (remainingMinor <= 0) return 0;
    return (remainingMinor / daysRemaining).floor();
  }

  /// Daily allowance implied by the plan rather than by what has been spent.
  int get plannedDailyMinor =>
      dayCount <= 0 ? totalMinor : (totalMinor / dayCount).floor();

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    List<BudgetCategoryAllocation> categories =
        const <BudgetCategoryAllocation>[],
    int dayCount = 1,
    int? remainingDays,
  }) => Budget(
    id: '${json['id']}',
    tripId: '${json['trip_id']}',
    currency: (json['currency'] as String?) ?? Currencies.defaultCode,
    totalMinor: decodeInt(json['total_minor']),
    contingencyMinor: decodeInt(json['contingency_minor']),
    dailyLimitMinor: decodeInt(json['daily_limit_minor']),
    alertThresholdPct:
        decodeDouble(json['alert_threshold_pct'])?.toDouble() ?? 80,
    notes: json['notes'] as String?,
    categories: categories,
    dayCount: dayCount,
    remainingDays: remainingDays,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'currency': currency,
    'total_minor': totalMinor,
    'contingency_minor': contingencyMinor,
    'daily_limit_minor': dailyLimitMinor,
    'alert_threshold_pct': alertThresholdPct,
    'notes': notes,
  };
}

enum ItineraryItemKind {
  attraction('attraction', 'Attraction', '🏛️'),
  restaurant('restaurant', 'Restaurant', '🍽️'),
  experience('experience', 'Experience', '🎟️'),
  accommodation('accommodation', 'Stay', '🏨'),
  transport('transport', 'Transport', '🚆'),
  flight('flight', 'Flight', '✈️'),
  freeTime('free_time', 'Free time', '☕'),
  other('other', 'Other', '📌');

  const ItineraryItemKind(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  static ItineraryItemKind fromId(String? id) => ItineraryItemKind.values
      .firstWhere((k) => k.id == id, orElse: () => ItineraryItemKind.other);
}

@immutable
class ItineraryItem extends Model {
  const ItineraryItem({
    required this.id,
    required this.tripId,
    required this.dayId,
    required this.title,
    this.kind = ItineraryItemKind.other,
    this.description,
    this.startTime,
    this.endTime,
    this.address,
    this.latitude,
    this.longitude,
    this.placeId,
    this.costMinor = 0,
    this.costCurrency = Currencies.defaultCode,
    this.bookingUrl,
    this.bookingReference,
    this.openingHoursVerified = false,
    this.openingHoursSourceUrl,
    this.completed = false,
    this.position = 0,
  });

  final String id;
  final String tripId;
  final String dayId;
  final String title;
  final ItineraryItemKind kind;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final int costMinor;
  final String costCurrency;
  final String? bookingUrl;
  final String? bookingReference;
  final bool openingHoursVerified;
  final String? openingHoursSourceUrl;
  final bool completed;
  final int position;

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasTime => startTime != null && endTime != null;

  Duration? get duration => hasTime ? endTime!.difference(startTime!) : null;

  /// True when the item's window runs past midnight, which is almost always a
  /// data-entry mistake rather than a real plan.
  bool get crossesMidnight =>
      hasTime &&
      (endTime!.isBefore(startTime!) || endTime!.day != startTime!.day);

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? raw) {
      if (raw == null) return null;
      final String value = '$raw';
      if (value.length < 5) return null;
      return DateTime.tryParse(
        value.contains(':') && !value.contains('-') && value.length <= 5
            ? '2000-01-01T$value'
            : value,
      );
    }

    return ItineraryItem(
      id: '${json['id']}',
      tripId: '${json['trip_id']}',
      dayId: '${json['day_id']}',
      title: json['title'] as String? ?? '',
      kind: ItineraryItemKind.fromId(json['kind'] as String?),
      description: json['description'] as String?,
      startTime: time(json['start_time']),
      endTime: time(json['end_time']),
      address: json['address'] as String?,
      latitude: decodeDouble(json['latitude']),
      longitude: decodeDouble(json['longitude']),
      placeId: json['place_id'] as String?,
      costMinor: decodeInt(json['cost_minor']),
      costCurrency:
          (json['cost_currency'] as String?) ?? Currencies.defaultCode,
      bookingUrl: json['booking_url'] as String?,
      bookingReference: json['booking_reference'] as String?,
      openingHoursVerified: json['opening_hours_verified'] as bool? ?? false,
      openingHoursSourceUrl: json['opening_hours_source_url'] as String?,
      completed: json['completed'] as bool? ?? false,
      position: decodeInt(json['position']),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'day_id': dayId,
    'title': title,
    'kind': kind.id,
    'description': description,
    'start_time': _hhmm(startTime),
    'end_time': _hhmm(endTime),
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'place_id': placeId,
    'cost_minor': costMinor,
    'cost_currency': costCurrency,
    'booking_url': bookingUrl,
    'booking_reference': bookingReference,
    'opening_hours_verified': openingHoursVerified,
    'opening_hours_source_url': openingHoursSourceUrl,
    'completed': completed,
    'position': position,
  };

  ItineraryItem copyWith({
    String? title,
    ItineraryItemKind? kind,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? address,
    double? latitude,
    double? longitude,
    int? costMinor,
    String? costCurrency,
    String? bookingUrl,
    String? bookingReference,
    bool? completed,
    int? position,
  }) => ItineraryItem(
    id: id,
    tripId: tripId,
    dayId: dayId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    placeId: placeId,
    costMinor: costMinor ?? this.costMinor,
    costCurrency: costCurrency ?? this.costCurrency,
    bookingUrl: bookingUrl ?? this.bookingUrl,
    bookingReference: bookingReference ?? this.bookingReference,
    openingHoursVerified: openingHoursVerified,
    openingHoursSourceUrl: openingHoursSourceUrl,
    completed: completed ?? this.completed,
    position: position ?? this.position,
  );
}

@immutable
class ItineraryDay extends Model {
  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.title,
    this.notes,
    this.position = 0,
    this.items = const <ItineraryItem>[],
  });

  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final String? title;
  final String? notes;
  final int position;
  final List<ItineraryItem> items;

  int get estimatedCostMinor =>
      items.fold<int>(0, (sum, item) => sum + item.costMinor);

  String get costCurrency =>
      items.isEmpty ? Currencies.defaultCode : items.first.costCurrency;

  bool get isToday {
    final DateTime now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isPast => date.isBefore(DateTime.now());

  /// Activities whose time windows overlap within this day.
  List<List<ItineraryItem>> get conflicts {
    final List<ItineraryItem> timed = items.where((i) => i.hasTime).toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    final List<List<ItineraryItem>> result = <List<ItineraryItem>>[];
    for (var i = 0; i < timed.length; i++) {
      for (var j = i + 1; j < timed.length; j++) {
        if (timed[j].startTime!.isBefore(timed[i].endTime!) &&
            timed[i].startTime!.isBefore(timed[j].endTime!)) {
          result.add(<ItineraryItem>[timed[i], timed[j]]);
        }
      }
    }
    return result;
  }

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
    id: '${json['id']}',
    tripId: '${json['trip_id']}',
    dayNumber: decodeInt(json['day_number'], 1),
    date: decodeDate(json['date']),
    title: json['title'] as String?,
    notes: json['notes'] as String?,
    position: decodeInt(json['position']),
    items: ((json['itinerary_items'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ItineraryItem.fromJson)
        .toList(),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'day_number': dayNumber,
    'date': _isoDate(date),
    'title': title,
    'notes': notes,
    'position': position,
  };

  ItineraryDay copyWith({
    String? title,
    String? notes,
    List<ItineraryItem>? items,
  }) => ItineraryDay(
    id: id,
    tripId: tripId,
    dayNumber: dayNumber,
    date: date,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    position: position,
    items: items ?? this.items,
  );
}

enum BookingKind {
  flight('flight', 'Flight', '✈️'),
  train('train', 'Train', '🚆'),
  bus('bus', 'Bus', '🚌'),
  hotel('hotel', 'Hotel', '🏨'),
  hostel('hostel', 'Hostel', '🎒'),
  rental('rental', 'Car rental', '🚗'),
  transfer('transfer', 'Transfer', '🚐'),
  tour('tour', 'Tour', '🎫'),
  restaurant('restaurant', 'Restaurant', '🍽️'),
  cruise('cruise', 'Cruise', '🛳️'),
  other('other', 'Other', '📌');

  const BookingKind(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;

  static BookingKind fromId(String? id) => BookingKind.values.firstWhere(
    (k) => k.id == id,
    orElse: () => BookingKind.other,
  );
}

enum BookingStatus {
  confirmed('confirmed', 'Confirmed'),
  pending('pending', 'Pending'),
  cancelled('cancelled', 'Cancelled'),
  refunded('refunded', 'Refunded'),
  completed('completed', 'Completed');

  const BookingStatus(this.id, this.label);
  final String id;
  final String label;

  static BookingStatus fromId(String? id) => BookingStatus.values.firstWhere(
    (s) => s.id == id,
    orElse: () => BookingStatus.confirmed,
  );
}

@immutable
class Booking extends Model {
  const Booking({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.provider,
    required this.title,
    this.confirmationReference,
    this.origin,
    this.destination,
    this.startsAt,
    this.endsAt,
    this.address,
    this.amountPaidMinor = 0,
    this.currency = Currencies.defaultCode,
    this.cancellationDeadline,
    this.status = BookingStatus.confirmed,
    this.externalUrl,
    this.attachmentPaths = const <String>[],
    this.notes,
  });

  final String id;
  final String tripId;
  final BookingKind kind;
  final String provider;
  final String title;
  final String? confirmationReference;
  final String? origin;
  final String? destination;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? address;
  final int amountPaidMinor;
  final String currency;
  final DateTime? cancellationDeadline;
  final BookingStatus status;
  final String? externalUrl;
  final List<String> attachmentPaths;
  final String? notes;

  int? get daysUntilCancellation {
    if (cancellationDeadline == null) return null;
    return cancellationDeadline!.difference(DateTime.now()).inDays;
  }

  bool get cancellationUrgent {
    final int? days = daysUntilCancellation;
    return days != null && days <= 3 && days >= 0;
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: '${json['id']}',
    tripId: '${json['trip_id']}',
    kind: BookingKind.fromId(json['kind'] as String?),
    provider: json['provider'] as String? ?? '',
    title: json['title'] as String? ?? '',
    confirmationReference: json['confirmation_reference'] as String?,
    origin: json['origin'] as String?,
    destination: json['destination'] as String?,
    startsAt: decodeDateTimeOrNull(json['starts_at']),
    endsAt: decodeDateTimeOrNull(json['ends_at']),
    address: json['address'] as String?,
    amountPaidMinor: decodeInt(json['amount_paid_minor']),
    currency: (json['currency'] as String?) ?? Currencies.defaultCode,
    cancellationDeadline: decodeDateTimeOrNull(json['cancellation_deadline']),
    status: BookingStatus.fromId(json['status'] as String?),
    externalUrl: json['external_url'] as String?,
    attachmentPaths: decodeStringList(json['attachment_paths']),
    notes: json['notes'] as String?,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'kind': kind.id,
    'provider': provider,
    'title': title,
    'confirmation_reference': confirmationReference,
    'origin': origin,
    'destination': destination,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'address': address,
    'amount_paid_minor': amountPaidMinor,
    'currency': currency,
    'cancellation_deadline': cancellationDeadline?.toUtc().toIso8601String(),
    'status': status.id,
    'external_url': externalUrl,
    'attachment_paths': attachmentPaths,
    'notes': notes,
  };
}

@immutable
class TravelDocument extends Model {
  const TravelDocument({
    required this.id,
    required this.userId,
    this.tripId,
    required this.name,
    this.docType = 'other',
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    this.sensitive = true,
    this.expiryDate,
    this.expiresAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? tripId;
  final String name;
  final String docType;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final bool sensitive;
  final DateTime? expiryDate;
  final DateTime? expiresAt;
  final String? notes;
  final DateTime? createdAt;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get expiryUrgent {
    final int? days = daysUntilExpiry;
    return days != null && days <= 30;
  }

  factory TravelDocument.fromJson(Map<String, dynamic> json) => TravelDocument(
    id: '${json['id']}',
    userId: '${json['user_id']}',
    tripId: json['trip_id'] as String?,
    name: json['name'] as String? ?? '',
    docType: (json['doc_type'] as String?) ?? 'other',
    storagePath: json['storage_path'] as String? ?? '',
    mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
    sizeBytes: decodeInt(json['size_bytes']),
    sensitive: json['sensitive'] as bool? ?? true,
    expiryDate: decodeDateOrNull(json['expiry_date']),
    expiresAt: decodeDateTimeOrNull(json['expires_at']),
    notes: json['notes'] as String?,
    createdAt: decodeDateTimeOrNull(json['created_at']),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'trip_id': tripId,
    'name': name,
    'doc_type': docType,
    'storage_path': storagePath,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'sensitive': sensitive,
    'expiry_date': expiryDate == null ? null : _isoDate(expiryDate!),
    'notes': notes,
  };
}

@immutable
class PackingItem extends Model {
  const PackingItem({
    required this.id,
    required this.label,
    this.category = 'other',
    this.quantity = 1,
    this.isPacked = false,
    this.assignedTo,
    this.notes,
    this.position = 0,
  });

  final String id;
  final String label;
  final String category;
  final int quantity;
  final bool isPacked;
  final String? assignedTo;
  final String? notes;
  final int position;

  PackingItem copyWith({bool? isPacked, String? assignedTo, int? quantity}) =>
      PackingItem(
        id: id,
        label: label,
        category: category,
        quantity: quantity ?? this.quantity,
        isPacked: isPacked ?? this.isPacked,
        assignedTo: assignedTo ?? this.assignedTo,
        notes: notes,
        position: position,
      );

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
    id: '${json['id']}',
    label: json['label'] as String? ?? '',
    category: (json['category'] as String?) ?? 'other',
    quantity: decodeInt(json['quantity'], 1),
    isPacked: json['is_packed'] as bool? ?? false,
    assignedTo: json['assigned_to'] as String?,
    notes: json['notes'] as String?,
    position: decodeInt(json['position']),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'category': category,
    'quantity': quantity,
    'is_packed': isPacked,
    'assigned_to': assignedTo,
    'notes': notes,
    'position': position,
  };
}

@immutable
class PackingList extends Model {
  const PackingList({
    required this.id,
    required this.ownerId,
    this.tripId,
    required this.name,
    this.kind = 'packing',
    this.isShared = true,
    this.isTemplate = false,
    this.items = const <PackingItem>[],
  });

  final String id;
  final String ownerId;
  final String? tripId;
  final String name;
  final String kind;
  final bool isShared;
  final bool isTemplate;
  final List<PackingItem> items;

  int get packedCount => items.where((i) => i.isPacked).length;

  double get completion => items.isEmpty ? 0 : packedCount / items.length;

  Map<String, List<PackingItem>> get byCategory {
    final Map<String, List<PackingItem>> map = <String, List<PackingItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.category, () => <PackingItem>[]).add(item);
    }
    return map;
  }

  factory PackingList.fromJson(Map<String, dynamic> json) => PackingList(
    id: '${json['id']}',
    ownerId: '${json['owner_id']}',
    tripId: json['trip_id'] as String?,
    name: json['name'] as String? ?? '',
    kind: (json['kind'] as String?) ?? 'packing',
    isShared: json['is_shared'] as bool? ?? true,
    isTemplate: json['is_template'] as bool? ?? false,
    items: ((json['packing_list_items'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PackingItem.fromJson)
        .toList(),
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'owner_id': ownerId,
    'trip_id': tripId,
    'name': name,
    'kind': kind,
    'is_shared': isShared,
    'is_template': isTemplate,
  };

  PackingList copyWith({List<PackingItem>? items}) => PackingList(
    id: id,
    ownerId: ownerId,
    tripId: tripId,
    name: name,
    kind: kind,
    isShared: isShared,
    isTemplate: isTemplate,
    items: items ?? this.items,
  );
}

@immutable
class InsurancePolicy extends Model {
  const InsurancePolicy({
    required this.id,
    required this.provider,
    this.tripId,
    this.policyReference,
    this.assistancePhone,
    this.coverageStart,
    this.coverageEnd,
    this.coverageNotes,
    this.documentPath,
  });

  final String id;
  final String provider;
  final String? tripId;
  final String? policyReference;
  final String? assistancePhone;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final String? coverageNotes;
  final String? documentPath;

  bool get isActive {
    final DateTime now = DateTime.now();
    if (coverageStart == null || coverageEnd == null) return false;
    return !now.isBefore(coverageStart!) && !now.isAfter(coverageEnd!);
  }

  factory InsurancePolicy.fromJson(Map<String, dynamic> json) =>
      InsurancePolicy(
        id: '${json['id']}',
        provider: json['provider'] as String? ?? '',
        tripId: json['trip_id'] as String?,
        policyReference: json['policy_reference'] as String?,
        assistancePhone: json['assistance_phone'] as String?,
        coverageStart: decodeDateOrNull(json['coverage_start']),
        coverageEnd: decodeDateOrNull(json['coverage_end']),
        coverageNotes: json['coverage_notes'] as String?,
        documentPath: json['document_path'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'provider': provider,
    'trip_id': tripId,
    'policy_reference': policyReference,
    'assistance_phone': assistancePhone,
    'coverage_start': coverageStart == null ? null : _isoDate(coverageStart!),
    'coverage_end': coverageEnd == null ? null : _isoDate(coverageEnd!),
    'coverage_notes': coverageNotes,
  };
}

String _hhmm(DateTime? time) {
  if (time == null) return '';
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
