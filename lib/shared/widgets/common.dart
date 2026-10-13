import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Placeholder shown while content loads. Uses a subtle shimmer that respects
/// the user's reduced-motion preference.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    double? height = 16,
    this.borderRadius = AppRadius.sm,
  }) : height = height,
       assert(
         height == null || height <= 100000.0,
         'SkeletonBox needs a finite height, or null to fill the parent. '
         'double.infinity is invalid here: a Column sizes itself to its '
         'children, so an infinite child height produces invalid constraints '
         'and overflows wherever the parent is unbounded. Wrap the box in '
         'Expanded and pass no height instead.',
       );

  final double? width;

  /// Fixed height, or null to fill whatever height the parent already
  /// constrains.
  ///
  /// Pass null inside an Expanded or AspectRatio to fill it. Do NOT pass
  /// `double.infinity`: a Column sizes itself to its children, so an infinite
  /// child height is invalid and overflows by an arbitrary amount wherever the
  /// parent is unbounded.
  final double? height;

  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ThemeData theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = reduceMotion ? 0.5 : _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              t,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBox(width: 160, height: 20),
            const SizedBox(height: AppSpacing.lg),
            for (int i = 0; i < lines; i++) ...<Widget>[
              SkeletonBox(height: 12, width: i.isEven ? double.infinity : 220),
              if (i < lines - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: const <Widget>[
          SkeletonBox(width: 44, height: 44, borderRadius: AppRadius.pill),
          SizedBox(width: AppSpacing.lg),
          Expanded(child: SkeletonBox(height: 14)),
        ],
      ),
    );
  }
}

/// Full-screen empty state with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Widget? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.huge,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 26 : 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
              if (secondaryAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                secondaryAction!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state that always explains what the user can do next.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }
}

/// Small status pill used for trip status, verification state and warnings.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = StatusTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final StatusTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    final (Color bg, Color fg) = switch (tone) {
      StatusTone.positive =>
        dark
            ? (
                AppColors.positive.withValues(alpha: 0.22),
                const Color(0xFF6EE7B7),
              )
            : (AppColors.positiveSoft, AppColors.positive),
      StatusTone.warning =>
        dark
            ? (
                AppColors.warning.withValues(alpha: 0.22),
                const Color(0xFFFCD34D),
              )
            : (AppColors.warningSoft, AppColors.warning),
      StatusTone.danger =>
        dark
            ? (
                AppColors.danger.withValues(alpha: 0.22),
                const Color(0xFFFCA5A5),
              )
            : (AppColors.dangerSoft, AppColors.danger),
      StatusTone.info =>
        dark
            ? (AppColors.info.withValues(alpha: 0.22), const Color(0xFF93C5FD))
            : (AppColors.infoSoft, AppColors.info),
      StatusTone.neutral =>
        dark
            ? (AppColors.darkSurfaceMuted, AppColors.darkInkMuted)
            : (AppColors.surfaceMuted, AppColors.inkMuted),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 2 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            SizedBox(width: dense ? 3 : AppSpacing.xs),
          ],
          Text(
            label,
            style:
                (dense
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { neutral, positive, warning, danger, info }

/// Section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xxl,
      AppSpacing.lg,
      AppSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Card wrapper that adds consistent padding and an optional onTap affordance.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.onTap,
    this.margin,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Padding(padding: padding, child: child);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: content,
              ),
      ),
    );
  }
}

/// Progress bar with tone thresholds so overspend is obvious at a glance.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.showOverflow = true,
  });

  /// 0.0 to 1.0+ (values above 1 represent an overspend).
  final double value;
  final double height;
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool over = value > 1;
    final bool near = value >= 0.8 && !over;
    final Color color = over
        ? theme.colorScheme.error
        : near
        ? AppColors.warning
        : theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        semanticsLabel: showOverflow ? 'Budget used' : null,
        semanticsValue: '${(value * 100).round()} percent of the budget used',
      ),
    );
  }
}

/// Inline banner used for stale data, demo mode, verification warnings and
/// offline state. Tone controls the colour but never removes the text, so a
/// warning can never be communicated by colour alone.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.icon,
    this.tone = StatusTone.info,
    this.action,
    this.onDismiss,
  });

  final String message;
  final IconData? icon;
  final StatusTone tone;
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    final (Color bg, Color fg, IconData defaultIcon) = switch (tone) {
      StatusTone.warning =>
        dark
            ? (
                AppColors.warning.withValues(alpha: 0.18),
                const Color(0xFFFCD34D),
                Icons.warning_amber_rounded,
              )
            : (
                AppColors.warningSoft,
                AppColors.warning,
                Icons.warning_amber_rounded,
              ),
      StatusTone.danger =>
        dark
            ? (
                AppColors.danger.withValues(alpha: 0.18),
                const Color(0xFFFCA5A5),
                Icons.error_outline,
              )
            : (AppColors.dangerSoft, AppColors.danger, Icons.error_outline),
      StatusTone.positive =>
        dark
            ? (
                AppColors.positive.withValues(alpha: 0.18),
                const Color(0xFF6EE7B7),
                Icons.check_circle_outline,
              )
            : (
                AppColors.positiveSoft,
                AppColors.positive,
                Icons.check_circle_outline,
              ),
      _ =>
        dark
            ? (
                AppColors.info.withValues(alpha: 0.18),
                const Color(0xFF93C5FD),
                Icons.info_outline,
              )
            : (AppColors.infoSoft, AppColors.info, Icons.info_outline),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon ?? defaultIcon, size: 20, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                height: 1.45,
              ),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
              color: fg,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Confirms destructive actions. Always requires an explicit confirmation and
/// spells out what will be lost.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Keep it',
  bool isDestructive = true,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Bottom sheet that scrolls and stays usable on a 320px-wide screen.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: builder,
  );
}

/// Toast-style feedback. Uses SnackBar for consistency with Material.
void showFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final ThemeData theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? theme.colorScheme.error
            : theme.colorScheme.inverseSurface,
        duration: Duration(seconds: isError ? 5 : 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// A labelled key/value row used throughout detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.monospace = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 4,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy-to-clipboard row for references and emergency numbers.
class CopyableValue extends StatelessWidget {
  const CopyableValue({super.key, required this.value, this.label, this.icon});

  final String value;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (label != null) Text(label!, style: theme.textTheme.bodySmall),
              SelectableText(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(ClipboardData(text: value));
            showFeedback(context, 'Copied $value');
          },
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          tooltip: 'Copy',
        ),
      ],
    );
  }
}
