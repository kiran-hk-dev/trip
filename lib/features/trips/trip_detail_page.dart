import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/models/planning.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';

/// Hub for one trip. Every module is scoped to this trip id.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTripIdProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Trip?> async = ref.watch(currentTripProvider);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object err, StackTrace _) => Scaffold(
        appBar: AppBar(),
        body: ErrorStateView(
          message: 'Could not load this trip.\n$err',
          onRetry: () => ref.invalidate(currentTripProvider),
        ),
      ),
      data: (Trip? trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              title: 'Trip not found',
              message: 'It may have been deleted, or you may no longer be a member of it.',
              onRetry: () => context.go('/trips'),
            ),
          );
        }
        return _TripDetailBody(trip: trip);
      },
    );
  }
}

class _TripDetailBody extends ConsumerWidget {
  const _TripDetailBody({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TripMember>> members = ref.watch(
      membersProvider(trip.id),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                trip.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: <Shadow>[
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
              background:
                  trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.network(
                          trip.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _FlatHero(color: theme.colorScheme.primary),
                          loadingBuilder: (
                            BuildContext c,
                            Widget child,
                            ImageChunkEvent? p,
                          ) => p == null ? child : const SkeletonBox(),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.transparent,
                                Color(0xB3000000),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _FlatHero(color: theme.colorScheme.primary),
            ),
            actions: <Widget>[
              PopupMenuButton<String>(
                onSelected: (String value) =>
                    _handleAction(context, ref, value),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit trip'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy_all_outlined),
                      title: Text('Duplicate'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('Archive'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (trip.myRole.isOwner)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (trip.myRole.isOwner)
                    const PopupMenuItem(
                      value: 'leave',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Leave trip'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      StatusPill(
                        label: trip.effectiveStatus.label,
                        tone: trip.isOngoing
                            ? StatusTone.positive
                            : StatusTone.info,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(
                        label: trip.travelStyle.label,
                        icon: Icons.tune,
                      ),
                      const Spacer(),
                      Text(
                        trip.dateRangeLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (trip.description != null &&
                      trip.description!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(trip.description!, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _MetaRow(
                    trip: trip,
                    members: members.value ?? const <TripMember>[],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _BudgetStrip(trip: trip)),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Trip modules',
              subtitle: 'Everything below is scoped to this trip',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: 104,
              ),
              delegate: SliverChildListDelegate(<Widget>[
                _ModuleTile(
                  icon: Icons.map_outlined,
                  label: 'Itinerary',
                  caption: '${trip.dayCount} days',
                  onTap: () => context.push('/trips/${trip.id}/itinerary'),
                ),
                _ModuleTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Budget',
                  caption: trip.baseCurrency,
                  onTap: () => context.push('/trips/${trip.id}/budget'),
                ),
                _ModuleTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Expenses',
                  caption: 'Split & settle',
                  onTap: () => context.push('/trips/${trip.id}/expenses'),
                  primary: true,
                ),
                _ModuleTile(
                  icon: Icons.balance_outlined,
                  label: 'Balances',
                  caption: 'Who owes whom',
                  onTap: () => context.push('/trips/${trip.id}/balances'),
                ),
                _ModuleTile(
                  icon: Icons.bar_chart_outlined,
                  label: 'Reports',
                  caption: 'CSV & PDF',
                  onTap: () => context.push('/trips/${trip.id}/reports'),
                ),
                _ModuleTile(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Bookings',
                  caption: 'Flights & stays',
                  onTap: () => context.push('/trips/${trip.id}/bookings'),
                ),
                _ModuleTile(
                  icon: Icons.folder_outlined,
                  label: 'Documents',
                  caption: 'Tickets & insurance',
                  onTap: () => context.push('/documents?trip=${trip.id}'),
                ),
                _ModuleTile(
                  icon: Icons.work_outline,
                  label: 'Visa & entry',
                  caption: 'Check requirements',
                  onTap: () => context.push('/trips/${trip.id}/visa'),
                ),
                _ModuleTile(
                  icon: Icons.checklist_outlined,
                  label: 'Packing',
                  caption: 'Checklist',
                  onTap: () => context.push('/trips/${trip.id}/packing'),
                ),
                _ModuleTile(
                  icon: Icons.group_outlined,
                  label: 'Members',
                  caption: '${trip.memberCount} people',
                  onTap: () => context.push('/trips/${trip.id}/members'),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/trips/${trip.id}/expenses/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final TripRepository repo = ref.read(tripRepositoryProvider);
    switch (action) {
      case 'edit':
        await context.push('/trips/new', extra: trip);
      case 'duplicate':
        if (AppConfig.demoMode) {
          if (context.mounted) {
            showFeedback(
              context,
              'Duplicating is disabled in demo mode.',
              isError: true,
            );
          }
          return;
        }
        try {
          final String id = await repo.duplicateTrip(trip.id);
          if (context.mounted) context.push('/trips/$id');
        } catch (err) {
          if (context.mounted) {
            showFeedback(
              context,
              err is RepositoryException ? err.message : 'Could not duplicate.',
              isError: true,
            );
          }
        }
      case 'archive':
        await repo.archiveTrip(trip.id, !trip.archived);
        ref.invalidate(tripsProvider);
        ref.invalidate(currentTripProvider);
        if (context.mounted) {
          showFeedback(
            context,
            trip.archived ? 'Trip restored.' : 'Trip archived.',
          );
        }
      case 'leave':
        final bool confirmed = await confirmDestructive(
          context,
          title: 'Leave this trip?',
          message: 'You will lose access to its expenses, itinerary and documents. The other members keep their copy.',
          confirmLabel: 'Leave',
        );
        if (!confirmed) return;
        await repo.leaveTrip(trip.id);
        ref.invalidate(tripsProvider);
        if (context.mounted) context.go('/trips');
      case 'delete':
        final bool confirmed = await confirmDestructive(
          context,
          title: 'Delete "${trip.name}"?',
          message: 'This permanently removes the trip and everything in it: expenses, balances, itineraries, bookings and documents. This cannot be undone.',
          confirmLabel: 'Delete permanently',
        );
        if (!confirmed) return;
        try {
          await repo.deleteTrip(trip.id);
          ref.invalidate(tripsProvider);
          if (context.mounted) context.go('/trips');
        } catch (err) {
          if (context.mounted) {
            showFeedback(
              context,
              err is RepositoryException ? err.message : 'Could not delete.',
              isError: true,
            );
          }
        }
    }
  }
}

class _FlatHero extends StatelessWidget {
  const _FlatHero({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(color: color.withValues(alpha: 0.12));
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.trip, required this.members});

  final Trip trip;
  final List<TripMember> members;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _Meta(icon: Icons.place_outlined, text: trip.destinationLabel),
        _Meta(
          icon: Icons.people_outline,
          text: '${trip.travelerCount} travellers',
        ),
        _Meta(
          icon: Icons.event_outlined,
          text: '${trip.dayCount} day${trip.dayCount == 1 ? '' : 's'}',
        ),
        if (trip.perTravelerBudgetMinor > 0)
          _Meta(
            icon: Icons.pie_chart_outline,
            text:
                '${Money(trip.perTravelerBudgetMinor, trip.baseCurrency).format()} per person',
          ),
        if (members.isNotEmpty)
          _Meta(
            icon: Icons.group_outlined,
            text: members
                .map((TripMember m) => m.displayName)
                .take(3)
                .join(', '),
          ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Live budget strip computed from the trip's real expenses.
class _BudgetStrip extends ConsumerWidget {
  const _BudgetStrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.demoMode) {
      final Budget budget = DemoFixtures.budgetFor(trip.id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppCard(
          onTap: () => context.push('/trips/${trip.id}/budget'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Budget', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    '${Money(budget.spentMinor, budget.currency).format()} of '
                    '${Money(budget.totalMinor, budget.currency).format()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BudgetProgressBar(
                value: budget.totalMinor == 0
                    ? 0
                    : budget.spentMinor / budget.totalMinor,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: FutureBuilder<Budget>(
        future: ref
            .watch(tripRepositoryProvider)
            .budget
            .load(
              trip.id,
              dayCount: trip.dayCount,
              daysRemaining: trip.isPast ? 0 : trip.daysUntilStart,
            ),
        builder: (BuildContext context, AsyncSnapshot<Budget> snapshot) {
          if (!snapshot.hasData) {
            return const AppCard(child: SkeletonBox(height: 48));
          }
          final Budget budget = snapshot.data!;
          return AppCard(
            onTap: () => context.push('/trips/${trip.id}/budget'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Budget',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${Money(budget.spentMinor, budget.currency).format()} of '
                      '${Money(budget.totalMinor, budget.currency).format()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                BudgetProgressBar(value: budget.utilisation),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  budget.isOverBudget
                      ? 'Over budget by ${Money(-budget.remainingMinor, budget.currency).format()}'
                      : '${Money(budget.remainingMinor, budget.currency).format()} left',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: budget.isOverBudget
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: primary
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: primary
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 20,
                    color: primary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                caption,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Members & invitations
// ---------------------------------------------------------------------
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TripMember>> async = ref.watch(
      membersProvider(widget.tripId),
    );
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: trip != null && trip.myRole.canAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _invite(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
        data: (List<TripMember> members) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            InlineBanner(
              message: 'Roles are enforced on the server. Hiding a button here does not grant or remove access — the database decides.',
              tone: StatusTone.info,
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final TripMember m in members)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(initials: m.initials, size: 44),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            m.displayName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            m.role.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (trip != null && trip.myRole.canAdmin && !m.role.isOwner)
                      PopupMenuButton<String>(
                        onSelected: (String value) =>
                            _changeRole(context, m, value),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              for (final TripRole role in <TripRole>[
                                TripRole.admin,
                                TripRole.editor,
                                TripRole.viewer,
                              ])
                                PopupMenuItem<String>(
                                  value: role.name,
                                  child: Text('Make ${role.label}'),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'remove',
                                child: Text('Remove from trip'),
                              ),
                            ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'What each role can do',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final TripRole role in TripRole.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StatusPill(label: role.label, dense: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        role.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    TripMember member,
    String action,
  ) async {
    final TripRepository repo = ref.read(tripRepositoryProvider);
    try {
      if (action == 'remove') {
        final bool ok = await confirmDestructive(
          context,
          title: 'Remove ${member.displayName}?',
          message: 'They lose access to this trip immediately. Their expenses stay, because deleting them would break the balance history for everyone else.',
          confirmLabel: 'Remove',
        );
        if (!ok) return;
        await repo.removeMember(widget.tripId, member.userId);
      } else {
        await repo.updateMemberRole(
          widget.tripId,
          member.userId,
          TripRole.fromId(action),
        );
      }
      ref.invalidate(membersProvider(widget.tripId));
      if (context.mounted) showFeedback(context, 'Membership updated.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : '$err',
          isError: true,
        );
      }
    }
  }

  Future<void> _invite(BuildContext context) async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Invitations are disabled in demo mode.',
        isError: true,
      );
      return;
    }
    final ({String email, TripRole role})? result =
        await showAppSheet<({String email, TripRole role})>(
          context: context,
          builder: (BuildContext context) => const _InviteSheet(),
        );
    if (result == null) return;

    try {
      final InvitationResult invite = await ref
          .read(tripRepositoryProvider)
          .inviteMember(
            tripId: widget.tripId,
            email: result.email,
            role: result.role,
          );
      if (!context.mounted) return;
      await showAppSheet<void>(
        context: context,
        builder: (BuildContext context) => _InviteLinkSheet(result: invite),
      );
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : '$err',
          isError: true,
        );
      }
    }
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _email = TextEditingController();
  TripRole _role = TripRole.editor;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Invite someone', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<TripRole>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: <DropdownMenuItem<TripRole>>[
              for (final TripRole role in <TripRole>[
                TripRole.admin,
                TripRole.editor,
                TripRole.viewer,
              ])
                DropdownMenuItem<TripRole>(
                  value: role,
                  child: Text(role.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (TripRole? r) => setState(() => _role = r ?? _role),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_role.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              final String email = _email.text.trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return;
              }
              Navigator.of(context).pop((email: email, role: _role));
            },
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );
  }
}

class _InviteLinkSheet extends StatelessWidget {
  const _InviteLinkSheet({required this.result});

  final InvitationResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Invitation created', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.emailSent
                ? 'An invitation was emailed to the address you entered.'
                : 'No email could be sent from this deployment. Share the link below directly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (result.link.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                result.link,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The link can only be used by the invited address and expires automatically.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
