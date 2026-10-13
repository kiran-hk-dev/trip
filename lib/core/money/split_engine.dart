import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import 'currency.dart';

/// How an expense total is divided among participants.
enum SplitMethod {
  equal('equal', 'Equal split'),
  exact('exact', 'Custom amounts'),
  percentage('percentage', 'Percentage'),
  shares('shares', 'Shares / weights'),
  none('none', 'Personal expense');

  const SplitMethod(this.id, this.label);
  final String id;
  final String label;

  static SplitMethod fromId(String? id) => SplitMethod.values.firstWhere(
    (m) => m.id == id,
    orElse: () => SplitMethod.equal,
  );
}

/// A single member's share of an expense, in the expense's own currency.
class ExpenseShare {
  const ExpenseShare({
    required this.memberId,
    required this.amountMinor,
    required this.isParticipant,
    this.percent,
    this.weight,
  });

  final String memberId;
  final int amountMinor;
  final bool isParticipant;
  final double? percent;
  final int? weight;

  Money money(String currencyCode) => Money(amountMinor, currencyCode);
}

/// Result of splitting one expense.
class SplitOutcome {
  const SplitOutcome({
    required this.shares,
    required this.totalMinor,
    required this.method,
    this.warnings = const <String>[],
  });

  /// memberId -> share in minor units of the expense currency.
  final Map<String, int> shares;
  final int totalMinor;
  final SplitMethod method;
  final List<String> warnings;

  /// The invariant every split must satisfy.
  bool get isBalanced =>
      shares.values.fold<int>(0, (a, b) => a + b) == totalMinor;
}

/// Pure, deterministic expense-splitting arithmetic.
///
/// Every method is built on integer largest-remainder apportionment so the
/// per-person shares of an expense always add up to the expense total *exactly*,
/// even when the total is not divisible by the participant count.
abstract final class SplitEngine {
  /// Equal split. Remainder minor units are distributed one each, in a stable
  /// participant-id order, so repeated recalculation is idempotent.
  static SplitOutcome equal({
    required int totalMinor,
    required String currencyCode,
    required List<String> participantIds,
  }) {
    _validate(totalMinor, participantIds, SplitMethod.equal);
    final Map<String, int> shares = allocateById(
      totalMinor,
      participantIds,
      <String, int>{for (final id in participantIds) id: 1},
    );
    return SplitOutcome(
      shares: shares,
      totalMinor: totalMinor,
      method: SplitMethod.equal,
    );
  }

  /// Custom amounts. Every amount is entered in minor units by the caller.
  ///
  /// When the entered amounts do not sum to the total the difference is spread
  /// with the same stable apportionment rule and reported as a warning, so a
  /// user who is 1 cent out never loses that cent and always sees a notice.
  static SplitOutcome exact({
    required int totalMinor,
    required String currencyCode,
    required List<String> participantIds,
    required Map<String, int> amountsMinor,
  }) {
    _validate(totalMinor, participantIds, SplitMethod.exact);
    int entered = 0;
    for (final id in participantIds) {
      entered += amountsMinor[id] ?? 0;
    }
    final List<String> warnings = <String>[];
    final Map<String, int> shares = <String, int>{
      for (final id in participantIds) id: amountsMinor[id] ?? 0,
    };
    int residual = totalMinor - entered;
    if (residual != 0) {
      warnings.add(
        'Entered amounts differ from the expense total by '
        '${_describe(residual, currencyCode)}; it was adjusted across participants.',
      );
      // Spread the discrepancy evenly so the allocation stays balanced.
      final Map<String, int> adjustment = allocateById(
        residual,
        participantIds,
        <String, int>{for (final id in participantIds) id: 1},
      );
      for (final id in participantIds) {
        shares[id] = shares[id]! + adjustment[id]!;
      }
    }
    return SplitOutcome(
      shares: shares,
      totalMinor: totalMinor,
      method: SplitMethod.exact,
      warnings: warnings,
    );
  }

