import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/misc.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AppNotification>> async = ref.watch(
      notificationsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await ref
                  .read(tripRepositoryProvider)
                  .notifications
                  .markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
        data: (List<AppNotification> items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nothing new',
              message:
                  'Trip invitations, budget alerts, settlement reminders and departure '
                  'reminders will appear here.',
            );
          }
          final List<AppNotification> unread = items
              .where((AppNotification n) => n.isUnread)
              .toList();
          final List<AppNotification> read = items
              .where((AppNotification n) => !n.isUnread)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              if (unread.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Unread',
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                ),
                for (final AppNotification n in unread) _Tile(notification: n),
              ],
              if (read.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Earlier',
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                ),
                for (final AppNotification n in read) _Tile(notification: n),
              ],
              const SizedBox(height: AppSpacing.huge),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      onTap: () async {
        await ref
            .read(tripRepositoryProvider)
            .notifications
            .markRead(notification.id);
        if (!context.mounted) return;
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
        if (notification.tripId != null) {
          context.push('/trips/${notification.tripId}');
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notification.isUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              notification.kind.emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: notification.isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (notification.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (notification.body != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(notification.body!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _relative(notification.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime when) {
    final Duration d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return '${when.day}/${when.month}/${when.year}';
  }
}

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (Ref ref) {
    return ref.watch(tripRepositoryProvider).notifications.list();
  },
);
