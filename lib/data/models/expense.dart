import 'package:flutter/foundation.dart';

import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import 'model.dart';
import 'trip.dart';

/// Mirrors the Postgres `expense_category` enum.
enum ExpenseCategory {
  flights('flights', 'Flights', '✈️'),
  groundTransport('ground_transport', 'Trains & buses', '🚆'),
  accommodation('accommodation', 'Accommodation', '🏨'),
  food('food', 'Food & drinks', '🍜'),
  localTransport('local_transport', 'Local transport', '🚇'),
  activities('activities', 'Activities', '🎟️'),
  shopping('shopping', 'Shopping', '🛍️'),
  visaFees('visa_fees', 'Visa & fees', '📄'),
  insurance('insurance', 'Insurance', '🛡️'),
  connectivity('connectivity', 'SIM & connectivity', '📶'),
  airportTransfer('airport_transfer', 'Airport transfer', '🧳'),
  medical('medical', 'Medical reserve', '⚕️'),
  other('other', 'Other', '📦');

  const ExpenseCategory(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  static ExpenseCategory fromId(String? id) => ExpenseCategory.values
      .firstWhere((c) => c.id == id, orElse: () => ExpenseCategory.other);

  /// Categories that cannot reasonably be avoided on an international trip.
  bool get isEssential => const <ExpenseCategory>{
    ExpenseCategory.flights,
    ExpenseCategory.accommodation,
    ExpenseCategory.insurance,
    ExpenseCategory.visaFees,
    ExpenseCategory.medical,
  }.contains(this);
}

/// A trip member, as seen by the signed-in user.
@immutable
class TripMember extends Model {
  const TripMember({
    required this.userId,
    required this.tripId,
    this.role = TripRole.viewer,
    this.fullName,
    this.email,
    this.avatarPath,
    this.joinedAt,
    this.status = 'active',
  });

  final String userId;
  final String tripId;
  final TripRole role;
  final String? fullName;
  final String? email;
  final String? avatarPath;
  final DateTime? joinedAt;
  final String status;

  String get displayName {
    final String? name = fullName?.trim();
    if (name == null || name.isEmpty) return email ?? 'Traveller';
    return name;
  }

  String get initials {
    final String name = (fullName ?? '').trim();
    if (name.isEmpty) return '?';
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory TripMember.fromJson(Map<String, dynamic> json) {
    final Object? profile = json['profiles'];
    final Map<String, dynamic> p = profile is Map<String, dynamic>
        ? profile
        : const <String, dynamic>{};
    return TripMember(
      userId: '${json['user_id']}',
      tripId: '${json['trip_id']}',
      role: TripRole.fromId(json['role'] as String?),
      fullName: p['full_name'] as String?,
      avatarPath: p['avatar_path'] as String?,
      joinedAt: decodeDateTimeOrNull(json['joined_at']),
      status: (json['status'] as String?) ?? 'active',
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'trip_id': tripId,
    'role': role.name,
    'status': status,
  };
}

@immutable
class ExpenseShareEntry extends Model {
  const ExpenseShareEntry({
    required this.userId,
    required this.amountMinor,
    required this.baseAmountMinor,
    this.percentage,
    this.weight,
    this.fullName,
  });

  final String userId;
  final int amountMinor;
  final int baseAmountMinor;
  final double? percentage;
  final int? weight;
  final String? fullName;

  factory ExpenseShareEntry.fromJson(Map<String, dynamic> json) =>
      ExpenseShareEntry(
        userId: '${json['user_id']}',
        amountMinor: decodeInt(json['amount_minor']),
        baseAmountMinor: decodeInt(json['base_amount_minor']),
        percentage: decodeDouble(json['percentage']),
        weight: json['weight'] == null ? null : decodeInt(json['weight']),
        fullName:
            (json['profiles'] as Map<String, dynamic>?)?['full_name']
                as String?,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'amount_minor': amountMinor,
    'base_amount_minor': baseAmountMinor,
    'percentage': percentage,
    'weight': weight,
  };
}

@immutable
class Expense extends Model {
  const Expense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amountMinor,
    required this.currency,
    required this.baseAmountMinor,
    this.fxRate = 1,
    this.fxProvider,
    this.fxFetchedAt,
    this.category = ExpenseCategory.other,
    required this.expenseDate,
    required this.paidBy,
    this.splitMethod = SplitMethod.equal,
    this.isPersonal = false,
    this.notes,
    this.receiptPath,
    this.participantIds = const <String>[],
    this.shares = const <ExpenseShareEntry>[],
    this.myShareMinor = 0,
    this.createdBy,
    this.createdAt,
    this.payerName,
    this.hasFxConversion = false,
  });