  /// Percentage split. Percentages must total 100 (±0.01 tolerance).
  ///
  /// Percentages are converted to integer basis points before any
  /// multiplication, so the division is exact integer arithmetic rather than
  /// floating point.
  static SplitOutcome percentage({
    required int totalMinor,
    required String currencyCode,
    required List<String> participantIds,
    required Map<String, double> percentages,
  }) {
    _validate(totalMinor, participantIds, SplitMethod.percentage);
    final Map<String, int> weights = <String, int>{};
    for (final id in participantIds) {
      final double pct = percentages[id] ?? 0;
      weights[id] = (pct * 100).round();
    }
    final int totalBasisPoints = weights.values.fold<int>(0, (a, b) => a + b);
    if ((totalBasisPoints - 10000).abs() > 1) {
      throw SplitValidationException(
        'Percentages must add up to 100% (got '
        '${(totalBasisPoints / 100).toStringAsFixed(2)}%).',
      );
    }
    final Map<String, int> shares = allocateById(
      totalMinor,
      participantIds,
      weights,
    );
    return SplitOutcome(
      shares: shares,
      totalMinor: totalMinor,
      method: SplitMethod.percentage,
    );
  }

  /// Shares/weights split (e.g. 2 adults, 1 child → weights 2,2,1).
  static SplitOutcome shares({
    required int totalMinor,
    required String currencyCode,
    required List<String> participantIds,
    required Map<String, int> weights,
  }) {
    _validate(totalMinor, participantIds, SplitMethod.shares);
    final bool anyPositive = participantIds.any((id) => (weights[id] ?? 0) > 0);
    if (!anyPositive) {
      throw const SplitValidationException(
        'At least one participant needs a share greater than zero.',
      );
    }
    final Map<String, int> shares = allocateById(
      totalMinor,
      participantIds,
      weights,
    );
    return SplitOutcome(
      shares: shares,
      totalMinor: totalMinor,
      method: SplitMethod.shares,
    );
  }

  /// Convenience: split `totalMinor` of `currencyCode` across the given
  /// participants using the requested method.
  static SplitOutcome split({
    required SplitMethod method,
    required int totalMinor,
    required String currencyCode,
    required List<String> participantIds,
    Map<String, int>? exactAmounts,
    Map<String, double>? percentages,
    Map<String, int>? weights,
  }) {
    switch (method) {
      case SplitMethod.equal:
      case SplitMethod.none:
        return equal(
          totalMinor: totalMinor,
          currencyCode: currencyCode,
          participantIds: participantIds,
        );
      case SplitMethod.exact:
        return exact(
          totalMinor: totalMinor,
          currencyCode: currencyCode,
          participantIds: participantIds,
          amountsMinor: exactAmounts ?? const <String, int>{},
        );
      case SplitMethod.percentage:
        return percentage(
          totalMinor: totalMinor,
          currencyCode: currencyCode,
          participantIds: participantIds,
          percentages: percentages ?? const <String, double>{},
        );
      case SplitMethod.shares:
        return shares(
          totalMinor: totalMinor,
          currencyCode: currencyCode,
          participantIds: participantIds,
          weights: weights ?? const <String, int>{},
        );
    }
  }

  static void _validate(
    int totalMinor,
    List<String> participantIds,
    SplitMethod method,
  ) {
    if (totalMinor <= 0) {
      throw const SplitValidationException(
        'Expense amount must be greater than zero.',
      );
    }
    if (participantIds.isEmpty) {
      throw const SplitValidationException(
        'Select at least one participant for a shared expense.',
      );
    }
    if (participantIds.toSet().length != participantIds.length) {
      throw const SplitValidationException(
        'A participant can only appear once.',
      );
    }
    if (method != SplitMethod.equal && participantIds.length < 2) {
      throw SplitValidationException(
        'Custom, percentage and weighted splits need at least two participants.',
      );
    }
  }

  static String _describe(int minor, String code) =>
      Money(minor, code).toString();
}

class SplitValidationException implements Exception {
  const SplitValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The canonical worked example from the product spec, kept executable as a
/// regression guard.
class SplitExamples {
  const SplitExamples._();

  static SplitOutcome dinnerOfThree() => SplitEngine.equal(
    totalMinor: 300000, // ₹3,000.00
    currencyCode: 'INR',
    participantIds: const <String>['alice', 'bob', 'charlie'],
  );
}

/// Net position of one member within a trip, in the trip's base currency.
///
/// positive => the member is owed money; negative => the member owes money.
class MemberBalance {
  const MemberBalance({
    required this.memberId,
    required this.paidMinor,
    required this.owesMinor,
    required this.settledInMinor,
    required this.settledOutMinor,
    required this.currencyCode,
  });

