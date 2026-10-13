import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money/currency.dart';
import '../core/money/split_engine.dart';
import 'models/expense.dart';
import 'models/misc.dart';
import 'models/model.dart';
import 'models/planning.dart';
import 'models/reference.dart';
import 'models/trip.dart';
import 'supabase_service.dart';

/// Reads and writes trips, members and destinations.
///
/// All list methods support a cached fallback: when the network is unavailable
/// the last known rows are returned with [TripListResult.isStale] set, so the
/// UI can show data and label it honestly instead of showing an error.
class TripRepository {
  TripRepository(this._service);

  final SupabaseService _service;
  LocalCache? _cache;

  Future<LocalCache> get _localCache async =>
      _cache ??= await LocalCache.open();

  SupabaseClient get _db => _service.client;

  static const String _cacheKey = 'trips';

  // -------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------

  Future<TripListResult> listTrips({bool includeArchived = false}) async {
    try {
      final String userId = _service.currentUserId ?? '';
      var query = _db
          .from('trips')
          .select(
            '*, trip_destinations(*), trip_members!trip_members_trip_id_fkey(user_id, role)',
          );
      if (!includeArchived) {
        query = query.eq('archived', false);
      }

      final List<Map<String, dynamic>> rows = await query.order(
        'start_date',
        ascending: false,
      );

      final List<Trip> trips = <Trip>[];
      for (final Map<String, dynamic> row in rows) {
        final List<dynamic> memberships =
            (row['trip_members'] as List?) ?? const <dynamic>[];
        Map<String, dynamic>? mine;
        for (final dynamic m in memberships) {
          if (m is Map<String, dynamic> && m['user_id'] == userId) {
            mine = m;
            break;
          }
        }
        trips.add(
          Trip.fromJson(<String, dynamic>{
            ...row,
            'my_role': mine?['role'],
            'member_count': memberships.length,
          }),
        );
      }

      await (await _localCache).putJson(
        _cacheKey,
        trips.map((t) => t.toJson()).toList(),
      );
      return TripListResult(trips: trips, isStale: false);
    } catch (err) {
      final List<Map<String, dynamic>> cached = (await _localCache).getJsonList(
        _cacheKey,
      );
      if (cached.isEmpty) {
        throw RepositoryException(_message(err), cause: err);
      }
      return TripListResult(
        trips: cached.map(Trip.fromJson).toList(),
        isStale: true,
        fetchedAt: (await _localCache).lastUpdated(_cacheKey),
      );
    }
  }