  final String id;
  final String tripId;
  final String title;
  final int amountMinor;
  final String currency;
  final int baseAmountMinor;
  final double fxRate;
  final String? fxProvider;
  final DateTime? fxFetchedAt;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final String paidBy;
  final SplitMethod splitMethod;
  final bool isPersonal;
  final String? notes;
  final String? receiptPath;
  final List<String> participantIds;
  final List<ExpenseShareEntry> shares;
  final int myShareMinor;
  final String? createdBy;
  final DateTime? createdAt;
  final String? payerName;
  final bool hasFxConversion;

  bool get hasReceipt => receiptPath != null && receiptPath!.isNotEmpty;

  /// True when the expense was recorded in a currency other than the trip's.
  bool get isForeignCurrency => hasFxConversion;

  /// The fx rate actually used, kept for audit. Never recomputed.
  String get fxRateLabel =>
      fxRate == 1 ? '' : '1 $currency = ${fxRate.toStringAsFixed(4)}';

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: '${json['id']}',
    tripId: '${json['trip_id']}',
    title: json['title'] as String? ?? '',
    amountMinor: decodeInt(json['amount_minor']),
    currency: (json['currency'] as String?) ?? Currencies.defaultCode,
    baseAmountMinor: decodeInt(json['base_amount_minor']),
    fxRate: decodeDouble(json['fx_rate'])?.toDouble() ?? 1,
    fxProvider: json['fx_provider'] as String?,
    fxFetchedAt: decodeDateTimeOrNull(json['fx_fetched_at']),
    category: ExpenseCategory.fromId(json['category'] as String?),
    expenseDate: decodeDate(json['expense_date']),
    paidBy: '${json['paid_by']}',
    splitMethod: SplitMethod.fromId(json['split_method'] as String?),
    isPersonal: json['is_personal'] as bool? ?? false,
    notes: json['notes'] as String?,
    receiptPath: json['receipt_path'] as String?,
    participantIds: decodeStringList(json['participant_ids']),
    shares: ((json['expense_shares'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ExpenseShareEntry.fromJson)
        .toList(),
    myShareMinor: decodeInt(json['my_share_minor']),
    createdBy: json['created_by'] as String?,
    createdAt: decodeDateTimeOrNull(json['created_at']),
    payerName:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
    hasFxConversion: (decodeDouble(json['fx_rate']) ?? 1) != 1,
  );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'title': title,
    'amount_minor': amountMinor,
    'currency': currency,
    'base_amount_minor': baseAmountMinor,
    'fx_rate': fxRate,
    'fx_provider': fxProvider,
    'category': category.id,
    'expense_date': _isoDate(expenseDate),
    'paid_by': paidBy,
    'split_method': splitMethod.id,
    'is_personal': isPersonal,
    'notes': notes,
    'receipt_path': receiptPath,
    'participant_ids': participantIds,
  };

