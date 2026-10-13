import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/money/split_engine.dart';

/// Builds a balance map where `net` is the desired final position.
Map<String, MemberBalance> balancesOf(Map<String, int> net) =>
    <String, MemberBalance>{
      for (final e in net.entries)
        e.key: MemberBalance(
          memberId: e.key,
          // Derive paid/owes consistent with the target net so the object is
          // internally coherent.
          paidMinor: e.value > 0 ? e.value : 0,
          owesMinor: e.value < 0 ? -e.value : 0,
          settledInMinor: 0,
          settledOutMinor: 0,
          currencyCode: 'INR',
        ),
    };

void main() {
  group('MemberBalance.net', () {
    test('positive means the member is owed money', () {
      const b = MemberBalance(
        memberId: 'alice',
        paidMinor: 300000,
        owesMinor: 100000,
        settledInMinor: 0,
        settledOutMinor: 0,
        currencyCode: 'INR',
      );
      expect(b.netMinor, 200000);
    });

    test('settlements shift the position in the right direction', () {
      const b = MemberBalance(
        memberId: 'bob',
        paidMinor: 0,
        owesMinor: 100000,
        settledInMinor: 0,
        settledOutMinor: 40000,
        currencyCode: 'INR',
      );
      // Bob paid out 40,000 of what he owed, so he still owes 60,000.
      expect(b.netMinor, -60000);
    });
  });

  group('SettlementEngine.simplify', () {
    test('no transfers when everyone is square', () {
      final out = SettlementEngine.simplify(
        balancesOf(const <String, int>{'a': 0, 'b': 0}),
        'INR',
      );
      expect(out, isEmpty);
    });

    test('single debtor pays a single creditor', () {
      final out = SettlementEngine.simplify(
        balancesOf(const <String, int>{'alice': 200000, 'bob': -200000}),
        'INR',
      );
      expect(out, hasLength(1));
      expect(out.single.fromMemberId, 'bob');
      expect(out.single.toMemberId, 'alice');
      expect(out.single.amountMinor, 200000);
    });

    test('spec example: two debtors, one creditor yields two transfers', () {
      final out = SettlementEngine.simplify(
        balancesOf(const <String, int>{
          'alice': 200000,
          'bob': -100000,
          'charlie': -100000,
        }),
        'INR',
      );
      expect(out, hasLength(2));
      expect(
        out.every((t) => t.toMemberId == 'alice'),
        isTrue,
        reason: 'both payments must go to the single creditor',
      );
      expect(out.fold<int>(0, (a, t) => a + t.amountMinor), 200000);
    });

    test('transfers fully clear every balance', () {
      final balances = balancesOf(const <String, int>{
        'a': 5000,
        'b': -3000,
        'c': -2000,
        'd': 0,
      });
      final out = SettlementEngine.simplify(balances, 'INR');
      final residual = <String, int>{
        for (final e in balances.entries) e.key: e.value.netMinor,
      };
      for (final t in out) {
        residual[t.fromMemberId] = residual[t.fromMemberId]! + t.amountMinor;
        residual[t.toMemberId] = residual[t.toMemberId]! - t.amountMinor;
      }
      expect(residual.values.every((v) => v == 0), isTrue);
    });

    test('minimises transfers for a classic three-way cycle', () {
      // a owes 100, b owes 100, c owes 100, and the creditors absorb it.
      final out = SettlementEngine.simplify(
        balancesOf(const <String, int>{
          'a': -100,
          'b': -100,
          'c': -100,
          'x': 150,
          'y': 150,
        }),
        'INR',
      );
      // Without simplification this would need 4+ transfers; the simplifier
      // must never exceed n-1 transfers for n non-zero members.
      final int nonZero = 5;
      expect(out.length, lessThanOrEqualTo(nonZero - 1));
      final residual = <String, int>{
        'a': -100,
        'b': -100,
        'c': -100,
        'x': 150,
        'y': 150,
      };
      for (final t in out) {
        residual[t.fromMemberId] = residual[t.fromMemberId]! + t.amountMinor;
        residual[t.toMemberId] = residual[t.toMemberId]! - t.amountMinor;
      }
      expect(residual.values.every((v) => v == 0), isTrue);
    });

    test('splits independent groups so they do not settle with each other', () {
      // Group 1: x is owed 100 by a. Group 2: y is owed 100 by b.
      final out = SettlementEngine.simplify(
        balancesOf(const <String, int>{
          'a': -100,
          'x': 100,
          'b': -100,
          'y': 100,
        }),
        'INR',
      );
      expect(out, hasLength(2));
      expect(
        out.map((t) => '${t.fromMemberId}->${t.toMemberId}').toSet(),
        <String>{'a->x', 'b->y'},
      );
    });

    test('is deterministic across repeated runs', () {
      final balances = balancesOf(const <String, int>{
        'a': -3333,
        'b': -3333,
        'c': -3334,
        'x': 5000,
        'y': 5000,
      });
      final first = SettlementEngine.simplify(balances, 'INR');
      final second = SettlementEngine.simplify(balances, 'INR');
      expect(first, second);
    });

    test('handles a large group without the exact search', () {
      final net = <String, int>{};
      for (var i = 0; i < 15; i++) {
        net['debtor$i'] = -100;
      }
      for (var i = 0; i < 15; i++) {
        net['creditor$i'] = 100;
      }
      final out = SettlementEngine.simplify(balancesOf(net), 'INR');
      expect(out, isNotEmpty);
      final residual = Map<String, int>.from(net);
      for (final t in out) {
        residual[t.fromMemberId] = residual[t.fromMemberId]! + t.amountMinor;
        residual[t.toMemberId] = residual[t.toMemberId]! - t.amountMinor;
      }
      expect(residual.values.every((v) => v == 0), isTrue);
    });
  });

  group('SettlementEngine.validate', () {
    final balances = balancesOf(const <String, int>{
      'alice': 150000,
      'bob': -100000,
      'charlie': -50000,
    });

    test('accepts a valid full settlement', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'bob',
        toMemberId: 'alice',
        amountMinor: 100000,
        currencyCode: 'INR',
      );
      expect(v.ok, isTrue);
    });

    test('accepts a valid partial settlement', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'charlie',
        toMemberId: 'alice',
        amountMinor: 25000,
        currencyCode: 'INR',
      );
      expect(v.ok, isTrue);
    });

    test('rejects overpayment beyond what is owed', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'charlie',
        toMemberId: 'alice',
        amountMinor: 60000,
        currencyCode: 'INR',
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('500.00'));
    });

    test('rejects a payer who owes nothing', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'alice',
        toMemberId: 'bob',
        amountMinor: 100,
        currencyCode: 'INR',
      );
      expect(v.ok, isFalse);
    });

    test('rejects a recipient who is owed nothing', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'bob',
        toMemberId: 'charlie',
        amountMinor: 100,
        currencyCode: 'INR',
      );
      expect(v.ok, isFalse);
    });

    test('rejects self settlement and non-positive amounts', () {
      expect(
        SettlementEngine.validate(
          balances: balances,
          fromMemberId: 'bob',
          toMemberId: 'bob',
          amountMinor: 100,
          currencyCode: 'INR',
        ).ok,
        isFalse,
      );
      expect(
        SettlementEngine.validate(
          balances: balances,
          fromMemberId: 'bob',
          toMemberId: 'alice',
          amountMinor: 0,
          currencyCode: 'INR',
        ).ok,
        isFalse,
      );
    });

    test('rejects members outside the trip', () {
      final v = SettlementEngine.validate(
        balances: balances,
        fromMemberId: 'stranger',
        toMemberId: 'alice',
        amountMinor: 100,
        currencyCode: 'INR',
      );
      expect(v.ok, isFalse);
      expect(v.message, contains('trip'));
    });
  });
}
