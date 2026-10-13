import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import '../../core/money/currency.dart';
import '../../core/money/split_engine.dart';
import '../models/expense.dart';
import '../models/misc.dart';
import '../models/planning.dart';
import '../models/trip.dart';

/// Deterministic pseudo-random helper so demo data is identical on every run.
class _Det {
  _Det(this._seed);
  int _seed;
  int next(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return max <= 0 ? 0 : _seed % max;
  }
}

/// Fictional data for demo mode.
///
/// EVERYTHING IN THIS FILE IS INVENTED. No figure here is a real exchange
/// rate, a real price, or a real person's spending. Demo mode is labelled
/// prominently in the UI and never mixes with a signed-in account's data.
class DemoFixtures {
  const DemoFixtures._();

  // Stable fictional user ids.
  static const String aliceId = 'demo-alice';
  static const String bobId = 'demo-bob';
  static const String charlieId = 'demo-charlie';
  static const String danaId = 'demo-dana';

  static DateTime get _today {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static final List<Profile> profiles = <Profile>[
    const Profile(
      id: aliceId,
      fullName: 'Alice Nakamura',
      homeCountry: 'GB',
      residenceCountry: 'GB',
      nationalityCountries: <String>['GB'],
      passportCountry: 'GB',
      preferredCurrency: 'HKD',
      timezone: 'Europe/London',
      travelInterests: <String>[
        'food',
        'sightseeing',
        'photography',
        'shopping',
      ],
      travelStyle: TravelStyle.balanced,
      emergencyContactName: 'Haruto Nakamura',
      emergencyContactPhone: '+44 7700 900000',
      onboardingCompleted: true,
      demoAccount: true,
    ),
    const Profile(
      id: bobId,
      fullName: 'Bob Okafor',
      preferredCurrency: 'HKD',
      travelInterests: <String>['adventure', 'food', 'nightlife'],
      travelStyle: TravelStyle.comfort,
      onboardingCompleted: true,
      demoAccount: true,
    ),
    const Profile(
      id: charlieId,
      fullName: 'Charlie Lindqvist',
      preferredCurrency: 'SEK',
      travelInterests: <String>['nature', 'mountains', 'photography'],
      travelStyle: TravelStyle.budget,
      onboardingCompleted: true,
      demoAccount: true,
    ),
    const Profile(
      id: danaId,
      fullName: 'Dana Rivera',
      preferredCurrency: Currencies.defaultCode,
      travelInterests: <String>['food', 'beaches', 'shopping'],
      travelStyle: TravelStyle.balanced,
      onboardingCompleted: true,
      demoAccount: true,
    ),
  ];

  static Profile? get profile => profiles.first;

  static Profile? profileById(String id) {
    for (final Profile p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  static final String hkTripId = 'demo-trip-hong-kong';
  static final String lisbonTripId = 'demo-trip-lisbon';

  static List<Trip> get trips => <Trip>[
    Trip(
      id: hkTripId,
      ownerId: aliceId,
      name: 'Hong Kong & Shenzhen long weekend',
      description: 'Four friends, three days, two cities. Everything is logged in the currency it was actually paid in.',
      origin: 'London',
      countryCode: 'HK',
      startDate: _today.add(const Duration(days: 21)),
      endDate: _today.add(const Duration(days: 24)),
      timezone: 'Asia/Hong_Kong',
      travelerCount: 4,
      baseCurrency: 'HKD',
      totalBudgetMinor: 3200000,
      contingencyPct: 10,
      travelStyle: TravelStyle.balanced,
      travelPurpose: 'City break',
      interests: const <String>[
        'food',
        'sightseeing',
        'shopping',
        'photography',
      ],
      transportPreferences: const <String>['MTR', 'walking', 'Peak Tram'],
      accommodationPreferences: const <String>['Apartment with kitchen'],
      dietaryNotes: 'Charlie is vegetarian.',
      coverImageUrl: 'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?auto=format&fit=crop&w=1200&q=70',
      status: TripStatus.upcoming,
      myRole: TripRole.owner,
      memberCount: 4,
      destinations: <TripDestination>[
        TripDestination(
          id: 'demo-dest-hk',
          tripId: hkTripId,
          position: 0,
          name: 'Hong Kong',
          country: 'Hong Kong SAR',
          countryCode: 'HK',
          city: 'Hong Kong',
          latitude: 22.3193,
          longitude: 114.1694,
          timezone: 'Asia/Hong_Kong',
        ),
        TripDestination(
          id: 'demo-dest-sz',
          tripId: hkTripId,
          position: 1,
          name: 'Shenzhen',
          country: 'China',
          countryCode: 'CN',
          city: 'Shenzhen',
          latitude: 22.5431,
          longitude: 114.0579,
          timezone: 'Asia/Shanghai',
        ),
      ],
    ),
    Trip(
      id: lisbonTripId,
      ownerId: aliceId,
      name: 'Lisbon long weekend',
      description: 'A solo trip. Budget tracked in euros.',
      origin: 'London',
      countryCode: 'PT',
      startDate: _today.add(const Duration(days: 95)),
      endDate: _today.add(const Duration(days: 99)),
      timezone: 'Europe/Lisbon',
      travelerCount: 1,
      baseCurrency: 'EUR',
      totalBudgetMinor: 90000,
      travelStyle: TravelStyle.budget,
      interests: const <String>['food', 'heritage', 'city'],
      status: TripStatus.planning,
      myRole: TripRole.owner,
      memberCount: 1,
      destinations: <TripDestination>[
        TripDestination(
          id: 'demo-dest-lx',
          tripId: lisbonTripId,
          position: 0,
          name: 'Lisbon',
          country: 'Portugal',
          countryCode: 'PT',
          city: 'Lisbon',
          latitude: 38.7223,
          longitude: -9.1393,
          timezone: 'Europe/Lisbon',
        ),
      ],
    ),
  ];

  static List<TripMember> membersFor(String tripId) {
    if (tripId != hkTripId) {
      return <TripMember>[
        TripMember(
          userId: aliceId,
          tripId: tripId,
          role: TripRole.owner,
          fullName: 'Alice Nakamura',
        ),
      ];
    }
    return <TripMember>[
      TripMember(
        userId: aliceId,
        tripId: tripId,
        role: TripRole.owner,
        fullName: 'Alice Nakamura',
        joinedAt: _today.subtract(const Duration(days: 30)),
      ),
      TripMember(
        userId: bobId,
        tripId: tripId,
        role: TripRole.editor,
        fullName: 'Bob Okafor',
        joinedAt: _today.subtract(const Duration(days: 28)),
      ),
      TripMember(
        userId: charlieId,
        tripId: tripId,
        role: TripRole.editor,
        fullName: 'Charlie Lindqvist',
        joinedAt: _today.subtract(const Duration(days: 27)),
      ),
      TripMember(
        userId: danaId,
        tripId: tripId,
        role: TripRole.viewer,
        fullName: 'Dana Rivera',
        joinedAt: _today.subtract(const Duration(days: 25)),
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Expenses. Shares are computed with the SAME SplitEngine used in
  // production, so demo balances are internally consistent and exercise the
  // real arithmetic rather than a hand-written approximation.
  // ---------------------------------------------------------------------

  static List<Expense> get _hkExpensesRaw => <Expense>[
    Expense(
      id: 'demo-exp-1',
      tripId: hkTripId,
      title: 'Airport Express tickets + Octopus top-up',
      amountMinor: 42000,
      currency: 'HKD',
      baseAmountMinor: 42000,
      category: ExpenseCategory.localTransport,
      expenseDate: _today.subtract(const Duration(days: 3)),
      paidBy: aliceId,
      splitMethod: SplitMethod.equal,
      participantIds: const <String>[aliceId, bobId, charlieId, danaId],
      myShareMinor: 10500,
      payerName: 'Alice Nakamura',
      createdBy: aliceId,
      createdAt: _today.subtract(const Duration(days: 3)),
      notes: 'Four Airport Express tickets, card top-up done at the counter.',
    ),
    Expense(
      id: 'demo-exp-2',
      tripId: hkTripId,
      title: 'Shenzhen hotpot dinner',
      amountMinor: 88000,
      currency: 'CNY',
      baseAmountMinor: 96000,
      fxRate: 1.0909,
      fxProvider: 'demo-fixture',
      fxFetchedAt: _today.subtract(const Duration(days: 2)),
      category: ExpenseCategory.food,
      expenseDate: _today.subtract(const Duration(days: 2)),
      paidBy: bobId,
      splitMethod: SplitMethod.equal,
      participantIds: const <String>[aliceId, bobId, charlieId, danaId],
      myShareMinor: 24000,
      payerName: 'Bob Okafor',
      createdBy: bobId,
      createdAt: _today.subtract(const Duration(days: 2)),
      notes: 'Paid in yuan. The original amount is kept; the trip total uses the rate shown at the time of entry.',
      hasFxConversion: true,
    ),
    Expense(
      id: 'demo-exp-3',
      tripId: hkTripId,
      title: 'Airbnb, 3 nights in Tsim Sha Tsui',
      amountMinor: 768000,
      currency: 'HKD',
      baseAmountMinor: 768000,
      category: ExpenseCategory.accommodation,
      expenseDate: _today.subtract(const Duration(days: 12)),
      paidBy: aliceId,
      splitMethod: SplitMethod.percentage,
      participantIds: const <String>[aliceId, bobId, charlieId, danaId],
      myShareMinor: 230400,
      payerName: 'Alice Nakamura',
      createdBy: aliceId,
      createdAt: _today.subtract(const Duration(days: 12)),
      notes: 'Booked on Alice\'s card for the whole group. Two rooms, so the adults split 30/30.',
    ),
    Expense(
      id: 'demo-exp-4',
      tripId: hkTripId,
      title: 'Museum and gallery tickets',
      amountMinor: 96000,
      currency: 'HKD',
      baseAmountMinor: 96000,
      category: ExpenseCategory.activities,
      expenseDate: _today.subtract(const Duration(days: 8)),
      paidBy: charlieId,
      splitMethod: SplitMethod.shares,
      participantIds: const <String>[aliceId, bobId, charlieId, danaId],
      myShareMinor: 24000,
      payerName: 'Charlie Lindqvist',
      createdBy: charlieId,
      createdAt: _today.subtract(const Duration(days: 8)),
    ),
    Expense(
      id: 'demo-exp-5',
      tripId: hkTripId,
      title: 'Birthday dinner at K Lok',
      amountMinor: 456000,
      currency: 'HKD',
      baseAmountMinor: 456000,
      category: ExpenseCategory.food,
      expenseDate: _today.subtract(const Duration(days: 6)),
      paidBy: danaId,
      splitMethod: SplitMethod.exact,
      participantIds: const <String>[aliceId, bobId, charlieId, danaId],
      myShareMinor: 152000,
      payerName: 'Dana Rivera',
      createdBy: danaId,
      createdAt: _today.subtract(const Duration(days: 6)),
      notes: 'Custom amounts per person, entered by Dana.',
    ),
    Expense(
      id: 'demo-exp-6',
      tripId: hkTripId,
      title: 'Taxi up to Victoria Peak',
      amountMinor: 36000,
      currency: 'HKD',
      baseAmountMinor: 36000,
      category: ExpenseCategory.localTransport,
      expenseDate: _today.subtract(const Duration(days: 5)),
      paidBy: bobId,
      splitMethod: SplitMethod.equal,
      participantIds: const <String>[aliceId, bobId, charlieId],
      myShareMinor: 12000,
      payerName: 'Bob Okafor',
      createdBy: bobId,
      createdAt: _today.subtract(const Duration(days: 5)),
      notes: 'Dana did not join this one, so they are excluded from the split.',
    ),
    Expense(
      id: 'demo-exp-7',
      tripId: hkTripId,
      title:
          'Charlie'
          's prepaid SIM',
      amountMinor: 38000,
      currency: 'HKD',
      baseAmountMinor: 38000,
      category: ExpenseCategory.connectivity,
      expenseDate: _today.subtract(const Duration(days: 4)),
      paidBy: charlieId,
      splitMethod: SplitMethod.none,
      isPersonal: true,
      participantIds: const <String>[charlieId],
      myShareMinor: 38000,
      payerName: 'Charlie Lindqvist',
      createdBy: charlieId,
      createdAt: _today.subtract(const Duration(days: 4)),
      notes: 'Personal expense — excluded from everyone else\'s balance.',
    ),
  ];

  static final Map<String, List<ExpenseShareEntry>> _sharesByExpense =
      _buildShares();

  static Map<String, List<ExpenseShareEntry>> _buildShares() {
    final Map<String, List<ExpenseShareEntry>> result =
        <String, List<ExpenseShareEntry>>{};

    for (final Expense expense in _hkExpensesRaw) {
      final List<String> ids = expense.participantIds;
      final Map<String, int> allocated;

      if (expense.isPersonal || expense.splitMethod == SplitMethod.none) {
        allocated = <String, int>{ids.first: expense.amountMinor};
      } else if (expense.splitMethod == SplitMethod.percentage) {
        allocated = allocateById(expense.amountMinor, ids, <String, int>{
          aliceId: 3000,
          bobId: 3000,
          charlieId: 2000,
          danaId: 2000,
        });
      } else if (expense.splitMethod == SplitMethod.exact) {
        allocated = SplitEngine.exact(
          totalMinor: expense.amountMinor,
          currencyCode: expense.currency,
          participantIds: ids,
          amountsMinor: <String, int>{
            aliceId: 152000,
            bobId: 152000,
            charlieId: 101000,
            danaId: 101000,
          },
        ).shares;
      } else if (expense.splitMethod == SplitMethod.shares) {
        allocated = SplitEngine.shares(
          totalMinor: expense.amountMinor,
          currencyCode: expense.currency,
          participantIds: ids,
          weights: <String, int>{for (final String id in ids) id: 1},
        ).shares;
      } else {
        allocated = SplitEngine.equal(
          totalMinor: expense.amountMinor,
          currencyCode: expense.currency,
          participantIds: ids,
        ).shares;
      }

      final double fx = expense.amountMinor == 0
          ? 1
          : expense.baseAmountMinor / expense.amountMinor;
      result[expense.id] = <ExpenseShareEntry>[
        for (final MapEntry<String, int> entry in allocated.entries)
          ExpenseShareEntry(
            userId: entry.key,
            amountMinor: entry.value,
            baseAmountMinor: (entry.value * fx).round(),
            fullName: profileById(entry.key)?.fullName,
          ),
      ];
    }

    return result;
  }

  static List<Expense> get hkExpenses => <Expense>[
    for (final Expense e in _hkExpensesRaw)
      Expense(
        id: e.id,
        tripId: e.tripId,
        title: e.title,
        amountMinor: e.amountMinor,
        currency: e.currency,
        baseAmountMinor: e.baseAmountMinor,
        fxRate: e.fxRate,
        fxProvider: e.fxProvider,
        fxFetchedAt: e.fxFetchedAt,
        category: e.category,
        expenseDate: e.expenseDate,
        paidBy: e.paidBy,
        splitMethod: e.splitMethod,
        isPersonal: e.isPersonal,
        notes: e.notes,
        receiptPath: e.receiptPath,
        participantIds: e.participantIds,
        shares: _sharesByExpense[e.id] ?? const <ExpenseShareEntry>[],
        myShareMinor: (_sharesByExpense[e.id] ?? const <ExpenseShareEntry>[])
            .where((s) => s.userId == aliceId)
            .fold<int>(0, (sum, s) => sum + s.baseAmountMinor),
        createdBy: e.createdBy,
        createdAt: e.createdAt,
        payerName: e.payerName,
        hasFxConversion: e.hasFxConversion,
      ),
  ];

  static List<Expense> expensesFor(String tripId) =>
      tripId == hkTripId ? hkExpenses : <Expense>[];

  // ---------------------------------------------------------------------
  // Balances, computed with the production engines.
  // ---------------------------------------------------------------------

  static List<MemberBalance> balancesFor(String tripId) {
    if (tripId != hkTripId) {
      return <MemberBalance>[
        MemberBalance(
          memberId: aliceId,
          paidMinor: 0,
          owesMinor: 0,
          settledInMinor: 0,
          settledOutMinor: 0,
          currencyCode: 'EUR',
        ),
      ];
    }

    final List<TripMember> members = membersFor(tripId);
    final Map<String, MemberBalance> map = <String, MemberBalance>{
      for (final TripMember m in members)
        m.userId: MemberBalance(
          memberId: m.userId,
          paidMinor: 0,
          owesMinor: 0,
          settledInMinor: 0,
          settledOutMinor: 0,
          currencyCode: 'HKD',
        ),
    };

    for (final Expense expense in hkExpenses) {
      if (expense.isPersonal) continue;
      final MemberBalance? payer = map[expense.paidBy];
      if (payer != null) {
        map[expense.paidBy] = payer.copyWith(
          paidMinor: payer.paidMinor + expense.baseAmountMinor,
        );
      }
      for (final ExpenseShareEntry share in expense.shares) {
        final MemberBalance? owed = map[share.userId];
        if (owed != null) {
          map[share.userId] = owed.copyWith(
            owesMinor: owed.owesMinor + share.baseAmountMinor,
          );
        }
      }
    }

    // One recorded settlement: Dana paid Alice back HKD 1,000.
    final MemberBalance dana = map[danaId]!;
    map[danaId] = dana.copyWith(settledOutMinor: 100000);
    final MemberBalance alice = map[aliceId]!;
    map[aliceId] = alice.copyWith(settledInMinor: 100000);

    return map.values.toList();
  }

  static List<SettlementTransfer> suggestionsFor(String tripId) {
    if (tripId != hkTripId) return const <SettlementTransfer>[];
    final Map<String, MemberBalance> map = <String, MemberBalance>{
      for (final MemberBalance b in balancesFor(tripId)) b.memberId: b,
    };
    return SettlementEngine.simplify(map, 'HKD');
  }

  static List<Settlement> settlementsFor(String tripId) => tripId == hkTripId
      ? <Settlement>[
          Settlement(
            id: 'demo-settle-1',
            tripId: tripId,
            fromUserId: danaId,
            toUserId: aliceId,
            amountMinor: 100000,
            currency: 'HKD',
            baseAmountMinor: 100000,
            status: SettlementStatus.recorded,
            method: SettlementMethod.bankTransfer,
            reference: 'DEMO-REF-0001',
            notes: 'Dana paid Alice back after the first night.',
            settledAt: _today.subtract(const Duration(days: 5)),
            createdAt: _today.subtract(const Duration(days: 5)),
            fromName: 'Dana Rivera',
            toName: 'Alice Nakamura',
          ),
        ]
      : <Settlement>[];

  // ---------------------------------------------------------------------
  // Budget, itinerary, bookings, packing
  // ---------------------------------------------------------------------

  static Budget budgetFor(String tripId) {
    if (tripId != hkTripId) {
      return Budget(
        id: 'demo-budget-lx',
        tripId: tripId,
        currency: 'EUR',
        totalMinor: 90000,
        contingencyMinor: 9000,
        dayCount: 5,
        remainingDays: 5,
      );
    }

    final List<({ExpenseCategory category, int planned, bool essential})>
    plan = <({ExpenseCategory category, int planned, bool essential})>[
      (category: ExpenseCategory.flights, planned: 900000, essential: true),
      (
        category: ExpenseCategory.accommodation,
        planned: 800000,
        essential: true,
      ),
      (category: ExpenseCategory.food, planned: 500000, essential: false),
      (
        category: ExpenseCategory.localTransport,
        planned: 250000,
        essential: false,
      ),
      (category: ExpenseCategory.activities, planned: 350000, essential: false),
      (category: ExpenseCategory.shopping, planned: 200000, essential: false),
      (category: ExpenseCategory.insurance, planned: 80000, essential: true),
      (category: ExpenseCategory.visaFees, planned: 40000, essential: true),
      (
        category: ExpenseCategory.connectivity,
        planned: 40000,
        essential: false,
      ),
      (category: ExpenseCategory.medical, planned: 80000, essential: true),
    ];

    final Map<String, int> actual = <String, int>{};
    for (final Expense expense in hkExpenses) {
      if (expense.isPersonal) continue;
      actual[expense.category.id] =
          (actual[expense.category.id] ?? 0) + expense.baseAmountMinor;
    }

    return Budget(
      id: 'demo-budget-hk',
      tripId: tripId,
      currency: 'HKD',
      totalMinor: 3200000,
      contingencyMinor: 320000,
      dailyLimitMinor: 1330000,
      alertThresholdPct: 80,
      dayCount: 4,
      remainingDays: 4,
      notes: 'Demo budget. Figures are invented for illustration.',
      categories: <BudgetCategoryAllocation>[
        for (final ({int planned, bool essential, ExpenseCategory category}) row
            in plan)
          BudgetCategoryAllocation(
            id: 'demo-cat-${row.category.id}',
            category: row.category,
            plannedMinor: row.planned,
            actualMinor: actual[row.category.id] ?? 0,
            isEssential: row.essential,
          ),
      ],
    );
  }

  static List<ItineraryDay> itineraryFor(String tripId) {
    final Trip trip = trips.firstWhere(
      (Trip t) => t.id == tripId,
      orElse: () => trips.first,
    );
    final List<ItineraryDay> days = <ItineraryDay>[];
    for (var i = 0; i < trip.dayCount; i++) {
      days.add(
        ItineraryDay(
          id: '$tripId-day-${i + 1}',
          tripId: tripId,
          dayNumber: i + 1,
          date: trip.startDate.add(Duration(days: i)),
        ),
      );
    }

    if (tripId != hkTripId) {
      return <ItineraryDay>[
        days.first.copyWith(
          title: 'Arrival in Lisbon',
          notes: 'Nothing booked yet — this is a draft plan.',
        ),
      ];
    }

    DateTime at(int day, int hour, [int minute = 0]) =>
        DateTime(2000, 1, day, hour, minute);

    return <ItineraryDay>[
      days[0].copyWith(
        title: 'Central and the harbour',
        items: <ItineraryItem>[
          ItineraryItem(
            id: 'demo-it-1',
            tripId: hkTripId,
            dayId: 'demo-day-1',
            title: 'Breakfast at Australia Dairy Company',
            kind: ItineraryItemKind.restaurant,
            description: 'Classic dai pai dong. Get there before 9am or expect a queue on the weekend.',
            startTime: at(1, 8, 30),
            endTime: at(1, 9, 30),
            address: '47 Parkes Street, Central',
            latitude: 22.2949,
            longitude: 114.17,
            costMinor: 60000,
            costCurrency: 'HKD',
            position: 0,
          ),
          ItineraryItem(
            id: 'demo-it-2',
            tripId: hkTripId,
            dayId: 'demo-day-1',
            title: 'Hong Kong Museum of Art',
            kind: ItineraryItemKind.attraction,
            description: 'Harbourfront campus. Opening hours change — check the official site before you go.',
            startTime: at(1, 10, 30),
            endTime: at(1, 12, 30),
            address: '10 Salisbury Road, Central',
            latitude: 22.2936,
            longitude: 114.1707,
            costMinor: 0,
            costCurrency: 'HKD',
            position: 1,
          ),
          ItineraryItem(
            id: 'demo-it-3',
            tripId: hkTripId,
            dayId: 'demo-day-1',
            title: 'Star Ferry across the harbour',
            kind: ItineraryItemKind.transport,
            description:
                'TST to Central. Cheap, fast, and the best view in the city.',
            startTime: at(1, 13, 0),
            endTime: at(1, 13, 30),
            address: 'Star Ferry Pier, Tsim Sha Tsui',
            latitude: 22.2933,
            longitude: 114.174,
            costMinor: 1000,
            costCurrency: 'HKD',
            position: 2,
          ),
          ItineraryItem(
            id: 'demo-it-4',
            tripId: hkTripId,
            dayId: 'demo-day-1',
            title: 'Dim sum lunch in Sham Shui Po',
            kind: ItineraryItemKind.restaurant,
            description: 'Old teahouses. Sit upstairs — quieter and cheaper.',
            startTime: at(1, 14, 0),
            endTime: at(1, 16, 0),
            address: 'Kite Street, Sham Shui Po',
            latitude: 22.3303,
            longitude: 114.1622,
            costMinor: 90000,
            costCurrency: 'HKD',
            position: 3,
          ),
          ItineraryItem(
            id: 'demo-it-5',
            tripId: hkTripId,
            dayId: 'demo-day-1',
            title: "Dragon's Ridge sunset hike",
            kind: ItineraryItemKind.experience,
            description: 'About 6 km, moderate. Bring water and shoes with grip. Allow time to get back down before dark.',
            startTime: at(1, 16, 30),
            endTime: at(1, 19, 30),
            address: 'Tai Tam Reservoir',
            latitude: 22.407,
            longitude: 114.148,
            costMinor: 0,
            costCurrency: 'HKD',
            position: 4,
          ),
        ],
      ),
      days[1].copyWith(
        title: 'Outlying islands',
        items: <ItineraryItem>[
          ItineraryItem(
            id: 'demo-it-6',
            tripId: hkTripId,
            dayId: 'demo-day-2',
            title: 'Morning at Tai O fishing village',
            kind: ItineraryItemKind.attraction,
            description:
                'Stilt houses and the Sunday market if you time it right.',
            startTime: at(2, 9, 0),
            endTime: at(2, 12, 0),
            address: 'Tai O, Lantau Island',
            latitude: 22.2488,
            longitude: 113.9436,
            costMinor: 40000,
            costCurrency: 'HKD',
            position: 0,
          ),
          ItineraryItem(
            id: 'demo-it-7',
            tripId: hkTripId,
            dayId: 'demo-day-2',
            title: 'Ngong Ping cable car and Big Buddha',
            kind: ItineraryItemKind.experience,
            description:
                'Combine with the bus back down. Book the return together.',
            startTime: at(2, 14, 0),
            endTime: at(2, 18, 0),
            address: 'Ngong Ping, Lantau Island',
            latitude: 22.2659,
            longitude: 113.9436,
            costMinor: 180000,
            costCurrency: 'HKD',
            position: 1,
          ),
        ],
      ),
      days[2].copyWith(
        title: 'Shenzhen day trip',
        items: <ItineraryItem>[
          ItineraryItem(
            id: 'demo-it-8',
            tripId: hkTripId,
            dayId: 'demo-day-3',
            title: 'Cross the border',
            kind: ItineraryItemKind.transport,
            description: 'Entry requirements depend on your nationality. Check the official immigration pages before you travel.',
            startTime: at(3, 8, 30),
            endTime: at(3, 10, 0),
            address: 'Lok Ma Chau checkpoint',
            latitude: 22.5146,
            longitude: 114.0409,
            costMinor: 0,
            costCurrency: 'HKD',
            position: 0,
          ),
          ItineraryItem(
            id: 'demo-it-9',
            tripId: hkTripId,
            dayId: 'demo-day-3',
            title: 'Dinner — hotpot',
            kind: ItineraryItemKind.restaurant,
            description: 'Paying in yuan, so this expense records a currency conversion.',
            startTime: at(3, 19, 0),
            endTime: at(3, 21, 30),
            address: 'Futian District, Shenzhen',
            latitude: 22.5411,
            longitude: 114.055,
            costMinor: 96000,
            costCurrency: 'HKD',
            position: 1,
          ),
        ],
      ),
      days[3].copyWith(
        title: 'Last morning and fly home',
        items: const <ItineraryItem>[],
      ),
    ];
  }

  static List<Booking> bookingsFor(String tripId) => tripId == hkTripId
      ? <Booking>[
          Booking(
            id: 'demo-book-1',
            tripId: tripId,
            kind: BookingKind.flight,
            provider: 'Demo Air',
            title: 'Outbound to Hong Kong',
            confirmationReference: 'DEMO-X7K2Q1',
            origin: 'LHR',
            destination: 'HKG',
            startsAt: tripDate(21).add(const Duration(hours: 10, minutes: 30)),
            endsAt: tripDate(21).add(const Duration(hours: 23)),
            amountPaidMinor: 2100000,
            currency: 'HKD',
            status: BookingStatus.confirmed,
            notes: 'Fictional booking used for the demo.',
          ),
          Booking(
            id: 'demo-book-2',
            tripId: tripId,
            kind: BookingKind.hotel,
            provider: 'Demo Stays',
            title: 'Tsim Sha Tsui apartment',
            confirmationReference: 'DEMO-HK-8842',
            address: 'Austin Road, Tsim Sha Tsui',
            startsAt: tripDate(21),
            endsAt: tripDate(24),
            amountPaidMinor: 768000,
            currency: 'HKD',
            cancellationDeadline: tripDate(18),
            status: BookingStatus.confirmed,
          ),
        ]
      : <Booking>[];

  static DateTime tripDate(int dayOffset) =>
      _today.add(Duration(days: dayOffset));

  static List<PackingList> packingFor(String tripId) => <PackingList>[
    PackingList(
      id: 'demo-list-$tripId',
      ownerId: aliceId,
      tripId: tripId,
      name: 'International travel',
      kind: 'predeparture',
      items: const <PackingItem>[
        PackingItem(
          id: 'p1',
          label: 'Valid passport',
          category: 'documents',
          isPacked: true,
          position: 0,
        ),
        PackingItem(
          id: 'p2',
          label: 'Visa / eTravel authorisation checked',
          category: 'documents',
          isPacked: true,
          position: 1,
        ),
        PackingItem(
          id: 'p3',
          label: 'Flight tickets',
          category: 'documents',
          isPacked: true,
          position: 2,
        ),
        PackingItem(
          id: 'p4',
          label: 'Travel insurance policy saved offline',
          category: 'insurance',
          isPacked: false,
          position: 3,
        ),
        PackingItem(
          id: 'p5',
          label: 'Emergency contacts written down',
          category: 'documents',
          isPacked: false,
          position: 4,
        ),
        PackingItem(
          id: 'p6',
          label: 'Type adapter',
          category: 'electronics',
          isPacked: false,
          position: 5,
        ),
        PackingItem(
          id: 'p7',
          label: 'Prescription medicines',
          category: 'health',
          isPacked: false,
          position: 6,
        ),
      ],
    ),
  ];

  static List<AppNotification> get notifications => <AppNotification>[
    AppNotification(
      id: 'demo-n1',
      kind: NotificationKind.departureReminder,
      title: 'Hong Kong starts in 21 days',
      body:
          'Departure is ${tripDate(21).toIso8601String().substring(0, 10)}. Check documents, bookings and packing.',
      tripId: hkTripId,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'demo-n2',
      kind: NotificationKind.budgetAlert,
      title: 'Budget alert: Hong Kong & Shenzhen long weekend',
      body: 'Spending has passed the alert threshold you set.',
      tripId: hkTripId,
      readAt: DateTime.now().subtract(const Duration(hours: 20)),
      createdAt: DateTime.now().subtract(const Duration(hours: 26)),
    ),
    AppNotification(
      id: 'demo-n3',
      kind: NotificationKind.settlement,
      title: 'Settlement recorded',
      body: 'Dana recorded a payment of HKD 1,000 to you.',
      tripId: hkTripId,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  static List<ActivityLog> activityFor(String tripId) => <ActivityLog>[
    ActivityLog(
      id: 'demo-a1',
      tripId: tripId,
      userId: danaId,
      entityType: 'expense',
      action: 'expense_added',
      summary: 'Dana added Birthday dinner at K Lok (HKD 4,560.00)',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      actorName: 'Dana Rivera',
    ),
    ActivityLog(
      id: 'demo-a2',
      tripId: tripId,
      userId: bobId,
      entityType: 'expense',
      action: 'expense_added',
      summary: 'Bob added Shenzhen hotpot dinner (CNY 880.00)',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      actorName: 'Bob Okafor',
    ),
    ActivityLog(
      id: 'demo-a3',
      tripId: tripId,
      userId: danaId,
      entityType: 'settlement',
      action: 'settlement_recorded',
      summary: 'Dana recorded a settlement of HKD 1,000 to Alice',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      actorName: 'Dana Rivera',
    ),
    ActivityLog(
      id: 'demo-a4',
      tripId: tripId,
      userId: aliceId,
      entityType: 'trip',
      action: 'invitation_sent',
      summary: 'Invitation sent to dana@demo.tripsplit.example',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      actorName: 'Alice Nakamura',
    ),
  ];

  /// Fictional, illustrative rates. Deliberately NOT live, and labelled as
  /// such everywhere they are shown.
  static List<CachedRate> ratesFor(String base) {
    const Map<String, double> perUsd = <String, double>{
      'USD': 1,
      'EUR': 0.92,
      'GBP': 0.79,
      'INR': 83.2,
      'JPY': 152.4,
      'HKD': 7.81,
      'SGD': 1.35,
      'AUD': 1.52,
      'CAD': 1.37,
      'THB': 36.1,
      'MYR': 4.71,
      'CHF': 0.89,
      'CNY': 7.24,
      'IDR': 15800,
      'AED': 3.67,
    };
    final double basePerUsd = perUsd[base] ?? 1;
    final DateTime fetched = DateTime.now().subtract(const Duration(hours: 3));
    return perUsd.entries
        .map(
          (e) => CachedRate(
            base: base,
            quote: e.key,
            rate: (1 / basePerUsd * e.value),
            provider: 'demo-fixture',
            fetchedAt: fetched,
            isIndicative: true,
            isStale: false,
          ),
        )
        .toList();
  }

  static Decimal demoRate(String from, String to) => Decimal.parse('1.0870');

  static String randomReference() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final _Det rnd = _Det(DateTime.now().millisecondsSinceEpoch);
    return List<String>.generate(
      8,
      (_) => chars[rnd.next(chars.length)],
    ).join();
  }

  static int mathMin(int a, int b) => math.min(a, b);
}