  Future<Trip?> getTrip(String tripId) async {
    try {
      final Map<String, dynamic> row = (await _db
          .from('trips')
          .select('*, trip_destinations(*)')
          .eq('id', tripId)
          .single());
      final String userId = _service.currentUserId ?? '';
      final List<Map<String, dynamic>> members = (await _db
          .from('trip_members')
          .select('user_id, role, profiles(full_name, avatar_path)')
          .eq('trip_id', tripId)
          .eq('status', 'active'));

      Map<String, dynamic>? mine;
      for (final Map<String, dynamic> m in members) {
        if (m['user_id'] == userId) {
          mine = m;
          break;
        }
      }

      return Trip.fromJson(<String, dynamic>{
        ...row,
        'my_role': mine?['role'] ?? 'viewer',
        'member_count': members.length,
      });
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<List<TripMember>> listMembers(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = await _db
          .from('trip_members')
          .select('*, profiles(full_name, avatar_path)')
          .eq('trip_id', tripId)
          .eq('status', 'active')
          .order('joined_at');
      return rows.map(TripMember.fromJson).toList();
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  // -------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------

  /// Creates a trip. The database trigger generates budget, itinerary days and
  /// the owner membership, so this is a single insert.
  Future<String> createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? origin,
    String? countryCode,
    String baseCurrency = Currencies.defaultCode,
    int travelerCount = 1,
    int totalBudgetMinor = 0,
    double contingencyPct = 10,
    TravelStyle travelStyle = TravelStyle.balanced,
    String? travelPurpose,
    List<String> interests = const <String>[],
    List<String> transportPreferences = const <String>[],
    List<String> accommodationPreferences = const <String>[],
    String? dietaryNotes,
    String? accessibilityNotes,
    String? notes,
    String? coverImageUrl,
    ItineraryPace itineraryPace = ItineraryPace.balanced,
    TripStatus status = TripStatus.planning,
    String visibility = 'private',
    List<TripDestinationDraft> destinations = const <TripDestinationDraft>[],
  }) async {
    try {
      final Map<String, dynamic> row = <String, dynamic>{
        'owner_id': _service.currentUserId,
        'name': name.trim(),
        'start_date': _isoDate(startDate),
        'end_date': _isoDate(endDate),
        'base_currency': baseCurrency,
        'traveler_count': travelerCount,
        'total_budget_minor': totalBudgetMinor,
        'contingency_pct': contingencyPct,
        'travel_style': travelStyle.name,
        'itinerary_pace': itineraryPace.name,
        'status': status.name,
        'visibility': visibility,
        'description': ?description,
        if (origin != null && origin.isNotEmpty) 'origin': origin,
        if (countryCode != null && countryCode.isNotEmpty)
          'country_code': countryCode,
        if (travelPurpose != null && travelPurpose.isNotEmpty)
          'travel_purpose': travelPurpose,
        if (interests.isNotEmpty) 'interests': interests,
        if (transportPreferences.isNotEmpty)
          'transport_preferences': transportPreferences,
        if (accommodationPreferences.isNotEmpty)
          'accommodation_preferences': accommodationPreferences,
        if (dietaryNotes != null && dietaryNotes.isNotEmpty)
          'dietary_notes': dietaryNotes,
        if (accessibilityNotes != null && accessibilityNotes.isNotEmpty)
          'accessibility_notes': accessibilityNotes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty)
          'cover_image_url': coverImageUrl,
      };

      final Map<String, dynamic> created = (await _db
          .from('trips')
          .insert(row)
          .select('id')
          .single());
      final String tripId = '${created['id']}';

      if (destinations.isNotEmpty) {
        await _db.from('trip_destinations').insert(<Map<String, dynamic>>[
          for (var i = 0; i < destinations.length; i++)
            <String, dynamic>{
              'trip_id': tripId,
              'position': i,
              'name': destinations[i].name,
              if (destinations[i].country != null)
                'country': destinations[i].country,
              if (destinations[i].countryCode != null)
                'country_code': destinations[i].countryCode,
              if (destinations[i].city != null) 'city': destinations[i].city,
              if (destinations[i].latitude != null)
                'latitude': destinations[i].latitude,
              if (destinations[i].longitude != null)
                'longitude': destinations[i].longitude,
              if (destinations[i].arrivalDate != null)
                'arrival_date': _isoDate(destinations[i].arrivalDate!),
            },
        ]);
      }

      return tripId;
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<void> updateTrip(String tripId, Map<String, dynamic> changes) async {
    try {
      await _db.from('trips').update(changes).eq('id', tripId);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<void> archiveTrip(String tripId, bool archived) async {
    await updateTrip(tripId, <String, dynamic>{
      'archived': archived,
      if (archived) 'status': TripStatus.archived.name,
    });
  }

  /// Copies a trip and its itinerary into a new draft trip.
  Future<String> duplicateTrip(String tripId, {String? newName}) async {
    final Trip? source = await getTrip(tripId);
    if (source == null) throw const RepositoryException('Trip not found.');

    final String newId = await createTrip(
      name: newName ?? '${source.name} (copy)',
      startDate: source.startDate,
      endDate: source.endDate,
      description: source.description,
      origin: source.origin,
      countryCode: source.countryCode,
      baseCurrency: source.baseCurrency,
      travelerCount: source.travelerCount,
      totalBudgetMinor: source.totalBudgetMinor,
      contingencyPct: source.contingencyPct,
      travelStyle: source.travelStyle,
      travelPurpose: source.travelPurpose,
      interests: source.interests,
      transportPreferences: source.transportPreferences,
      accommodationPreferences: source.accommodationPreferences,
      dietaryNotes: source.dietaryNotes,
      accessibilityNotes: source.accessibilityNotes,
      notes: source.notes,
      coverImageUrl: source.coverImageUrl,
      itineraryPace: source.itineraryPace,
      status: TripStatus.draft,
      destinations: source.destinations
          .map(
            (d) => TripDestinationDraft(
              name: d.name,
              country: d.country,
              countryCode: d.countryCode,
              city: d.city,
              latitude: d.latitude,
              longitude: d.longitude,
              arrivalDate: d.arrivalDate,
            ),
          )
          .toList(),
    );

    // Copy itinerary items day by day.
    final List<ItineraryDay> days = await itinerary.listDays(newId);
    final List<ItineraryDay> sourceDays = await itinerary.listDays(tripId);
    for (var d = 0; d < days.length && d < sourceDays.length; d++) {
      if (sourceDays[d].items.isEmpty) continue;
      await itinerary.replaceItems(days[d].id, sourceDays[d].items);
    }

    return newId;
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await _db.from('trips').delete().eq('id', tripId);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  // -------------------------------------------------------------------
  // Membership
  // -------------------------------------------------------------------

  Future<void> updateMemberRole(
    String tripId,
    String userId,
    TripRole role,
  ) async {
    try {
      await _db
          .from('trip_members')
          .update(<String, dynamic>{'role': role.name})
          .eq('trip_id', tripId)
          .eq('user_id', userId);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<void> removeMember(String tripId, String userId) async {
    try {
      await _db
          .from('trip_members')
          .update(<String, dynamic>{'status': 'removed'})
          .eq('trip_id', tripId)
          .eq('user_id', userId);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<void> leaveTrip(String tripId) async {
    await removeMember(tripId, _service.currentUserId ?? '');
  }

  /// Creates an invitation through the Edge Function, which emails the link
  /// and stores only a hash of the token.
  Future<InvitationResult> inviteMember({
    required String tripId,
    required String email,
    required TripRole role,
  }) async {
    final Map<String, dynamic> result = await _service.invokeFunction(
      'invitations',
      body: <String, dynamic>{
        'trip_id': tripId,
        'email': email,
        'role': role.name,
      },
    );
    return InvitationResult(
      link: result['invite_link'] as String? ?? '',
      emailSent: result['email_sent'] as bool? ?? false,
      emailNote: result['email_note'] as String?,
      expiresAt: DateTime.tryParse(result['expires_at'] as String? ?? ''),
    );
  }

  Future<void> revokeInvitation(String invitationId) async {
    try {
      await _db
          .from('trip_invitations')
          .update(<String, dynamic>{'status': 'revoked'})
          .eq('id', invitationId);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<List<InvitationSummary>> listInvitations(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('trip_invitations')
          .select(
            'id, invited_email, role, status, expires_at, created_at, accepted_at',
          )
          .eq('trip_id', tripId)
          .order('created_at', ascending: false));
      return rows.map(InvitationSummary.fromJson).toList();
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  // -------------------------------------------------------------------
  // Activity
  // -------------------------------------------------------------------

  Future<List<ActivityLog>> listActivity(
    String tripId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('activity_logs')
          .select('*, profiles(full_name)')
          .eq('trip_id', tripId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1));
      return rows.map(ActivityLog.fromJson).toList();
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  ItineraryRepository get itinerary => ItineraryRepository(_service);
  ExpenseRepository get expenses => ExpenseRepository(_service);
  BudgetRepository get budget => BudgetRepository(_service);
  BookingRepository get bookings => BookingRepository(_service);
  DocumentRepository get documents => DocumentRepository(_service);
  PackingRepository get packing => PackingRepository(_service);
  EmergencyRepository get emergency => EmergencyRepository(_service);
  ConverterRepository get converter => ConverterRepository(_service);
  NotificationRepository get notifications => NotificationRepository(_service);

  String _message(Object err) {
    if (err is RepositoryException) return err.message;
    final String text = '$err';
    if (text.contains('duplicate key')) return 'That record already exists.';
    if (text.contains('violates row-level security')) {
      return 'You do not have permission to do that.';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'No connection. Showing what was saved on this device.';
    }
    return 'Could not complete that. Please try again.';
  }
}

class TripListResult {
  const TripListResult({
    required this.trips,
    required this.isStale,
    this.fetchedAt,
  });

  final List<Trip> trips;
  final bool isStale;
  final DateTime? fetchedAt;
}

class TripDestinationDraft {
  const TripDestinationDraft({
    required this.name,
    this.country,
    this.countryCode,
    this.city,
    this.latitude,
    this.longitude,
    this.arrivalDate,
  });

  final String name;
  final String? country;
  final String? countryCode;
  final String? city;
  final double? latitude;
  final double? longitude;
  final DateTime? arrivalDate;
}

class InvitationResult {
  const InvitationResult({
    required this.link,
    required this.emailSent,
    this.emailNote,
    this.expiresAt,
  });

  final String link;
  final bool emailSent;
  final String? emailNote;
  final DateTime? expiresAt;
}

class InvitationSummary {
  const InvitationSummary({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.expiresAt,
    this.acceptedAt,
  });

  final String id;
  final String email;
  final TripRole role;
  final String status;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;

  bool get isPending => status == 'pending';
  bool get isExpired =>
      status == 'expired' || (expiresAt?.isBefore(DateTime.now()) ?? false);

  factory InvitationSummary.fromJson(Map<String, dynamic> json) =>
      InvitationSummary(
        id: '${json['id']}',
        email: json['invited_email'] as String? ?? '',
        role: TripRole.fromId(json['role'] as String?),
        status: json['status'] as String? ?? 'pending',
        expiresAt: decodeDateTimeOrNull(json['expires_at']),
        acceptedAt: decodeDateTimeOrNull(json['accepted_at']),
      );
}

/// Itinerary days and items.
class ItineraryRepository {
  ItineraryRepository(this._service);

  final SupabaseService _service;

  SupabaseClient get _db => _service.client;

  Future<List<ItineraryDay>> listDays(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('itinerary_days')
          .select('*, itinerary_items(*)')
          .eq('trip_id', tripId)
          .order('day_number'));
      final List<ItineraryDay> days = rows.map(ItineraryDay.fromJson).toList();
      for (final ItineraryDay day in days) {
        day.items.sort((a, b) => a.position.compareTo(b.position));
      }
      return days;
    } catch (err) {
      throw RepositoryException('Could not load the itinerary.', cause: err);
    }
  }

  Future<void> updateDay(String dayId, Map<String, dynamic> changes) async {
    try {
      await _db.from('itinerary_days').update(changes).eq('id', dayId);
    } catch (err) {
      throw RepositoryException('Could not update that day.', cause: err);
    }
  }

  Future<String> addItem(String dayId, Map<String, dynamic> item) async {
    try {
      final Map<String, dynamic> created = (await _db
          .from('itinerary_items')
          .insert(item)
          .select('id')
          .single());
      return '${created['id']}';
    } catch (err) {
      throw RepositoryException('Could not add that activity.', cause: err);
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> changes) async {
    try {
      await _db.from('itinerary_items').update(changes).eq('id', itemId);
    } catch (err) {
      throw RepositoryException('Could not update that activity.', cause: err);
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _db.from('itinerary_items').delete().eq('id', itemId);
    } catch (err) {
      throw RepositoryException('Could not delete that activity.', cause: err);
    }
  }

  /// Replaces a day's items with the supplied order in one transaction-safe
  /// sequence. Positions are contiguous so drag-and-drop stays stable.
  Future<void> reorderItems(String dayId, List<ItineraryItem> ordered) async {
    try {
      for (var i = 0; i < ordered.length; i++) {
        await _db
            .from('itinerary_items')
            .update(<String, dynamic>{'position': i})
            .eq('id', ordered[i].id);
      }
    } catch (err) {
      throw RepositoryException('Could not reorder activities.', cause: err);
    }
  }

  Future<void> replaceItems(String dayId, List<ItineraryItem> items) async {
    try {
      final List<Map<String, dynamic>> existing = (await _db
          .from('itinerary_items')
          .select('id')
          .eq('day_id', dayId));
      for (final Map<String, dynamic> row in existing) {
        await _db.from('itinerary_items').delete().eq('id', row['id']);
      }
      if (items.isEmpty) return;
      await _db.from('itinerary_items').insert(<Map<String, dynamic>>[
        for (var i = 0; i < items.length; i++)
          <String, dynamic>{
            ...items[i].toJson(),
            'id': null,
            'day_id': dayId,
            'position': i,
          },
      ]);
    } catch (err) {
      throw RepositoryException('Could not copy activities.', cause: err);
    }
  }

  Future<List<ItineraryItemConflict>> findConflicts(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db.rpc(
        'itinerary_conflicts',
        params: {'p_trip_id': tripId},
      ));
      return rows.map(ItineraryItemConflict.fromJson).toList();
    } catch (err) {
      // A conflict check failing must never break the itinerary screen.
      return const <ItineraryItemConflict>[];
    }
  }
}

class ItineraryItemConflict {
  const ItineraryItemConflict({
    required this.itemId,
    required this.otherItemId,
    required this.dayId,
    required this.overlapMinutes,
  });

  final String itemId;
  final String otherItemId;
  final String dayId;
  final int overlapMinutes;

  factory ItineraryItemConflict.fromJson(Map<String, dynamic> json) =>
      ItineraryItemConflict(
        itemId: '${json['item_id']}',
        otherItemId: '${json['other_item_id']}',
        dayId: '${json['day_id']}',
        overlapMinutes: decodeInt(json['overlap_minutes']),
      );
}

/// Expenses, balances and settlements.
class ExpenseRepository {
  ExpenseRepository(this._service);

  final SupabaseService _service;

  SupabaseClient get _db => _service.client;

  Future<ExpensePage> listExpenses(
    String tripId, {
    ExpenseFilters filters = const ExpenseFilters(),
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db.rpc(
        'list_trip_expenses',
        params: {
          'p_trip_id': tripId,
          'p_category': filters.category?.id,
          'p_paid_by': filters.paidBy,
          'p_participant': filters.participant,
          'p_from_date': filters.fromDate == null
              ? null
              : _isoDate(filters.fromDate!),
          'p_to_date': filters.toDate == null
              ? null
              : _isoDate(filters.toDate!),
          'p_search': filters.search.isEmpty ? null : filters.search,
          'p_limit': limit,
          'p_offset': offset,
          'p_sort': filters.sort.id,
        },
      ));

      List<Expense> expenses = rows.map(Expense.fromJson).toList();
      final String userId = _service.currentUserId ?? '';

      if (filters.onlyMine) {
        expenses = expenses.where((e) => e.myShareMinor > 0).toList();
      }
      if (filters.onlyOwedByMe) {
        expenses = expenses
            .where((e) => e.myShareMinor > 0 && e.paidBy != userId)
            .toList();
      }
      if (filters.onlyOwedToMe) {
        expenses = expenses
            .where((e) => e.paidBy == userId && e.myShareMinor == 0)
            .toList();
      }

      return ExpensePage(expenses: expenses, offset: offset, limit: limit);
    } catch (err) {
      throw RepositoryException('Could not load expenses.', cause: err);
    }
  }

  Future<Expense?> getExpense(String expenseId) async {
    try {
      final Map<String, dynamic> row =
          (await _db
              .from('expenses')
              .select(
                '*, expense_shares(*, profiles(full_name)), profiles(full_name)',
              )
              .eq('id', expenseId)
              .maybeSingle() ??
          {});
      if (row.isEmpty) return null;
      return Expense.fromJson(row);
    } catch (err) {
      throw RepositoryException('Could not load that expense.', cause: err);
    }
  }

  /// Creates an expense. The database computes every share; nothing about the
  /// split is trusted from the client beyond the user's stated intent.
  Future<String> createExpense({
    required String tripId,
    required String title,
    required int amountMinor,
    required String currency,
    required ExpenseCategory category,
    required DateTime expenseDate,
    required String paidBy,
    required SplitMethod splitMethod,
    required List<String> participantIds,
    Map<String, int> exactAmounts = const <String, int>{},
    Map<String, double> percentages = const <String, double>{},
    Map<String, int> weights = const <String, int>{},
    bool isPersonal = false,
    String? notes,
    String? receiptPath,
    int? baseAmountMinor,
    double? fxRate,
    String? fxProvider,
  }) async {
    try {
      final Map<String, dynamic> result = (await _db.rpc(
        'create_expense',
        params: {
          'p_trip_id': tripId,
          'p_title': title,
          'p_amount_minor': amountMinor,
          'p_currency': currency,
          'p_category': category.id,
          'p_expense_date': _isoDate(expenseDate),
          'p_paid_by': paidBy,
          'p_split_method': isPersonal ? 'none' : splitMethod.id,
          'p_participants': participantIds,
          'p_shares': exactAmounts.isEmpty ? null : exactAmounts,
          'p_percentages': percentages.isEmpty ? null : percentages,
          'p_weights': weights.isEmpty ? null : weights,
          'p_is_personal': isPersonal,
          'p_notes': notes,
          'p_receipt_path': receiptPath,
          'p_base_amount_minor': baseAmountMinor,
          'p_fx_rate': fxRate,
          'p_fx_provider': fxProvider,
        },
      )) as Map<String, dynamic>;

      return '${result['id']}';
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  /// Edits an expense. Financial fields are re-split server-side, so the
  /// result is always consistent with the new inputs.
  Future<String> updateExpense({
    required String expenseId,
    String? title,
    int? amountMinor,
    String? currency,
    int? baseAmountMinor,
    double? fxRate,
    String? fxProvider,
    ExpenseCategory? category,
    DateTime? expenseDate,
    String? paidBy,
    List<String>? participantIds,
    Map<String, int>? exactAmounts,
    Map<String, double>? percentages,
    Map<String, int>? weights,
    String? notes,
    String? receiptPath,
  }) async {
    try {
      final Map<String, dynamic> result = (await _db.rpc(
        'update_expense',
        params: {
          'p_expense_id': expenseId,
          'p_title': title,
          'p_amount_minor': amountMinor,
          'p_currency': currency,
          'p_base_amount_minor': baseAmountMinor,
          'p_fx_rate': fxRate,
          'p_fx_provider': fxProvider,
          'p_category': category?.id,
          'p_expense_date': expenseDate == null ? null : _isoDate(expenseDate),
          'p_paid_by': paidBy,
          'p_participants': participantIds,
          'p_shares': (exactAmounts?.isEmpty ?? true) ? null : exactAmounts,
          'p_percentages': (percentages?.isEmpty ?? true) ? null : percentages,
          'p_weights': (weights?.isEmpty ?? true) ? null : weights,
          'p_notes': notes,
          'p_receipt_path': receiptPath,
        },
      )) as Map<String, dynamic>;

      final Object? id = result['id'];
      return id == null ? expenseId : '$id';
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _db.rpc('delete_expense', params: {'p_expense_id': expenseId});
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  /// Live balances straight from the database. This is the authoritative
  /// figure; the client recomputes the same numbers only for offline display.
  Future<List<MemberBalance>> balances(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db.rpc(
        'trip_balances',
        params: {'p_trip_id': tripId},
      ));
      return rows
          .map(
            (r) => MemberBalance(
              memberId: '${r['user_id']}',
              paidMinor: decodeInt(r['paid_minor']),
              owesMinor: decodeInt(r['share_minor']),
              settledInMinor: decodeInt(r['settled_in_minor']),
              settledOutMinor: decodeInt(r['settled_out_minor']),
              currencyCode:
                  (r['currency'] as String?) ?? Currencies.defaultCode,
            ),
          )
          .toList();
    } catch (err) {
      throw RepositoryException('Could not load balances.', cause: err);
    }
  }

  Future<List<SettlementTransfer>> suggestedSettlements(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db.rpc(
        'suggest_settlements',
        params: {'p_trip_id': tripId},
      ));
      return rows
          .map(
            (r) => SettlementTransfer(
              fromMemberId: '${r['from_user_id']}',
              toMemberId: '${r['to_user_id']}',
              amountMinor: decodeInt(r['amount_minor']),
              currencyCode:
                  (r['currency'] as String?) ?? Currencies.defaultCode,
            ),
          )
          .toList();
    } catch (err) {
      throw RepositoryException('Could not work out settlements.', cause: err);
    }
  }

  Future<Settlement> recordSettlement({
    required String tripId,
    required String fromUserId,
    required String toUserId,
    required int amountMinor,
    required String currency,
    required SettlementMethod method,
    String? reference,
    String? notes,
    DateTime? settledAt,
    int? baseAmountMinor,
    double? fxRate,
    String? fxProvider,
    required String idempotencyKey,
  }) async {
    try {
      final Map<String, dynamic> row = (await _db.rpc(
        'record_settlement',
        params: {
          'p_trip_id': tripId,
          'p_from_user_id': fromUserId,
          'p_to_user_id': toUserId,
          'p_amount_minor': amountMinor,
          'p_currency': currency,
          'p_method': method.id,
          'p_reference': reference,
          'p_notes': notes,
          'p_settled_at': settledAt == null ? null : _isoDate(settledAt),
          'p_base_amount_minor': baseAmountMinor,
          'p_fx_rate': fxRate,
          'p_fx_provider': fxProvider,
          'p_idempotency_key': idempotencyKey,
        },
      )) as Map<String, dynamic>;
      return Settlement.fromJson(row);
    } catch (err) {
      throw RepositoryException(_message(err), cause: err);
    }
  }

  Future<List<Settlement>> listSettlements(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('settlements')
          .select(
            '*, from_profile:profiles!settlements_from_user_id_fkey(full_name), to_profile:profiles!settlements_to_user_id_fkey(full_name)',
          )
          .eq('trip_id', tripId)
          .isFilter('deleted_at', null)
          .order('settled_at', ascending: false));
      return rows.map(Settlement.fromJson).toList();
    } catch (err) {
      throw RepositoryException(
        'Could not load settlement history.',
        cause: err,
      );
    }
  }

  String _message(Object err) {
    if (err is RepositoryException) return err.message;
    final String text = '$err';
    if (text.contains('Percentages must add up')) {
      return 'Percentages must add up to 100%.';
    }
    if (text.contains('do not sum to the total')) {
      return 'The split does not add up to the expense total. Please check the amounts.';
    }
    if (text.contains('Maximum valid settlement')) {
      return text.replaceAll(
        'Maximum valid settlement is ',
        'That is more than is owed. The maximum is ',
      );
    }
    if (text.contains('not a member of this trip')) {
      return 'One of those people is not a member of this trip.';
    }
    if (text.contains('violates row-level security') ||
        text.contains('permission')) {
      return 'You do not have permission to do that.';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'No connection. Your change was not saved.';
    }
    return 'Could not save that. Please try again.';
  }
}

class ExpensePage {
  const ExpensePage({
    required this.expenses,
    required this.offset,
    required this.limit,
  });

  final List<Expense> expenses;
  final int offset;
  final int limit;

  bool get hasMore => expenses.length >= limit;
}

/// Budget allocations and planned-vs-actual reporting.
class BudgetRepository {
  BudgetRepository(this._service);

  final SupabaseService _service;

  SupabaseClient get _db => _service.client;

  Future<Budget> load(
    String tripId, {
    required int dayCount,
    int? daysRemaining,
  }) async {
    try {
      Map<String, dynamic> row =
          (await _db
              .from('budgets')
              .select('*')
              .eq('trip_id', tripId)
              .maybeSingle() ??
          <String, dynamic>{});

      if (row.isEmpty) {
        await _db.from('budgets').insert(<String, dynamic>{'trip_id': tripId});
        row = (await _db
            .from('budgets')
            .select('*')
            .eq('trip_id', tripId)
            .single());
      }

      final List<Map<String, dynamic>> actual = (await _db.rpc(
        'budget_summary',
        params: {'p_trip_id': tripId},
      ));

      final List<Map<String, dynamic>> planned = (await _db
          .from('budget_categories')
          .select('*')
          .eq('trip_id', tripId));

      final Map<String, int> actualByCategory = <String, int>{
        for (final Map<String, dynamic> a in actual)
          if (a['category'] != null)
            '${a['category']}': decodeInt(a['actual_minor']),
      };

      final List<BudgetCategoryAllocation> allocations = planned.map((p) {
        final String key = p['category'] as String;
        return BudgetCategoryAllocation(
          id: '${p['id']}',
          category: ExpenseCategory.fromId(key),
          plannedMinor: decodeInt(p['planned_minor']),
          actualMinor: actualByCategory[key] ?? 0,
          isEssential: p['is_essential'] as bool? ?? false,
          notes: p['notes'] as String?,
        );
      }).toList();

      // Categories with spending but no allocation still need a row so the
      // report shows them rather than silently dropping money.
      for (final Map<String, dynamic> a in actual) {
        final String key = a['category'] as String;
        if (allocations.any((x) => x.category.id == key)) continue;
        allocations.add(
          BudgetCategoryAllocation(
            id: 'unallocated-$key',
            category: ExpenseCategory.fromId(key),
            plannedMinor: 0,
            actualMinor: decodeInt(a['actual_minor']),
          ),
        );
      }

      return Budget.fromJson(
        row,
        categories: allocations,
        dayCount: dayCount <= 0 ? 1 : dayCount,
        remainingDays: daysRemaining,
      );
    } catch (err) {
      throw RepositoryException('Could not load the budget.', cause: err);
    }
  }

  Future<void> updateTotals(
    String tripId, {
    int? totalMinor,
    int? contingencyMinor,
    int? dailyLimitMinor,
    double? alertThresholdPct,
    String? notes,
  }) async {
    try {
      await _db
          .from('budgets')
          .update(<String, dynamic>{
            'total_minor': ?totalMinor,
            'contingency_minor': ?contingencyMinor,
            'daily_limit_minor': ?dailyLimitMinor,
            'alert_threshold_pct': ?alertThresholdPct,
            'notes': ?notes,
          })
          .eq('trip_id', tripId);
    } catch (err) {
      throw RepositoryException('Could not save the budget.', cause: err);
    }
  }

  Future<void> upsertAllocation({
    required String tripId,
    required ExpenseCategory category,
    required int plannedMinor,
    bool? isEssential,
  }) async {
    try {
      await _db.from('budget_categories').upsert(<String, dynamic>{
        'trip_id': tripId,
        'category': category.id,
        'planned_minor': plannedMinor,
        'is_essential': ?isEssential,
      }, onConflict: 'budget_id,category');
    } catch (err) {
      throw RepositoryException('Could not save the allocation.', cause: err);
    }
  }

  Future<List<CategoryTotal>> categoryTotals(
    String tripId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('expenses')
          .select('category, base_amount_minor')
          .eq('trip_id', tripId)
          .isFilter('deleted_at', null)
          .gte('expense_date', from == null ? '1900-01-01' : _isoDate(from))
          .lte('expense_date', to == null ? '2999-12-31' : _isoDate(to)));
      final Map<String, int> totals = <String, int>{};
      final Map<String, int> counts = <String, int>{};
      for (final Map<String, dynamic> row in rows) {
        final String category = row['category'] as String? ?? 'other';
        totals[category] =
            (totals[category] ?? 0) + decodeInt(row['base_amount_minor']);
        counts[category] = (counts[category] ?? 0) + 1;
      }
      return totals.entries
          .map(
            (e) => CategoryTotal(
              category: e.key,
              amountMinor: e.value,
              count: counts[e.key] ?? 0,
            ),
          )
          .toList();
    } catch (err) {
      throw RepositoryException(
        'Could not load the category report.',
        cause: err,
      );
    }
  }

  Future<List<DailyTotal>> dailyTotals(
    String tripId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('expenses')
          .select('expense_date, base_amount_minor')
          .eq('trip_id', tripId)
          .isFilter('deleted_at', null)
          .gte('expense_date', from == null ? '1900-01-01' : _isoDate(from))
          .lte('expense_date', to == null ? '2999-12-31' : _isoDate(to)));
      final Map<String, int> totals = <String, int>{};
      for (final Map<String, dynamic> row in rows) {
        final String day = _isoDate(decodeDate(row['expense_date']));
        totals[day] = (totals[day] ?? 0) + decodeInt(row['base_amount_minor']);
      }
      final List<DateTime> sorted = totals.keys.map(DateTime.parse).toList()
        ..sort();
      return sorted
          .map(
            (d) => DailyTotal(date: d, amountMinor: totals[_isoDate(d)] ?? 0),
          )
          .toList();
    } catch (err) {
      throw RepositoryException('Could not load the daily report.', cause: err);
    }
  }

  Future<List<TravelerTotal>> travelerTotals(String tripId) async {
    try {
      final List<MemberBalance> balances = await ExpenseRepository(_service)
          .balances(tripId);
      final List<Map<String, dynamic>> profiles = (await _db
          .from('trip_members')
          .select('user_id, profiles(full_name)')
          .eq('trip_id', tripId)
          .eq('status', 'active'));
      final Map<String, String> names = <String, String>{
        for (final Map<String, dynamic> p in profiles)
          '${p['user_id']}':
              ((p['profiles'] as Map<String, dynamic>?)?['full_name']
                  as String?) ??
              'Traveller',
      };
      return balances
          .map(
            (b) => TravelerTotal(
              userId: b.memberId,
              name: names[b.memberId] ?? 'Traveller',
              paidMinor: b.paidMinor,
              shareMinor: b.owesMinor,
              netMinor: b.netMinor,
            ),
          )
          .toList();
    } catch (err) {
      throw RepositoryException(
        'Could not load the traveller report.',
        cause: err,
      );
    }
  }
}

/// Bookings, documents, packing lists.
class BookingRepository {
  BookingRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;

