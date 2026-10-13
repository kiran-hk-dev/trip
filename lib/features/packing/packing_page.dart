import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/supabase_service.dart';
import '../../data/models/planning.dart';
import '../../data/models/trip.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import 'packing_template.dart';

final packingListsProvider = FutureProvider.autoDispose
    .family<List<PackingList>, String>((Ref ref, String tripId) {
      return ref.watch(tripRepositoryProvider).packing.list(tripId: tripId);
    });

class PackingPage extends ConsumerStatefulWidget {
  const PackingPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends ConsumerState<PackingPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PackingList>> async = ref.watch(
      packingListsProvider(widget.tripId),
    );
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Packing & checklists')),
      floatingActionButton: trip != null && trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _newList(context),
              icon: const Icon(Icons.add),
              label: const Text('New checklist'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
        data: (List<PackingList> lists) {
          if (lists.isEmpty) {
            return EmptyState(
              icon: Icons.checklist_outlined,
              title: 'No checklists yet',
              message:
                  'Start from a template for international travel, a beach holiday, cold '
                  'weather, business, family, adventure or a long stay — then edit it.',
              action: FilledButton.icon(
                onPressed: () => _fromTemplate(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Start from a template'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: lists.length,
            itemBuilder: (BuildContext context, int i) =>
                ChecklistCard(list: lists[i], tripId: widget.tripId),
          );
        },
      ),
    );
  }

  Future<void> _newList(BuildContext context) async {
    final ({String name, String kind})? result =
        await showAppSheet<({String name, String kind})>(
          context: context,
          builder: (BuildContext context) => const _NewListSheet(),
        );
    if (result == null) return;
    if (!context.mounted) return;
    ref.invalidate(packingListsProvider(widget.tripId));
    showFeedback(context, 'Checklist created. Add items to it.');
  }

  Future<void> _fromTemplate(BuildContext context) async {
    final String? slug = await showAppSheet<String>(
      context: context,
      builder: (BuildContext context) => const TemplatePickerSheet(),
    );
    if (slug == null) return;

    try {
      await ref
          .read(tripRepositoryProvider)
          .packing
          .createFromTemplate(slug: slug, tripId: widget.tripId);
      ref.invalidate(packingListsProvider(widget.tripId));
      if (context.mounted) {
        showFeedback(context, 'Checklist created from a template.');
      }
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

class ChecklistCard extends ConsumerStatefulWidget {
  const ChecklistCard({super.key, required this.list, required this.tripId});

  final PackingList list;
  final String tripId;

  @override
  ConsumerState<ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends ConsumerState<ChecklistCard> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<PackingItem>> byCategory = widget.list.byCategory;
    final List<String> categories = byCategory.keys.toList()..sort();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.list.name,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${widget.list.packedCount}/${widget.list.items.length}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          BudgetProgressBar(value: widget.list.completion),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(widget.list.completion * 100).round()}% packed',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: AppSpacing.xl),

          for (final String category in categories) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                category.replaceAll('_', ' ').toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final PackingItem item in byCategory[category]!)
              CheckboxListTile(
                value: item.isPacked,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: item.isPacked
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.isPacked
                        ? theme.textTheme.bodySmall?.color
                        : null,
                  ),
                ),
                secondary: item.quantity > 1
                    ? Text(
                        '×${item.quantity}',
                        style: theme.textTheme.bodySmall,
                      )
                    : null,
                onChanged: (bool? v) async {
                  await ref
                      .read(tripRepositoryProvider)
                      .packing
                      .setPacked(item.id, v ?? false);
                  ref.invalidate(packingListsProvider(widget.tripId));
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _addItem(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final ({String label, String category})? result =
        await showAppSheet<({String label, String category})>(
          context: context,
          builder: (BuildContext context) => const _AddItemSheet(),
        );
    if (result == null) return;
    await ref
        .read(tripRepositoryProvider)
        .packing
        .addItem(widget.list.id, result.label, category: result.category);
    ref.invalidate(packingListsProvider(widget.tripId));
  }
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final TextEditingController _label = TextEditingController();
  String _category = 'other';

  static const List<String> _categories = <String>[
    'clothing',
    'toiletries',
    'electronics',
    'health',
    'documents',
    'accessories',
    'money',
    'connectivity',
    'transport',
    'navigation',
    'other',
  ];

  @override
  void dispose() {
    _label.dispose();
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
          Text('Add an item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _label,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item',
              hintText: 'Universal adaptor',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: <DropdownMenuItem<String>>[
              for (final String c in _categories)
                DropdownMenuItem<String>(value: c, child: Text(c)),
            ],
            onChanged: (String? v) =>
                setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              if (_label.text.trim().isEmpty) return;
              Navigator.of(context)
                  .pop((label: _label.text.trim(), category: _category));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _NewListSheet extends StatefulWidget {
  const _NewListSheet();

  @override
  State<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends State<_NewListSheet> {
  final TextEditingController _name = TextEditingController();
  String _kind = 'packing';

  @override
  void dispose() {
    _name.dispose();
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
          Text('New checklist', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'packing',
                child: Text('Packing list'),
              ),
              DropdownMenuItem<String>(
                value: 'predeparture',
                child: Text('Pre-departure'),
              ),
              DropdownMenuItem<String>(
                value: 'visa',
                child: Text('Visa preparation'),
              ),
              DropdownMenuItem<String>(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (String? v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((
              name: _name.text.trim().isEmpty ? 'Checklist' : _name.text.trim(),
              kind: _kind,
            )),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class TemplatePickerSheet extends ConsumerWidget {
  const TemplatePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Choose a template',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final ChecklistTemplate t in checklistTemplates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.name),
                    subtitle: Text(
                      t.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(t.slug),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
