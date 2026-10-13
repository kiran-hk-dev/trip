import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/money/currency.dart';
import 'model.dart';

enum NotificationKind {
  tripInvite('trip_invite', 'Invitations', '✉️'),
  tripUpdate('trip_update', 'Trip updates', '🧭'),
  expenseAdded('expense_added', 'Expenses', '💸'),
  budgetAlert('budget_alert', 'Budget alerts', '⚠️'),
  settlement('settlement', 'Settlements', '🤝'),
  departureReminder('departure_reminder', 'Departures', '✈️'),
  bookingReminder('booking_reminder', 'Bookings', '🎫'),
  documentReminder('document_reminder', 'Documents', '📄'),
  passportReminder('passport_reminder', 'Passport', '🛂'),
  visaReminder('visa_reminder', 'Visa', '📋'),
  packingReminder('packing_reminder', 'Packing', '🎒'),
  system('system', 'System', 'ℹ️');

  const NotificationKind(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  static NotificationKind fromId(String? id) => NotificationKind.values
      .firstWhere((k) => k.id == id, orElse: () => NotificationKind.system);
}

@immutable
class AppNotification extends Model {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.tripId,
    this.payload = const <String, dynamic>{},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String? body;
  final String? tripId;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: '${json['id']}',
        kind: NotificationKind.fromId(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        tripId: json['trip_id'] as String?,
        payload: decodeMap(json['payload']),
        readAt: decodeDateTimeOrNull(json['read_at']),
        createdAt: decodeDateTimeOrNull(json['created_at']) ?? DateTime.now(),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.id,
    'title': title,
    'body': body,
    'trip_id': tripId,
    'payload': payload,
    'read_at': readAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

@immutable
class ActivityLog extends Model {
  const ActivityLog({
    required this.id,
    this.tripId,
    this.userId,
    required this.entityType,
    this.entityId,
    required this.action,
    required this.summary,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    this.actorName,
  });

  final String id;
  final String? tripId;
  final String? userId;
  final String entityType;
  final String? entityId;
  final String action;
  final String summary;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? actorName;

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
    id: '${json['id']}',
    tripId: json['trip_id'] as String?,
    userId: json['user_id'] as String?,
    entityType: json['entity_type'] as String? ?? '',
    entityId: json['entity_id'] as String?,
    action: json['action'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    metadata: decodeMap(json['metadata']),
    createdAt: decodeDateTimeOrNull(json['created_at']) ?? DateTime.now(),
    actorName:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'user_id': userId,
    'entity_type': entityType,
    'action': action,
    'summary': summary,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

@immutable
class ConversionRecord {
  const ConversionRecord({
    required this.from,
    required this.to,
    required this.inputMinor,
    required this.outputMinor,
    required this.rate,
    required this.provider,
    required this.isIndicative,
    required this.isOfflineCached,
    required this.createdAt,
  });

  final String from;
  final String to;
  final int inputMinor;
  final int outputMinor;
  final double rate;
  final String provider;
  final bool isIndicative;
  final bool isOfflineCached;
  final DateTime createdAt;

  factory ConversionRecord.fromJson(Map<String, dynamic> json) =>
      ConversionRecord(
        from: (json['from_currency'] as String?) ?? '',
        to: (json['to_currency'] as String?) ?? '',
        inputMinor: decodeInt(json['input_minor']),
        outputMinor: decodeInt(json['output_minor']),
        rate: decodeDouble(json['rate'])?.toDouble() ?? 1,
        provider: json['provider'] as String? ?? '',
        isIndicative: json['is_indicative'] as bool? ?? true,
        isOfflineCached: json['is_offline_cached'] as bool? ?? false,
        createdAt: decodeDateTimeOrNull(json['created_at']) ?? DateTime.now(),
      );
}

/// A cached exchange rate plus the provenance the UI needs to be honest about
/// it. Never present a stale rate as live.
@immutable
class CachedRate {
  const CachedRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.provider,
    required this.fetchedAt,
    this.isIndicative = true,
    this.isStale = false,
  });

  final String base;
  final String quote;
  final double rate;
  final String provider;
  final DateTime fetchedAt;
  final bool isIndicative;
  final bool isStale;

  Duration get age => DateTime.now().difference(fetchedAt);

  /// A rate of 1 against itself, used when no conversion is required.
  static CachedRate identity(String code) => CachedRate(
    base: code,
    quote: code,
    rate: 1,
    provider: 'identity',
    fetchedAt: DateTime.now(),
  );

  String get ageLabel {
    final Duration d = age;
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  /// Cached in SharedPreferences so the converter still works with no signal.
  Map<String, dynamic> toCache() => <String, dynamic>{
    'base': base,
    'quote': quote,
    'rate': rate,
    'provider': provider,
    'fetched_at': fetchedAt.toIso8601String(),
    'is_indicative': isIndicative,
    'is_stale': isStale,
  };

  factory CachedRate.fromCache(Map<String, dynamic> json) => CachedRate(
    base: json['base'] as String? ?? '',
    quote: json['quote'] as String? ?? '',
    rate: (json['rate'] as num?)?.toDouble() ?? 1,
    provider: json['provider'] as String? ?? 'cache',
    fetchedAt:
        DateTime.tryParse(json['fetched_at'] as String? ?? '') ??
        DateTime.now(),
    isIndicative: json['is_indicative'] as bool? ?? true,
    isStale: json['is_stale'] as bool? ?? false,
  );

  Money convert(Money amount) {
    if (amount.currencyCode == quote) return amount;
    return Money.fromDecimal(
      amount.major * Decimal.parse(rate.toString()),
      quote,
    );
  }
}

/// Aggregated figures for the home dashboard, computed from real records.
@immutable
class DashboardSummary {
  const DashboardSummary({
    this.nextTripId,
    this.plannedBudgetMinor = 0,
    this.spentMinor = 0,
    this.currency = Currencies.defaultCode,
    this.owedToMeMinor = 0,
    this.iOweMinor = 0,
    this.isDemo = false,
  });

  final String? nextTripId;
  final int plannedBudgetMinor;
  final int spentMinor;
  final String currency;
  final int owedToMeMinor;
  final int iOweMinor;
  final bool isDemo;

  int get remainingMinor => plannedBudgetMinor - spentMinor;

  double get utilisation => plannedBudgetMinor <= 0
      ? 0
      : (spentMinor / plannedBudgetMinor).clamp(0.0, 9.0);

  bool get isOverBudget =>
      spentMinor > plannedBudgetMinor && plannedBudgetMinor > 0;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        nextTripId: json['next_trip_id'] as String?,
        plannedBudgetMinor: decodeInt(json['planned_budget_minor']),
        spentMinor: decodeInt(json['spent_minor']),
        currency: (json['currency'] as String?) ?? Currencies.defaultCode,
        owedToMeMinor: decodeInt(json['owed_to_me_minor']),
        iOweMinor: decodeInt(json['i_owe_minor']),
      );

  static const DashboardSummary empty = DashboardSummary();
}

/// Category totals used by the reports charts.
@immutable
class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amountMinor,
    this.count = 0,
  });