  Future<List<Booking>> list(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('bookings')
          .select('*')
          .eq('trip_id', tripId)
          .order('starts_at', ascending: true, nullsFirst: false));
      return rows.map(Booking.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load bookings.', cause: err);
    }
  }

  Future<void> upsert(
    String tripId,
    Map<String, dynamic> values, {
    String? id,
  }) async {
    try {
      if (id == null) {
        await _db.from('bookings').insert(<String, dynamic>{
          'trip_id': tripId,
          ...values,
        });
      } else {
        await _db.from('bookings').update(values).eq('id', id);
      }
    } catch (err) {
      throw RepositoryException('Could not save that booking.', cause: err);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.from('bookings').delete().eq('id', id);
    } catch (err) {
      throw RepositoryException('Could not delete that booking.', cause: err);
    }
  }
}

class DocumentRepository {
  DocumentRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;

  Future<List<TravelDocument>> list({String? tripId}) async {
    try {
      var query = _db
          .from('travel_documents')
          .select('*')
          .isFilter('deleted_at', null);
      if (tripId != null) query = query.eq('trip_id', tripId);
      final List<Map<String, dynamic>> rows = (await query.order(
        'created_at',
        ascending: false,
      ));
      return rows.map(TravelDocument.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load documents.', cause: err);
    }
  }

  /// Records document metadata. The file itself must already be uploaded to the
  /// private bucket under `<user_id>/<trip_id>/`.
  Future<void> register({
    String? tripId,
    required String name,
    required String docType,
    required String storagePath,
    required String mimeType,
    required int sizeBytes,
    DateTime? expiryDate,
    String? notes,
    bool sensitive = true,
  }) async {
    try {
      await _db.from('travel_documents').insert(<String, dynamic>{
        'trip_id': ?tripId,
        'user_id': _service.currentUserId,
        'name': name,
        'doc_type': docType,
        'storage_path': storagePath,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'expiry_date': expiryDate == null ? null : _isoDate(expiryDate),
        'notes': notes,
        'sensitive': sensitive,
      });
    } catch (err) {
      throw RepositoryException(
        'Could not save the document record.',
        cause: err,
      );
    }
  }

  /// Requests a short-lived signed URL. No public URL is ever stored or shown.
  Future<String> signedUrl(String storagePath, {bool isReceipt = false}) async {
    try {
      final String url = (await _db.rpc(
        isReceipt ? 'create_signed_receipt_url' : 'create_signed_document_url',
        params: <String, dynamic>{
          'p_storage_path': storagePath,
          'p_expires_seconds': 300,
        },
      )) as String;
      return url;
    } catch (err) {
      throw RepositoryException('Could not open that document.', cause: err);
    }
  }

  Future<void> softDelete(String id) async {
    try {
      await _db
          .from('travel_documents')
          .update(<String, dynamic>{
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (err) {
      throw RepositoryException('Could not delete that document.', cause: err);
    }
  }
}

class PackingRepository {
  PackingRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;

  Future<List<PackingList>> list({String? tripId}) async {
    try {
      var query = _db.from('packing_lists').select('*, packing_list_items(*)');
      if (tripId != null) query = query.eq('trip_id', tripId);
      final List<Map<String, dynamic>> rows = (await query);
      return rows.map(PackingList.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load checklists.', cause: err);
    }
  }

  Future<List<Map<String, dynamic>>> templates() async {
    try {
      return await _db
          .from('checklist_templates')
          .select('slug, name, kind, description, items')
          .order('name');
    } catch (err) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<String> createFromTemplate({
    required String slug,
    String? name,
    String? tripId,
    bool shared = true,
  }) async {
    try {
      return (await _db.rpc(
        'copy_template_list',
        params: {
          'p_template_slug': slug,
          'p_name': name,
          'p_trip_id': tripId,
          'p_shared': shared,
        },
      )) as String;
    } catch (err) {
      throw RepositoryException('Could not create that checklist.', cause: err);
    }
  }

  Future<void> addItem(
    String listId,
    String label, {
    String category = 'other',
  }) async {
    try {
      await _db.from('packing_list_items').insert(<String, dynamic>{
        'list_id': listId,
        'label': label,
        'category': category,
        'available_offline': true,
      });
    } catch (err) {
      throw RepositoryException('Could not add that item.', cause: err);
    }
  }

  Future<void> setPacked(String itemId, bool packed) async {
    try {
      await _db
          .from('packing_list_items')
          .update(<String, dynamic>{'is_packed': packed})
          .eq('id', itemId);
    } catch (err) {
      throw RepositoryException('Could not update that item.', cause: err);
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await _db.from('packing_list_items').delete().eq('id', itemId);
    } catch (err) {
      throw RepositoryException('Could not remove that item.', cause: err);
    }
  }
}

/// Emergency, visa and advisory reference data. Reads are public-safe.
class EmergencyRepository {
  EmergencyRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;
  LocalCache? _cache;

  Future<LocalCache> get _localCache async =>
      _cache ??= await LocalCache.open();

  Future<List<EmergencyResource>> resources({String? countryCode}) async {
    try {
      var query = _db.from('emergency_resources').select('*');
      if (countryCode != null) query = query.eq('country_code', countryCode);
      final List<Map<String, dynamic>> rows = (await query.order('category'));
      await (await _localCache).putJson('emergency_resources', rows);
      return rows.map(EmergencyResource.fromJson).toList();
    } catch (err) {
      final List<Map<String, dynamic>> cached = (await _localCache).getJsonList(
        'emergency_resources',
      );
      if (cached.isEmpty) {
        throw RepositoryException(
          'Emergency contacts are not available offline. Download them while connected.',
          cause: err,
        );
      }
      return cached.map(EmergencyResource.fromJson).toList();
    }
  }

  Future<List<EmergencyGuide>> guides() async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('emergency_guides')
          .select('*')
          .order('country_code'));
      await (await _localCache).putJson('emergency_guides', rows);
      return rows.map(EmergencyGuide.fromJson).toList();
    } catch (err) {
      final List<Map<String, dynamic>> cached = (await _localCache).getJsonList(
        'emergency_guides',
      );
      if (cached.isEmpty) {
        throw RepositoryException(
          'Emergency guides are not downloaded yet.',
          cause: err,
        );
      }
      return cached.map(EmergencyGuide.fromJson).toList();
    }
  }

  /// Merges locally saved guide edits (e.g. a language the user pinned) with
  /// the server copy.
  Future<void> saveGuideLocally(EmergencyGuide guide) async {
    await (await _localCache).putJson('guide_${guide.slug}', guide.toJson());
    await (await _localCache).touch('guide_${guide.slug}');
  }

  Future<EmergencyGuide?> savedGuide(String slug) async {
    final Map<String, dynamic>? raw = (await _localCache).getJson(
      'guide_$slug',
    );
    return raw == null ? null : EmergencyGuide.fromJson(raw);
  }

  Future<List<VisaResourceLink>> visaLinks({String? countryCode}) async {
    try {
      var query = _db.from('visa_resource_links').select('*');
      if (countryCode != null) query = query.eq('country_code', countryCode);
      return (await query).map(VisaResourceLink.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load visa resources.', cause: err);
    }
  }

  Future<List<TravelAdvisory>> advisories({String? countryCode}) async {
    try {
      var query = _db.from('travel_advisories').select('*');
      if (countryCode != null) query = query.eq('country_code', countryCode);
      return (await query).map(TravelAdvisory.fromJson).toList();
    } catch (err) {
      return const <TravelAdvisory>[];
    }
  }

  Future<List<VisaRecord>> visaRecords(String tripId) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('visa_records')
          .select('*')
          .eq('trip_id', tripId)
          .order('destination_country'));
      return rows.map(VisaRecord.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load visa records.', cause: err);
    }
  }

  Future<void> upsertVisaRecord(VisaRecord record) async {
    try {
      await _db
          .from('visa_records')
          .upsert(record.toJson(), onConflict: 'trip_id,destination_country');
    } catch (err) {
      throw RepositoryException('Could not save that visa record.', cause: err);
    }
  }
}

/// Exchange rates and conversion history.
class ConverterRepository {
  ConverterRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;
  LocalCache? _cache;

  Future<LocalCache> get _localCache async =>
      _cache ??= await LocalCache.open();

  static const String _ratesKey = 'fx_rates';

  /// Returns rates for the requested quotes, falling back to the local cache
  /// when the network fails. The caller is told which it got.
  Future<RateResult> rates(String base, List<String> quotes) async {
    try {
      final Map<String, dynamic> result = await _service.invokeFunction(
        'exchange-rates',
        query: <String, String>{
          'action': 'rates',
          'base': base,
          'quotes': quotes.join(','),
        },
      );
      final List<Map<String, dynamic>> rows =
          ((result['rates'] as List?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList();

      final List<CachedRate> parsed = rows.map((r) {
        final DateTime fetched =
            DateTime.tryParse(r['fetched_at'] as String? ?? '') ??
            DateTime.now();
        return CachedRate(
          base: base,
          quote: '${r['quote']}',
          rate: (r['rate'] as num?)?.toDouble() ?? 1,
          provider: r['provider'] as String? ?? 'unknown',
          fetchedAt: fetched,
          isIndicative: r['is_indicative'] as bool? ?? true,
          isStale: r['is_stale'] as bool? ?? false,
        );
      }).toList();

      await (await _localCache).putJson('$_ratesKey:$base', <String, dynamic>{
        'fetched_at': DateTime.now().toIso8601String(),
        'rates': parsed.map((r) => r.toCache()).toList(),
      });
      await (await _localCache).touch('$_ratesKey:$base');

      return RateResult(
        rates: parsed,
        fromCache: false,
        notice: result['notice'] as String?,
      );
    } catch (err) {
      final Map<String, dynamic>? cached = (await _localCache).getJson(
        '$_ratesKey:$base',
      );
      if (cached == null) {
        throw RepositoryException(
          'Exchange rates are unavailable and nothing is cached for $base yet. '
          'Connect to the internet and try again.',
          cause: err,
        );
      }
      final List<CachedRate> parsed =
          ((cached['rates'] as List?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(CachedRate.fromCache)
              .where((r) => quotes.contains(r.quote))
              .toList();
      return RateResult(
        rates: parsed,
        fromCache: true,
        notice: 'Cached rates. These are not live quotes and your provider may use a different rate.',
      );
    }
  }

  Future<void> saveConversion({
    required String from,
    required String to,
    required int inputMinor,
    required int outputMinor,
    required double rate,
    required String provider,
    bool isOfflineCached = false,
    double? feeEstimatePct,
  }) async {
    try {
      await _db.from('currency_conversion_history').insert(<String, dynamic>{
        'user_id': _service.currentUserId,
        'from_currency': from,
        'to_currency': to,
        'input_minor': inputMinor,
        'output_minor': outputMinor,
        'rate': rate,
        'provider': provider,
        'is_offline_cached': isOfflineCached,
        'fee_estimate_pct': feeEstimatePct,
      });
    } catch (err) {
      // History is a convenience, not a ledger; a failure must not surface.
    }
  }

  Future<List<ConversionRecord>> history({int limit = 50}) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('currency_conversion_history')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit));
      return rows.map(ConversionRecord.fromJson).toList();
    } catch (err) {
      return const <ConversionRecord>[];
    }
  }
}

class RateResult {
  const RateResult({required this.rates, required this.fromCache, this.notice});

  final List<CachedRate> rates;
  final bool fromCache;
  final String? notice;
}

class NotificationRepository {
  NotificationRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;

  /// Realtime stream of a single user's notifications.
  ///
  /// Requires the `notifications` table to be added to the Supabase
  /// `supabase_realtime` publication. If replication is off, the stream simply
  /// never emits and the screen falls back to [list] on refresh.
  Stream<List<Map<String, dynamic>>> watchRealtime() {
    return _db
        .from('notifications')
        .stream(primaryKey: const <String>['id'])
        .map((rows) => rows)
        .handleError((Object _) {
          // Realtime is an enhancement, never a requirement.
        });
  }

  Future<List<AppNotification>> list({int limit = 50, int offset = 0}) async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1));
      return rows.map(AppNotification.fromJson).toList();
    } catch (err) {
      return const <AppNotification>[];
    }
  }

  Future<int> unreadCount() async {
    try {
      final List<Map<String, dynamic>> rows = (await _db
          .from('notifications')
          .select('id')
          .isFilter('read_at', null)
          .limit(200));
      return rows.length;
    } catch (err) {
      return 0;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _db
          .from('notifications')
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (err) {
      // Non-critical.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _db
          .from('notifications')
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .isFilter('read_at', null);
    } catch (err) {
      // Non-critical.
    }
  }
}