  Expense copyWith({
    String? title,
    int? amountMinor,
    String? currency,
    int? baseAmountMinor,
    ExpenseCategory? category,
    DateTime? expenseDate,
    String? paidBy,
    List<String>? participantIds,
    List<ExpenseShareEntry>? shares,
    int? myShareMinor,
    String? notes,
    String? receiptPath,
  }) => Expense(
    id: id,
    tripId: tripId,
    title: title ?? this.title,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    baseAmountMinor: baseAmountMinor ?? this.baseAmountMinor,
    fxRate: fxRate,
    fxProvider: fxProvider,
    fxFetchedAt: fxFetchedAt,
    category: category ?? this.category,
    expenseDate: expenseDate ?? this.expenseDate,
    paidBy: paidBy ?? this.paidBy,
    splitMethod: splitMethod,
    isPersonal: isPersonal,
    notes: notes ?? this.notes,
    receiptPath: receiptPath ?? this.receiptPath,
    participantIds: participantIds ?? this.participantIds,
    shares: shares ?? this.shares,
    myShareMinor: myShareMinor ?? this.myShareMinor,
    createdBy: createdBy,
    createdAt: createdAt,
    payerName: payerName,
    hasFxConversion: hasFxConversion,
  );
}

/// Status semantics matter here: a settlement a user typed in is *recorded*,
/// never *verified*. Verification requires a provider-side webhook.
enum SettlementStatus {
  recorded,
  confirmed,
  disputed;

  static SettlementStatus fromId(String? id) => SettlementStatus.values
      .firstWhere((s) => s.name == id, orElse: () => SettlementStatus.recorded);

  String get label => switch (this) {
    SettlementStatus.recorded => 'Recorded',
    SettlementStatus.confirmed => 'Confirmed',
    SettlementStatus.disputed => 'Disputed',
  };

  String get explanation => switch (this) {
    SettlementStatus.recorded => 'Someone recorded that this payment happened. TripSplit has not verified it with a bank or payment provider.',
    SettlementStatus.confirmed => 'A payment provider confirmed this transfer.',
    SettlementStatus.disputed => 'Someone flagged this payment as incorrect.',
  };
}

enum SettlementMethod {
  cash('cash', 'Cash'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  upi('upi', 'UPI / instant'),
  card('card', 'Card'),
  other('other', 'Other');

  const SettlementMethod(this.id, this.label);
  final String id;
  final String label;

  static SettlementMethod fromId(String? id) => SettlementMethod.values
      .firstWhere((m) => m.id == id, orElse: () => SettlementMethod.other);
}

@immutable
class Settlement extends Model {
  const Settlement({
    required this.id,
    required this.tripId,
    required this.fromUserId,
    required this.toUserId,
    required this.amountMinor,
    required this.currency,
    required this.baseAmountMinor,
    this.fxRate = 1,
    this.fxProvider,
    this.status = SettlementStatus.recorded,
    this.method = SettlementMethod.other,
    this.reference,
    this.notes,
    required this.settledAt,
    this.verifiedAt,
    this.verifiedBy,
    this.createdAt,
    this.fromName,
    this.toName,
  });

  final String id;
  final String tripId;
  final String fromUserId;
  final String toUserId;
  final int amountMinor;
  final String currency;
  final int baseAmountMinor;
  final double fxRate;
  final String? fxProvider;
  final SettlementStatus status;
  final SettlementMethod method;
  final String? reference;
  final String? notes;
  final DateTime settledAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime? createdAt;
  final String? fromName;
  final String? toName;

  bool get isVerified => status == SettlementStatus.confirmed;