  final String category;
  final int amountMinor;
  final int count;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) => CategoryTotal(
    category: json['category'] as String? ?? '',
    amountMinor: decodeInt(json['amount_minor']),
    count: decodeInt(json['count']),
  );
}

/// Daily spend series for the reports chart.
@immutable
class DailyTotal {
  const DailyTotal({required this.date, required this.amountMinor});

  final DateTime date;
  final int amountMinor;

  factory DailyTotal.fromJson(Map<String, dynamic> json) => DailyTotal(
    date: decodeDate(json['day'] ?? json['date']),
    amountMinor: decodeInt(json['amount_minor']),
  );
}

/// Per-traveler cost breakdown.
@immutable
class TravelerTotal {
  const TravelerTotal({
    required this.userId,
    required this.name,
    required this.paidMinor,
    required this.shareMinor,
    required this.netMinor,
  });

  final String userId;
  final String name;
  final int paidMinor;
  final int shareMinor;
  final int netMinor;

  factory TravelerTotal.fromJson(Map<String, dynamic> json) => TravelerTotal(
    userId: '${json['user_id']}',
    name: (json['full_name'] as String?) ?? 'Traveller',
    paidMinor: decodeInt(json['paid_minor']),
    shareMinor: decodeInt(json['share_minor']),
    netMinor: decodeInt(json['net_minor']),
  );
}