/// Destination catalogue.
class DestinationRepository {
  DestinationRepository(this._service);

  final SupabaseService _service;
  SupabaseClient get _db => _service.client;

  Future<List<Destination>> search({
    String? query,
    String? category,
    int limit = 60,
  }) async {
    try {
      var q = _db.from('destinations').select('*');
      if (query != null && query.trim().isNotEmpty) {
        final String term = query.trim();
        q = q.or(
          'name.ilike.%$term%,city.ilike.%$term%,country.ilike.%$term%,'
          'categories.cs.{${_escapeCsv(term)}}',
        );
      }
      if (category != null) q = q.contains('categories', <String>[category]);
      final List<Map<String, dynamic>> rows = (await q.limit(limit));
      return rows.map(Destination.fromJson).toList();
    } catch (err) {
      throw RepositoryException('Could not load destinations.', cause: err);
    }
  }

  Future<Destination?> byId(String id) async {
    try {
      final Map<String, dynamic>? row = (await _db
          .from('destinations')
          .select('*')
          .eq('id', id)
          .maybeSingle());
      return row == null ? null : Destination.fromJson(row);
    } catch (err) {
      return null;
    }
  }

  Future<void> saveToWishlist({
    required String name,
    String? country,
    String? countryCode,
    DateTime? targetDate,
    int? estimatedBudgetMinor,
    String currency = Currencies.defaultCode,
    String? notes,
  }) async {
    try {
      await _db.from('saved_destinations').upsert(<String, dynamic>{
        'user_id': _service.currentUserId,
        'name': name,
        'country': country,
        'country_code': countryCode,
        'target_date': targetDate == null ? null : _isoDate(targetDate),
        'estimated_budget_minor': estimatedBudgetMinor,
        'currency': currency,
        'notes': notes,
      }, onConflict: 'user_id,name,country');
    } catch (err) {
      throw RepositoryException('Could not save that destination.', cause: err);
    }
  }

  Future<List<Map<String, dynamic>>> wishlist() async {
    try {
      return (await _db
          .from('saved_destinations')
          .select('*')
          .order('created_at', ascending: false));
    } catch (err) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> removeFromWishlist(String id) async {
    try {
      await _db.from('saved_destinations').delete().eq('id', id);
    } catch (err) {
      // Non-critical.
    }
  }

  static String _escapeCsv(String value) =>
      value.replaceAll(RegExp(r'[,"{}\s]'), '');
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// jsonDecode helper used by repositories that need a loose map.
Map<String, dynamic> decodeMapLoose(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is String) {
    final Object? decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  return <String, dynamic>{};
}