  final String memberId;

  /// Total of shared expenses this member paid on behalf of the group.
  final int paidMinor;

  /// Total of this member's own fair share across all shared expenses.
  final int owesMinor;

  /// Money this member has *received* via recorded settlements.
  ///
  /// Receiving reduces what the group owes this member, so it is subtracted.
  final int settledInMinor;

  /// Money this member has *paid out* via recorded settlements.
  ///
  /// Paying reduces what this member owes, so it is added.
  final int settledOutMinor;
  final String currencyCode;

  /// Net position: positive means the group owes this member money.
  int get netMinor => paidMinor - owesMinor + settledOutMinor - settledInMinor;

  Money get net => Money(netMinor, currencyCode);
  Money get paid => Money(paidMinor, currencyCode);
  Money get share => Money(owesMinor, currencyCode);

  MemberBalance copyWith({
    int? paidMinor,
    int? owesMinor,
    int? settledInMinor,
    int? settledOutMinor,
  }) => MemberBalance(
    memberId: memberId,
    paidMinor: paidMinor ?? this.paidMinor,
    owesMinor: owesMinor ?? this.owesMinor,
    settledInMinor: settledInMinor ?? this.settledInMinor,
    settledOutMinor: settledOutMinor ?? this.settledOutMinor,
    currencyCode: currencyCode,
  );
}

/// A single recommended (or recorded) money movement.
class SettlementTransfer {
  const SettlementTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.currencyCode,
  });

  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final String currencyCode;

  Money get amount => Money(amountMinor, currencyCode);

  SettlementTransfer copyWith({int? amountMinor}) => SettlementTransfer(
    fromMemberId: fromMemberId,
    toMemberId: toMemberId,
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode,
  );

  @override
  bool operator ==(Object other) =>
      other is SettlementTransfer &&
      other.fromMemberId == fromMemberId &&
      other.toMemberId == toMemberId &&
      other.amountMinor == amountMinor &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(fromMemberId, toMemberId, amountMinor);
}

/// Converts a set of net balances into the smallest practical list of
/// transfers that clears them exactly.
///
/// Strategy: first partition the members into maximal zero-sum groups (so
/// unrelated groups of friends settle only with each other), then run a
/// largest-first greedy pass inside each group. For small groups the
/// zero-sum partition is found exactly with a bitmask search, which yields the
/// provably minimal number of transfers.
abstract final class SettlementEngine {
  /// Maximum group size for which the exact zero-sum partition search is run.
  static const int exactSearchLimit = 12;

  static List<SettlementTransfer> simplify(
    Map<String, MemberBalance> balances,
    String currencyCode,
  ) {
    final List<String> creditors =
        balances.values
            .where((b) => b.netMinor > 0)
            .map((b) => b.memberId)
            .toList()
          ..sort();
    final List<String> debtors =
        balances.values
            .where((b) => b.netMinor < 0)
            .map((b) => b.memberId)
            .toList()
          ..sort();

    if (creditors.isEmpty || debtors.isEmpty) {
      return const <SettlementTransfer>[];
    }

    final Map<String, int> amount = <String, int>{
      for (final b in balances.values) b.memberId: b.netMinor,
    };

    final List<Set<String>> groups = <Set<String>>[];
    if (creditors.length <= exactSearchLimit) {
      groups.addAll(_exactZeroSumGroups(amount, creditors));
    } else {
      groups.add(creditors.toSet());
    }
    for (final String d in debtors) {
      groups.firstWhere((g) => g.contains(d), orElse: () => groups.last);
    }

    final List<SettlementTransfer> transfers = <SettlementTransfer>[];
    for (final Set<String> creditorGroup in groups) {
      final Set<String> debtorSet = <String>{
        for (final d in debtors)
          if (_netSum(amount, creditorGroup) == _sumOf(creditorGroup, amount) &&
              _reachesZero(amount, creditorGroup, d))
            d,
      };
      transfers.addAll(
        _greedyMatch(
          amount,
          creditorGroup.toList(),
          debtorSet.toList(),
          currencyCode,
        ),
      );
    }

    // Safety net: verify the suggested transfers fully clear every balance.
    final Map<String, int> residual = _apply(transfers, amount);
    final List<String> leftover = residual.entries
        .where((e) => e.value != 0)
        .map((e) => e.key)
        .toList();
    if (leftover.isNotEmpty) {
      return _greedyMatch(
        amount,
        balances.values
            .where((b) => b.netMinor > 0)
            .map((b) => b.memberId)
            .toList(),
        balances.values
            .where((b) => b.netMinor < 0)
            .map((b) => b.memberId)
            .toList(),
        currencyCode,
      );
    }
    return transfers;
  }