  factory Settlement.fromJson(Map<String, dynamic> json) {
    final Object? fromProfile = json['from_profile'];
    final Object? toProfile = json['to_profile'];
    return Settlement(
      id: '${json['id']}',
      tripId: '${json['trip_id']}',
      fromUserId: '${json['from_user_id']}',
      toUserId: '${json['to_user_id']}',
      amountMinor: decodeInt(json['amount_minor']),
      currency: (json['currency'] as String?) ?? Currencies.defaultCode,
      baseAmountMinor: decodeInt(json['base_amount_minor']),
      fxRate: decodeDouble(json['fx_rate'])?.toDouble() ?? 1,
      fxProvider: json['fx_provider'] as String?,
      status: SettlementStatus.fromId(json['status'] as String?),
      method: SettlementMethod.fromId(json['method'] as String?),
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      settledAt: decodeDate(json['settled_at']),
      verifiedAt: decodeDateTimeOrNull(json['verified_at']),
      verifiedBy: json['verified_by'] as String?,
      createdAt: decodeDateTimeOrNull(json['created_at']),
      fromName: fromProfile is Map<String, dynamic>
          ? fromProfile['full_name'] as String?
          : null,
      toName: toProfile is Map<String, dynamic>
          ? toProfile['full_name'] as String?
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trip_id': tripId,
    'from_user_id': fromUserId,
    'to_user_id': toUserId,
    'amount_minor': amountMinor,
    'currency': currency,
    'base_amount_minor': baseAmountMinor,
    'fx_rate': fxRate,
    'status': status.name,
    'method': method.id,
    'reference': reference,
    'notes': notes,
    'settled_at': _isoDate(settledAt),
  };
}

/// A recommended money movement produced by the settlement engine.
@immutable
class SuggestedTransfer {
  const SuggestedTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.currency,
    this.fromName,
    this.toName,
  });

  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final String currency;
  final String? fromName;
  final String? toName;

  factory SuggestedTransfer.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> names = const <String, String>{},
  }) => SuggestedTransfer(
    fromMemberId: '${json['from_user_id']}',
    toMemberId: '${json['to_user_id']}',
    amountMinor: decodeInt(json['amount_minor']),
    currency: (json['currency'] as String?) ?? Currencies.defaultCode,
    fromName: names[json['from_user_id'] as String],
    toName: names[json['to_user_id'] as String],
  );
}

@immutable
class ExpenseFilters {
  const ExpenseFilters({
    this.category,
    this.paidBy,
    this.participant,
    this.fromDate,
    this.toDate,
    this.search = '',
    this.sort = ExpenseSort.dateDesc,
    this.onlyMine = false,
    this.onlyOwedByMe = false,
    this.onlyOwedToMe = false,
  });

  final ExpenseCategory? category;
  final String? paidBy;
  final String? participant;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String search;
  final ExpenseSort sort;
  final bool onlyMine;
  final bool onlyOwedByMe;
  final bool onlyOwedToMe;

  bool get hasActiveFilter =>
      category != null ||
      paidBy != null ||
      participant != null ||
      fromDate != null ||
      toDate != null ||
      search.isNotEmpty ||
      onlyMine ||
      onlyOwedByMe ||
      onlyOwedToMe;

  int get activeCount => <bool>[
    category != null,
    paidBy != null,
    participant != null,
    fromDate != null || toDate != null,
    search.isNotEmpty,
    onlyMine,
    onlyOwedByMe,
    onlyOwedToMe,
  ].where((b) => b).length;

  ExpenseFilters copyWith({
    ExpenseCategory? category,
    bool clearCategory = false,
    String? paidBy,
    bool clearPaidBy = false,
    String? participant,
    bool clearParticipant = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    String? search,
    ExpenseSort? sort,
    bool? onlyMine,
    bool? onlyOwedByMe,
    bool? onlyOwedToMe,
  }) => ExpenseFilters(
    category: clearCategory ? null : (category ?? this.category),
    paidBy: clearPaidBy ? null : (paidBy ?? this.paidBy),
    participant: clearParticipant ? null : (participant ?? this.participant),
    fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
    toDate: clearToDate ? null : (toDate ?? this.toDate),
    search: search ?? this.search,
    sort: sort ?? this.sort,
    onlyMine: onlyMine ?? this.onlyMine,
    onlyOwedByMe: onlyOwedByMe ?? this.onlyOwedByMe,
    onlyOwedToMe: onlyOwedToMe ?? this.onlyOwedToMe,
  );

  ExpenseFilters cleared() => const ExpenseFilters();
}

enum ExpenseSort {
  dateDesc('date_desc', 'Newest first'),
  dateAsc('date_asc', 'Oldest first'),
  amountDesc('amount_desc', 'Largest first'),
  amountAsc('amount_asc', 'Smallest first'),
  category('category', 'By category');

  const ExpenseSort(this.id, this.label);
  final String id;
  final String label;
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