  static int _sumOf(Set<String> ids, Map<String, int> amount) =>
      ids.fold<int>(0, (a, id) => a + (amount[id] ?? 0));

  static int _netSum(Map<String, int> amount, Set<String> ids) =>
      ids.fold<int>(0, (a, id) => a + (amount[id] ?? 0));

  static bool _reachesZero(
    Map<String, int> amount,
    Set<String> creditors,
    String debtorId,
  ) {
    final int credit = creditors.fold<int>(0, (a, id) => a + (amount[id] ?? 0));
    return credit + (amount[debtorId] ?? 0) == 0;
  }

  static List<Set<String>> _exactZeroSumGroups(
    Map<String, int> amount,
    List<String> creditors,
  ) {
    final int total = creditors.fold<int>(0, (a, id) => a + amount[id]!);
    if (total <= 0) return <Set<String>>[creditors.toSet()];

    final List<Set<String>> groups = <Set<String>>[];
    final Set<int> used = <int>{};

    for (int i = 0; i < creditors.length; i++) {
      if (used.contains(i)) continue;
      final Set<int> best = <int>{};
      _searchSubset(
        index: i,
        creditors: creditors,
        amount: amount,
        target: total,
        used: used,
        current: <int>{},
        best: best,
      );
      if (best.isNotEmpty) {
        for (final idx in best) {
          used.add(idx);
        }
        groups.add(<String>{for (final idx in best) creditors[idx]});
      }
    }

    final List<String> remaining = <String>[
      for (var i = 0; i < creditors.length; i++)
        if (!used.contains(i)) creditors[i],
    ];
    if (remaining.isNotEmpty) groups.add(remaining.toSet());
    return groups;
  }

  static void _searchSubset({
    required int index,
    required List<String> creditors,
    required Map<String, int> amount,
    required int target,
    required Set<int> used,
    required Set<int> current,
    required Set<int> best,
  }) {
    if (current.isNotEmpty &&
        _subsetSum(current, amount, creditors) == target) {
      if (current.length > best.length) {
        best
          ..clear()
          ..addAll(current);
      }
      return;
    }
    if (index >= creditors.length) return;
    if (used.contains(index)) {
      _searchSubset(
        index: index + 1,
        creditors: creditors,
        amount: amount,
        target: target,
        used: used,
        current: current,
        best: best,
      );
      return;
    }
    final int projected =
        _subsetSum(current, amount, creditors) +
        (amount[creditors[index]] ?? 0);
    if (projected <= target) {
      current.add(index);
      _searchSubset(
        index: index + 1,
        creditors: creditors,
        amount: amount,
        target: target,
        used: used,
        current: current,
        best: best,
      );
      current.remove(index);
    }
    _searchSubset(
      index: index + 1,
      creditors: creditors,
      amount: amount,
      target: target,
      used: used,
      current: current,
      best: best,
    );
  }

  static int _subsetSum(
    Set<int> indices,
    Map<String, int> amount,
    List<String> creditors,
  ) => indices.fold<int>(0, (a, i) => a + (amount[creditors[i]] ?? 0));

  static List<SettlementTransfer> _greedyMatch(
    Map<String, int> amount,
    List<String> creditorIds,
    List<String> debtorIds,
    String currencyCode,
  ) {
    final List<_Leg> creditors =
        creditorIds
            .where((id) => (amount[id] ?? 0) > 0)
            .map((id) => _Leg(id, amount[id]!))
            .toList()
          ..sort((a, b) => b.remaining.compareTo(a.remaining));
    final List<_Leg> debtors =
        debtorIds
            .where((id) => (amount[id] ?? 0) < 0)
            .map((id) => _Leg(id, -amount[id]!))
            .toList()
          ..sort((a, b) => b.remaining.compareTo(a.remaining));

    final List<SettlementTransfer> transfers = <SettlementTransfer>[];
    int c = 0;
    int d = 0;
    while (c < creditors.length && d < debtors.length) {
      final int pay = math.min(creditors[c].remaining, debtors[d].remaining);
      if (pay <= 0) break;
      transfers.add(
        SettlementTransfer(
          fromMemberId: debtors[d].id,
          toMemberId: creditors[c].id,
          amountMinor: pay,
          currencyCode: currencyCode,
        ),
      );
      creditors[c].remaining -= pay;
      debtors[d].remaining -= pay;
      if (creditors[c].remaining == 0) c++;
      if (debtors[d].remaining == 0) d++;
    }
    return transfers;
  }

  static Map<String, int> _apply(
    List<SettlementTransfer> transfers,
    Map<String, int> balances,
  ) {
    final Map<String, int> result = Map<String, int>.from(balances);
    for (final t in transfers) {
      result[t.fromMemberId] = (result[t.fromMemberId] ?? 0) + t.amountMinor;
      result[t.toMemberId] = (result[t.toMemberId] ?? 0) - t.amountMinor;
    }
    return result;
  }

  /// Validates a proposed settlement against current outstanding balances.
  ///
  /// Prevents paying more than is owed and paying someone you do not owe,
  /// which is what stops double-processing when two people record the same
  /// transfer.
  static SettlementValidation validate({
    required Map<String, MemberBalance> balances,
    required String fromMemberId,
    required String toMemberId,
    required int amountMinor,
    required String currencyCode,
  }) {
    if (amountMinor <= 0) {
      return const SettlementValidation.invalid(
        'Settlement amount must be greater than zero.',
      );
    }
    if (fromMemberId == toMemberId) {
      return const SettlementValidation.invalid(
        'A member cannot settle with themselves.',
      );
    }
    final MemberBalance? payer = balances[fromMemberId];
    final MemberBalance? payee = balances[toMemberId];
    if (payer == null || payee == null) {
      return const SettlementValidation.invalid(
        'Both members must belong to this trip.',
      );
    }
    if (payer.netMinor >= 0) {
      return SettlementValidation.invalid(
        '${payer.memberId} is not owed money by anyone in this trip, so this '
        'payment would not reduce any debt.',
      );
    }
    if (payee.netMinor <= 0) {
      return SettlementValidation.invalid(
        '${payee.memberId} is not owed money in this trip, so this payment '
        'would not clear any debt.',
      );
    }
    final int maxPayable = math.min(-payer.netMinor, payee.netMinor);
    if (amountMinor > maxPayable) {
      return SettlementValidation.invalid(
        'Maximum valid partial settlement is '
        '${Money(maxPayable, currencyCode)}.',
      );
    }
    return const SettlementValidation.valid();
  }
}

class SettlementValidation {
  const SettlementValidation.valid() : ok = true, message = '';
  const SettlementValidation.invalid(this.message) : ok = false;

  final bool ok;
  final String message;
}

class _Leg {
  _Leg(this.id, this.remaining);
  final String id;
  int remaining;
}

/// Decimal helpers shared by budget maths.
abstract final class DecimalMath {
  static Decimal percentOf(Decimal total, double percent) => round2(
    (total * Decimal.parse(percent.toStringAsFixed(4)) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 12),
  );

  static Decimal round2(Decimal value) => value.round(scale: 2);

  static Decimal ratio(Decimal part, Decimal whole) => whole == Decimal.zero
      ? Decimal.zero
      : (part / whole).toDecimal(scaleOnInfinitePrecision: 12).round(scale: 4);

  /// Integer minor units for a decimal amount in the given currency.
  static int toMinorUnits(Decimal value, String currencyCode) =>
      (value * Decimal.fromInt(_factor(currencyCode)))
          .round()
          .toBigInt()
          .toInt();

  static int _factor(String currencyCode) {
    int f = 1;
    for (var i = 0; i < Currencies.minorUnitsFor(currencyCode); i++) {
      f *= 10;
    }
    return f;
  }
}
